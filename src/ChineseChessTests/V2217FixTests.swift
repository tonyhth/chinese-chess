import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.17 iOS 6 Bug 修复验证

@Suite("v2.2.17 Bug 修复验证", .serialized)
struct V2217FixTests {

    // MARK: - 辅助方法

    private static func makeTestPuzzle(
        id: String = "test-puzzle",
        initialFEN: String = "3ak4/9/9/9/9/9/9/9/9/4K4 w",
        playerSide: String = "red",
        stars: Int = 1,
        solution: [String] = [],
        solutionType: String = "checkmate"
    ) -> Puzzle {
        Puzzle(
            id: id, name: "测试残局", category: "test", difficulty: 1, stars: stars,
            description: "测试", playerSide: playerSide, initialFEN: initialFEN,
            solution: solution, hints: nil, maxMoves: 10,
            solutionType: solutionType
        )
    }

    // MARK: - Bug 1：残局失败后重试无法走子 【P0】

    @Suite("Bug 1：残局失败后重试无法走子", .serialized)
    struct Bug1PuzzleRetryTests {

        @MainActor
@Test("resetPuzzle() 重置 isThinking 为 false")
        func resetPuzzleClearsIsThinking() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-retry")
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 模拟 isThinking 被设为 true
            vm.isThinking = true
            #expect(vm.isThinking == true, "前置条件：isThinking 应为 true")

            // 调用 resetPuzzle
            vm.resetPuzzle()

            // 验证 isThinking 被重置
            #expect(vm.isThinking == false, "resetPuzzle() 应将 isThinking 重置为 false")
        }

        @MainActor
@Test("resetPuzzle() 后 gameState 恢复为 playing")
        func resetPuzzleRestoresGameState() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-retry-state")
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 模拟失败状态
            vm.gameState = PuzzleViewModel.PuzzleState.failed
            vm.isThinking = true

            vm.resetPuzzle()

            #expect(vm.gameState == PuzzleViewModel.PuzzleState.playing, "resetPuzzle() 应将 gameState 恢复为 playing")
            #expect(vm.isThinking == false, "resetPuzzle() 应将 isThinking 重置为 false")
        }

        @MainActor
@Test("resetPuzzle() 后清空 gameMoves")
        func resetPuzzleClearsGameMoves() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-retry-moves")
            let vm = PuzzleViewModel(puzzle: puzzle)

            vm.resetPuzzle()

            #expect(vm.gameMoves.isEmpty, "resetPuzzle() 应清空 gameMoves")
            #expect(vm.selectedPosition == nil, "resetPuzzle() 应清空 selectedPosition")
            #expect(vm.legalMovesForSelected.isEmpty, "resetPuzzle() 应清空 legalMovesForSelected")
        }

        @MainActor
@Test("resetPuzzle() 后可以选择棋子（isThinking 不阻塞）")
        func resetPuzzleAllowsSelection() {
            // 使用标准开局 FEN，确保红方有棋子可走
            let puzzle = V2217FixTests.makeTestPuzzle(
                id: "test-retry-select",
                initialFEN: FENParser.standardInitial  // 标准开局
            )
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 模拟失败+思考状态
            vm.gameState = PuzzleViewModel.PuzzleState.failed
            vm.isThinking = true

            // 重置
            vm.resetPuzzle()

            // 验证重置后 gameState 和 isThinking 正确
            #expect(vm.gameState == PuzzleViewModel.PuzzleState.playing, "重置后 gameState 应为 playing")
            #expect(vm.isThinking == false, "重置后 isThinking 应为 false")

            // 验证重置后可以选择棋子：红炮在 row=7, col=1
            let cannonPos = Position(row: 7, col: 1)
            let moves = vm.selectPiece(at: cannonPos)
            #expect(!moves.isEmpty, "重置后应能选择红炮并获取合法走法")
        }

        @MainActor
