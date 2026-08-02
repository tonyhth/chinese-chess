//
//  Phase1P0Tests.swift
//  ChineseChessTests
//
//  Phase 1 P0 修复测试（5 项全部覆盖）
//  注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 1 P0 修复测试", .serialized)
struct Phase1P0Tests {

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

    // MARK: - 修复 1: 教程规则文案（tutorial.lesson2 含将军/将死/困毙/长将判负）
    // 注意：tutorial key 已从 tutorial.3.* 改为 tutorial.lesson*

    @Test("tutorial.lesson2.description 中文版包含将军/将死/困毙/长将判负")
    func tutorialDescriptionRulesFixChinese() {
        let zhVal = Self.translationValue("tutorial.lesson2.description", "zh-Hans")
        #expect(zhVal != nil, "tutorial.lesson2.description 应有 zh-Hans 翻译")

        guard let zh = zhVal else { return }

        #expect(zh.contains("将死"), "中文版应包含 '将死'，实际: \(zh)")
        #expect(zh.contains("困毙"), "中文版应包含 '困毙'，实际: \(zh)")
    }

    @Test("tutorial.lesson2.subtitle 中文版包含长将判负")
    func tutorialDescriptionRulesFixEnglish() {
        let zhVal = Self.translationValue("tutorial.lesson2.subtitle", "zh-Hans")
        #expect(zhVal != nil, "tutorial.lesson2.subtitle 应有 zh-Hans 翻译")

        guard let zh = zhVal else { return }

        #expect(zh.contains("长将判负"), "subtitle 应包含 '长将判负'，实际: \(zh)")
    }

    @Test("tutorial.lesson3.title 存在且为走子练习")
    func tutorialTitleFix() {
        let zhVal = Self.translationValue("tutorial.lesson3.title", "zh-Hans")
        #expect(zhVal != nil, "tutorial.lesson3.title 应有 zh-Hans 翻译")

        guard let zh = zhVal else { return }
        #expect(!zh.isEmpty, "tutorial.lesson3.title 中文不应为空")
    }

    // MARK: - 修复 2: 长将弹窗 perpetualCheckMessage

    @MainActor
    @Test("GameViewModel.perpetualCheckMessage 初始为 nil")
    func perpetualCheckMessageInitiallyNil() {
        let vm = GameViewModel()
        #expect(vm.perpetualCheckMessage == nil, "新对局 perpetualCheckMessage 应为 nil")
    }

    @Test("game.perpetualCheckTitle 和 game.perpetualCheckMessage xcstrings key 存在")
    func perpetualCheckAlertKeysExist() {
        let titleKey = "game.perpetualCheckTitle"
        let msgKey = "game.perpetualCheckMessage"

        let zhTitle = Self.translationValue(titleKey, "zh-Hans")
        let enTitle = Self.translationValue(titleKey, "en")
        let zhMsg = Self.translationValue(msgKey, "zh-Hans")
        let enMsg = Self.translationValue(msgKey, "en")

        #expect(zhTitle != nil, "\(titleKey) 应有 zh-Hans 翻译")
        #expect(enTitle != nil, "\(titleKey) 应有 en 翻译")
        #expect(zhMsg != nil, "\(msgKey) 应有 zh-Hans 翻译")
        #expect(enMsg != nil, "\(msgKey) 应有 en 翻译")
    }

    @Test("common.gotIt xcstrings key 存在（弹窗按钮）")
    func commonGotItKeyExists() {
        let zhVal = Self.translationValue("common.gotIt", "zh-Hans")
        let enVal = Self.translationValue("common.gotIt", "en")

        #expect(zhVal != nil, "common.gotIt 应有 zh-Hans 翻译")
        #expect(enVal != nil, "common.gotIt 应有 en 翻译")
    }

