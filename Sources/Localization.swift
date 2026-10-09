import Combine
import Foundation

enum AppLanguage: String, CaseIterable {
    case system, english, simplifiedChinese

    static func code(for preference: AppLanguage, preferredLanguages: [String]) -> String {
        switch preference {
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        case .system: return preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
        }
    }
}

final class LanguageSettings: ObservableObject {
    private let defaults: UserDefaults
    private var preferencesObserver: AnyCancellable?
    @Published var selection: AppLanguage {
        didSet {
            if selection != L.preference(in: defaults) {
                defaults.set(selection.rawValue, forKey: "language")
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = L.preference(in: defaults)
        // Uninstall clears preferences; update the language selector as well.
        preferencesObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.selection != L.preference(in: self.defaults) else { return }
                self.selection = L.preference(in: self.defaults)
            }
    }
    var locale: Locale { Locale(identifier: L.languageCode) }
}

/// Resolves strings from the selected language bundle at runtime.
enum L {
    static var preference: AppLanguage {
        preference(in: .standard)
    }
    static func preference(in defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: "language") ?? "system") ?? .system
    }
    static var languageCode: String {
        AppLanguage.code(for: preference, preferredLanguages: Locale.preferredLanguages)
    }
    static func text(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: languageCode), arguments: arguments)
    }
}
