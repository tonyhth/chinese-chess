import Foundation
@testable import ChineseChess

// MARK: - v6.3 H-1 测试卫生 · 语言锁哨兵（Tina 2026-08-29）
//
// 目的：守护 run-tests-mutex.sh 的全局语言锁（AppleLanguages=(zh-Hans) 注入）。
// 机制：若批不是经 runner 起跑（未注入语言锁），本哨兵红——把"跑批纪律"变成可断言的测试面。
// 依据：跨 suite L10n 竞态假红指纹（前1英文后4中文，08-28 二次实证），
//       UserDefaults "chinesechess.language" 跨 suite 污染 + 系统语言漂移双重来源。
// 注意：单跑本套件也必须经 runner（bash scripts/run-tests-mutex.sh RunnerHygieneTests）。

import Testing

@Suite("runner 卫生哨兵（H-1）", .serialized)
final class RunnerHygieneTests {

    @Test("语言锁在位：进程 AppleLanguages 首选 zh-Hans")
    func languageLockActive() {
        let args = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
        print("HYGIENE_PROBE AppleLanguages=\(args ?? []) preferred0=\(Locale.preferredLanguages.first ?? "nil")")
        #expect(args?.first?.hasPrefix("zh") == true,
                "AppleLanguages 首选非 zh：\(args ?? [])——本批未经 run-tests-mutex.sh 起跑（缺语言锁注入）")
    }

    @Test("app 层语言状态确定性：chinesechess.language 为 zh-Hans 或空（未被残留英文污染）")
    func appLanguageDeterministic() {
        let lang = UserDefaults.standard.string(forKey: "chinesechess.language") ?? ""
        print("HYGIENE_PROBE chinesechess.language='\(lang)'")
        #expect(lang.isEmpty || lang == "zh-Hans",
                "跨 suite 语言残留：chinesechess.language='\(lang)'——上序 suite setLanguage 未恢复")
    }
}
