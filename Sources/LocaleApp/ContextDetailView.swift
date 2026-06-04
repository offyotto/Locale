import SwiftUI

enum DetailTab: String, CaseIterable {
    case hosts = "Hosts"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .hosts: return "list.bullet"
        case .settings: return "gearshape"
        }
    }
}

struct ContextDetailView: View {
    let context: NetworkContext
    @EnvironmentObject var store: LocaleStore
    @State private var selectedTab: DetailTab = .hosts
    @State private var isApplying = false
    @State private var headerAppeared = false

    var currentContext: NetworkContext {
        store.contexts.first { $0.id == context.id } ?? context
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            DetailHeader(context: currentContext, selectedTab: $selectedTab)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : -8)

            Divider().opacity(0.4)

            // Tab content
            Group {
                switch selectedTab {
                case .hosts:
                    HostsTabView(contextID: currentContext.id, hosts: currentContext.hosts)
                case .settings:
                    ContextSettingsTabView(context: currentContext)
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedTab)

            Divider().opacity(0.4)

            // Apply bar
            ApplyBar(context: currentContext)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                headerAppeared = true
            }
        }
    }
}

// MARK: - Detail Header
struct DetailHeader: View {
    let context: NetworkContext
    @Binding var selectedTab: DetailTab
    @EnvironmentObject var store: LocaleStore
    @State private var duplicateHovered = false
    @State private var deactivateHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Title row
            HStack(spacing: 12) {
                // Color dot + name
                HStack(spacing: 9) {
                    ZStack {
                        if context.isActive {
                            Circle()
                                .fill(context.color.swiftUIColor.opacity(0.2))
                                .frame(width: 20, height: 20)
                                .scaleEffect(1.0)
                        }
                        Circle()
                            .fill(context.color.swiftUIColor)
                            .frame(width: 10, height: 10)
                    }
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: context.isActive)

                    Text(context.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                if context.isActive {
                    ActiveBadge()
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    ActionButton(label: "Duplicate", icon: "doc.on.doc") {
                        store.duplicateContext(context)
                    }

                    if context.isActive {
                        ActionButton(label: "Deactivate", icon: "xmark.circle", style: .destructive) {
                            store.deactivateAll()
                        }
                    } else if context.isPinned && context.name == "Home" {
                        // Home shows nothing extra
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Stats row
            HStack(spacing: 10) {
                StatCard(value: "\(context.hosts.count)", label: "Entries")
                StatCard(value: "\(context.activeHostCount)", label: "Active")
                StatCard(value: "\(context.disabledHostCount)", label: "Disabled",
                         style: context.disabledHostCount > 0 ? .warning : .normal)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Tab bar
            DetailTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }
}

// MARK: - Active Badge
struct ActiveBadge: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(red: 0.25, green: 0.72, blue: 0.42))
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            Text("Active")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(red: 0.25, green: 0.72, blue: 0.42))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(Color(red: 0.25, green: 0.72, blue: 0.42).opacity(0.12))
                .overlay(
                    Capsule()
                        .strokeBorder(Color(red: 0.25, green: 0.72, blue: 0.42).opacity(0.3), lineWidth: 0.5)
                )
        )
        .onAppear { pulse = true }
    }
}

// MARK: - Stat Card
enum StatCardStyle { case normal, warning }

struct StatCard: View {
    let value: String
    let label: String
    var style: StatCardStyle = .normal

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(style == .warning && value != "0" ? Color(red: 0.95, green: 0.6, blue: 0.25) : .primary)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .frame(width: 70, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Tab Bar
struct DetailTabBar: View {
    @Binding var selectedTab: DetailTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { selectedTab = tab } }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .background(
                            Group {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.primary.opacity(0.08))
                                        .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 96)
                .contentShape(Rectangle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - Action Button
enum ActionButtonStyle { case `default`, destructive }

struct ActionButton: View {
    let label: String
    let icon: String
    var style: ActionButtonStyle = .default
    let action: () -> Void
    @State private var isHovered = false

    var fgColor: Color {
        switch style {
        case .default: return .primary
        case .destructive: return Color(red: 0.9, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isHovered ? fgColor : fgColor.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 5.5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Apply Bar
struct ApplyBar: View {
    let context: NetworkContext
    @EnvironmentObject var store: LocaleStore
    @State private var applyHovered = false

    var statusText: String {
        if context.isActive {
            return "\(context.name) is currently active · \(context.hosts.count) hosts entries applied"
        } else {
            return "\(context.name) is currently inactive · \(context.hosts.count) hosts entries pending"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Info text
            Text(statusText)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            // Revert
            if context.isActive {
                Button("Revert") {
                    store.deactivateAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }

            // Apply / Deactivate button
            Group {
                if store.isApplying {
                    HStack(spacing: 7) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text("Applying…")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.6))
                    )
                } else {
                    Button(action: {
                        if context.isActive { store.deactivateAll() }
                        else { store.activateContext(context) }
                    }) {
                        HStack(spacing: 6) {
                            Text(context.isActive ? "Active Context" : "Apply Context")
                                .font(.system(size: 13, weight: .semibold))
                            Text("⌘↩")
                                .font(.system(size: 11, weight: .regular))
                                .opacity(0.7)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(context.isActive
                                    ? Color(red: 0.25, green: 0.72, blue: 0.42)
                                    : Color.accentColor)
                                .shadow(
                                    color: (context.isActive
                                        ? Color(red: 0.25, green: 0.72, blue: 0.42)
                                        : Color.accentColor).opacity(applyHovered ? 0.4 : 0.2),
                                    radius: applyHovered ? 10 : 4, y: 2
                                )
                        )
                        .scaleEffect(applyHovered ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { applyHovered = $0 }
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: applyHovered)
                }
            }
            .animation(.spring(response: 0.3), value: store.isApplying)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(.background.opacity(0.6))
    }
}
