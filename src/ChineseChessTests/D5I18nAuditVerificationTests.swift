//
//  D5I18nAuditVerificationTests.swift
//  ChineseChessTests
//
//  D5 i18n 国际化审计报告验证测试
//  验证审计报告中的关键结论和发现
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("D5 i18n 审计验证", .serialized)
struct D5I18nAuditVerificationTests {

    // MARK: - 工具方法

    private static let xcstringsPath: String = {
        let homeDir = NSHomeDirectory()
        return "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
    }()

    private static func loadStrings() -> [String: [String: Any]] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            return [:]
        }
        return strings
    }

    private static func translationValue(_ key: String, _ lang: String) -> String? {
        let strings = loadStrings()
        guard let entry = strings[key],
              let locs = entry["localizations"] as? [String: [String: Any]],
              let langEntry = locs[lang],
              let stringUnit = langEntry["stringUnit"] as? [String: Any] else {
            return nil
        }
        return stringUnit["value"] as? String
    }

    // MARK: - 1. xcstrings 完整性验证

    @Test("xcstrings 总 key 数 >= 544")
    func xcstringsKeyCount() {
        let strings = Self.loadStrings()
        #expect(strings.count >= 544, "xcstrings 总 key 数 \(strings.count)，期望 >= 544")
    }

    @Test("所有 key 都有 zh-Hans 和 en 翻译")
    func allKeysHaveBothTranslations() {
        let strings = Self.loadStrings()
        var issues: [String] = []

        for (key, entry) in strings {
            guard let locs = entry["localizations"] as? [String: [String: Any]] else {
                issues.append("\(key): 缺少 localizations")
                continue
            }

            // zh-Hans
            let zhVal = (locs["zh-Hans"]?["stringUnit"] as? [String: Any])?["value"] as? String
            if zhVal == nil || zhVal!.isEmpty {
                issues.append("\(key): zh-Hans 缺失或为空")
            }

            // en
            let enVal = (locs["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            if enVal == nil || enVal!.isEmpty {
                issues.append("\(key): en 缺失或为空")
            }
        }

        #expect(issues.isEmpty, "翻译完整性问题 (\(issues.count) 个): \(issues.prefix(10))")
    }

    // MARK: - 2. 中英文切换功能验证

    @MainActor
    @Test("L10n 中→英 切换后翻译立即生效")
    func languageSwitchChineseToEnglish() {
        let l10n = L10n.shared

        // 中文
        l10n.setLanguage("zh-Hans")
        let zhValue = l10n.t("settings.title")
        #expect(zhValue == "设置", "中文模式下 settings.title 应为 '设置'，实际 '\(zhValue)'")

        // 切换到英文
        l10n.setLanguage("en")
        let enValue = l10n.t("settings.title")
        #expect(enValue == "Settings", "英文模式下 settings.title 应为 'Settings'，实际 '\(enValue)'")

        // 切换回中文
        l10n.setLanguage("zh-Hans")
        let zhAgain = l10n.t("settings.title")
        #expect(zhAgain == "设置", "切回中文后应恢复 '设置'，实际 '\(zhAgain)'")
    }

    @MainActor
    @Test("L10n 英文模式下多个 key 返回英文")
    func englishModeMultipleKeys() {
        let l10n = L10n.shared
        l10n.setLanguage("en")

        let testCases: [(key: String, expected: String)] = [
            ("game.newGame", "New"),
            ("game.undoMove", "Undo"),
            ("difficulty.amateurLow", "Medium"),
            ("result.redWon", "Red Won"),
            ("result.draw", "Draw"),
        ]

        for tc in testCases {
            let actual = l10n.t(tc.key)
            #expect(actual == tc.expected, "en[\(tc.key)] 期望 '\(tc.expected)'，实际 '\(actual)'")
        }
    }

    @MainActor
    @Test("L10n 中文模式下多个 key 返回中文")
    func chineseModeMultipleKeys() {
        let l10n = L10n.shared
        l10n.setLanguage("zh-Hans")

        let testCases: [(key: String, expected: String)] = [
            ("game.newGame", "新局"),
            ("game.undoMove", "悔棋"),
            ("difficulty.amateurLow", "中级"),
            ("result.redWon", "红方胜"),
            ("result.draw", "和棋"),
        ]

        for tc in testCases {
            let actual = l10n.t(tc.key)
            #expect(actual == tc.expected, "zh-Hans[\(tc.key)] 期望 '\(tc.expected)'，实际 '\(actual)'")
        }
    }

    // MARK: - 3. 领域语言保持验证（英文界面下中文术语不翻译）

    @Test("棋子 Piece.displayName 保持中文（车馬炮将士象兵卒）")
    func pieceDisplayNameStaysChinese() {
        // 领域语言：棋子名称应硬编码中文，不走 L10n
        // PieceKind 枚举: general, advisor, elephant, horse, chariot, cannon, soldier
        let redPieces: [Piece] = [
            Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 0), id: 100),
            Piece(kind: .horse, side: .red, position: Position(row: 0, col: 1), id: 101),
            Piece(kind: .elephant, side: .red, position: Position(row: 0, col: 2), id: 102),
            Piece(kind: .advisor, side: .red, position: Position(row: 0, col: 3), id: 103),
            Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 104),
            Piece(kind: .cannon, side: .red, position: Position(row: 2, col: 1), id: 121),
            Piece(kind: .soldier, side: .red, position: Position(row: 3, col: 0), id: 130),
        ]

        for piece in redPieces {
            let name = piece.displayName
            // 验证包含中文字符
            #expect(!name.isEmpty, "棋子 displayName 不应为空")
            #expect(Self.containsChinese(name), "红方棋子 \(piece.kind) displayName '\(name)' 应为中文")
        }

        let blackPieces: [Piece] = [
            Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 0), id: 290),
            Piece(kind: .horse, side: .black, position: Position(row: 9, col: 1), id: 291),
            Piece(kind: .elephant, side: .black, position: Position(row: 9, col: 2), id: 292),
            Piece(kind: .advisor, side: .black, position: Position(row: 9, col: 3), id: 293),
            Piece(kind: .general, side: .black, position: Position(row: 9, col: 4), id: 294),
            Piece(kind: .cannon, side: .black, position: Position(row: 7, col: 1), id: 271),
            Piece(kind: .soldier, side: .black, position: Position(row: 6, col: 0), id: 260),
        ]

        for piece in blackPieces {
            let name = piece.displayName
            #expect(!name.isEmpty, "棋子 displayName 不应为空")
            #expect(Self.containsChinese(name), "黑方棋子 \(piece.kind) displayName '\(name)' 应为中文")
        }
    }

    @Test("段位名 L10n key 存在且英文使用意译（非中文原字）")
    func rankNamesUseLocalization() {
        let rankKeys: [(rank: Rank, key: String)] = [
            (.student, "rank.student"),
            (.scholar, "rank.scholar"),
            (.juren, "rank.juren"),
            (.jinshi, "rank.jinshi"),
            (.hanlin, "rank.hanlin"),
            (.master, "rank.master"),
            (.sage, "rank.sage"),
        ]

        for item in rankKeys {
            let enVal = Self.translationValue(item.key, "en")
            #expect(enVal != nil, "key '\(item.key)' 缺少 en 翻译")
            #expect(!Self.containsChinese(enVal ?? ""), "key '\(item.key)' 英文翻译 '\(enVal ?? "")' 不应包含中文（段位名应意译）")
        }
    }

    @MainActor
    @Test("棋盘楚河汉界在 xcstrings 中保持中文（board.chuRiver / board.hanBorder）")
    func boardRiverTextStaysChinese() {
        // 审计报告：英文版保持中文原文
        let chuEn = Self.translationValue("board.chuRiver", "en")
        let hanEn = Self.translationValue("board.hanBorder", "en")

        #expect(chuEn != nil, "board.chuRiver 应存在 en 翻译")
        #expect(hanEn != nil, "board.hanBorder 应存在 en 翻译")

        // 英文版的值应包含中文（楚河汉界是领域语言，不翻译）
        if let chu = chuEn {
            #expect(Self.containsChinese(chu), "board.chuRiver 英文翻译 '\(chu)' 应保持中文（领域语言）")
        }
        if let han = hanEn {
            #expect(Self.containsChinese(han), "board.hanBorder 英文翻译 '\(han)' 应保持中文（领域语言）")
        }
    }

    // MARK: - 4. P1 发现验证
    // MARK: - 5. P2 发现验证

    @Test("P2-1: game.vsAITitle 占位符不匹配")
    func p2_1_vsAITitlePlaceholderMismatch() {
        let strings = Self.loadStrings()

        let zhVal = Self.translationValue("game.vsAITitle", "zh-Hans")
        let enVal = Self.translationValue("game.vsAITitle", "en")

        #expect(zhVal != nil, "game.vsAITitle 应有 zh-Hans 翻译")
        #expect(enVal != nil, "game.vsAITitle 应有 en 翻译")

        // 审计发现：中文有 %@，英文没有
        let zhHasPlaceholder = zhVal?.contains("%@") ?? false
        let enHasPlaceholder = enVal?.contains("%@") ?? false

        // 审计发现已修复：中文和英文占位符应一致
        #expect(zhHasPlaceholder == enHasPlaceholder,
                "game.vsAITitle 中英文占位符应一致")
    }

    // MARK: - 6. L10n 运行时可靠性

    @MainActor
    @Test("不存在的 key 返回 key 原文（fallback 机制）")
    func unknownKeyReturnsKey() {
        let l10n = L10n.shared
        l10n.setLanguage("en")
        let result = l10n.t("nonexistent.key.12345")
        #expect(result == "nonexistent.key.12345", "不存在的 key 应返回 key 原文，实际 '\(result)'")
    }

    @MainActor
    @Test("带参数的翻译在两种语言下都能格式化")
    func formatWithArguments() {
        let l10n = L10n.shared

        l10n.setLanguage("zh-Hans")
        let zhResult = l10n.t("status.roundN", 5)
        #expect(zhResult.contains("5"), "中文格式化应包含参数 5")

        l10n.setLanguage("en")
        let enResult = l10n.t("status.roundN", 5)
        #expect(enResult.contains("5"), "英文格式化应包含参数 5")
    }

    @MainActor
    @Test("语言切换后 translations 字典确实更新")
    func translationsUpdateAfterSwitch() {
        let l10n = L10n.shared

        l10n.setLanguage("zh-Hans")
        let zhDict = l10n.translations
        let zhCount = zhDict.count

        l10n.setLanguage("en")
        let enDict = l10n.translations
        let enCount = enDict.count

        #expect(zhCount > 0, "中文翻译表不应为空")
        #expect(enCount > 0, "英文翻译表不应为空")
        #expect(zhCount == enCount, "两种语言的 key 数量应一致（zh=\(zhCount), en=\(enCount)）")

        // 验证翻译内容不同（至少 settings.title 不同）
        #expect(zhDict["settings.title"] != enDict["settings.title"], "中英文 settings.title 应不同")
    }

    // MARK: - 7. 回归保护：xcstrings JSON 格式正确

    @Test("xcstrings JSON 结构正确")
    func xcstringsJsonStructure() {
        let strings = Self.loadStrings()
        #expect(!strings.isEmpty, "xcstrings 不应为空")

        // 抽查若干 key 的结构
        let sampleKeys = ["settings.title", "game.newGame", "difficulty.beginner", "result.draw"]
        for key in sampleKeys {
            guard let entry = strings[key] else {
                Issue.record("抽样 key '\(key)' 不存在")
                continue
            }
            #expect(entry["localizations"] != nil, "key '\(key)' 应有 localizations 节点")
        }
    }

    // MARK: - Helper

    private static func containsChinese(_ str: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "[\u{4e00}-\u{9fff}]")
        let range = NSRange(location: 0, length: (str as NSString).length)
        return (regex?.firstMatch(in: str, range: range)) != nil
    }
}
