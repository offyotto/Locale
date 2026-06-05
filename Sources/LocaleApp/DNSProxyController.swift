import Foundation
import LocaleShared
import NetworkExtension
import SystemExtensions

enum DNSProxyControllerError: LocalizedError {
    case activationNeedsApproval
    case activationRequiresReboot
    case activationFailed(String)
    case preferencesFailed(String)

    var errorDescription: String? {
        switch self {
        case .activationNeedsApproval:
            return "Approve Locale DNS Proxy in System Settings, then apply the context again."
        case .activationRequiresReboot:
            return "Locale DNS Proxy will finish activating after a restart."
        case .activationFailed(let message):
            return "Could not activate Locale DNS Proxy: \(message)"
        case .preferencesFailed(let message):
            return "Could not update DNS proxy settings: \(message)"
        }
    }
}

actor DNSProxyController {
    static let shared = DNSProxyController()

    func apply(contextName: String, mappings: [LocaleDNSHostMapping]) async throws {
        let configuration = LocaleActiveDNSConfiguration(contextName: contextName, mappings: mappings)
        try LocaleDNSConfigurationStore.save(configuration)

        if mappings.isEmpty {
            try await setProxyEnabled(false)
        } else {
            try await SystemExtensionActivator.activate()
            try await setProxyEnabled(true)
        }
    }

    func clear() async throws {
        try LocaleDNSConfigurationStore.clear()
        try await setProxyEnabled(false)
    }

    private func setProxyEnabled(_ isEnabled: Bool) async throws {
        let manager = NEDNSProxyManager.shared()

        do {
            try await manager.loadFromPreferencesWithTimeout()
            let providerProtocol = NEDNSProxyProviderProtocol()
            providerProtocol.providerBundleIdentifier = LocaleDNSConstants.extensionBundleIdentifier
            providerProtocol.serverAddress = "Locale DNS Proxy"
            providerProtocol.providerConfiguration = [
                "appGroupIdentifier": LocaleDNSConstants.appGroupIdentifier,
                "configurationKey": LocaleDNSConstants.activeConfigurationKey
            ]

            manager.localizedDescription = "Locale"
            manager.providerProtocol = providerProtocol
            manager.isEnabled = isEnabled
            try await manager.saveToPreferencesWithTimeout()
        } catch {
            throw DNSProxyControllerError.preferencesFailed(error.localizedDescription)
        }
    }
}

private enum SystemExtensionActivator {
    static func activate() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = SystemExtensionRequestDelegate(continuation: continuation)
            SystemExtensionRequestDelegateStore.shared.insert(delegate)

            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: LocaleDNSConstants.extensionBundleIdentifier,
                queue: .main
            )
            request.delegate = delegate
            delegate.request = request
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }
}

private final class SystemExtensionRequestDelegateStore: @unchecked Sendable {
    static let shared = SystemExtensionRequestDelegateStore()
    private let lock = NSLock()
    private var delegates: [ObjectIdentifier: SystemExtensionRequestDelegate] = [:]

    func insert(_ delegate: SystemExtensionRequestDelegate) {
        lock.lock()
        defer { lock.unlock() }
        delegates[ObjectIdentifier(delegate)] = delegate
    }

    func remove(_ delegate: SystemExtensionRequestDelegate) {
        lock.lock()
        defer { lock.unlock() }
        delegates.removeValue(forKey: ObjectIdentifier(delegate))
    }
}

private final class SystemExtensionRequestDelegate: NSObject, OSSystemExtensionRequestDelegate, @unchecked Sendable {
    fileprivate weak var request: OSSystemExtensionRequest?
    private let lock = NSLock()
    private var didFinish = false
    private let continuation: CheckedContinuation<Void, Error>

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        finish(throwing: DNSProxyControllerError.activationNeedsApproval)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            finish()
        case .willCompleteAfterReboot:
            finish(throwing: DNSProxyControllerError.activationRequiresReboot)
        @unknown default:
            finish(throwing: DNSProxyControllerError.activationFailed("Unknown activation result: \(result.rawValue)"))
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        finish(throwing: DNSProxyControllerError.activationFailed(error.localizedDescription))
    }

    private func finish(throwing error: Error? = nil) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        SystemExtensionRequestDelegateStore.shared.remove(self)
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

private extension NEDNSProxyManager {
    func loadFromPreferencesWithTimeout() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = PreferenceOperationContinuation(continuation: continuation, operationName: "load DNS proxy preferences")
            operation.scheduleTimeout()
            loadFromPreferences { error in
                if let error {
                    operation.resume(throwing: error)
                } else {
                    operation.resume()
                }
            }
        }
    }

    func saveToPreferencesWithTimeout() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = PreferenceOperationContinuation(continuation: continuation, operationName: "save DNS proxy preferences")
            operation.scheduleTimeout()
            saveToPreferences { error in
                if let error {
                    operation.resume(throwing: error)
                } else {
                    operation.resume()
                }
            }
        }
    }
}

private final class PreferenceOperationContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private let operationName: String

    init(continuation: CheckedContinuation<Void, Error>, operationName: String) {
        self.continuation = continuation
        self.operationName = operationName
    }

    func scheduleTimeout() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            self.resume(
                throwing: DNSProxyControllerError.preferencesFailed(
                    "Timed out while trying to \(self.operationName). Check that Locale is signed with the DNS Proxy Network Extension entitlement."
                )
            )
        }
    }

    func resume() {
        finish { $0.resume() }
    }

    func resume(throwing error: Error) {
        finish { $0.resume(throwing: error) }
    }

    private func finish(_ resume: (CheckedContinuation<Void, Error>) -> Void) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()

        resume(continuation)
    }
}
