import Foundation

/// In-app UI language. `system` follows macOS preferred languages, falling back to English.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    func resolvedLocale(preferredLanguages: [String] = Locale.preferredLanguages) -> Locale {
        switch self {
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .system:
            return Self.localeMatchingSystem(preferredLanguages: preferredLanguages)
        }
    }

    static func localeMatchingSystem(preferredLanguages: [String]) -> Locale {
        for identifier in preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
            if code == "zh" { return Locale(identifier: "zh-Hans") }
            if code == "en" { return Locale(identifier: "en") }
        }
        return Locale(identifier: "en")
    }
}

enum L10n {
    static var bundle: Bundle { Bundle(for: PreferencesStore.self) }

    /// English is the source language (keys). Chinese is loaded from `zh-Hans.lproj`.
    /// `String(localized:locale:)` cannot switch tables without restarting.
    static func key(_ key: String, locale: Locale) -> String {
        guard locale.language.languageCode?.identifier == "zh" else { return key }
        guard
            let path = bundle.path(forResource: "zh-Hans", ofType: "lproj"),
            let localizedBundle = Bundle(path: path)
        else {
            return key
        }
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, locale: Locale, _ args: CVarArg...) -> String {
        String(format: self.key(key, locale: locale), locale: locale, arguments: args)
    }
}
