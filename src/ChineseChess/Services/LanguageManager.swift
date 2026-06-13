import SwiftUI

/// 语言管理器：非单例，通过 .environmentObject() 注入视图树
/// 优先级：手动设置 > 系统语言 > 默认中文
@Observable
class LanguageManager: ObservableObject {
    /// 用户手动选择的语言，nil 表示跟随系统
    /// 注意：@Observable 宏会重写存储属性导致 didSet 不触发，
    /// 因此通过 setPreferredLanguage() 方法同步写 UserDefaults
    var preferredLanguage: String?

    /// 当前生效的语言代码
    var currentLanguage: String {
        preferredLanguage ?? Locale.current.language.languageCode?.identifier ?? "zh-Hans"
    }

    /// 当前 locale，用于注入 SwiftUI 环境
    var currentLocale: Locale {
        Locale(identifier: currentLanguage)
    }

    private let languageKey = "chinesechess.language"

    init() {
        self.preferredLanguage = UserDefaults.standard.string(forKey: languageKey)
    }

    /// 设置首选语言并同步写入 UserDefaults
    func setPreferredLanguage(_ language: String?) {
        preferredLanguage = language
        UserDefaults.standard.set(language, forKey: languageKey)
    }
}
