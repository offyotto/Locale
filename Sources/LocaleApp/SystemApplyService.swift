import Foundation
import Network

enum SystemApplyError: LocalizedError {
    case invalidHost(String)
    case hostsReadFailed(String)
    case privilegedWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost(let message):
            return message
        case .hostsReadFailed(let message):
            return "Could not read /etc/hosts: \(message)"
        case .privilegedWriteFailed(let message):
            return "Could not write /etc/hosts: \(message)"
        }
    }
}

enum SystemApplyService {
    private static let hostsPath = "/etc/hosts"
    private static let beginMarker = "# BEGIN LOCALE MANAGED HOSTS"
    private static let endMarker = "# END LOCALE MANAGED HOSTS"

    static func applyHosts(for context: NetworkContext) async throws {
        let enabledHosts = try validatedHosts(from: context.hosts)
        let currentHosts: String

        do {
            currentHosts = try String(contentsOfFile: hostsPath, encoding: .utf8)
        } catch {
            throw SystemApplyError.hostsReadFailed(error.localizedDescription)
        }

        try writeBackup(of: currentHosts)

        let baseHosts = removingManagedBlock(from: currentHosts)
        let nextHosts = composingHostsFile(from: baseHosts, context: context, enabledHosts: enabledHosts)
        do {
            try await LocaleHelperClient.shared.applyHosts(nextHosts)
        } catch {
            throw SystemApplyError.privilegedWriteFailed(error.localizedDescription)
        }
    }

    private static func validatedHosts(from hosts: [HostEntry]) throws -> [HostEntry] {
        try hosts.filter(\.isEnabled).map { host in
            let ipAddress = host.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let hostname = host.hostname.trimmingCharacters(in: .whitespacesAndNewlines)

            guard IPv4Address(ipAddress) != nil || IPv6Address(ipAddress) != nil else {
                throw SystemApplyError.invalidHost("Invalid IP address: \(host.ipAddress)")
            }

            let allowedHostnameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
            guard !hostname.isEmpty,
                  hostname.rangeOfCharacter(from: allowedHostnameCharacters.inverted) == nil,
                  !hostname.contains("..") else {
                throw SystemApplyError.invalidHost("Invalid hostname: \(host.hostname)")
            }

            var sanitized = host
            sanitized.ipAddress = ipAddress
            sanitized.hostname = hostname
            sanitized.note = sanitized.note.replacingOccurrences(of: "\n", with: " ")
            return sanitized
        }
    }

    private static func removingManagedBlock(from content: String) -> String {
        var keptLines: [String] = []
        var pendingBlockLines: [String] = []
        var isInsideManagedBlock = false

        for line in content.components(separatedBy: .newlines) {
            if line == beginMarker {
                isInsideManagedBlock = true
                pendingBlockLines = [line]
                continue
            }

            if isInsideManagedBlock {
                pendingBlockLines.append(line)
                if line == endMarker {
                    isInsideManagedBlock = false
                    pendingBlockLines = []
                }
            } else {
                keptLines.append(line)
            }
        }

        if isInsideManagedBlock {
            keptLines.append(contentsOf: pendingBlockLines)
        }

        return keptLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }

    private static func composingHostsFile(
        from baseHosts: String,
        context: NetworkContext,
        enabledHosts: [HostEntry]
    ) -> String {
        var sections: [String] = []
        let trimmedBase = baseHosts.trimmingCharacters(in: .newlines)
        if !trimmedBase.isEmpty {
            sections.append(trimmedBase)
        }

        if !enabledHosts.isEmpty {
            var managedLines = [
                beginMarker,
                "# Context: \(sanitizedComment(context.name))",
                "# Applied: \(ISO8601DateFormatter().string(from: Date()))"
            ]

            managedLines.append(contentsOf: enabledHosts.map { host in
                let note = sanitizedComment(host.note)
                if note.isEmpty {
                    return "\(host.ipAddress)\t\(host.hostname)"
                }
                return "\(host.ipAddress)\t\(host.hostname)\t# \(note)"
            })
            managedLines.append(endMarker)
            sections.append(managedLines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    private static func sanitizedComment(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func writeBackup(of currentHosts: String) throws {
        let fileManager = FileManager.default
        let supportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let backupDirectory = supportDirectory
            .appendingPathComponent("Locale", isDirectory: true)
            .appendingPathComponent("HostsBackups", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = backupDirectory.appendingPathComponent("hosts-\(stamp).bak")
        try currentHosts.write(to: backupURL, atomically: true, encoding: .utf8)
    }

}