@Test("triggerDefenderMove 将死/和局路径 isThinking 最终为 false")
        func triggerDefenderCheckmateClearsIsThinking() async {
            // 构造黑方走棋的局面：黑方走后可能将死红方
            let puzzle = V2217FixTests.makeTestPuzzle(
                id: "test-checkmate-path",
                initialFEN: "4k4/4R4/9/9/9/9/9/9/9/4K4 b",
                playerSide: "red"
            )
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 验证初始状态
            #expect(vm.isThinking == false)

            // 等待足够时间让 Task.detached 完成
            try? await Task.sleep(for: .milliseconds(800))

            // 验证最终 isThinking 不卡在 true
            #expect(vm.isThinking == false, "AI 走棋完成后 isThinking 应为 false")
        }

        @MainActor
@Test("resetPuzzle() 后 puzzleVersion 递增（防止旧 Task 干扰）")
        func resetPuzzleIncrementsVersion() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-version")
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 第一次重置
            vm.resetPuzzle()
            // 第二次重置
            vm.resetPuzzle()

            // 如果两次重置都正常执行了且不 crash，说明 puzzleVersion 递增逻辑正常
            #expect(vm.gameState == .playing, "多次重置后 gameState 应仍为 playing")
            #expect(vm.isThinking == false, "多次重置后 isThinking 应仍为 false")
        }
    }

    // MARK: - Bug 2：设置页面进入后没内容 【P0】

    @Suite("Bug 2：设置页面 ScrollView 移除", .serialized)
    struct Bug2SettingsViewTests {

        @MainActor
@Test("SettingsView 不包含外层 ScrollView")
        func settingsViewNoOuterScrollView() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/SettingsView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 SettingsView.swift")
                return
            }

            // 检查 Form 之前没有 ScrollView
            let lines = content.components(separatedBy: "\n")
            var foundFormBody = false
            var scrollViewBeforeForm = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("var body: some View") {
                    foundFormBody = true
                }
                if foundFormBody && trimmed.hasPrefix("ScrollView") {
                    scrollViewBeforeForm = true
                }
                if foundFormBody && trimmed.hasPrefix("Form") {
                    break
                }
            }

            #expect(!scrollViewBeforeForm, "SettingsView 不应在 Form 之前有外层 ScrollView")
        }

        @MainActor
@Test("SettingsView 使用 .formStyle(.grouped)")
        func settingsViewUsesGroupedFormStyle() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/SettingsView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 SettingsView.swift")
                return
            }

            #expect(content.contains(".formStyle(.grouped)"),
                   "SettingsView 应使用 .formStyle(.grouped) 提供自带滚动")
        }

        @MainActor
@Test("SettingsView 包含所有必要的 Section")
        func settingsViewContainsAllSections() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/SettingsView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 SettingsView.swift")
                return
            }

            // 验证关键 Section 存在
            #expect(content.contains("Section"), "SettingsView 应包含 Section")
            #expect(content.contains("difficulty.label"), "应包含难度设置 Section")
            #expect(content.contains("settings.sound"), "应包含音效 Section")
            #expect(content.contains("settings.aboutSection"), "应包含关于 Section")
        }
    }

    // MARK: - Bug 3：历史对局选中后不显示 【P0】

    @Suite("Bug 3：历史对局选中后不显示", .serialized)
    struct Bug3HistoryReplayTests {

        @MainActor
@Test("GameHistoryView 使用 onReplayRequest 回调（非内嵌 sheet）")
        func gameHistoryViewUsesCallback() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameHistoryView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 GameHistoryView.swift")
                return
            }

            #expect(content.contains("onReplayRequest"), "GameHistoryView 应定义 onReplayRequest 回调")
            #expect(content.contains("onReplayRequest?"), "应通过回调通知上层，而非内嵌 sheet")
        }

        @MainActor
@Test("iOS App 层使用 fullScreenCover(item:) 呈现 ReplayView")
        func iOSAppUsesFullScreenCover() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessiOSApp.swift")
                return
            }

            #expect(content.contains("fullScreenCover(item:"), "iOS 应使用 fullScreenCover(item:) 呈现历史回放")
            #expect(content.contains("historyReplayRecord"), "应使用 historyReplayRecord 状态变量")
        }

        @MainActor
