import SwiftUI
import Combine
import AppKit

@MainActor
final class LocaleStore: ObservableObject {
    // MARK: - Published State
    @Published var contexts: [NetworkContext] = []
    @Published var groups: [ContextGroup] = []
    @Published var selectedContextID: UUID? = nil
    @Published var searchText: String = ""
    @Published var showingNewContext: Bool = false
    @Published var showingOnboarding: Bool = false
    @Published var showingPreferences: Bool = false
    @Published var toastMessage: ToastMessage? = nil
    @Published var isApplying: Bool = false

    // MARK: - Derived
    var homeContext: NetworkContext {
        contexts.first { $0.isPinned && $0.name == "Home" } ?? .homeContext
    }

    var activeContext: NetworkContext? {
        contexts.first { $0.isActive }
    }

    var selectedContext: NetworkContext? {
        get { contexts.first { $0.id == selectedContextID } }
    }

    var filteredContexts: [NetworkContext] {
        guard !searchText.isEmpty else { return contexts }
        return contexts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.hosts.contains { $0.hostname.localizedCaseInsensitiveContains(searchText) || $0.ipAddress.contains(searchText) }
        }
    }

    var pinnedContexts: [NetworkContext] { contexts.filter { $0.isPinned } }
    var groupedContexts: [(group: ContextGroup?, contexts: [NetworkContext])] {
        var result: [(group: ContextGroup?, contexts: [NetworkContext])] = []
        let ungrouped = contexts.filter { !$0.isPinned && $0.groupID == nil }
        if !ungrouped.isEmpty {
            result.append((nil, ungrouped))
        }
        for group in groups {
            let members = contexts.filter { $0.groupID == group.id }
            if !members.isEmpty {
                result.append((group, members))
            }
        }
        return result
    }

    // MARK: - Persistence Keys
    private let contextsKey = "locale.contexts"
    private let groupsKey = "locale.groups"
    private let onboardedKey = "locale.onboarded"

    // MARK: - Init
    init() {
        loadFromDisk()
        if contexts.isEmpty {
            seedDefaultData()
        }
        if !UserDefaults.standard.bool(forKey: onboardedKey) {
            showingOnboarding = true
        }
        // Select first context
        if selectedContextID == nil {
            selectedContextID = activeContext?.id ?? contexts.first?.id
        }
    }

    // MARK: - Context Management

    func activateContext(_ context: NetworkContext, successMessage: String? = nil) {
        guard !isApplying else { return }
        isApplying = true
        let contextName = context.name
        let contextID = context.id
        let activeHostCount = context.activeHostCount

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try SystemApplyService.applyHosts(for: context)
                }
            }.value

            switch result {
            case .success:
                for idx in contexts.indices {
                    contexts[idx].isActive = (contexts[idx].id == contextID)
                }
                if let idx = contexts.firstIndex(where: { $0.id == contextID }) {
                    contexts[idx].lastActivated = Date()
                }
                saveToDisk()
                isApplying = false
                showToast(successMessage ?? "✓ \(contextName) activated · \(activeHostCount) hosts applied", type: .success)

            case .failure(let error):
                isApplying = false
                showToast("Apply failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    func deactivateAll() {
        activateContext(homeContext, successMessage: "Reverted to Home context · Locale hosts removed")
    }

    func duplicateContext(_ context: NetworkContext) {
        var copy = context
        copy.id = UUID()
        copy.name = "\(context.name) (Copy)"
        copy.isActive = false
        copy.lastActivated = nil
        copy.createdAt = Date()
        if let idx = contexts.firstIndex(where: { $0.id == context.id }) {
            contexts.insert(copy, at: idx + 1)
        } else {
            contexts.append(copy)
        }
        selectedContextID = copy.id
        saveToDisk()
        showToast("Duplicated \"\(context.name)\"", type: .info)
    }

    func deleteContext(_ context: NetworkContext) {
        guard context.id != homeContext.id else { return }
        if context.isActive { deactivateAll() }
        contexts.removeAll { $0.id == context.id }
        selectedContextID = contexts.first?.id
        saveToDisk()
        showToast("Deleted \"\(context.name)\"", type: .warning)
    }

    func createContext(name: String, color: ContextColor = .blue) {
        let ctx = NetworkContext(id: UUID(), name: name, color: color)
        contexts.append(ctx)
        selectedContextID = ctx.id
        saveToDisk()
        showToast("Created \"\(name)\"", type: .success)
    }

    func updateContext(_ context: NetworkContext) {
        if let idx = contexts.firstIndex(where: { $0.id == context.id }) {
            contexts[idx] = context
            saveToDisk()
        }
    }

    // MARK: - Host Management
    func addHost(to contextID: UUID, ip: String, hostname: String, note: String = "") {
        guard let idx = contexts.firstIndex(where: { $0.id == contextID }) else { return }
        let entry = HostEntry(ipAddress: ip, hostname: hostname, note: note)
        contexts[idx].hosts.append(entry)
        saveToDisk()
    }

    func removeHost(_ host: HostEntry, from contextID: UUID) {
        guard let idx = contexts.firstIndex(where: { $0.id == contextID }) else { return }
        contexts[idx].hosts.removeAll { $0.id == host.id }
        saveToDisk()
    }

    func toggleHost(_ host: HostEntry, in contextID: UUID) {
        guard let ctxIdx = contexts.firstIndex(where: { $0.id == contextID }),
              let hostIdx = contexts[ctxIdx].hosts.firstIndex(where: { $0.id == host.id }) else { return }
        contexts[ctxIdx].hosts[hostIdx].isEnabled.toggle()
        saveToDisk()
    }

    // MARK: - Groups
    func createGroup(name: String) {
        let group = ContextGroup(id: UUID(), name: name)
        groups.append(group)
        saveToDisk()
    }

    func toggleGroupExpanded(_ group: ContextGroup) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx].isExpanded.toggle()
        }
    }

    // MARK: - Import / Export
    func exportContexts() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(contexts) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Locale-Contexts.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }

    func importContexts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let imported = try decoder.decode([NetworkContext].self, from: data)
                let newContexts = imported.filter { imp in
                    !self.contexts.contains { $0.id == imp.id }
                }
                Task { @MainActor in
                    self.contexts.append(contentsOf: newContexts)
                    self.saveToDisk()
                    self.showToast("Imported \(newContexts.count) context(s)", type: .success)
                }
            } catch {
                Task { @MainActor in
                    self.showToast("Import failed: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }

    // MARK: - Persistence
    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(contexts) {
            UserDefaults.standard.set(data, forKey: contextsKey)
        }
        if let data = try? encoder.encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: contextsKey),
           let loaded = try? decoder.decode([NetworkContext].self, from: data) {
            contexts = loaded
        }
        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let loaded = try? decoder.decode([ContextGroup].self, from: data) {
            groups = loaded
        }
    }

    func markOnboarded() {
        UserDefaults.standard.set(true, forKey: onboardedKey)
        showingOnboarding = false
    }

    func resetContexts() {
        contexts = [.homeContext]
        groups = []
        selectedContextID = contexts.first?.id
        saveToDisk()
        showToast("Reset to a clean Home context", type: .info)
    }

    // MARK: - Toast
    func showToast(_ message: String, type: ToastMessage.ToastType) {
        toastMessage = ToastMessage(text: message, type: type)
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                toastMessage = nil
            }
        }
    }

    // MARK: - Seed Data
    private func seedDefaultData() {
        contexts = [.homeContext]
        groups = []
        saveToDisk()
    }
}

// MARK: - Toast Message
struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: ToastType

    enum ToastType {
        case success, info, warning, error
        var color: Color {
            switch self {
            case .success: return Color(red: 0.25, green: 0.72, blue: 0.42)
            case .info: return Color(red: 0.3, green: 0.55, blue: 0.95)
            case .warning: return Color(red: 0.95, green: 0.65, blue: 0.2)
            case .error: return Color(red: 0.9, green: 0.3, blue: 0.3)
            }
        }
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
}
