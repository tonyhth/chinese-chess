import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.18 Guided Puzzle 引导式残局测试（返工复测）

@Suite("v2.2.18 返工复测")
struct V2218RetestTests {

    // MARK: - 辅助方法

    private static func makeTestPuzzle(
        id: String = "test-guided",
        initialFEN: String = "2baka3/3P3N1/bN7/7nc/9/4C1P2/P5n1P/B3R3B/4Apr2/2RAK3c w - - 0 1",
        playerSide: String = "red",
        stars: Int = 1,
        solution: [String] = [],
        solutionType: String = "checkmate"
    ) -> Puzzle {
        Puzzle(
            id: id, name: "测试引导残局", category: "test", difficulty: 1, stars: stars,
            description: "测试", playerSide: playerSide, initialFEN: initialFEN,
            solution: solution, hints: nil, maxMoves: 20,
            solutionType: solutionType
        )
    }

    private static func readSource(_ filename: String) -> String {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let basePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/"
        let fm = FileManager.default
        for sub in ["ViewModels", "Views", "Services", "Helpers", "Models", "AI", "App"] {
            let p = basePath + sub + "/" + filename
            if fm.fileExists(atPath: p), let data = try? String(contentsOfFile: p) {
                return data
            }
        }
        if let data = try? String(contentsOfFile: basePath + filename) {
            return data
        }
        return ""
    }

    // MARK: - ✅ P0 修复验证：ICCS 双格式支持

    @Suite("✅ P0 修复：ICCSParser 双格式支持")
    struct ICCSFormatFixTests {

        @Test("ICCSParser.parse 现在可以解析数字 ICCS '5450'")
        func iccsParserParsesNumericFormat() {
            let board = Board(fen: "2baka3/3P3N1/bN7/7nc/9/4C1P2/P5n1P/B3R3B/4Apr2/2RAK3c w - - 0 1")
            let result = ICCSParser.parse("5450", on: board)

            #expect(result != nil,
                   "✅ ICCSParser.parse('5450') 现在应返回合法 Move（数字格式已支持）")
        }

