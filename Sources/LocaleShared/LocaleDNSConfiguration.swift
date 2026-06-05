import Foundation

public enum LocaleDNSConstants {
    public static let appBundleIdentifier = "dev.offyotto.Locale"
    public static let extensionBundleIdentifier = "dev.offyotto.Locale.LocaleDNSProxy"
    public static let appGroupIdentifier = "group.dev.offyotto.Locale"
    public static let activeConfigurationKey = "locale.activeDNSConfiguration"
    public static let configurationChangedNotification = "dev.offyotto.Locale.activeDNSConfigurationChanged"
}

public struct LocaleDNSHostMapping: Codable, Equatable, Sendable {
    public var hostname: String
    public var ipAddress: String

    public init(hostname: String, ipAddress: String) {
        self.hostname = LocaleDNSHostMapping.normalize(hostname)
        self.ipAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func normalize(_ hostname: String) -> String {
        hostname
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }
}

public struct LocaleActiveDNSConfiguration: Codable, Equatable, Sendable {
    public var contextName: String
    public var mappings: [LocaleDNSHostMapping]
    public var updatedAt: Date

    public init(contextName: String, mappings: [LocaleDNSHostMapping], updatedAt: Date = Date()) {
        self.contextName = contextName
        self.mappings = mappings
        self.updatedAt = updatedAt
    }

    public var lookup: [String: String] {
        Dictionary(uniqueKeysWithValues: mappings.map { ($0.hostname, $0.ipAddress) })
    }
}

public enum LocaleDNSConfigurationStore {
    public static func load() throws -> LocaleActiveDNSConfiguration {
        guard let defaults = UserDefaults(suiteName: LocaleDNSConstants.appGroupIdentifier) else {
            throw StoreError.unavailable
        }

        guard let data = defaults.data(forKey: LocaleDNSConstants.activeConfigurationKey) else {
            return LocaleActiveDNSConfiguration(contextName: "Home", mappings: [])
        }

        return try JSONDecoder().decode(LocaleActiveDNSConfiguration.self, from: data)
    }

    public static func save(_ configuration: LocaleActiveDNSConfiguration) throws {
        guard let defaults = UserDefaults(suiteName: LocaleDNSConstants.appGroupIdentifier) else {
            throw StoreError.unavailable
        }

        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: LocaleDNSConstants.activeConfigurationKey)
        defaults.synchronize()
        notifyChange()
    }

    public static func clear() throws {
        guard let defaults = UserDefaults(suiteName: LocaleDNSConstants.appGroupIdentifier) else {
            throw StoreError.unavailable
        }

        defaults.removeObject(forKey: LocaleDNSConstants.activeConfigurationKey)
        defaults.synchronize()
        notifyChange()
    }

    private static func notifyChange() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(LocaleDNSConstants.configurationChangedNotification),
            object: LocaleDNSConstants.appBundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public enum StoreError: LocalizedError {
        case unavailable

        public var errorDescription: String? {
            "Locale could not open its shared app group storage."
        }
    }
}
