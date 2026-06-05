import Foundation
import LocaleShared
import Network

enum SystemApplyError: LocalizedError {
    case invalidHost(String)
    case dnsProxyFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost(let message):
            return message
        case .dnsProxyFailed(let message):
            return "Could not update Locale DNS Proxy: \(message)"
        }
    }
}

enum SystemApplyService {
    static func applyHosts(for context: NetworkContext) async throws {
        let mappings = try validatedMappings(from: context.hosts)
        do {
            try await DNSProxyController.shared.apply(contextName: context.name, mappings: mappings)
        } catch {
            throw SystemApplyError.dnsProxyFailed(error.localizedDescription)
        }
    }

    static func clearDNSMappings() async throws {
        do {
            try await DNSProxyController.shared.clear()
        } catch {
            throw SystemApplyError.dnsProxyFailed(error.localizedDescription)
        }
    }

    private static func validatedMappings(from hosts: [HostEntry]) throws -> [LocaleDNSHostMapping] {
        try hosts.filter(\.isEnabled).map { host in
            let ipAddress = host.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let hostname = LocaleDNSHostMapping.normalize(host.hostname)

            guard IPv4Address(ipAddress) != nil || IPv6Address(ipAddress) != nil else {
                throw SystemApplyError.invalidHost("Invalid IP address: \(host.ipAddress)")
            }

            let allowedHostnameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
            guard !hostname.isEmpty,
                  hostname.rangeOfCharacter(from: allowedHostnameCharacters.inverted) == nil,
                  !hostname.contains("..") else {
                throw SystemApplyError.invalidHost("Invalid hostname: \(host.hostname)")
            }

            return LocaleDNSHostMapping(hostname: hostname, ipAddress: ipAddress)
        }
    }
}