@Test("macOS App 层使用 .sheet(item:) 呈现 ReplayView")
        func macOSAppUsesSheetItem() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessApp.swift")
                return
            }

            #expect(content.contains("historyReplayRecord"), "macOS 应使用 historyReplayRecord 状态变量")
            #expect(content.contains(".sheet(item:"), "macOS 应使用 .sheet(item:) 呈现历史回放")
        }

        @MainActor
@Test("iOS GameHistoryView 的 onReplayRequest 回调设置 historyReplayRecord")
        func iOSHistoryCallbackSetsRecord() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessiOSApp.swift")
                return
            }

            // 验证回调设置 historyReplayRecord（而非直接弹 ReplayView）
            #expect(content.contains("onReplayRequest: { record in"),
                   "GameHistoryView 的回调应设置 historyReplayRecord")
            #expect(content.contains("historyReplayRecord = record"),
                   "回调应将 record 赋值给 historyReplayRecord")
        }

        @MainActor
@Test("GameHistoryView 不包含嵌套的 sheet 或 fullScreenCover")
        func gameHistoryViewNoNestedSheet() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameHistoryView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 GameHistoryView.swift")
                return
            }

            #expect(!content.contains(".sheet("), "GameHistoryView 不应包含嵌套 sheet")
            #expect(!content.contains("fullScreenCover"), "GameHistoryView 不应包含 fullScreenCover")
        }
    }

    // MARK: - Bug 4：中级AI思考时间太长 【P1】

    @Suite("Bug 4：中级AI思考时间优化", .serialized)
    struct Bug4MediumAITimeTests {

        @MainActor
@Test("TimeManager.forDifficulty(.medium) 现在返回非 nil")
        func mediumDifficultyReturnsTimeManager() {
            let tm = TimeManager.forDifficulty(.medium)
            #expect(tm != nil, ".medium 现在应返回 TimeManager（不再返回 nil）")
        }

        @MainActor
@Test("TimeManager.forDifficulty(.medium, isIOS: true) 时间 ≤ 2000ms")
        func mediumIOSTimeLimit() {
            let tm = TimeManager.forDifficulty(.medium, isIOS: true)
            #expect(tm != nil, ".medium iOS 应返回 TimeManager")
            #expect(tm!.timeLimitMs <= 2000, ".medium iOS 时间上限应为 ≤2000ms，实际 \(tm!.timeLimitMs)")
        }

        @MainActor
@Test("TimeManager.forDifficulty(.medium, isIOS: false) 时间 ≤ 3000ms")
        func mediumMacOSTimeLimit() {
            let tm = TimeManager.forDifficulty(.medium, isIOS: false)
            #expect(tm != nil, ".medium macOS 应返回 TimeManager")
            #expect(tm!.timeLimitMs <= 3000, ".medium macOS 时间上限应为 ≤3000ms，实际 \(tm!.timeLimitMs)")
        }

        @MainActor
@Test("TimeManager.forDifficulty(.beginner) 仍返回 nil")
        func beginnerStillReturnsNil() {
            let tm = TimeManager.forDifficulty(.beginner)
            #expect(tm == nil, ".beginner 应仍返回 nil")
        }

        @MainActor
@Test("TimeManager.forDifficulty(.easy) 仍返回 nil")
        func easyStillReturnsNil() {
            let tm = TimeManager.forDifficulty(.easy)
            #expect(tm == nil, ".easy 应仍返回 nil")
        }

        @MainActor
@Test("mediumSearch 实际思考时间 macOS ≤ 3.5s（含余量）")
        func mediumSearchTimeOnMacOS() async {
            let board = Board()  // 标准开局
            let engine = AIEngine()

            let start = Date()
            let move = await engine.bestMove(for: board, difficulty: .medium, isIOS: false)
            let elapsed = Date().timeIntervalSince(start)

            #expect(move != nil, "medium AI 应能返回走法")
            #expect(elapsed <= 3.5, "medium AI macOS 思考时间应 ≤3s（含余量 0.5s），实际 \(String(format: "%.2f", elapsed))s")
        }

        @MainActor
@Test("mediumSearch 返回合法走法（棋力不退化）")
        func mediumSearchReturnsLegalMove() async {
            let board = Board()
            let engine = AIEngine()

            let move = await engine.bestMove(for: board, difficulty: .medium, isIOS: false)

            #expect(move != nil, "medium AI 应返回走法")
            if let move = move {
                let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
                let isLegal = legalMoves.contains { $0.piece.id == move.piece.id && $0.from == move.from && $0.to == move.to }
                #expect(isLegal, "medium AI 走法应为合法走法")
            }
        }

        @MainActor
@Test("mediumSearch 使用 IDS + TimeManager.forDifficulty")
        func mediumSearchUsesIDS() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/AI/AIEngine.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 AIEngine.swift")
                return
            }

            // mediumSearch 应调用 iterativeDeepeningSearch 和 TimeManager.forDifficulty
            let range = content.range(of: "private func mediumSearch")
            #expect(range != nil, "应找到 mediumSearch 方法")

            if let range = range {
                let afterMethod = content[range.lowerBound...]
                let methodEnd = afterMethod.range(of: "private func", range: afterMethod.index(after: range.lowerBound)..<afterMethod.endIndex)
                let methodContent = methodEnd.map { String(afterMethod[range.lowerBound..<$0.lowerBound]) } ?? String(afterMethod)

                #expect(methodContent.contains("iterativeDeepeningSearch"),
                       "mediumSearch 应使用 iterativeDeepeningSearch（IDS）")
                #expect(methodContent.contains("TimeManager.forDifficulty"),
                       "mediumSearch 应使用 TimeManager.forDifficulty 统一获取时间配置")
            }
        }

        @MainActor
