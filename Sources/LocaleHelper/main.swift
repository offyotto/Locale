import Foundation
import LocaleShared
import Security

private enum HelperError: LocalizedError {
    case invalidPayload
    case openFailed(String)
    case writeFailed(String)
    case metadataFailed(String)
    case replaceFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Locale refused to write an empty or invalid hosts file."
        case .openFailed(let message):
            return "Could not create the temporary hosts file: \(message)"
        case .writeFailed(let message):
            return "Could not write the temporary hosts file: \(message)"
        case .metadataFailed(let message):
            return "Could not set hosts file ownership or permissions: \(message)"
        case .replaceFailed(let message):
            return "Could not replace /etc/hosts: \(message)"
        }
    }
}

private final class LocaleHelperService: NSObject, LocaleHelperXPCProtocol {
    func applyHosts(_ content: String, withReply reply: @escaping (Bool, String?) -> Void) {
        do {
            try HostsWriter.apply(content)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }
}

private final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard ClientVerifier.isTrusted(connection) else {
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: LocaleHelperXPCProtocol.self)
        connection.exportedObject = LocaleHelperService()
        connection.resume()
        return true
    }
}

private enum ClientVerifier {
    static func isTrusted(_ connection: NSXPCConnection) -> Bool {
        let requirementText = """
        identifier "\(LocaleHelperConstants.appBundleIdentifier)" and certificate leaf[subject.OU] = "\(LocaleHelperConstants.releaseTeamIdentifier)"
        """

        if check(connection: connection, requirementText: requirementText) {
            return true
        }

        // Keeps ad-hoc local builds usable. Developer ID/App Store builds pass the stricter Team ID requirement above.
        return check(
            connection: connection,
            requirementText: #"identifier "\#(LocaleHelperConstants.appBundleIdentifier)""#
        )
    }

    private static func check(connection: NSXPCConnection, requirementText: String) -> Bool {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid as String: connection.processIdentifier] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code) == errSecSuccess,
              let code else {
            return false
        }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementText as CFString, SecCSFlags(), &requirement) == errSecSuccess,
              let requirement else {
            return false
        }

        return SecCodeCheckValidity(code, SecCSFlags(), requirement) == errSecSuccess
    }
}

private enum HostsWriter {
    private static let hostsURL = URL(fileURLWithPath: "/private/etc/hosts")
    private static let maxPayloadBytes = 1_048_576

    static func apply(_ content: String) throws {
        guard !content.isEmpty,
              content.utf8.count <= maxPayloadBytes,
              !content.contains("\0") else {
            throw HelperError.invalidPayload
        }

        let directory = hostsURL.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(".hosts.locale.\(UUID().uuidString)")
        try write(content, to: tempURL)

        do {
            try replaceHosts(with: tempURL)
            flushDNSCache()
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    private static func write(_ content: String, to url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard descriptor >= 0 else {
            throw HelperError.openFailed(String(cString: strerror(errno)))
        }
        var isClosed = false
        defer {
            if !isClosed {
                _ = close(descriptor)
            }
        }

        let data = Array(content.utf8)
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }

            var written = 0
            while written < buffer.count {
                let result = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: written),
                    buffer.count - written
                )

                if result < 0 {
                    throw HelperError.writeFailed(String(cString: strerror(errno)))
                }
                written += result
            }
        }

        if fsync(descriptor) != 0 {
            throw HelperError.writeFailed(String(cString: strerror(errno)))
        }

        if close(descriptor) != 0 {
            throw HelperError.writeFailed(String(cString: strerror(errno)))
        }
        isClosed = true
    }

    private static func replaceHosts(with tempURL: URL) throws {
        guard chown(tempURL.path, 0, 0) == 0,
              chmod(tempURL.path, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) == 0 else {
            throw HelperError.metadataFailed(String(cString: strerror(errno)))
        }

        guard rename(tempURL.path, hostsURL.path) == 0 else {
            throw HelperError.replaceFailed(String(cString: strerror(errno)))
        }
    }

    private static func flushDNSCache() {
        run("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
    }

    private static func run(_ executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = nil
        process.standardError = nil
        try? process.run()
        process.waitUntilExit()
    }
}

private let delegate = HelperDelegate()
private let listener = NSXPCListener(machServiceName: LocaleHelperConstants.helperLabel)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
