import Foundation

public enum LocaleHelperConstants {
    public static let appBundleIdentifier = "dev.offyotto.Locale"
    public static let helperLabel = "dev.offyotto.Locale.Helper"
    public static let helperPlistName = "\(helperLabel).plist"
    public static let releaseTeamIdentifier = "6VDP675K4L"
}

@objc(LocaleHelperXPCProtocol)
public protocol LocaleHelperXPCProtocol {
    func applyHosts(_ content: String, withReply reply: @escaping (Bool, String?) -> Void)
}
