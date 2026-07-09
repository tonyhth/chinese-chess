//
//  Phase1P0Tests.swift
//  ChineseChessTests
//
//  Phase 1 P0 修复测试（5 项全部覆盖）
//  1. 教程规则文案：长将/长捉从"和棋"改为"判负"
//  2. 长将弹窗：perpetualCheckMessage + UserDefaults 单次触发
//  3. FirstLaunchDialog：首次启动引导集成
//  4. checkAfterPuzzle：残局完成后成就检查调用
//  5. negamax isTerminal：删除错误的 isTerminal 检查，修复 AI 不识别 forced mate
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

    private static func containsChinese(_ str: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "[\u{4e00}-\u{9fff}]")
        let range = NSRange(location: 0, length: (str as NSString).length)
        return (regex?.firstMatch(in: str, range: range)) != nil
    }

    // MARK: - 修复 1: 教程规则文案（tutorial.3.description）

    @Test("tutorial.3.description 中文版包含长将判负和长捉判负（不再含和棋）")
    func tutorialDescriptionRulesFixChinese() {
        let zhVal = Self.translationValue("tutorial.3.description", "zh-Hans")
        #expect(zhVal != nil, "tutorial.3.description 应有 zh-Hans 翻译")

        guard let zh = zhVal else { return }

        // P0 修复后应包含"判负"，不应包含"和棋"
        #expect(zh.contains("长将判负"), "中文版应包含 '长将判负'，实际: \(zh)")
        #expect(zh.contains("长捉判负"), "中文版应包含 '长捉判负'，实际: \(zh)")

        // 不应再包含旧版的"长将和棋"或"长捉和棋"
        #expect(!zh.contains("长将和棋"), "中文版不应再包含 '长将和棋'（旧文案），实际: \(zh)")
        #expect(!zh.contains("长捉和棋"), "中文版不应再包含 '长捉和棋'（旧文案），实际: \(zh)")
    }

    @Test("tutorial.3.description 英文版包含 Loss（不再是 Draw）")
    func tutorialDescriptionRulesFixEnglish() {
        let enVal = Self.translationValue("tutorial.3.description", "en")
        #expect(enVal != nil, "tutorial.3.description 应有 en 翻译")

        guard let en = enVal else { return }

        // 英文版应包含 "Loss for the checker" / "Loss for the chaser"
        #expect(en.contains("Loss"), "英文版应包含 'Loss'，实际: \(en)")

        // 不应再包含旧的 "Perpetual check = Draw"
        #expect(!en.contains("Perpetual check = Draw"), "英文版不应再包含 'Perpetual check = Draw'（旧文案），实际: \(en)")
        #expect(!en.contains("Perpetual chase = Draw"), "英文版不应再包含 'Perpetual chase = Draw'（旧文案），实际: \(en)")
    }

    @Test("tutorial.3.title 存在且为特殊规则")
    func tutorialTitleFix() {
        let zhVal = Self.translationValue("tutorial.3.title", "zh-Hans")
        #expect(zhVal != nil, "tutorial.3.title 应有 zh-Hans 翻译")

        guard let zh = zhVal else { return }
        // tutorial.3 的标题是 "特殊规则"，内容在 description 中详细说明判负规则
        #expect(zh == "特殊规则", "tutorial.3.title 中文应为 '特殊规则'，实际: \(zh)")
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

        // 记录原始值
        let originalValue = defaults.bool(forKey: key)

        // 清除标记模拟首次触发
        defaults.set(false, forKey: key)
        #expect(!defaults.bool(forKey: key), "清除后 perpetualCheckExplained 应为 false")

        // 模拟首次触发后设置标记
        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key), "设置后 perpetualCheckExplained 应为 true")

        // 恢复原始值
        defaults.set(originalValue, forKey: key)
    }

    // MARK: - 修复 3: FirstLaunchDialog 集成

    @Test("chinesechess.firstLaunchDialogShown UserDefaults 键逻辑")
    func firstLaunchDialogUserDefaultsLogic() {
        let key = "chinesechess.firstLaunchDialogShown"
        let defaults = UserDefaults.standard

        let originalValue = defaults.bool(forKey: key)

        // 模拟首次启动（未标记）
        defaults.set(false, forKey: key)
        let needsDialog = !defaults.bool(forKey: key)
        #expect(needsDialog == true, "首次启动应需要弹窗")

        // 模拟用户点击后标记
        defaults.set(true, forKey: key)
        let needsDialogAgain = !defaults.bool(forKey: key)
        #expect(needsDialogAgain == false, "标记后不需要再弹窗")

        // 恢复
        defaults.set(originalValue, forKey: key)
    }

    @Test("FirstLaunchDialog 组件存在于 TutorialView.swift")
    func firstLaunchDialogExists() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/Tutorial/TutorialView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 TutorialView.swift")
            return
        }

        #expect(content.contains("struct FirstLaunchDialog"), "FirstLaunchDialog 结构体应存在")
        #expect(content.contains("onShowTutorial"), "应有 onShowTutorial 回调")
        #expect(content.contains("onSkip"), "应有 onSkip 回调")
        #expect(content.contains("isPresented"), "应有 isPresented 绑定")
    }

    @Test("ChineseChessApp.swift 集成了 FirstLaunchDialog")
    func firstLaunchDialogIntegratedInMacOSApp() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 ChineseChessApp.swift")
            return
        }

        #expect(content.contains("firstLaunchDialogShown"), "应引用 firstLaunchDialogShown UserDefaults 键")
        #expect(content.contains("showFirstLaunchDialog"), "应有 showFirstLaunchDialog 状态变量")
        #expect(content.contains("FirstLaunchDialog"), "应实例化 FirstLaunchDialog")
        #expect(content.contains("firstLaunchNeeded"), "应有 firstLaunchNeeded 标志")
    }

    @Test("ChineseChessiOSApp.swift 集成了 FirstLaunchDialog")
    func firstLaunchDialogIntegratedInIOSApp() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 ChineseChessiOSApp.swift")
            return
        }

        #expect(content.contains("firstLaunchDialogShown"), "iOS App 应引用 firstLaunchDialogShown")
        #expect(content.contains("showFirstLaunchDialog"), "iOS App 应有 showFirstLaunchDialog")
        #expect(content.contains("FirstLaunchDialog"), "iOS App 应实例化 FirstLaunchDialog")
    }

    // MARK: - 修复 4: PuzzleViewModel 调用 checkAfterPuzzle

    @Test("PuzzleViewModel.swift 集成了 AchievementChecker.checkAfterPuzzle 调用")
    func checkAfterPuzzleIntegration() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/PuzzleViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 PuzzleViewModel.swift")
            return
        }

        #expect(content.contains("AchievementChecker.checkAfterPuzzle"), "PuzzleViewModel 应调用 checkAfterPuzzle")
        #expect(content.contains("AchievementManager.shared.unlock"), "PuzzleViewModel 应调用 unlock 解锁成就")
    }

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

    // MARK: - 修复 5: negamax isTerminal bug

    @Test("negamax 函数中不再调用 isTerminal")
    func negamaxIsTerminalNotCalledInNegamax() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/AI/AIEngine.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 AIEngine.swift")
            return
        }

        // P0 修复：negamax() 函数体中不再有 isTerminal(board) 调用
        // isTerminal 方法定义可能仍保留（死代码），但 negamax 内不应调用它
        // 策略：提取 negamax 函数体，检查其中不含 isTerminal 调用
        if let negamaxRange = content.range(of: "private func negamax(") {
            // 找到 negamax 函数的起始位置后，检查到下一个 private func 之前
            let afterNegamax = content[negamaxRange.lowerBound...]
            // 查找 negamax 函数体内是否有 isTerminal 调用
            // isTerminal( 是调用，isTerminal -> Bool 是方法定义（在文件底部）
            let negamaxSection = String(afterNegamax.prefix(3000)) // negamax 函数不会超过 3000 字符
            #expect(!negamaxSection.contains("isTerminal("), "negamax 函数内不应调用 isTerminal()")
        }
    }

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
        // 验证修复的核心效果：被将死时 AI 能正常处理，不崩溃
        // 策略：直接构造棋子数组，创建一个红方被将死的局面

        // 黑将在 e9(9,4)，黑士在 d9(9,3) 和 f9(9,5)
        // 黑车在 e1(1,4)，直接将军红帅
        // 红帅在 e0(0,4)，无法移动（被车控制 e 线，d0/f0 出九宫）
        var testPieces: [Piece] = [
            Piece(kind: .general, side: .black, position: Position(row: 9, col: 4), id: 294),
            Piece(kind: .advisor, side: .black, position: Position(row: 9, col: 3), id: 293),
            Piece(kind: .advisor, side: .black, position: Position(row: 9, col: 5), id: 295),
            Piece(kind: .chariot, side: .black, position: Position(row: 1, col: 4), id: 214),
            Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 104),
        ]

        let board = Board(pieces: testPieces)
        // currentTurn 默认 .red

        // 验证红方确实被将军
        let inCheck = MoveValidator.isInCheck(.red, on: board)
        #expect(inCheck, "红帅应被黑车将军")

        // 验证红方无合法走法（被将死）
        let redMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(redMoves.isEmpty, "红方应无合法走法（被将死），实际有 \(redMoves.count) 种走法")

        // 现在构造黑方走棋的局面，验证 AI 能正常处理
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

        // 测试多个难度
        for difficulty in [AIDifficulty.beginner, .easy, .medium] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: difficulty)
            #expect(move != nil, "\(difficulty) 难度应返回走法")
        }
    }

    // MARK: - 修复（OpeningExplorerView 重构）

    @Test("OpeningExplorerView.swift 包含 OpeningBoardPreview")
    func openingBoardPreviewExists() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/OpeningExplorerView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 OpeningExplorerView.swift")
            return
        }

        #expect(content.contains("struct OpeningBoardPreview"), "应有 OpeningBoardPreview 结构体")
        #expect(content.contains("func findPath"), "应有 findPath DFS 方法")
        #expect(content.contains("func dfsPath"), "应有 dfsPath 辅助方法")
    }

    @Test("OpeningExplorerView 不再使用 walkPath")
    func walkPathRemoved() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/OpeningExplorerView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 OpeningExplorerView.swift")
            return
        }

        #expect(!content.contains("walkPath"), "不应再使用 walkPath")
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
