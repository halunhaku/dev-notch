import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "Preferences")

/// Central observable preferences repository with UserDefaults persistence.
@MainActor
final class PreferencesStore: ObservableObject {
    // Keys
    private static let keyShowMenuBarItem = "devnotch_show_menu_bar_item"
    private static let keyGlobalHotkeyEnabled = "devnotch_global_hotkey_enabled"
    private static let keyGlobalHotkeyData = "devnotch_global_hotkey_data"
    private static let keyPreferredPrimaryID = "devnotch_preferred_primary_id"
    private static let keyTaskPulseEnabled = "devnotch_task_pulse_enabled"
    private static let keyShowCompletedActivity = "devnotch_show_completed_activity"
    private static let keyCompletedDisplayDuration = "devnotch_completed_display_duration"
    private static let keyAutoCollapseEnabled = "devnotch_auto_collapse_enabled"
    private static let keyProviderEnabled = "devnotch_provider_enabled_map"
    private static let keyProviderOrder = "devnotch_provider_order"
    private static let keyOpenCodeApiKey = "devnotch_opencode_api_key"
    private static let keySystemInsightsEnabled = "devnotch_system_insights_enabled"
    private static let keyAppLanguage = "devnotch_app_language"

    /// Static accessor for bridge helpers to query user's completed duration preference.
    nonisolated static var sharedCompletedDisplayDuration: Double {
        let dur = UserDefaults.standard.double(forKey: keyCompletedDisplayDuration)
        return dur > 0 ? dur : 3.0
    }

    /// Nonisolated static method to check if a provider is enabled by user.
    nonisolated static func isProviderEnabled(id: AIProviderID) -> Bool {
        let savedMap = UserDefaults.standard.dictionary(forKey: keyProviderEnabled) as? [String: Bool] ?? [:]
        return savedMap[id.rawValue] ?? true
    }