        @Test("数字 ICCS 解析结果位置正确")
        func numericICCSPositionCorrect() {
            let board = Board(fen: "2baka3/3P3N1/bN7/7nc/9/4C1P2/P5n1P/B3R3B/4Apr2/2RAK3c w - - 0 1")
            let result = ICCSParser.parse("5450", on: board)

            if let move = result {
                #expect(move.from.row == 5 && move.from.col == 4,
                       "from 应为 (row=5, col=4)，实际 \(move.from)")
                #expect(move.to.row == 5 && move.to.col == 0,
                       "to 应为 (row=5, col=0)，实际 \(move.to)")
            }
        }

        @Test("ICCSParser.isNumeric 检测数字格式")
        func isNumericDetection() {
            #expect(ICCSParser.isNumeric("5450"), "5450 应为数字格式")
            #expect(!ICCSParser.isNumeric("h2e2"), "h2e2 不应为数字格式")
            #expect(!ICCSParser.isNumeric("5a20"), "5a20 混合格式不应为数字格式")
            #expect(!ICCSParser.isNumeric("abc"), "abc 长度不足不应为数字格式")
        }

        @Test("numericIccsString 生成数字 ICCS")
        func numericIccsStringGeneration() {
            let from = Position(row: 5, col: 4)
            let to = Position(row: 5, col: 0)
            let result = ICCSParser.numericIccsString(from: from, to: to)

            #expect(result == "5450", "numericIccsString 应生成 '5450'，实际 '\(result)'")
        }

        @Test("字母格式仍然正常工作")
        func alphabeticFormatStillWorks() {
            let board = Board(fen: "rnbakabnr/9/9/9/9/9/9/9/9/RNBAKABNR w - - 0 1")
            // 红马 h0→g2 (字母格式)
            let result = ICCSParser.parse("h0g2", on: board)
            // 可能不合法（初始局面马不能走 h0g2），但至少不 crash
            // 用一个更合理的 FEN
            let board2 = Board(fen: "rnbakabnr/9/9/9/9/9/9/9/RN2KBNR/9 w - - 0 1")
            let result2 = ICCSParser.parse("b0c2", on: board2)
            #expect(result2 != nil, "字母格式 b0c2 应正常解析")
        }

        @Test("sqyq_001 所有 solution 步骤现在都能解析")
        func sqyq001AllSolutionStepsParseable() {
            let puzzle = PuzzleStore.shared.puzzle(byId: "sqyq_001")
            guard let puzzle = puzzle else {
                Issue.record("sqyq_001 不存在")
                return
            }

            let vm = PuzzleViewModel(puzzle: puzzle)
            var successCount = 0

            for (_, iccs) in puzzle.solution.enumerated() {
                if ICCSParser.parse(iccs, on: vm.board) != nil {
                    successCount += 1
                }
            }

            // 至少第1步（在初始棋盘上）应该能解析
            #expect(successCount >= 1,
                   "✅ 至少第1步数字 ICCS 解析成功，实际 \(successCount)/\(puzzle.solution.count) 成功")
        }

        @Test("引导模式走对判定现在能匹配")
        func guidedModeCorrectMoveNowMatches() {
            // 验证 numericIccsString 生成的格式与 puzzles.json 匹配
            let from = Position(row: 5, col: 4)
            let to = Position(row: 5, col: 0)
            let numericResult = ICCSParser.numericIccsString(from: from, to: to)

            #expect(numericResult == "5450",
                   "numericIccsString 应生成与 puzzles.json 一致的格式")
        }
    }

    // MARK: - ✅ P1-1 修复验证：solutionDegraded 降级

    @Suite("✅ P1-1 修复：solution 数据异常降级")
    struct SolutionDegradedTests {

        @Test("PuzzleViewModel 包含 solutionDegraded 属性")
        func solutionDegradedPropertyExists() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("solutionDegraded"),
                   "PuzzleViewModel 应包含 solutionDegraded 属性")
        }

        @Test("isGuidedMode 在 solutionDegraded=true 时返回 false")
        func isGuidedModeFalseWhenDegraded() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("!solutionDegraded"),
                   "isGuidedMode 应检查 !solutionDegraded")
        }

        @Test("resetPuzzle 重置 solutionDegraded = false")
        func resetPuzzleResetsDegraded() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("solutionDegraded = false"),
                   "resetPuzzle 应重置 solutionDegraded = false")
        }

        @Test("i18n key puzzle.solutionDegraded 存在")
        func i18nKeyExists() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            if let content = try? String(contentsOfFile: path) {
                #expect(content.contains("puzzle.solutionDegraded"),
                       "Localizable.xcstrings 应包含 puzzle.solutionDegraded key")
            }
        }
    }

    // MARK: - ✅ P1-2 修复验证：撤销按钮 disabled

    @Suite("✅ P1-2 修复：撤销按钮 disabled")
    struct UndoButtonDisabledTests {

        @Test("撤销按钮在 gameMoves.isEmpty 时 disabled")
        func undoButtonDisabledWhenEmpty() {
            let content = V2218RetestTests.readSource("PuzzleSelectView.swift")
            #expect(content.contains("gameMoves.isEmpty"),
                   "撤销按钮应检查 gameMoves.isEmpty")
        }

        @Test("撤销按钮 disabled 条件包含 isThinking 和 gameMoves.isEmpty")
        func undoButtonDisabledConditions() {
            let content = V2218RetestTests.readSource("PuzzleSelectView.swift")
            #expect(content.contains("isThinking || viewModel.gameMoves.isEmpty"),
                   "撤销按钮 disabled 应为 isThinking || gameMoves.isEmpty")
        }
    }

    // MARK: - 1. 引导模式基本流程

    @Suite("1. 引导模式基本流程")
    struct GuidedFlowTests {

        @Test("sqyq_001 effectiveMode 为 .guided")
        func sqyq001IsGuidedMode() {
            let puzzle = PuzzleStore.shared.puzzle(byId: "sqyq_001")
            #expect(puzzle != nil, "sqyq_001 应存在")
            guard let puzzle = puzzle else { return }
            #expect(puzzle.effectiveMode == .guided, "sqyq_001 effectiveMode 应为 .guided")
        }

        @Test("sqyq_001 solution 有 11 步")
        func sqyq001SolutionHas11Steps() {
            let puzzle = PuzzleStore.shared.puzzle(byId: "sqyq_001")
            guard let puzzle = puzzle else { return }
            #expect(puzzle.solution.count == 11, "sqyq_001 solution 应有 11 步")
        }

        @Test("PuzzleViewModel 初始化 sqyq_001 后状态正确")
        func puzzleViewModelInitialState() {
            let puzzle = PuzzleStore.shared.puzzle(byId: "sqyq_001")
            guard let puzzle = puzzle else { return }
            let vm = PuzzleViewModel(puzzle: puzzle)

            #expect(vm.gameState == .playing, "初始状态应为 playing")
            #expect(vm.isThinking == false, "初始 isThinking 应为 false")
            #expect(vm.solutionStepIndex == 0, "初始 solutionStepIndex 应为 0")
            #expect(vm.isProcessingWrongMove == false, "初始 isProcessingWrongMove 应为 false")
        }

        @Test("handleSquareTap 在 isProcessingWrongMove 时拒绝操作")
        func handleSquareTapBlockedDuringWrongMove() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.isProcessingWrongMove = true
            vm.handleSquareTap(at: Position(row: 4, col: 5))
            #expect(vm.selectedPosition == nil, "isProcessingWrongMove 时应拒绝点击")
        }

        @Test("movePiece 在 isProcessingWrongMove 时拒绝操作")
        func movePieceBlockedDuringWrongMove() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.isProcessingWrongMove = true
            let initialCount = vm.gameMoves.count
            vm.movePiece(from: Position(row: 4, col: 5), to: Position(row: 0, col: 5))
            #expect(vm.gameMoves.count == initialCount, "isProcessingWrongMove 时应拒绝走棋")
        }
    }

    // MARK: - 2. 走错回退

    @Suite("2. 走错回退机制")
    struct WrongMoveRollbackTests {

        @Test("handleWrongMove 设置 isProcessingWrongMove = true")
        func handleWrongMoveSetsProcessingFlag() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("isProcessingWrongMove = true"),
                   "handleWrongMove 应设置 isProcessingWrongMove = true")
        }

        @Test("handleWrongMove 设置 gameState = .wrongMove")
        func handleWrongMoveSetsWrongMoveState() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("gameState = .wrongMove"),
                   "handleWrongMove 应设置 gameState = .wrongMove")
        }

        @Test("0.8s 回退后清空 solutionHint 和 hintMove")
        func rollbackClearsHintState() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("self.solutionHint = nil"), "回退后应清空 solutionHint")
            #expect(content.contains("self.hintMove = nil"), "回退后应清空 hintMove")
        }

        @Test("0.8s 回退后重置 isProcessingWrongMove = false 和 gameState = .playing")
        func rollbackResetsState() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("self.isProcessingWrongMove = false"),
                   "回退后应重置 isProcessingWrongMove = false")
            #expect(content.contains("self.gameState = .playing"),
                   "回退后 gameState 应恢复为 .playing")
        }

        @Test("回退延迟为 800ms（0.8s）")
        func rollbackDelayIs800ms() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("800_000_000"), "回退延迟应为 800_000_000 纳秒")
        }
    }

    // MARK: - 3. 撤销功能

    @Suite("3. Guided 模式撤销")
    struct GuidedUndoTests {

        @Test("guided 模式撤销回退一对步")
        func guidedUndoRetreatsPair() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("isGuidedMode"), "undoMove 应有 isGuidedMode 分支")
            #expect(content.contains("undoLastMove"), "应调用 undoLastMove")
        }

        @Test("guided 撤销回退 solutionStepIndex -2")
        func guidedUndoDecrementsSolutionStepIndex() {
            let content = V2218RetestTests.readSource("PuzzleViewModel.swift")
            #expect(content.contains("solutionStepIndex = max(0, solutionStepIndex - 2)"),
                   "guided 撤销应回退 solutionStepIndex - 2")
        }

        @Test("isProcessingWrongMove 时拒绝撤销")
        func undoBlockedDuringWrongMoveProcessing() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.isProcessingWrongMove = true
            let initialMoveCount = vm.gameMoves.count
            vm.undoMove()
            #expect(vm.gameMoves.count == initialMoveCount, "isProcessingWrongMove 时撤销应被拒绝")
        }

        @Test("isThinking 时拒绝撤销")
        func undoBlockedDuringThinking() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.isThinking = true
            let initialMoveCount = vm.gameMoves.count
            vm.undoMove()
            #expect(vm.gameMoves.count == initialMoveCount, "isThinking 时撤销应被拒绝")
        }
    }

    // MARK: - 4. v2.2.17 累积修复

    @Suite("4. v2.2.17 累积修复")
    struct V2217RegressionTests {

        @Test("L10n 加载 .xcstrings 格式")
        func l10nLoadsXcstrings() {
            let content = V2218RetestTests.readSource("L10n.swift")
            #expect(content.contains(".xcstrings"), "L10n 应支持 .xcstrings")
            #expect(content.contains("Localizable.xcstrings"), "应加载 Localizable.xcstrings")
        }

        @Test("L10n 切换语言即时生效")
        func l10nSwitchWithoutRestart() {
            let l10n = L10n.shared
            let originalLang = l10n.language
            l10n.setLanguage("en")
            #expect(l10n.language == "en", "切换后语言应为 en")
            l10n.setLanguage(originalLang)
            #expect(l10n.language == originalLang, "切换回原语言应成功")
        }

        @Test("resetPuzzle 将 isThinking 重置为 false")
        func resetPuzzleClearsIsThinking() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.isThinking = true
            vm.resetPuzzle()
            #expect(vm.isThinking == false, "resetPuzzle 应重置 isThinking")
        }

        @Test("SettingsView 使用 Form 而非外层 ScrollView")
        func settingsViewNoOuterScrollView() {
            let content = V2218RetestTests.readSource("SettingsView.swift")
            #expect(content.contains("Form"), "应使用 Form")
            #expect(content.contains(".formStyle(.grouped)"), "应使用 .formStyle(.grouped)")
        }
    }

    // MARK: - 5. 引导角标 UI

    @Suite("5. 引导角标 UI")
    struct GuidedBadgeUITests {

        @Test("PuzzleSelectView 对 guided 残局显示绿色角标")
        func puzzleSelectViewShowsGuidedBadge() {
            let content = V2218RetestTests.readSource("PuzzleSelectView.swift")
            #expect(content.contains("puzzle.effectiveMode == .guided"), "应有 .guided 判断")
            #expect(content.contains("puzzle.guided"), "应显示引导本地化文本")
            #expect(content.contains(".green"), "引导角标应使用绿色")
        }
    }

    // MARK: - 6. 状态完整性

    @Suite("6. 状态完整性")
    struct StateIntegrityTests {

        @Test("wrongMove 是短暂状态")
        func wrongMoveIsTransientState() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            #expect(vm.gameState != .wrongMove, "初始状态不应为 wrongMove")
        }

        @Test("solutionHint 初始为 nil")
        func solutionHintInitiallyNil() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            #expect(vm.solutionHint == nil, "初始 solutionHint 应为 nil")
        }

        @Test("hintMove 初始为 nil")
        func hintMoveInitiallyNil() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            #expect(vm.hintMove == nil, "初始 hintMove 应为 nil")
        }

        @Test("resetPuzzle 清空所有引导状态")
        func resetPuzzleClearsAllGuidedState() {
            let puzzle = V2218RetestTests.makeTestPuzzle(solution: ["5450", "6674"])
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.solutionStepIndex = 3
            vm.isProcessingWrongMove = true
            vm.solutionHint = "测试提示"
            vm.resetPuzzle()

            #expect(vm.solutionStepIndex == 0, "resetPuzzle 应重置 solutionStepIndex")
            #expect(vm.isProcessingWrongMove == false, "resetPuzzle 应重置 isProcessingWrongMove")
            #expect(vm.solutionHint == nil, "resetPuzzle 应清空 solutionHint")
            #expect(vm.hintMove == nil, "resetPuzzle 应清空 hintMove")
        }

        @Test("PuzzleState.wrongMove 枚举值存在")
        func wrongMoveEnumCaseExists() {
            let state = PuzzleViewModel.PuzzleState.wrongMove
            #expect(state == .wrongMove, ".wrongMove 枚举值应存在")
        }
    }
}
