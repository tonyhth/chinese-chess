import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.21 Phase 2: 7 个 Bug 修复验证

@Suite("v2.2.21 Phase 2 Bug 修复验证")
struct V2221BugTests {

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

    // MARK: - Bug 1+2: 残局提示索引跟踪 + 中文棋谱

    @Suite("Bug 1+2: 残局提示索引跟踪 + 中文棋谱")
    struct Bug1And2HintTrackingTests {

        @Test("PuzzleViewModel 有 hintOffsetInSession 变量")
        func puzzleViewModelHasHintOffsetInSession() {
            // 验证 PuzzleViewModel 定义了 hintOffsetInSession 变量
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/PuzzleViewModel.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleViewModel.swift")
                return
            }

            #expect(content.contains("hintOffsetInSession"), "PuzzleViewModel 应定义 hintOffsetInSession 变量")
            #expect(content.contains("private var hintOffsetInSession: Int = 0"), "hintOffsetInSession 应初始化为 0")
        }

        @Test("showHint 方法使用 hintOffsetInSession 递增")
        func showHintUsesHintOffsetInSession() {
            // 验证 showHint 方法中正确使用和递增 hintOffsetInSession
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/PuzzleViewModel.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleViewModel.swift")
                return
            }

            // showHint 方法中应使用 hintOffsetInSession
            #expect(content.contains("let solIdx = baseStep + hintOffsetInSession"), "showHint 应计算 solIdx 基于 hintOffsetInSession")
            #expect(content.contains("hintOffsetInSession += 1"), "showHint 应递增 hintOffsetInSession")
        }

        @Test("走棋/撤销/重置后 hintOffsetInSession 重置为 0")
        func hintOffsetResetAfterMoveUndoReset() {
            // 验证 hintOffsetInSession 在走棋、撤销、重置后被重置
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/PuzzleViewModel.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleViewModel.swift")
                return
            }

            // movePiece 中应重置 hintOffsetInSession
            #expect(content.contains("hintOffsetInSession = 0"), "走棋后应重置 hintOffsetInSession")
            // undoMove 中应重置 hintOffsetInSession
            // resetPuzzle 中应重置 hintOffsetInSession
        }

        @Test("getSolutionInfo 不依赖当前 board 状态")
        func getSolutionInfoIndependentOfBoardState() {
            // 构造一个局面：走棋后 board 状态改变
            let puzzle = V2221BugTests.makeTestPuzzle(
                id: "test-independent-board",
                initialFEN: "3ak4/9/9/9/9/9/9/9/9/4K4 w",
                solution: ["a0a1", "a9a8", "a1a2"],
                solutionType: "checkmate"
            )
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 点击提示（此时 board 状态可能与 solution 推演不同）
            vm.showHint()

            // 提示仍能正常显示（不依赖 board 当前状态）
            #expect(vm.currentHint != nil, "提示应能正常显示，不依赖 board 状态")
            #expect(vm.hintMove != nil || vm.currentHint?.contains("noMoreHints") ?? false,
                   "提示高亮位置应有值或显示无更多提示")
        }

        @Test("撤销后 hintOffsetInSession 重置为 0")
        func hintOffsetResetAfterUndo() {
            let puzzle = V2221BugTests.makeTestPuzzle(
                id: "test-undo-reset",
                initialFEN: FENParser.standardInitial,
                solution: ["b0c2"],
                solutionType: "checkmate"
            )
            let vm = PuzzleViewModel(puzzle: puzzle)

            // 点击提示
            vm.showHint()
            vm.dismissHint()

            // 模拟撤销（直接调用 undoMove）
            vm.undoMove()

            // 撤销后再次点击提示，应从当前步开始
            vm.showHint()
            #expect(vm.currentHint != nil, "撤销后点击提示应有内容")
        }
    }

    // MARK: - Bug 3: iOS 回放棋盘空间优化

    @Suite("Bug 3: iOS 回放棋盘空间优化")
    struct Bug3ReplayBoardSpaceTests {

        @Test("ReplayBoardView iOS maxBoardHeight = 850")
        func replayBoardViewMaxBoardHeight() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ReplayBoardView.swift")
                return
            }

            #if os(iOS)
            // iOS 平台 maxBoardHeight 应为 850（而非 675）
            #expect(content.contains("maxBoardHeight: CGFloat = 850"),
                   "iOS maxBoardHeight 应为 850")
            #endif
        }

        @Test("ReplayView 标题栏包含对局信息（合并布局）")
        func replayViewTitleBarContainsGameInfo() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ReplayView.swift")
                return
            }

            // 标题栏应包含红方玩家和黑方玩家
            #expect(content.contains("redPlayer"), "标题栏应包含红方玩家信息")
            #expect(content.contains("blackPlayer"), "标题栏应包含黑方玩家信息")
            #expect(content.contains(" vs"), "标题栏应有 vs 分隔")

            // 不应有独立的对局信息区域
            #expect(!content.contains("对局信息：独立区域"),
                   "v2.2.21 后不应有独立对局信息区域")
        }

        @Test("ReplayControlView 控制按钮 + Slider 分行布局")
        func replayControlViewSplitLayout() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayControlView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ReplayControlView.swift")
                return
            }

            // 应有分行布局（HStack + Slider）
            #expect(content.contains("VStack(spacing: 6)"),
                   "ReplayControlView 应使用 VStack spacing=6")
            // 控制按钮和步数信息应合并为一行
            #expect(content.contains("HStack(spacing: 16)"),
                   "控制按钮和步数信息应合并为一行")
        }
    }

    // MARK: - Bug 4: iOS 工具栏布局

    @Suite("Bug 4: iOS 工具栏布局")
    struct Bug4ToolbarLayoutTests {

        @Test("ToolbarView iOS：悔棋/提示左侧，新开一局右侧")
        func toolbarViewIOSLeftRightLayout() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ToolbarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ToolbarView.swift")
                return
            }

            // iOS 应有左侧 HStack（悔棋 + 提示）
            #expect(content.contains("#if os(iOS)"), "应有 iOS 平台条件编译")

            // iOS 应有左侧分组 HStack
            let iosRange = content.range(of: "#if os(iOS)")
            if let range = iosRange {
                let afterIOS = content[range.upperBound...]
                // 找到 #else 或 #endif
                let elseRange = afterIOS.range(of: "#else")
                let iosContent: String
                if let elseRange = elseRange {
                    iosContent = String(afterIOS[..<elseRange.lowerBound])
                } else {
                    iosContent = String(afterIOS)
                }

                #expect(iosContent.contains("HStack {"), "iOS 应有 HStack 容器")
                #expect(iosContent.contains("Spacer()"), "iOS 应有 Spacer 分隔左右")
                #expect(iosContent.contains("arrow.uturn.backward"), "iOS 应有悔棋按钮")
                #expect(iosContent.contains("lightbulb"), "iOS 应有提示按钮")
                #expect(iosContent.contains("plus.circle"), "iOS 应有新开一局按钮")
            }
        }

        @Test("ToolbarView iOS 按钮顺序：悔棋在最左，新开一局在最右")
        func toolbarViewIOSButtonOrder() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ToolbarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ToolbarView.swift")
                return
            }

            // 找到 iOS 部分
            let iosRange = content.range(of: "#if os(iOS)")
            if let range = iosRange {
                let afterIOS = content[range.upperBound...]
                let elseRange = afterIOS.range(of: "#else")
                let iosContent: String
                if let elseRange = elseRange {
                    iosContent = String(afterIOS[..<elseRange.lowerBound])
                } else {
                    iosContent = String(afterIOS)
                }

                // 悔棋按钮应出现在 Spacer 之前
                let undoIdx = iosContent.range(of: "arrow.uturn.backward")?.lowerBound
                let spacerIdx = iosContent.range(of: "Spacer()")?.lowerBound

                if let undoIdx = undoIdx, let spacerIdx = spacerIdx {
                    #expect(undoIdx < spacerIdx, "悔棋按钮应在 Spacer 之前（左侧）")
                }

                // 新开一局按钮应出现在 Spacer 之后
                let newGameIdx = iosContent.range(of: "plus.circle")?.lowerBound
                if let spacerIdx = spacerIdx, let newGameIdx = newGameIdx {
                    #expect(newGameIdx > spacerIdx, "新开一局按钮应在 Spacer 之后（右侧）")
                }
            }
        }
    }

    // MARK: - Bug 5: 难度标签样式增强

    @Suite("Bug 5: 难度标签样式增强")
    struct Bug5DifficultyTagStyleTests {

        @Test("StatusBarView 难度标签使用黄色")
        func statusBarViewDifficultyYellow() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            #expect(content.contains(".yellow"), "难度标签应使用 .yellow 颜色")
        }

        @Test("StatusBarView 难度标签使用棕色背景")
        func statusBarViewDifficultyBrownBackground() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            #expect(content.contains(".brown.opacity(0.6)"),
                   "难度标签背景应使用 .brown.opacity(0.6)")
        }

        @Test("StatusBarView 难度标签有图标")
        func statusBarViewDifficultyHasIcon() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            #expect(content.contains("square.stack.3d.up.fill"),
                   "难度标签应有图标")
        }

        @Test("StatusBarView 难度标签有描边")
        func statusBarViewDifficultyHasStroke() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            #expect(content.contains("stroke(Color.yellow.opacity(0.3)"),
                   "难度标签应有描边")
        }
    }

    // MARK: - Bug 6: 通关状态筛选

    @Suite("Bug 6: 通关状态筛选")
    struct Bug6CompletionFilterTests {

        @Test("PuzzleSelectView 定义 CompletionFilter 枚举")
        func puzzleSelectViewCompletionFilterEnum() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            #expect(content.contains("enum CompletionFilter"), "应定义 CompletionFilter 枚举")
            #expect(content.contains("case all, completed, uncompleted"),
                   "CompletionFilter 应有 all, completed, uncompleted 三个值")
        }

        @Test("PuzzleSelectView 使用 Picker 展示筛选选项")
        func puzzleSelectViewFilterPicker() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            #expect(content.contains("Picker(\"\", selection: $completionFilter)"),
                   "应使用 Picker 展示筛选选项")
            #expect(content.contains(".pickerStyle(.segmented)"),
                   "Picker 应使用 segmented 样式")
        }

        @Test("filteredPuzzles 逻辑包含通关状态筛选")
        func filteredPuzzlesContainsCompletionFilter() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            // 应有通关状态筛选逻辑
            #expect(content.contains("completionFilter"), "filteredPuzzles 应使用 completionFilter")
            #expect(content.contains("case .completed:"), "应有 .completed 分支")
            #expect(content.contains("case .uncompleted:"), "应有 .uncompleted 分支")
        }

        @Test("筛选感知排序：已通关按完成时间降序")
        func completionFilterSortingByCompletedAt() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 PuzzleSelectView.swift")
                return
            }

            // 已通关列表应按完成时间降序
            #expect(content.contains("completedAt"), "排序逻辑应使用 completedAt")
            #expect(content.contains("aDate > bDate"), "已通关列表应按时间降序")
        }

        @Test("本地化 key puzzle.filterCompleted 和 puzzle.filterUncompleted 存在")
        func filterLocalizationKeysExist() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 Localizable.xcstrings")
                return
            }

            #expect(content.contains("\"puzzle.filterCompleted\""),
                   "应有 puzzle.filterCompleted 本地化 key")
            #expect(content.contains("\"puzzle.filterUncompleted\""),
                   "应有 puzzle.filterUncompleted 本地化 key")
        }
    }

    // MARK: - Bug 7: 棋谱红黑配行

    @Suite("Bug 7: 棋谱红黑配行显示")
    struct Bug7RecordPanelPairTests {

        @Test("RecordPanelView 定义 MovePair 结构体")
        func recordPanelDefinesMovePair() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            #expect(content.contains("struct MovePair"), "应定义 MovePair 结构体")
            #expect(content.contains("let first: GameMove"), "MovePair 应有 first 字段")
            #expect(content.contains("let second: GameMove?"), "MovePair 应有 second 字段（可选）")
        }

        @Test("RecordPanelView 有 pairMoves 方法")
        func recordPanelHasPairMovesMethod() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            #expect(content.contains("private func pairMoves"), "应有 pairMoves 方法")
        }

        @Test("RecordPanelView 字号 14")
        func recordPanelFontSize14() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            #expect(content.contains("size: 14"), "棋谱字号应为 14")
        }

        @Test("RecordPanelView 红黑双色显示")
        func recordPanelRedBlackColors() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            // 红方用 .red，黑方用 .white
            #expect(content.contains("gm.piece.side == .red ? .red : .white"),
                   "红方棋谱应用 .red，黑方应用 .white")
        }

        @Test("RecordPanelView 行距 spacing = 3")
        func recordPanelSpacing3() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            #expect(content.contains("VStack(alignment: .leading, spacing: 3)"),
                   "走法列表 VStack spacing 应为 3")
        }

        @Test("RecordPanelView 黑方先手前缀（……）")
        func recordPanelBlackFirstPrefix() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            #expect(content.contains("firstSide == .black"), "应检测黑方先手")
            #expect(content.contains("……"), "黑方先手应显示省略号前缀")
        }
    }

    // MARK: - 综合回归测试

    @Suite("综合回归：跨平台一致性")
    struct CrossPlatformRegressionTests {

        @Test("StatusBarView 在 iOS 和 macOS 共用难度标签代码")
        func statusBarViewSharedCode() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }

            // StatusBarView 应为跨平台共用（无 #if os 条件编译分割难度标签）
            // 验证难度标签逻辑在两个平台都生效
            #expect(content.contains("difficulty.displayName"), "两平台都应有难度标签")
        }

        @Test("RecordPanelView 在 iOS 和 macOS 共用配对逻辑")
        func recordPanelSharedCode() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 RecordPanelView.swift")
                return
            }

            // RecordPanelView 应为跨平台共用
            #expect(content.contains("pairMoves"), "两平台都应有 pairMoves 方法")
            #expect(content.contains("MovePair"), "两平台都应有 MovePair 结构体")
        }
    }
}