    /// Nonisolated static method to query user-configured OpenCode API key.
    nonisolated static func getOpenCodeApiKey() -> String? {
        let key = UserDefaults.standard.string(forKey: keyOpenCodeApiKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (key?.isEmpty == false) ? key : nil
    }

    @Published var showMenuBarItem: Bool {
        didSet { UserDefaults.standard.set(showMenuBarItem, forKey: Self.keyShowMenuBarItem) }
    }

    @Published var systemInsightsEnabled: Bool {
        didSet { UserDefaults.standard.set(systemInsightsEnabled, forKey: Self.keySystemInsightsEnabled) }
    }

    @Published var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.keyAppLanguage) }
    }

    var resolvedLocale: Locale { appLanguage.resolvedLocale() }

    @Published var openCodeApiKey: String {
        didSet { UserDefaults.standard.set(openCodeApiKey, forKey: Self.keyOpenCodeApiKey) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                try launchManager.setEnabled(launchAtLogin)
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin = launchManager.isEnabled
                logger.error("Failed to set launch at login: \(error.localizedDescription)")
            }
        }
    }

    @Published private(set) var launchAtLoginError: String?

    @Published var globalHotkeyEnabled: Bool {
        didSet { UserDefaults.standard.set(globalHotkeyEnabled, forKey: Self.keyGlobalHotkeyEnabled) }
    }

    @Published var globalHotkey: KeyboardShortcutDefinition {
        didSet {
            if let data = try? JSONEncoder().encode(globalHotkey) {
                UserDefaults.standard.set(data, forKey: Self.keyGlobalHotkeyData)
            }
        }
    }

    @Published var preferredPrimaryProviderID: AIProviderID {
        didSet { UserDefaults.standard.set(preferredPrimaryProviderID.rawValue, forKey: Self.keyPreferredPrimaryID) }
    }

    @Published var taskPulseEnabled: Bool {
        didSet { UserDefaults.standard.set(taskPulseEnabled, forKey: Self.keyTaskPulseEnabled) }
    }

    @Published var showCompletedActivity: Bool {
        didSet { UserDefaults.standard.set(showCompletedActivity, forKey: Self.keyShowCompletedActivity) }
    }

    @Published var completedDisplayDuration: Double {
        didSet { UserDefaults.standard.set(completedDisplayDuration, forKey: Self.keyCompletedDisplayDuration) }
    }

    @Published var autoCollapseEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCollapseEnabled, forKey: Self.keyAutoCollapseEnabled) }
    }

    @Published private(set) var providerEnabled: [AIProviderID: Bool]
    @Published private(set) var providerOrder: [AIProviderID]
    private let launchManager: any LaunchAtLoginManaging

    init(launchManager: any LaunchAtLoginManaging = DefaultLaunchAtLoginManager()) {
        let defaults = UserDefaults.standard
        self.launchManager = launchManager

        // Load showMenuBarItem (default: true)
        if defaults.object(forKey: Self.keyShowMenuBarItem) != nil {
            self.showMenuBarItem = defaults.bool(forKey: Self.keyShowMenuBarItem)
        } else {
            self.showMenuBarItem = true
        }
        if defaults.object(forKey: Self.keySystemInsightsEnabled) != nil {
            self.systemInsightsEnabled = defaults.bool(forKey: Self.keySystemInsightsEnabled)
        } else {
            self.systemInsightsEnabled = true
        }
        if let raw = defaults.string(forKey: Self.keyAppLanguage),
           let parsed = AppLanguage(rawValue: raw) {
            self.appLanguage = parsed
        } else {
            self.appLanguage = .system
        }



        // Sync launchAtLogin with system status
        self.launchAtLogin = launchManager.isEnabled

        // Global hotkey enabled (default: true)
        if defaults.object(forKey: Self.keyGlobalHotkeyEnabled) != nil {
            self.globalHotkeyEnabled = defaults.bool(forKey: Self.keyGlobalHotkeyEnabled)
        } else {
            self.globalHotkeyEnabled = true
        }

        // Global hotkey definition (default: ⌃⌥Space)
        if let data = defaults.data(forKey: Self.keyGlobalHotkeyData),
           let decoded = try? JSONDecoder().decode(KeyboardShortcutDefinition.self, from: data) {
            self.globalHotkey = decoded
        } else {
            self.globalHotkey = .defaultToggleNotch
        }

        // Preferred Primary Provider (migrating Phase 3-6 key)
        if let raw = defaults.string(forKey: Self.keyPreferredPrimaryID),
           let parsed = AIProviderID(rawValue: raw) {
            self.preferredPrimaryProviderID = parsed
        } else {
            self.preferredPrimaryProviderID = .codex
        }

        // Task pulse enabled (default: true)
        if defaults.object(forKey: Self.keyTaskPulseEnabled) != nil {
            self.taskPulseEnabled = defaults.bool(forKey: Self.keyTaskPulseEnabled)
        } else {
            self.taskPulseEnabled = true
        }

        // Show completed activity (default: true)
        if defaults.object(forKey: Self.keyShowCompletedActivity) != nil {
            self.showCompletedActivity = defaults.bool(forKey: Self.keyShowCompletedActivity)
        } else {
            self.showCompletedActivity = true
        }

        // Completed display duration (default: 3.0s)
        let dur = defaults.double(forKey: Self.keyCompletedDisplayDuration)
        self.completedDisplayDuration = dur > 0 ? dur : 3.0

        // Auto collapse (default: true)
        if defaults.object(forKey: Self.keyAutoCollapseEnabled) != nil {
            self.autoCollapseEnabled = defaults.bool(forKey: Self.keyAutoCollapseEnabled)
        } else {
            self.autoCollapseEnabled = true
        }

        // Provider enabled map (default: all enabled)
        var map: [AIProviderID: Bool] = [:]
        let savedMap = defaults.dictionary(forKey: Self.keyProviderEnabled) as? [String: Bool] ?? [:]
        for id in AIProviderID.allCases {
            map[id] = savedMap[id.rawValue] ?? true
        }
        self.providerEnabled = map
        self.providerOrder = Self.resolvedProviderOrder(
            saved: Self.loadSavedProviderOrder(),
            registered: Array(AIProviderID.allCases)
        )
        // OpenCode Go API key
        self.openCodeApiKey = defaults.string(forKey: Self.keyOpenCodeApiKey) ?? ""
    }

    /// Checks if a provider is enabled by user.
    func isProviderEnabled(_ id: AIProviderID) -> Bool {
        providerEnabled[id] ?? true
    }

    /// Toggles or sets provider enabled state.
    func setProviderEnabled(_ id: AIProviderID, enabled: Bool) {
        providerEnabled[id] = enabled
        var rawMap: [String: Bool] = [:]
        for (k, v) in providerEnabled {
            rawMap[k.rawValue] = v
        }
        UserDefaults.standard.set(rawMap, forKey: Self.keyProviderEnabled)
        logger.info("Provider \(id.rawValue) enabled state set to: \(enabled)")
    }

    /// Sets or clears the OpenCode Go API key.
    func setOpenCodeApiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.openCodeApiKey = clean
        UserDefaults.standard.set(clean, forKey: Self.keyOpenCodeApiKey)
    }

    /// Saved display order. Unknown IDs are dropped; new IDs append.
    nonisolated static func loadSavedProviderOrder() -> [AIProviderID] {
        let raw = UserDefaults.standard.stringArray(forKey: keyProviderOrder) ?? []
        return raw.compactMap { AIProviderID(rawValue: $0) }
    }

    nonisolated static func resolvedProviderOrder(
        saved: [AIProviderID],
        registered: [AIProviderID]
    ) -> [AIProviderID] {
        var seen = Set<AIProviderID>()
        var result: [AIProviderID] = []
        for id in saved where registered.contains(id) && seen.insert(id).inserted {
            result.append(id)
        }
        for id in registered where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    func setProviderOrder(_ ids: [AIProviderID]) {
        providerOrder = Self.resolvedProviderOrder(saved: ids, registered: Array(AIProviderID.allCases))
        UserDefaults.standard.set(providerOrder.map(\.rawValue), forKey: Self.keyProviderOrder)
        logger.info("Provider order updated: \(self.providerOrder.map(\.rawValue).joined(separator: ","))")
    }
}
