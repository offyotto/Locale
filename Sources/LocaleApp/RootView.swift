import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: LocaleStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingNewContextSheet = false
    @State private var newContextName = ""
    @State private var newContextColor: ContextColor = .blue

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
            } detail: {
                if let ctx = store.selectedContext {
                    ContextDetailView(context: ctx)
                        .id(ctx.id) // Force full refresh on selection change
                } else {
                    EmptyStateView()
                }
            }
            .navigationSplitViewStyle(.balanced)

            // Toast overlay
            VStack {
                Spacer()
                if let toast = store.toastMessage {
                    ToastView(toast: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.toastMessage?.id)
        }
        .frame(minWidth: 760, minHeight: 520)
        .sheet(isPresented: $store.showingOnboarding) {
            OnboardingView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showingNewContext) {
            NewContextSheet(isPresented: $store.showingNewContext)
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showingPreferences) {
            PreferencesView(isPresented: $store.showingPreferences)
                .environmentObject(store)
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "globe")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Select a Context")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Choose a network context from the sidebar\nor create a new one.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
