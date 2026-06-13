import SwiftUI

/// 语言管理器：非单例，通过 .environmentObject() 注入视图树
/// 优先级：手动设置 > 系统语言 > 默认中文
@Observable
class LanguageManager: ObservableObject {
    /// 用户手动选择的语言，nil 表示跟随系统
    var preferredLanguage: String? {
        didSet {
            UserDefaults.standard.set(preferredLanguage, forKey: languageKey)
        }
    }

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
}
