import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: LocaleStore
    @State private var hoveredID: UUID? = nil
    @State private var hoveredAction: MenuAction? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 9) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.blue.opacity(0.14)))
                Text("Locale")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let active = store.activeContext {
                    Text(active.name)
                        .font(.system(size: 11))
                        .foregroundStyle(active.color.swiftUIColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule().fill(active.color.swiftUIColor.opacity(0.12))
                        )
                        .lineLimit(1)
                }
            }

            Divider()

            // Contexts
            VStack(spacing: 2) {
                ForEach(store.contexts.prefix(8)) { ctx in
                    Button(action: { store.activateContext(ctx) }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ctx.color.swiftUIColor)
                                .frame(width: 7, height: 7)
                            Text(ctx.name)
                                .font(.system(size: 12.5))
                                .lineLimit(1)
                            Spacer()
                            if ctx.isActive {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(ctx.color.swiftUIColor)
                            }
                            Text("\(ctx.hosts.count)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(hoveredID == ctx.id ? Color.primary.opacity(0.07) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveredID = $0 ? ctx.id : nil }
                }
            }

            Divider()

            // Actions
            VStack(spacing: 2) {
                menuActionButton(
                    action: .open,
                    icon: "macwindow",
                    title: "Open Locale..."
                ) {
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionButton(
                    action: .quit,
                    icon: "power",
                    title: "Quit Locale"
                ) {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func menuActionButton(action: MenuAction, icon: String, title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12.5))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hoveredAction == action ? Color.primary.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hoveredAction = $0 ? action : nil }
    }

    private enum MenuAction {
        case open
        case quit
    }
}