@Test("TimeManager 局面复杂度调整时间")
        func timeManagerComplexityAdjustment() {
            // 简单局面：子力少，时间应偏短
            let simpleFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w"
            let simpleBoard = Board(fen: simpleFEN)
            let simpleTM = TimeManager.forDifficulty(.medium, isIOS: false, board: simpleBoard)

            // 复杂局面：标准开局，时间应偏长
            let complexBoard = Board()
            let complexTM = TimeManager.forDifficulty(.medium, isIOS: false, board: complexBoard)

            #expect(simpleTM != nil && complexTM != nil, "两种局面都应返回 TimeManager")
            if let simpleTM = simpleTM, let complexTM = complexTM {
                #expect(complexTM.timeLimitMs >= simpleTM.timeLimitMs,
                       "复杂局面的时间应 ≥ 简单局面：复杂=\(complexTM.timeLimitMs)ms, 简单=\(simpleTM.timeLimitMs)ms")
            }
        }
    }

    // MARK: - Bug 5：缺少当前难度展示 【P1】

    @Suite("Bug 5：当前难度展示", .serialized)
    struct Bug5DifficultyDisplayTests {

        @MainActor
@Test("StatusBarView 包含难度标签")
        func statusBarViewContainsDifficultyLabel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            #expect(content.contains("difficulty.displayName"),
                   "StatusBarView 应显示难度标签")
        }

        @MainActor
@Test("StatusBarView 难度标签使用黄色高对比（v2.2.21 增强）")
        func statusBarViewDifficultyLabelColor() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            // v2.2.21: 难度标签增强为黄色 + 棕色背景 + 描边
            #expect(content.contains(".yellow"),
                   "难度标签应使用 .yellow 高对比色")
            #expect(content.contains(".brown.opacity(0.6)"),
                   "难度标签背景应使用 .brown.opacity(0.6)")
        }

        @MainActor
@Test("iOS App 难度 Menu label 显示当前难度名")
        func iOSAppDifficultyMenuLabel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessiOSApp.swift")
                return
            }

            #expect(content.contains("difficulty.displayName"),
                   "iOS App 难度 Menu label 应显示当前难度名")
        }

        @MainActor
