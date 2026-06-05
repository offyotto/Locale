import Foundation
import LocaleShared
import ServiceManagement

enum LocaleHelperError: LocalizedError {
    case registrationFailed(String)
    case requiresApproval
    case notFound
    case connectionFailed(String)
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message):
            return "Could not register Locale Helper: \(message)"
        case .requiresApproval:
            return "Locale Helper needs approval in System Settings before it can update /etc/hosts."
        case .notFound:
            return "Locale Helper was not found inside the app bundle. Rebuild or reinstall Locale."
        case .connectionFailed(let message):
            return "Could not talk to Locale Helper: \(message)"
        case .rejected(let message):
            return message
        }
    }
}

actor LocaleHelperClient {
    static let shared = LocaleHelperClient()

    private let service = SMAppService.daemon(plistName: LocaleHelperConstants.helperPlistName)

    func applyHosts(_ content: String) async throws {
        try registerIfNeeded()

        let connection = NSXPCConnection(
            machServiceName: LocaleHelperConstants.helperLabel,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: LocaleHelperXPCProtocol.self)
        connection.resume()
        defer { connection.invalidate() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let replyBox = XPCReplyBox(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                replyBox.resume(throwing: LocaleHelperError.connectionFailed(error.localizedDescription))
            } as? LocaleHelperXPCProtocol

            guard let proxy else {
                replyBox.resume(throwing: LocaleHelperError.connectionFailed("The helper did not expose the expected XPC protocol."))
                return
            }

            proxy.applyHosts(content) { success, message in
                if success {
                    replyBox.resume()
                } else {
                    replyBox.resume(throwing: LocaleHelperError.rejected(message ?? "Locale Helper rejected the hosts update."))
                }
            }
        }
    }

    private func registerIfNeeded() throws {
        switch service.status {
        case .enabled:
            return
        case .notRegistered:
            do {
                try service.register()
            } catch {
                throw LocaleHelperError.registrationFailed(error.localizedDescription)
            }

            if service.status == .requiresApproval {
                throw LocaleHelperError.requiresApproval
            }
        case .requiresApproval:
            throw LocaleHelperError.requiresApproval
        case .notFound:
            throw LocaleHelperError.notFound
        @unknown default:
            throw LocaleHelperError.registrationFailed("Unknown helper status: \(service.status.rawValue)")
        }
    }
}

private final class XPCReplyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Void, Error>

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume() {
        guard claim() else { return }
        continuation.resume()
    }

    func resume(throwing error: Error) {
        guard claim() else { return }
        continuation.resume(throwing: error)
    }

    private func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return false }
        didResume = true
        return true
    }
}
