import SwiftUI
import AppKit

@main
struct LocaleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = LocaleStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            LocaleCommands(store: store)
        }

        MenuBarExtra("Locale", systemImage: "globe") {
            MenuBarView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil // Respect system dark/light
        // Set activation policy for menu bar + dock presence
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep alive as menu bar app
    }
}
