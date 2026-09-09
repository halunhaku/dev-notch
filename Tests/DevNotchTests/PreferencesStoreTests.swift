import XCTest
@testable import DevNotch

final class MockLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabled: Bool = false
    var shouldThrow: Bool = false

    func setEnabled(_ enabled: Bool) throws {
        if shouldThrow {
            throw NSError(domain: "SMAppServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        }
        isEnabled = enabled
    }
}

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private let testPrefix = "devnotch_test_"

    override func setUp() {
        super.setUp()
        clearUserDefaults()
    }

    override func tearDown() {
        clearUserDefaults()
        super.tearDown()
    }

    private func clearUserDefaults() {
        let keys = [
            "devnotch_show_menu_bar_item",
            "devnotch_system_insights_enabled",
            "devnotch_global_hotkey_enabled",
            "devnotch_global_hotkey_data",
            "devnotch_preferred_primary_id",
            "devnotch_task_pulse_enabled",
            "devnotch_show_completed_activity",
            "devnotch_completed_display_duration",
            "devnotch_auto_collapse_enabled",
            "devnotch_provider_enabled_map",
            "devnotch_app_language",
            "devnotch_provider_order"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func testDefaultValues() {
        let mockLaunch = MockLaunchAtLoginManager()
        let store = PreferencesStore(launchManager: mockLaunch)

        XCTAssertTrue(store.showMenuBarItem)
        XCTAssertTrue(store.systemInsightsEnabled)
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertTrue(store.globalHotkeyEnabled)
        XCTAssertEqual(store.globalHotkey, KeyboardShortcutDefinition.defaultToggleNotch)
        XCTAssertEqual(store.preferredPrimaryProviderID, .codex)
        XCTAssertTrue(store.taskPulseEnabled)
        XCTAssertTrue(store.showCompletedActivity)
        XCTAssertEqual(store.completedDisplayDuration, 3.0)
        XCTAssertTrue(store.autoCollapseEnabled)
        XCTAssertEqual(store.appLanguage, .system)

        for id in AIProviderID.allCases {
            XCTAssertTrue(store.isProviderEnabled(id))
        }
    }

    func testMigrationFromOldPreferredPrimaryID() {
        // Simulate existing Phase 3-6 installation having stored "deepseek"
        UserDefaults.standard.set("deepseek", forKey: "devnotch_preferred_primary_id")

        let mockLaunch = MockLaunchAtLoginManager()
        let store = PreferencesStore(launchManager: mockLaunch)

        XCTAssertEqual(store.preferredPrimaryProviderID, .deepseek)
    }

    func testProviderEnableDisablePersistence() {
        let mockLaunch = MockLaunchAtLoginManager()
        let store = PreferencesStore(launchManager: mockLaunch)

        XCTAssertTrue(store.isProviderEnabled(.claude))
        store.setProviderEnabled(.claude, enabled: false)
        XCTAssertFalse(store.isProviderEnabled(.claude))

        // Create new store instance to test persistence
        let store2 = PreferencesStore(launchManager: mockLaunch)
        XCTAssertFalse(store2.isProviderEnabled(.claude))
        XCTAssertTrue(store2.isProviderEnabled(.codex))

        // Re-enable
        store2.setProviderEnabled(.claude, enabled: true)
        XCTAssertTrue(store2.isProviderEnabled(.claude))
    }

    func testProviderOrderPersistsAndAppendsNewIDs() {
        let saved: [AIProviderID] = [.deepseek, .codex]
        let registered: [AIProviderID] = [.codex, .claude, .deepseek]
        XCTAssertEqual(
            PreferencesStore.resolvedProviderOrder(saved: saved, registered: registered),
            [.deepseek, .codex, .claude]
        )

        let mockLaunch = MockLaunchAtLoginManager()
        let store = PreferencesStore(launchManager: mockLaunch)
        store.setProviderOrder([.claude, .deepseek, .codex, .antigravity, .openCodeGo])

        let restored = PreferencesStore(launchManager: mockLaunch)
        XCTAssertEqual(restored.providerOrder.first, .claude)
        XCTAssertTrue(restored.providerOrder.contains(.grok), "Newly added provider IDs append")
    }

    func testSystemInsightsPreferencePersists() {
        let mockLaunch = MockLaunchAtLoginManager()
        let store = PreferencesStore(launchManager: mockLaunch)

        store.systemInsightsEnabled = false

        let restoredStore = PreferencesStore(launchManager: mockLaunch)
        XCTAssertFalse(restoredStore.systemInsightsEnabled)
    }

    func testCompletedDurationValues() {
        let mockLaunch = MockLaunchAtLoginManager()
        let store = PreferencesStore(launchManager: mockLaunch)

        store.completedDisplayDuration = 2.0
        XCTAssertEqual(store.completedDisplayDuration, 2.0)

        let store2 = PreferencesStore(launchManager: mockLaunch)
        XCTAssertEqual(store2.completedDisplayDuration, 2.0)
    }

    func testAppLanguagePersistsAndResolvesLocale() {
        XCTAssertEqual(AppLanguage.english.resolvedLocale().identifier, "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.resolvedLocale().identifier, "zh-Hans")
        XCTAssertEqual(
            AppLanguage.system.resolvedLocale(preferredLanguages: ["zh-Hans-CN", "en-US"]).identifier,
            "zh-Hans"
        )
        XCTAssertEqual(
            AppLanguage.system.resolvedLocale(preferredLanguages: ["fr-FR", "en"]).identifier,
            "en"
        )

        UserDefaults.standard.set(AppLanguage.simplifiedChinese.rawValue, forKey: "devnotch_app_language")
        let store = PreferencesStore(launchManager: MockLaunchAtLoginManager())
        XCTAssertEqual(store.appLanguage, .simplifiedChinese)
        XCTAssertEqual(store.resolvedLocale.identifier, "zh-Hans")
        XCTAssertEqual(L10n.key("Ready", locale: Locale(identifier: "en")), "Ready")
        XCTAssertEqual(L10n.key("Ready", locale: Locale(identifier: "zh-Hans")), "就绪")
        XCTAssertEqual(L10n.key("Follow System", locale: Locale(identifier: "zh-Hans")), "跟随系统")
        XCTAssertEqual(
            L10n.format("Reset in %dh %dm", locale: Locale(identifier: "zh-Hans"), 2, 14),
            "2 小时 14 分钟后重置"
        )
    }
}
