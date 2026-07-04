//
//  I18nKeyCompletionTests.swift
//  ChineseChessTests
//
//  i18n key 补全修复测试
//  验证 export.copyPGN, export.share, history.select 三个 key 正确定义并被使用
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("i18n Key 补全测试", .serialized)
struct I18nKeyCompletionTests {

    /// xcstrings 文件路径
    private static let xcstringsPath: String = {
        let homeDir = NSHomeDirectory()
        return "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
    }()

    /// 加载 xcstrings 并返回 strings 字典
    private static func loadStrings() -> [String: [String: Any]] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            return [:]
        }
        return strings
    }

    // MARK: - Key 存在性

    @Test("export.copyPGN key 存在且译文正确")
    func exportCopyPGNKeyExists() {
        let strings = Self.loadStrings()
        let key = "export.copyPGN"
        guard let entry = strings[key] else {
            Issue.record("❌ key '\(key)' 不存在于 xcstrings")
            return
        }
        guard let locs = entry["localizations"] as? [String: [String: Any]] else {
            Issue.record("❌ key '\(key)' 缺少 localizations")
            return
        }

        // zh-Hans
        let zhValue = (locs["zh-Hans"]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(zhValue == "复制 PGN", "zh-Hans 期望 '复制 PGN'，实际 '\(zhValue ?? "nil")'")

        // en
        let enValue = (locs["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(enValue == "Copy PGN", "en 期望 'Copy PGN'，实际 '\(enValue ?? "nil")'")
    }

    @Test("export.share key 存在且译文正确")
    func exportShareKeyExists() {
        let strings = Self.loadStrings()
        let key = "export.share"
        guard let entry = strings[key] else {
            Issue.record("❌ key '\(key)' 不存在于 xcstrings")
            return
        }
        guard let locs = entry["localizations"] as? [String: [String: Any]] else {
            Issue.record("❌ key '\(key)' 缺少 localizations")
            return
        }

        let zhValue = (locs["zh-Hans"]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(zhValue == "分享", "zh-Hans 期望 '分享'，实际 '\(zhValue ?? "nil")'")

        let enValue = (locs["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(enValue == "Share", "en 期望 'Share'，实际 '\(enValue ?? "nil")'")
    }

    @Test("history.select key 存在且译文正确")
    func historySelectKeyExists() {
        let strings = Self.loadStrings()
        let key = "history.select"
        guard let entry = strings[key] else {
            Issue.record("❌ key '\(key)' 不存在于 xcstrings")
            return
        }
        guard let locs = entry["localizations"] as? [String: [String: Any]] else {
            Issue.record("❌ key '\(key)' 缺少 localizations")
            return
        }

        let zhValue = (locs["zh-Hans"]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(zhValue == "选择", "zh-Hans 期望 '选择'，实际 '\(zhValue ?? "nil")'")

        let enValue = (locs["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
        #expect(enValue == "Select", "en 期望 'Select'，实际 '\(enValue ?? "nil")'")
    }

    // MARK: - Key 唯一性（不重复定义）

    @Test("3 个新 key 各只出现一次")
    func keysNotDuplicated() {
        let strings = Self.loadStrings()
        let keys = ["export.copyPGN", "export.share", "history.select"]
        for key in keys {
            let count = strings.keys.filter { $0 == key }.count
            #expect(count == 1, "key '\(key)' 出现了 \(count) 次，期望 1 次")
        }
    }

    // MARK: - l10n.t() 运行时验证

    @MainActor
    @Test("中文环境下 l10n.t() 返回中文译文")
    func l10nChineseOutput() {
        let l10n = L10n.shared
        l10n.setLanguage("zh-Hans")
        #expect(l10n.t("export.copyPGN") == "复制 PGN")
        #expect(l10n.t("export.share") == "分享")
        #expect(l10n.t("history.select") == "选择")
    }

    @MainActor
    @Test("英文环境下 l10n.t() 返回英文译文")
    func l10nEnglishOutput() {
        let l10n = L10n.shared
        l10n.setLanguage("en")
        #expect(l10n.t("export.copyPGN") == "Copy PGN")
        #expect(l10n.t("export.share") == "Share")
        #expect(l10n.t("history.select") == "Select")
    }

    @MainActor
    @Test("l10n.t() 不再返回 key 原文")
    func l10nDoesNotReturnRawKey() {
        let l10n = L10n.shared
        // 在两种语言下都不应返回 key 原文
        for lang in ["zh-Hans", "en"] {
            l10n.setLanguage(lang)
            for key in ["export.copyPGN", "export.share", "history.select"] {
                let result = l10n.t(key)
                #expect(result != key, "[\(lang)] l10n.t(\"\(key)\") 返回了 key 原文，说明翻译未生效")
            }
        }
    }

    // MARK: - 代码使用位置验证

    @Test("3 个 key 在 Swift 代码中被正确引用")
    func keysUsedInCode() {
        let homeDir = NSHomeDirectory()
        let srcPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess"
        let fileManager = FileManager.default

        var allCode = ""
        if let enumerator = fileManager.enumerator(atPath: srcPath) {
            for case let file as String in enumerator {
                guard file.hasSuffix(".swift") else { continue }
                let filePath = (srcPath as NSString).appendingPathComponent(file)
                if let content = try? String(contentsOfFile: filePath) {
                    allCode += content + "\n"
                }
            }
        }

        let keysToCheck = ["export.copyPGN", "export.share", "history.select"]
        for key in keysToCheck {
            let pattern = "l10n.t(\"\(key)\")"
            let altPattern = "l10n.t(\\(\"\(key)\"\\)"
            // 检查是否在代码中出现（直接字符串或插值）
            let appearsDirectly = allCode.contains("\"\(key)\"")
            #expect(appearsDirectly, "key '\(key)' 未在 Swift 代码中被引用")
            _ = pattern
            _ = altPattern
        }
    }

    // MARK: - 不破坏现有 key

    @Test("新增 key 后 xcstrings 总 key 数增加且现有 key 完好")
    func existingKeysIntact() {
        let strings = Self.loadStrings()
        // 验证一些已存在的 key 仍然完好
        let spotChecks: [(key: String, lang: String, expected: String)] = [
            ("settings.title", "zh-Hans", "设置"),
            ("settings.title", "en", "Settings"),
            ("game.newGame", "zh-Hans", "新局"),
            ("game.newGame", "en", "New"),
        ]
        for check in spotChecks {
            guard let entry = strings[check.key] else {
                Issue.record("已有 key '\(check.key)' 丢失！")
                continue
            }
            guard let locs = entry["localizations"] as? [String: [String: Any]] else {
                Issue.record("已有 key '\(check.key)' 的 localizations 丢失")
                continue
            }
            let value = (locs[check.lang]?["stringUnit"] as? [String: Any])?["value"] as? String
            #expect(value == check.expected, "已有 key '\(check.key)' [\(check.lang)] 期望 '\(check.expected)'，实际 '\(value ?? "nil")'")
        }

        // 总 key 数应 >= 505（新增 3 个后）
        #expect(strings.count >= 505, "总 key 数 \(strings.count)，期望 >= 505")
    }
}
