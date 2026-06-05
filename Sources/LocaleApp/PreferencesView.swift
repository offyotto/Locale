import SwiftUI

struct PreferencesView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: LocaleStore
    @State private var showingResetConfirmation = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Label("Preferences", systemImage: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
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
            .padding(.bottom, 16)

            Divider().opacity(0.4)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Safety
                    PrefsSection(title: "Safety") {
                        PrefsInfoRow(
                            label: "DNS Proxy",
                            icon: "lock.shield",
                            description: "Locale applies mappings through a sandboxed DNS proxy extension."
                        )

                        Divider().padding(.leading, 46).opacity(0.3)

                        PrefsInfoRow(
                            label: "System Files",
                            icon: "doc.badge.gearshape",
                            description: "Locale does not edit host files or require root privileges to switch contexts."
                        )
                    }

                    // Data
                    PrefsSection(title: "Data") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export All Contexts")
                                    .font(.system(size: 13))
                                Text("Save all contexts as a JSON file for backup or sharing")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Export…") { store.exportContexts() }
                                .buttonStyle(.plain)
                                .font(.system(size: 12.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.primary.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                                        )
                                )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 14).opacity(0.3)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Contexts")
                                    .font(.system(size: 13))
                                Text("Load contexts from a previously exported JSON file")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Import…") { store.importContexts() }
                                .buttonStyle(.plain)
                                .font(.system(size: 12.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.primary.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                                        )
                                )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    // About
                    PrefsSection(title: "About") {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(Color.primary.opacity(0.06))
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Locale")
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text("Version 1.0 · macOS Network Context Manager")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 14).opacity(0.3)

                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("No telemetry. No analytics. Contexts stay local.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.never)

            Divider().opacity(0.4)

            HStack {
                Button("Reset Contexts") {
                    showingResetConfirmation = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Color(red: 0.9, green: 0.3, blue: 0.3))

                Spacer()

                Button("Done") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    )
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 440, height: 520)
        .onAppear {
            withAnimation { appeared = true }
        }
        .alert("Reset all contexts?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                store.resetContexts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved context and returns Locale to a clean Home context. DNS settings are not changed until you apply Home.")
        }
    }
}

// MARK: - Prefs Section
struct PrefsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Prefs Info Row
struct PrefsInfoRow: View {
    let label: String
    let icon: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
