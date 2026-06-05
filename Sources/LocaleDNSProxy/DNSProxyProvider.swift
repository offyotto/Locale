import Foundation
import LocaleShared
import NetworkExtension
import Darwin

final class DNSProxyProvider: NEDNSProxyProvider, @unchecked Sendable {
    private let flowRegistry = FlowRegistry()
    private let reloadQueue = DispatchQueue(label: "dev.offyotto.LocaleDNSProxy.reload")
    private var activeLookup: [String: String] = [:]
    private var changeObserver: NSObjectProtocol?

    override func startProxy(options: [String: Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        reloadMappings()
        changeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(LocaleDNSConstants.configurationChangedNotification),
            object: LocaleDNSConstants.appBundleIdentifier,
            queue: nil
        ) { [weak self] _ in
            self?.reloadMappings()
        }
        completionHandler(nil)
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if let changeObserver {
            DistributedNotificationCenter.default().removeObserver(changeObserver)
            self.changeObserver = nil
        }
        flowRegistry.closeAll()
        completionHandler()
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
        reloadMappings()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let udpFlow = flow as? NEAppProxyUDPFlow else {
            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
            return false
        }

        let handler = DNSUDPFlowHandler(
            flow: udpFlow,
            provider: self,
            onClose: { [weak self] handler in
                self?.flowRegistry.remove(handler)
            }
        )
        flowRegistry.insert(handler)
        handler.start()
        return true
    }

    fileprivate func lookup() -> [String: String] {
        reloadQueue.sync { activeLookup }
    }

    fileprivate func upstreamServers() -> [String] {
        let configuredServers = systemDNSSettings?
            .flatMap(\.servers)
            .filter { !$0.isEmpty } ?? []

        if configuredServers.isEmpty {
            return ["1.1.1.1", "8.8.8.8"]
        }
        return configuredServers
    }

    private func reloadMappings() {
        reloadQueue.async {
            do {
                self.activeLookup = try LocaleDNSConfigurationStore.load().lookup
            } catch {
                self.activeLookup = [:]
            }
        }
    }
}

private final class FlowRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [ObjectIdentifier: DNSUDPFlowHandler] = [:]

    func insert(_ handler: DNSUDPFlowHandler) {
        lock.lock()
        defer { lock.unlock() }
        handlers[ObjectIdentifier(handler)] = handler
    }

    func remove(_ handler: DNSUDPFlowHandler) {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeValue(forKey: ObjectIdentifier(handler))
    }

    func closeAll() {
        lock.lock()
        let currentHandlers = Array(handlers.values)
        handlers.removeAll()
        lock.unlock()

        currentHandlers.forEach { $0.close() }
    }
}

private final class DNSUDPFlowHandler: @unchecked Sendable {
    private let flow: NEAppProxyUDPFlow
    private weak var provider: DNSProxyProvider?
    private let onClose: (DNSUDPFlowHandler) -> Void
    private let queue = DispatchQueue(label: "dev.offyotto.LocaleDNSProxy.udp-flow")
    private let lock = NSLock()
    private var isClosed = false

    init(
        flow: NEAppProxyUDPFlow,
        provider: DNSProxyProvider,
        onClose: @escaping (DNSUDPFlowHandler) -> Void
    ) {
        self.flow = flow
        self.provider = provider
        self.onClose = onClose
    }

    func start() {
        flow.open(withLocalEndpoint: nil) { [weak self] (error: Error?) in
            guard let self else { return }
            if error == nil {
                self.readNextBatch()
            } else {
                self.close()
            }
        }
    }

    func close() {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            return
        }
        isClosed = true
        lock.unlock()

        flow.closeReadWithError(nil)
        flow.closeWriteWithError(nil)
        onClose(self)
    }

    private func readNextBatch() {
        flow.readDatagrams { [weak self] (datagrams: [Data]?, endpoints: [NWEndpoint]?, error: Error?) in
            guard let self else { return }
            guard error == nil,
                  let datagrams,
                  let endpoints,
                  datagrams.count == endpoints.count,
                  !datagrams.isEmpty else {
                self.close()
                return
            }

            for index in datagrams.indices {
                self.handle(datagram: datagrams[index], endpoint: endpoints[index])
            }
            self.readNextBatch()
        }
    }

    private func handle(datagram: Data, endpoint: NWEndpoint) {
        guard let provider else {
            close()
            return
        }

        if let packet = DNSPacket(datagram),
           let mappedIP = provider.lookup()[packet.question.hostname],
           let response = packet.response(for: mappedIP) {
            write(response, to: endpoint)
            return
        }

        let servers = provider.upstreamServers()
        queue.async { [weak self] in
            guard let self,
                  let response = DNSForwarder.forward(datagram, to: servers) else {
                return
            }
            self.write(response, to: endpoint)
        }
    }

    private func write(_ response: Data, to endpoint: NWEndpoint) {
        flow.writeDatagrams([response], sentBy: [endpoint]) { [weak self] (error: Error?) in
            if error != nil {
                self?.close()
            }
        }
    }
}

private enum DNSForwarder {
    static func forward(
        _ datagram: Data,
        to servers: [String]
    ) -> Data? {
        for server in servers {
            if let response = query(datagram, server: server) {
                return response
            }
        }
        return nil
    }

    private static func query(_ datagram: Data, server: String) -> Data? {
        if let response = queryIPv4(datagram, server: server) {
            return response
        }
        return queryIPv6(datagram, server: server)
    }

    private static func queryIPv4(_ datagram: Data, server: String) -> Data? {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(53).bigEndian
        guard server.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else {
            return nil
        }

        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                query(datagram, socketFamily: AF_INET, sockaddr: $0, length: socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    private static func queryIPv6(_ datagram: Data, server: String) -> Data? {
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = sa_family_t(AF_INET6)
        address.sin6_port = in_port_t(53).bigEndian
        guard server.withCString({ inet_pton(AF_INET6, $0, &address.sin6_addr) }) == 1 else {
            return nil
        }

        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                query(datagram, socketFamily: AF_INET6, sockaddr: $0, length: socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
    }

    private static func query(
        _ datagram: Data,
        socketFamily: Int32,
        sockaddr: UnsafePointer<sockaddr>,
        length: socklen_t
    ) -> Data? {
        let descriptor = socket(socketFamily, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let sent = datagram.withUnsafeBytes { buffer -> ssize_t in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return sendto(descriptor, baseAddress, buffer.count, 0, sockaddr, length)
        }
        guard sent == datagram.count else { return nil }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(descriptor, &buffer, buffer.count, 0)
        guard count > 0 else { return nil }
        return Data(buffer.prefix(count))
    }
}
