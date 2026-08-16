import Foundation
@testable import ChineseChess

// MARK: - v6.2 断言清偿 · 簇1 测试基建
//
// 根因：测试有宿主（TEST_HOST ✓），L10n.shared 本可从 app bundle 加载 zh-Hans.lproj；
// 但部分 i18n 测试调用 setLanguage("en") 后不恢复 → 全局语言状态跨套件污染
// （UserDefaults "chinesechess.language" 持久化），导致依赖中文环境的后续用例
// （B3S4 人名 / V223Fix displayName / Phase4 displayName 等）拿到错误语言。
//
// 修法（Luke 裁定：测试基建修——setUp 注入 zh-Hans，fallback 策略保持）：
// 各 i18n 相关 Suite 在 init/setUp 中调用 L10n.shared.setLanguage("zh-Hans")，
// deinit/tearDown 恢复原值。零 src/ 改动。

/// i18n 测试基建：L10n 语言状态保存/恢复
enum TestL10nSupport {
    /// 保存当前语言并切换到 zh-Hans
    static func injectZhHans() -> String {
        let saved = L10n.shared.language
        L10n.shared.setLanguage("zh-Hans")
        return saved
    }

    /// 恢复原始语言
    static func restore(_ saved: String) {
        L10n.shared.setLanguage(saved)
    }
}
