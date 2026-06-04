import SwiftUI

struct HostsTabView: View {
    let contextID: UUID
    let hosts: [HostEntry]
    @EnvironmentObject var store: LocaleStore

    @State private var newIP = ""
    @State private var newHostname = ""
    @State private var newNote = ""
    @State private var addFieldFocused = false
    @State private var hoveredHostID: UUID? = nil
    @State private var editingHostID: UUID? = nil
    @State private var sortOrder: HostSortOrder = .byIP
    @State private var appeared = false

    enum HostSortOrder { case byIP, byHostname, byStatus }

    var sortedHosts: [HostEntry] {
        switch sortOrder {
        case .byIP: return hosts.sorted { $0.ipAddress < $1.ipAddress }
        case .byHostname: return hosts.sorted { $0.hostname < $1.hostname }
        case .byStatus: return hosts.sorted { $0.isEnabled && !$1.isEnabled }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // How it works banner
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Text("How it works:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Locale writes these entries to /etc/hosts when this context is activated. Previous system entries are preserved and restored when you switch away.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.025))

            Divider().opacity(0.35)

            // Table header
            if !hosts.isEmpty {
                HostTableHeader(sortOrder: $sortOrder)
                Divider().opacity(0.35)
            }

            // Host rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedHosts.enumerated()), id: \.element.id) { idx, host in
                        HostRow(
                            host: host,
                            contextID: contextID,
                            isHovered: hoveredHostID == host.id,
                            isEditing: editingHostID == host.id,
                            onEdit: { editingHostID = editingHostID == host.id ? nil : host.id }
                        )
                        .onHover { hovered in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                hoveredHostID = hovered ? host.id : nil
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.8).delay(Double(idx) * 0.04),
                            value: appeared
                        )

                        if host.id != sortedHosts.last?.id {
                            Divider()
                                .padding(.leading, 16)
                                .opacity(0.25)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)

            Divider().opacity(0.35)

            // Add entry row
            AddHostRow(contextID: contextID)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Table Header
struct HostTableHeader: View {
    @Binding var sortOrder: HostsTabView.HostSortOrder

    var body: some View {
        HStack(spacing: 0) {
            Text("IP Address")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
                .padding(.leading, 20)
                .onTapGesture { sortOrder = .byIP }

            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 0.5)

            Text("Hostname")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 180, alignment: .leading)
                .padding(.leading, 12)
                .onTapGesture { sortOrder = .byHostname }

            Spacer()

            Text("Note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 120, alignment: .leading)

            Text("Actions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.025))
    }
}

// MARK: - Host Row
struct HostRow: View {
    let host: HostEntry
    let contextID: UUID
    let isHovered: Bool
    let isEditing: Bool
    let onEdit: () -> Void
    @EnvironmentObject var store: LocaleStore

    @State private var editIP: String = ""
    @State private var editHostname: String = ""
    @State private var editNote: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Enable toggle
            Button(action: { store.toggleHost(host, in: contextID) }) {
                Image(systemName: host.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(host.isEnabled ? host.displayColor : Color.secondary.opacity(0.4))
                    .frame(width: 28)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)

            // IP Address
            Text(host.ipAddress)
                .font(.system(size: 12.5))
                .foregroundStyle(host.isEnabled ? host.displayColor : .secondary.opacity(0.5))
                .frame(width: 115, alignment: .leading)
                .padding(.leading, 4)
                .opacity(host.isEnabled ? 1 : 0.6)

            Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 0.5).frame(height: 18)

            // Hostname
            Text(host.hostname)
                .font(.system(size: 12.5))
                .foregroundStyle(host.isEnabled ? Color.primary : Color.secondary.opacity(0.5))
                .frame(minWidth: 180, alignment: .leading)
                .padding(.leading, 12)
                .opacity(host.isEnabled ? 1 : 0.55)
                .strikethrough(!host.isEnabled, color: .secondary.opacity(0.4))

            Spacer()

            // Note
            HStack(spacing: 5) {
                Text(host.note)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)

                if !host.isEnabled {
                    Text("off")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.secondary.opacity(0.5)))
                }
            }
            .frame(minWidth: 120, alignment: .leading)

            // Actions (show on hover)
            HStack(spacing: 6) {
                if isHovered {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))

                    Button(action: { store.removeHost(host, from: contextID) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.35))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(width: 52, alignment: .trailing)
            .padding(.trailing, 16)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        }
        .frame(height: 36)
        .background(
            isHovered
            ? Color.primary.opacity(0.04)
            : (host.isEnabled ? Color.clear : Color.primary.opacity(0.01))
        )
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Add Host Row
struct AddHostRow: View {
    let contextID: UUID
    @EnvironmentObject var store: LocaleStore
    @State private var newIP = ""
    @State private var newHostname = ""
    @State private var newNote = ""
    @FocusState private var ipFocused: Bool

    var isValid: Bool {
        !newIP.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newHostname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            // IP field
            TextField("IP address", text: $newIP)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .frame(width: 130)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(ipFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .focused($ipFocused)
                .padding(.leading, 16)

            // Hostname field
            TextField("hostname.domain", text: $newHostname)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .frame(minWidth: 170)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )

            // Note field
            TextField("Note (optional)", text: $newNote)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(minWidth: 100)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )

            Spacer()

            // Add button
            Button(action: addHost) {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isValid ? Color.accentColor : Color.primary.opacity(0.08))
                    )
                    .foregroundStyle(isValid ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
            .keyboardShortcut(.return, modifiers: .command)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.015))
        .animation(.easeInOut(duration: 0.15), value: isValid)
    }

    private func addHost() {
        guard isValid else { return }
        store.addHost(
            to: contextID,
            ip: newIP.trimmingCharacters(in: .whitespaces),
            hostname: newHostname.trimmingCharacters(in: .whitespaces),
            note: newNote.trimmingCharacters(in: .whitespaces)
        )
        newIP = ""
        newHostname = ""
        newNote = ""
        ipFocused = true
    }
}
