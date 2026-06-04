import SwiftUI

struct ContextSettingsTabView: View {
    let context: NetworkContext
    @EnvironmentObject var store: LocaleStore
    @State private var editedName: String = ""
    @State private var editedColor: ContextColor = .blue
    @State private var editedNotes: String = ""
    @State private var editedIcon: String = ""
    @State private var appeared = false
    @State private var isDirty = false

    init(context: NetworkContext) {
        self.context = context
        _editedName = State(initialValue: context.name)
        _editedColor = State(initialValue: context.color)
        _editedNotes = State(initialValue: context.notes)
        _editedIcon = State(initialValue: context.icon)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Context Name")
                    TextField("Name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                        .onChange(of: editedName) { isDirty = true }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.35).delay(0.0), value: appeared)

                // Color
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Context Color")

                    HStack(spacing: 10) {
                        ForEach(ContextColor.allCases) { color in
                            ColorSwatch(
                                color: color,
                                isSelected: editedColor == color,
                                onSelect: {
                                    withAnimation(.spring(response: 0.25)) {
                                        editedColor = color
                                        isDirty = true
                                    }
                                }
                            )
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.35).delay(0.05), value: appeared)

                // Icon (SF Symbol quick picks)
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Icon")

                    let icons = [
                        ("house", "Home"), ("lock.shield", "VPN"), ("hammer", "Dev"),
                        ("wifi", "WiFi"), ("ant", "Debug"), ("person", "Personal"),
                        ("building.2", "Office"), ("airplane", "Travel"), ("laptopcomputer", "Local"),
                        ("server.rack", "Server"), ("cloud", "Cloud"), ("globe", "Network")
                    ]

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(52)), count: 6), spacing: 8) {
                        ForEach(icons, id: \.0) { icon, label in
                            IconPicker(
                                iconName: icon,
                                label: label,
                                isSelected: editedIcon == icon,
                                color: editedColor,
                                onSelect: {
                                    withAnimation(.spring(response: 0.25)) {
                                        editedIcon = icon
                                        isDirty = true
                                    }
                                }
                            )
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.35).delay(0.1), value: appeared)

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Notes")
                    TextEditor(text: $editedNotes)
                        .font(.system(size: 13))
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.primary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                        .scrollContentBackground(.hidden)
                        .onChange(of: editedNotes) { isDirty = true }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.35).delay(0.15), value: appeared)

                // Metadata
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Metadata")
                    HStack {
                        MetaItem(label: "Created", value: context.createdAt.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        if let lastActive = context.lastActivated {
                            MetaItem(label: "Last activated", value: lastActive.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.primary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.35).delay(0.2), value: appeared)

                // Save / Delete actions
                HStack {
                    if !context.isPinned || context.name != "Home" {
                        Button(role: .destructive, action: { store.deleteContext(context) }) {
                            Label("Delete Context", systemImage: "trash")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color(red: 0.9, green: 0.3, blue: 0.3))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.25), lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if isDirty {
                        Button("Save Changes") {
                            saveChanges()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 3)
                        )
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.25), value: isDirty)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.35).delay(0.22), value: appeared)
            }
            .padding(20)
        }
        .scrollIndicators(.never)
        .onAppear {
            editedName = context.name
            editedColor = context.color
            editedNotes = context.notes
            editedIcon = context.icon
            withAnimation { appeared = true }
        }
    }

    private func saveChanges() {
        var updated = context
        updated.name = editedName.trimmingCharacters(in: .whitespaces).isEmpty ? context.name : editedName
        updated.color = editedColor
        updated.notes = editedNotes
        updated.icon = editedIcon
        store.updateContext(updated)
        isDirty = false
        store.showToast("Settings saved", type: .success)
    }
}

// MARK: - Color Swatch
struct ColorSwatch: View {
    let color: ContextColor
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 26, height: 26)
                    .scaleEffect(isHovered ? 1.1 : 1.0)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .transaction { transaction in
                if isSelected {
                    transaction.animation = nil
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Icon Picker
struct IconPicker: View {
    let iconName: String
    let label: String
    let isSelected: Bool
    let color: ContextColor
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(isSelected ? color.swiftUIColor : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)))
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Meta Item
struct MetaItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }
}
