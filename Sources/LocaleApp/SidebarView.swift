import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: LocaleStore
    @State private var hoveredID: UUID? = nil
    @State private var isSearchFocused = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SidebarSearchBar(text: $store.searchText, isFocused: $isSearchFocused)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider()
                .opacity(0.4)

            ScrollView {
                LazyVStack(spacing: 2, pinnedViews: []) {
                    // CONTEXTS section
                    SidebarSectionHeader(title: "CONTEXTS")

                    // Pinned contexts (Home + any user-pinned)
                    ForEach(store.filteredContexts.filter(\.isPinned)) { ctx in
                        SidebarContextRow(
                            context: ctx,
                            isSelected: store.selectedContextID == ctx.id,
                            isHovered: hoveredID == ctx.id,
                            onSelect: { store.selectedContextID = ctx.id }
                        )
                        .onHover { hoveredID = $0 ? ctx.id : nil }
                    }

                    // Remaining ungrouped contexts
                    ForEach(store.filteredContexts.filter { !$0.isPinned && $0.groupID == nil }) { ctx in
                        SidebarContextRow(
                            context: ctx,
                            isSelected: store.selectedContextID == ctx.id,
                            isHovered: hoveredID == ctx.id,
                            onSelect: { store.selectedContextID = ctx.id }
                        )
                        .onHover { hoveredID = $0 ? ctx.id : nil }
                    }

                    // Groups
                    if !store.groups.isEmpty {
                        SidebarSectionHeader(title: "GROUPS")
                        ForEach(store.groups) { group in
                            SidebarGroupSection(group: group)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)

            Divider()
                .opacity(0.4)

            // Bottom actions
            SidebarFooter()
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Section Header
struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Context Row
struct SidebarContextRow: View {
    let context: NetworkContext
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void

    @State private var isActivePulse = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                // Active/Color indicator
                ZStack {
                    Circle()
                        .fill(context.color.swiftUIColor.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(context.color.swiftUIColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(context.isActive && isActivePulse ? 1.3 : 1.0)
                        .animation(
                            context.isActive
                            ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                            : .default,
                            value: isActivePulse
                        )
                }

                // Name + host count
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.88))
                        .lineLimit(1)

                    if !context.hosts.isEmpty {
                        Text("\(context.hosts.count) host\(context.hosts.count == 1 ? "" : "s")")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                }

                Spacer()

                // Active checkmark
                if context.isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(context.color.swiftUIColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isSelected
                        ? context.color.swiftUIColor.opacity(0.14)
                        : (isHovered ? Color.primary.opacity(0.05) : Color.clear)
                    )
            )
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onAppear {
            if context.isActive { isActivePulse = true }
        }
        .contextMenu {
            Button("Activate") {}
            Button("Duplicate") {}
            Divider()
            Button("Delete", role: .destructive) {}
        }
    }
}

// MARK: - Group Section
struct SidebarGroupSection: View {
    @EnvironmentObject var store: LocaleStore
    let group: ContextGroup
    @State private var isExpanded = true
    @State private var hoveredID: UUID? = nil

    var groupContexts: [NetworkContext] {
        store.filteredContexts.filter { $0.groupID == group.id }
    }

    var body: some View {
        VStack(spacing: 2) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.28), value: isExpanded)

                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)

                    Text(group.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(groupContexts.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(groupContexts) { ctx in
                    SidebarContextRow(
                        context: ctx,
                        isSelected: store.selectedContextID == ctx.id,
                        isHovered: hoveredID == ctx.id,
                        onSelect: { store.selectedContextID = ctx.id }
                    )
                    .onHover { hoveredID = $0 ? ctx.id : nil }
                    .padding(.leading, 8)
                }
            }
        }
    }
}

// MARK: - Search Bar
struct SidebarSearchBar: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)

            TextField("Search contexts, hosts…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($focused)
                .onChange(of: focused) { isFocused = $1 }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6.5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .animation(.spring(response: 0.25), value: text.isEmpty)
    }
}

// MARK: - Footer
struct SidebarFooter: View {
    @EnvironmentObject var store: LocaleStore
    @State private var newContextHovered = false
    @State private var prefsHovered = false
    @State private var helpHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // New Context
            Button(action: { store.showingNewContext = true }) {
                Label("New Context", systemImage: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(newContextHovered ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { newContextHovered = $0 }
            .padding(.leading, 14)

            Spacer()

            // Preferences
            Button(action: { store.showingPreferences = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(prefsHovered ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
            .onHover { prefsHovered = $0 }

            // Help
            Button(action: { store.showingOnboarding = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(helpHovered ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
            .onHover { helpHovered = $0 }
            .padding(.trailing, 14)
        }
        .padding(.vertical, 9)
        .animation(.easeInOut(duration: 0.15), value: newContextHovered)
        .animation(.easeInOut(duration: 0.15), value: prefsHovered)
    }
}
