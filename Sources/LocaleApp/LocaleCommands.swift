import SwiftUI

struct LocaleCommands: Commands {
    @ObservedObject var store: LocaleStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Context") {
                store.showingNewContext = true
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Context") {
            Button("Activate Selected Context") {
                if let ctx = store.selectedContext {
                    store.activateContext(ctx)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(store.selectedContext == nil)

            Button("Deactivate Current Context") {
                store.deactivateAll()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button("Duplicate Context") {
                if let ctx = store.selectedContext {
                    store.duplicateContext(ctx)
                }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(store.selectedContext == nil)

            Button("Delete Context") {
                if let ctx = store.selectedContext {
                    store.deleteContext(ctx)
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(store.selectedContext == nil || store.selectedContext?.id == store.homeContext.id)

            Divider()

            Button("Export All Contexts…") {
                store.exportContexts()
            }

            Button("Import Contexts…") {
                store.importContexts()
            }
        }

        CommandGroup(after: .windowArrangement) {
            Button("Show Setup Guide") {
                store.showingOnboarding = true
            }
        }
    }
}
