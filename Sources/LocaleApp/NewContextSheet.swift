import SwiftUI

struct NewContextSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: LocaleStore
    @State private var name = ""
    @State private var selectedColor: ContextColor = .blue
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Context")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 20) {
                // Name field
                VStack(alignment: .leading, spacing: 7) {
                    Text("Context Name")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Client VPN, Local API…", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(nameFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .focused($nameFocused)
                        .onSubmit { if isValid { create() } }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05), value: appeared)

                // Color picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(ContextColor.allCases) { color in
                            Button(action: {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedColor = color
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 28, height: 28)
                                        .scaleEffect(selectedColor == color ? 1.12 : 1.0)
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.22), value: selectedColor)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1), value: appeared)

                // Preview
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(selectedColor.swiftUIColor.opacity(0.18))
                            .frame(width: 30, height: 30)
                        Circle()
                            .fill(selectedColor.swiftUIColor)
                            .frame(width: 11, height: 11)
                    }
                    Text(name.isEmpty ? "Context Name" : name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(name.isEmpty ? .tertiary : .primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedColor.swiftUIColor.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selectedColor.swiftUIColor.opacity(0.25), lineWidth: 0.5)
                        )
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 4)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15), value: appeared)
            }
            .padding(24)

            Divider().opacity(0.4)

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: create) {
                    Text("Create Context")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isValid ? selectedColor.swiftUIColor : Color.primary.opacity(0.2))
                                .shadow(color: isValid ? selectedColor.swiftUIColor.opacity(0.3) : .clear, radius: 8, y: 3)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
                .animation(.spring(response: 0.25), value: isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 380)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nameFocused = true
            }
        }
    }

    private func create() {
        guard isValid else { return }
        store.createContext(name: name.trimmingCharacters(in: .whitespaces), color: selectedColor)
        isPresented = false
    }
}