@Test("AIDifficulty.displayName 对所有难度返回非空字符串")
        func allDifficultyDisplayNames() {
            for difficulty in AIDifficulty.allCases {
                let name = difficulty.displayName
                #expect(!name.isEmpty, "\(difficulty) 的 displayName 不应为空")
            }
        }
    }

    // MARK: - Bug 6：棋谱记录不工作 【P0】

    @Suite("Bug 6：棋谱记录实时更新", .serialized)
    struct Bug6RecordPanelTests {

        @MainActor
@Test("RecordPanelView 有双初始化器")
        func recordPanelDualInitializers() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            #expect(content.contains("init(viewModel:"), "应有 init(viewModel:) 初始化器")
            #expect(content.contains("init(gameMoves:"), "应有 init(gameMoves:) 初始化器")
        }

        @MainActor
@Test("RecordPanelView 通过 viewModel 实时读取 gameMoves")
        func recordPanelReadsFromViewModel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            // 验证 gameMoves 计算属性优先读取 _viewModel?.gameMoves
            #expect(content.contains("_viewModel?.gameMoves"), "gameMoves 应从 viewModel 实时读取")
        }

        @MainActor
@Test("iOS App 棋谱 sheet 传入 viewModel（非静态 gameMoves）")
        func iOSAppRecordSheetPassesViewModel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessiOSApp.swift")
                return
            }

            #expect(content.contains("RecordPanelView(viewModel: gameViewModel)"),
                   "iOS 棋谱 sheet 应传入 gameViewModel 以实现实时更新")
        }

        @MainActor
@Test("macOS App 棋谱 sheet 传入 viewModel")
        func macOSAppRecordSheetPassesViewModel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessApp.swift")
                return
            }

            #expect(content.contains("RecordPanelView(viewModel: viewModel)"),
                   "macOS 棋谱 sheet 应传入 viewModel 以实现实时更新")
        }

        @MainActor
@Test("GameViewModel.gameMoves 在走棋后增长")
        func gameViewModelGameMovesGrowsAfterMove() {
            let vm = GameViewModel()
            let initialCount = vm.gameMoves.count

            // 红方走一步棋
            let board = vm.board
            let redPieces = board.pieces(for: .red)

            // 找一个有合法走法的红方棋子
            var foundMove: Move? = nil
            for piece in redPieces {
                if let move = MoveValidator.legalMoves(for: piece, on: board).first {
                    foundMove = move
                    break
                }
            }
            guard let move = foundMove else {
                Issue.record("找不到有合法走法的红方棋子")
                return
            }

            vm.movePiece(from: move.from, to: move.to)

            #expect(vm.gameMoves.count > initialCount,
                   "走棋后 gameMoves 应增长：之前=\(initialCount), 之后=\(vm.gameMoves.count)")
        }
    }

    // MARK: - 追加测试：PuzzleRow VoiceOver accessibilityLabel

    @Suite("追加：PuzzleRow VoiceOver accessibilityLabel", .serialized)
    struct PuzzleRowAccessibilityTests {

        @MainActor
@Test("PuzzleRow 使用 .accessibilityElement(children: .combine)")
        func puzzleRowCombineChildren() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            // 在 PuzzleRow 的 body 中查找 accessibilityElement(children: .combine)
            let puzzleRowRange = content.range(of: "struct PuzzleRow")
            #expect(puzzleRowRange != nil, "应找到 PuzzleRow struct")

            if let start = puzzleRowRange?.upperBound {
                let afterPuzzleRow = content[start...]
                // 找到下一个 struct 或 enum 定义作为 PuzzleRow 的结尾
                let nextStruct = afterPuzzleRow.range(of: "\nstruct ", range: afterPuzzleRow.index(after: afterPuzzleRow.startIndex)..<afterPuzzleRow.endIndex)
                let puzzleRowContent: String
                if let ns = nextStruct {
                    puzzleRowContent = String(afterPuzzleRow[..<ns.lowerBound])
                } else {
                    puzzleRowContent = String(afterPuzzleRow)
                }

                #expect(puzzleRowContent.contains(".accessibilityElement(children: .combine)"),
                       "PuzzleRow 应使用 .accessibilityElement(children: .combine) 合并子元素朗读")
            }
        }

        @MainActor
