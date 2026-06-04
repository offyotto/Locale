import SwiftUI
import Foundation

// MARK: - HostEntry
struct HostEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var ipAddress: String
    var hostname: String
    var note: String = ""
    var isEnabled: Bool = true

    var isLoopback: Bool { ipAddress.hasPrefix("127.") }
    var isPrivate: Bool {
        ipAddress.hasPrefix("10.") ||
        ipAddress.hasPrefix("192.168.") ||
        (ipAddress.hasPrefix("172.") && {
            let parts = ipAddress.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]) {
                return second >= 16 && second <= 31
            }
            return false
        }())
    }

    var displayColor: Color {
        if !isEnabled { return .secondary }
        if isLoopback { return Color(red: 0.3, green: 0.7, blue: 0.4) }
        if isPrivate { return Color(red: 0.3, green: 0.55, blue: 0.95) }
        return Color(red: 0.9, green: 0.6, blue: 0.3)
    }
}

// MARK: - ContextColor
enum ContextColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case blue, green, orange, red, purple, yellow, teal, pink, gray

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .blue: return Color(red: 0.3, green: 0.55, blue: 0.95)
        case .green: return Color(red: 0.25, green: 0.72, blue: 0.42)
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .red: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .purple: return Color(red: 0.65, green: 0.35, blue: 0.9)
        case .yellow: return Color(red: 0.95, green: 0.75, blue: 0.2)
        case .teal: return Color(red: 0.2, green: 0.7, blue: 0.75)
        case .pink: return Color(red: 0.9, green: 0.4, blue: 0.65)
        case .gray: return Color(red: 0.55, green: 0.6, blue: 0.65)
        }
    }
}

// MARK: - NetworkContext
struct NetworkContext: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var color: ContextColor = .blue
    var isActive: Bool = false
    var isPinned: Bool = false
    var groupID: UUID? = nil
    var hosts: [HostEntry] = []
    var notes: String = ""
    var createdAt: Date = Date()
    var lastActivated: Date? = nil
    var icon: String = ""

    var activeHostCount: Int { hosts.filter(\.isEnabled).count }
    var disabledHostCount: Int { hosts.filter { !$0.isEnabled }.count }

    static let homeContext = NetworkContext(
        id: UUID(),
        name: "Home",
        color: .green,
        isActive: true,
        isPinned: true,
        hosts: [],
        icon: "house"
    )
}

// MARK: - ContextGroup
struct ContextGroup: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var isExpanded: Bool = true
}
