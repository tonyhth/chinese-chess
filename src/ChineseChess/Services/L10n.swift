import Foundation
import Observation

/// 运行时本地化管理器
///
/// 直接从 Bundle.main 的 .lproj/Localizable.strings 加载翻译，
/// bypass 系统本地化机制，实现即时语言切换。
///
/// - View 层：通过 `private let l10n = L10n.shared` 访问，调用 `l10n.t("key")`
/// - 非 View 层：通过 `L10n.shared.t("key")` 访问
@Observable
final class L10n {
    static let shared = L10n()

    /// 当前语言代码，如 "en", "zh-Hans"
    private(set) var language: String

    /// 当前加载的翻译表 key→value
    private(set) var translations: [String: String]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "chinesechess.language")
            ?? Locale.current.language.languageCode?.identifier ?? "zh-Hans"
        self.language = saved
        self.translations = [:]
        loadTranslations(for: saved)
    }

    /// 切换语言（即时生效，不需要重启）
    func setLanguage(_ lang: String) {
        language = lang
        UserDefaults.standard.set(lang, forKey: "chinesechess.language")
        loadTranslations(for: lang)
    }

    /// 清除语言偏好，回退到系统语言
    func clearLanguage() {
        UserDefaults.standard.removeObject(forKey: "chinesechess.language")
        let systemLang = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
        setLanguage(systemLang)
    }

    /// 翻译 key
    func t(_ key: String) -> String {
        translations[key] ?? key
    }

    /// 带参数的翻译
    func t(_ key: String, _ args: CVarArg...) -> String {
        let template = translations[key] ?? key
        return String(format: template, arguments: args)
    }

    private func loadTranslations(for lang: String) {
        // 映射语言代码到 .lproj 目录名 / xcstrings language key
        let lprojName: String
        switch lang {
        case "zh-Hans", "zh-CN", "zh":
            lprojName = "zh-Hans"
        case "en", "en-US":
            lprojName = "en"
        default:
            lprojName = lang
        }

        // 优先尝试 Localizable.xcstrings（JSON 格式，SPM 资源打包）
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let stringsDict = json["strings"] as? [String: Any] {
            var result: [String: String] = [:]
            for (key, value) in stringsDict {
                guard let localizations = value as? [String: Any],
                      let langEntry = localizations["localizations"] as? [String: Any],
                      let targetLang = langEntry[lprojName] as? [String: Any],
                      let stringUnit = targetLang["stringUnit"] as? [String: Any],
                      let translated = stringUnit["value"] as? String else {
                    continue
                }
                result[key] = translated
            }
            if !result.isEmpty {
                translations = result
                return
            }
        }

        // Fallback: .lproj/Localizable.strings（旧路径）
        if let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
           let lprojBundle = Bundle(path: path),
           let stringsPath = lprojBundle.path(forResource: "Localizable", ofType: "strings"),
           let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String] {
            translations = dict
        } else {
            translations = [:]
        }
    }
}