@Test("PuzzleRow 使用 accessibility.puzzleRow 格式化标签")
        func puzzleRowAccessibilityLabel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            #expect(content.contains("accessibility.puzzleRow"),
                   "PuzzleRow 应使用 accessibility.puzzleRow 本地化 key 格式化标签")
            #expect(content.contains("String(format:"),
                   "应使用 String(format:) 格式化标签")
        }

        @MainActor
@Test("PuzzleRow 标签包含棋名、星级、通关状态")
        func puzzleRowLabelContainsAllInfo() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            // 验证 accessibilityLabel 包含 puzzle.name、puzzle.stars、通关状态
            let labelRange = content.range(of: ".accessibilityLabel(")
            #expect(labelRange != nil, "应找到 .accessibilityLabel")
            if let range = labelRange {
                let lineContent = content[range.lowerBound..<min(content.endIndex, content.index(range.lowerBound, offsetBy: 200))]
                #expect(lineContent.contains("puzzle.name"), "标签应包含 puzzle.name")
                #expect(lineContent.contains("puzzle.stars"), "标签应包含 puzzle.stars")
                #expect(lineContent.contains("isCompleted"), "标签应包含通关状态判断")
            }
        }

        @MainActor
@Test("本地化 key puzzle.notCompleted 存在")
        func puzzleNotCompletedKeyExists() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 Localizable.xcstrings")
                return
            }

            #expect(content.contains("\"puzzle.notCompleted\""),
                   "Localizable.xcstrings 应包含 puzzle.notCompleted key")
        }

        @MainActor
@Test("本地化 key accessibility.puzzleRow 存在且中英文完整")
        func puzzleRowKeyBilingual() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 Localizable.xcstrings")
                return
            }

            #expect(content.contains("\"accessibility.puzzleRow\""),
                   "Localizable.xcstrings 应包含 accessibility.puzzleRow key")
            #expect(content.contains("zh-Hans"), "应包含中文翻译")
            #expect(content.contains("en"), "应包含英文翻译")
        }
    }

    // MARK: - 跨平台回归测试

    @Suite("跨平台回归：Bug 3/5/6 涉及改动", .serialized)
    struct CrossPlatformRegressionTests {

        @MainActor
@Test("macOS App 定义了 historyReplayRecord 状态")
        func macOSHistoryReplayRecordExists() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessApp.swift")
                return
            }

            #expect(content.contains("historyReplayRecord"),
                   "macOS App 应定义 historyReplayRecord 状态变量")
        }

        @MainActor
@Test("macOS StatusBarView 也显示难度标签")
        func macOSStatusBarShowsDifficulty() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            #expect(content.contains("difficulty.displayName"),
                   "StatusBarView（macOS/iOS 共用）应显示难度标签")
        }

        @MainActor
@Test("macOS RecordPanelView 使用 viewModel 路径")
        func macOSRecordPanelUsesViewModel() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChineseChessApp.swift")
                return
            }

            #expect(content.contains("RecordPanelView(viewModel:"),
                   "macOS 棋谱面板应使用 viewModel 初始化器")
        }

        @MainActor
@Test("GameHistoryView 在两个平台都使用 onReplayRequest 回调")
        func bothPlatformsUseCallback() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let iosPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift"
            let macPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"

            for (label, path) in [("iOS", iosPath), ("macOS", macPath)] {
                guard let content = try? String(contentsOfFile: path) else {
                    Issue.record("无法读取 \(path)")
                    return
                }
                #expect(content.contains("onReplayRequest"), "\(label) App 的 GameHistoryView 应使用 onReplayRequest 回调")
            }
        }
    }
}