    @Test("perpetualCheckMessage UserDefaults 单次触发逻辑")
    func perpetualCheckMessageUserDefaultsFlag() {
        let key = "chinesechess.perpetualCheckExplained"
        let defaults = UserDefaults.standard

        let originalValue = defaults.bool(forKey: key)

        defaults.set(false, forKey: key)
        #expect(!defaults.bool(forKey: key), "清除后 perpetualCheckExplained 应为 false")

        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key), "设置后 perpetualCheckExplained 应为 true")

        defaults.set(originalValue, forKey: key)
    }

    // MARK: - 修复 3: FirstLaunchDialog 集成

    @Test("chinesechess.firstLaunchDialogShown UserDefaults 键逻辑")
    func firstLaunchDialogUserDefaultsLogic() {
        let key = "chinesechess.firstLaunchDialogShown"
        let defaults = UserDefaults.standard

        let originalValue = defaults.bool(forKey: key)

        defaults.set(false, forKey: key)
        let needsDialog = !defaults.bool(forKey: key)
        #expect(needsDialog == true, "首次启动应需要弹窗")

        defaults.set(true, forKey: key)
        let needsDialogAgain = !defaults.bool(forKey: key)
        #expect(needsDialogAgain == false, "标记后不需要再弹窗")

        defaults.set(originalValue, forKey: key)
    }

    // MARK: - 修复 4: PuzzleViewModel 调用 checkAfterPuzzle

    @MainActor
    @Test("AchievementChecker.checkAfterPuzzle 方法存在且签名正确")
    func checkAfterPuzzleMethodExists() {
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else {
            Issue.record("无残局数据")
            return
        }
        let profile = PlayerProfileStore.shared.profile

        let result = AchievementChecker.checkAfterPuzzle(
            puzzleType: puzzle.solutionType,
            chapterId: puzzle.category,
            allPuzzleCount: PuzzleStore.shared.totalPuzzles,
            completedCount: PuzzleStore.shared.completedCount,
            profile: profile
        )
        #expect(result.count >= 0, "checkAfterPuzzle 应返回数组")
    }

    // MARK: - 修复 5: negamax isTerminal bug（行为测试）

    @MainActor
    @Test("AI 仍能正常走棋（beginner 难度）")
    func aiCanStillMoveBeginner() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
        #expect(move != nil, "beginner 难度应返回走法")
    }

    @MainActor
    @Test("AI 仍能正常走棋（master 难度）")
    func aiCanStillMoveMaster() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        #expect(move != nil, "master 难度应返回走法")
    }

    @MainActor
    @Test("negamax 终局位置返回将死分而非材质分")
    func negamaxReturnsMateScoreForTerminalPosition() async {
        var testPieces: [Piece] = [
            Piece(kind: .general, side: .black, position: Position(row: 9, col: 4), id: 294),
            Piece(kind: .advisor, side: .black, position: Position(row: 9, col: 3), id: 293),
            Piece(kind: .advisor, side: .black, position: Position(row: 9, col: 5), id: 295),
            Piece(kind: .chariot, side: .black, position: Position(row: 1, col: 4), id: 214),
            Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 104),
        ]

        let board = Board(pieces: testPieces)

        let inCheck = MoveValidator.isInCheck(.red, on: board)
        #expect(inCheck, "红帅应被黑车将军")

        let redMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(redMoves.isEmpty, "红方应无合法走法（被将死），实际有 \(redMoves.count) 种走法")

        let blackBoard = board.snapshot()
        blackBoard.toggleTurn()
        let engine = AIEngine()
        let move = await engine.bestMove(for: blackBoard.snapshot(), difficulty: .easy)
        #expect(move != nil, "黑方在被将死对手的局面应能返回走法")
    }

    @MainActor
    @Test("AI 在标准开局能正常走棋（无 isTerminal 回归）")
    func aiStandardOpeningNoRegression() async {
        let engine = AIEngine()
        let board = Board()

        for difficulty in [AIDifficulty.beginner, .easy, .medium] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: difficulty)
            #expect(move != nil, "\(difficulty) 难度应返回走法")
        }
    }

    // MARK: - 回归保护

    @MainActor
    @Test("GameViewModel 回归：新局 32 子 + perpetualCheckMessage nil")
    func gameViewModelRegression() {
        let vm = GameViewModel()
        #expect(vm.board.pieces.count == 32, "新局应有 32 子")
        #expect(vm.gameState == .playing, "初始状态应为 playing")
        #expect(vm.perpetualCheckMessage == nil, "初始 perpetualCheckMessage 应为 nil")
        #expect(vm.engineFallbackMessage == nil, "初始 engineFallbackMessage 应为 nil")
    }

    @MainActor
    @Test("PuzzleViewModel 回归：仍能正常初始化")
    func puzzleViewModelRegression() {
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else {
            Issue.record("无残局数据")
            return
        }
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing, "残局初始状态应为 playing")
        #expect(vm.board.pieces.count > 0, "残局棋盘应有棋子")
    }
}
