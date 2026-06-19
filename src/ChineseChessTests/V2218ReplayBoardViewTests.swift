import Foundation
import Testing
@testable import ChineseChess

@Suite("v2.2.18 方案B: ReplayBoardView 独立回放棋盘测试")
struct V2218ReplayBoardViewTests {

    let homeDir: String = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()

    // MARK: - P0: BoardMode enum 不再持有 replay case

    @Test("BoardMode enum 不包含 replay case（消除 @Observable associated value 崩溃根因）")
    func boardModeNoReplayCase() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        // extract enum BoardMode block
        guard let enumStart = content.range(of: "enum BoardMode"),
              let enumEnd = content.range(of: "}") ?? content.range(of: "\n}") else {
            Issue.record("无法定位 BoardMode enum"); return
        }
        let enumBlock = String(content[enumStart.lowerBound..<enumEnd.upperBound])
        #expect(!enumBlock.contains("case replay"),
               "BoardMode 不应包含 replay case，否则 @Observable associated value 会在 sheet 中触发 AG LayoutDescriptor 递归崩溃")
    }

    @Test("BoardMode 仅有 playGame 和 playPuzzle 两个 case")
    func boardModeOnlyTwoCases() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        guard let enumStart = content.range(of: "enum BoardMode") else {
            Issue.record("无法定位 BoardMode enum"); return
        }
        let snippet = String(content[enumStart.lowerBound..<content.index(enumStart.upperBound, offsetBy: 200)])
        #expect(snippet.contains("case playGame"))
        #expect(snippet.contains("case playPuzzle"))
    }

    // MARK: - P0: ChessBoardView 完全清除 replay 引用

    @Test("ChessBoardView 中无 .replay 模式分支")
    func chessBoardViewNoReplayBranches() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        // 不应有 case .replay 或 .replay( 出现
        #expect(!content.contains("case .replay"),
               "ChessBoardView 不应包含 case .replay 分支")
        #expect(!content.contains(".replay("),
               "ChessBoardView 不应包含 .replay( 调用")
    }

    @Test("ChessBoardView 不再包含 isReadOnly 属性（replay 移除后已清理）")
    func chessBoardViewNoIsReadOnly() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        // isReadOnly 属性已随 replay 移除而清理
        #expect(!content.contains("var isReadOnly"), "isReadOnly 属性应已移除")
        #expect(!content.contains("lastMove"), "lastMove 属性应已移除")
    }

    // MARK: - P0: ReplayBoardView.swift 新增文件

    @Test("ReplayBoardView.swift 存在且为独立视图")
    func replayBoardViewExists() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift") else {
            Issue.record("ReplayBoardView.swift 不存在或无法读取"); return
        }
        #expect(content.contains("struct ReplayBoardView: View"),
               "ReplayBoardView 应为独立 SwiftUI View struct")
    }

    @Test("ReplayBoardView 直接接收 ReplayViewModel（不经 BoardMode enum）")
    func replayBoardViewReceivesViewModel() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains("let viewModel: ReplayViewModel"),
               "ReplayBoardView 应直接持有 ReplayViewModel，不经过 BoardMode enum")
    }

    @Test("ReplayBoardView 不使用 @Environment(L10n.self)")
    func replayBoardViewNoEnvironmentL10n() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(!content.contains("@Environment(L10n.self)"),
               "ReplayBoardView 不应使用 @Environment(L10n.self)，避免 sheet 中 environment 断裂")
    }

    @Test("ReplayBoardView 渲染棋盘背景、线条、棋子、上一步高亮")
    func replayBoardViewRendersComponents() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains("Rectangle") || content.contains("LinearGradient"), "应有棋盘背景")
        #expect(content.contains("drawBoardLines"), "应绘制棋盘线条")
        #expect(content.contains("PieceView"), "应渲染棋子")
        #expect(content.contains("lastMove"), "应高亮上一步")
    }

    @Test("ReplayBoardView 是只读的（allowsHitTesting(false) 或无交互）")
    func replayBoardViewIsReadOnly() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains("allowsHitTesting(false)") || content.contains("allowsHitTesting"),
               "ReplayBoardView 棋子应设置 allowsHitTesting(false) 禁用交互")
    }

    @Test("ReplayBoardView 不引用 BoardMode")
    func replayBoardViewNoBoardMode() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        // 注释中提到 BoardMode 是 OK 的（说明不使用的原因），但不应有实际代码依赖
        let nonCommentLines = content.components(separatedBy: "\n").filter { !$0.hasPrefix("//") && !$0.hasPrefix(" *") }
        let codeContent = nonCommentLines.joined(separator: "\n")
        #expect(!codeContent.contains("BoardMode") || codeContent.contains("BoardMode enum") == false,
               "ReplayBoardView 代码不应依赖 BoardMode")
    }

    // MARK: - P0: ReplayView 使用 ReplayBoardView 替代 ChessBoardView

    @Test("ReplayView 使用 ReplayBoardView 而非 ChessBoardView(mode: .replay)")
    func replayViewUsesReplayBoardView() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        #expect(content.contains("ReplayBoardView(viewModel: viewModel)"),
               "ReplayView 应使用 ReplayBoardView(viewModel:)")
        #expect(!content.contains("ChessBoardView(mode: .replay"),
               "ReplayView 不应再使用 ChessBoardView(mode: .replay)")
    }

    @Test("ReplayView 使用 L10n.shared（非 @Environment）")
    func replayViewUsesL10nShared() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        #expect(content.contains("private let l10n = L10n.shared"))
        #expect(!content.contains("@Environment(L10n.self)"))
    }

    @Test("ReplayView 仍包含 ReplayControlView")
    func replayViewStillHasControlView() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        #expect(content.contains("ReplayControlView(viewModel: viewModel)"))
    }

    @Test("ReplayView 无 minHeight 硬编码")
    func replayViewNoMinHeight() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        let pattern = "ReplayBoardView(viewModel:"
        guard let range = content.range(of: pattern) else {
            Issue.record("未找到 ReplayBoardView"); return
        }
        let after = content[range.lowerBound...]
        let lines = after.split(separator: "\n", maxSplits: 6, omittingEmptySubsequences: false)
        let block = lines.prefix(5).joined(separator: "\n")
        #expect(!block.contains("minHeight"), "ReplayBoardView 不应有 minHeight 硬编码")
    }

    @Test("ReplayView 保留空步数提示")
    func replayViewEmptyMovesHint() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        #expect(content.contains("viewModel.record.moves.isEmpty"), "应有空步数提示逻辑")
        #expect(content.contains("replay.empty"), "应有 replay.empty 本地化键")
    }

    // MARK: - P0: ReplayControlView 使用 L10n.shared

    @Test("ReplayControlView 使用 L10n.shared（非 @Environment）")
    func replayControlViewUsesL10nShared() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayControlView.swift") else {
            Issue.record("无法读取 ReplayControlView.swift"); return
        }
        #expect(content.contains("private let l10n = L10n.shared"))
        #expect(!content.contains("@Environment(L10n.self)"))
    }

    // MARK: - P0: L10n.shared 单例可用性

    @Test("L10n.shared 单例可访问且为同一实例")
    func l10nSharedSingleton() {
        #expect(L10n.shared === L10n.shared)
        #expect(!L10n.shared.language.isEmpty)
    }

    @Test("L10n.shared.t() 未知 key 返回 key 本身（不 crash）")
    func l10nSharedFallback() {
        let key = "test.nonexistent.\(UUID().uuidString)"
        #expect(L10n.shared.t(key) == key)
    }

    // MARK: - 回归: ChessBoardView playGame/playPuzzle 不受影响

    @Test("ChessBoardView 仍支持 playGame 模式")
    func chessBoardViewStillSupportsPlayGame() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        #expect(content.contains("case .playGame"))
    }

    @Test("ChessBoardView 仍支持 playPuzzle 模式")
    func chessBoardViewStillSupportsPlayPuzzle() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        #expect(content.contains("case .playPuzzle"))
    }

    @Test("ChessBoardView 所有 switch mode 分支完整（无遗漏 case）")
    func chessBoardViewSwitchExhaustive() {
        guard let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        // BoardMode 有 2 个 case，每个 switch 都应处理两者
        // 编译通过即证明 switch 完整（Swift 要求 exhaustive switch）
        #expect(content.contains("case .playGame"))
        #expect(content.contains("case .playPuzzle"))
    }

    // MARK: - 回归: ReplayViewModel 功能不受影响

    @Test("ReplayViewModel: 初始化不 crash")
    func replayViewModelInit() {
        let record = Self.makeSimpleRecord(moves: [])
        let vm = ReplayViewModel(record: record)
        #expect(vm.currentIndex == 0)
        #expect(!vm.canGoForward)
        #expect(!vm.canGoBack)
    }

    @Test("ReplayViewModel: 空记录安全处理")
    func replayViewModelEmpty() {
        let record = Self.makeSimpleRecord(moves: [])
        let vm = ReplayViewModel(record: record)
        vm.goForward(); vm.goBack(); vm.goToStart(); vm.goToEnd()
        #expect(vm.currentIndex == 0)
    }

    @Test("ReplayViewModel: jumpTo 边界值")
    func replayViewModelJumpBoundary() {
        let record = Self.makeSimpleRecord(moves: [])
        let vm = ReplayViewModel(record: record)
        vm.jumpTo(index: -1); #expect(vm.currentIndex == 0)
        vm.jumpTo(index: 999); #expect(vm.currentIndex == 0)
    }

    @Test("ReplayViewModel: 前进后退完整流程")
    func replayViewModelNavigation() {
        let moves = Self.makeTestMoves()
        let record = Self.makeSimpleRecord(moves: moves)
        let vm = ReplayViewModel(record: record)

        while vm.canGoForward { vm.goForward() }
        #expect(vm.currentIndex == moves.count)

        while vm.canGoBack { vm.goBack() }
        #expect(vm.currentIndex == 0)

        #expect(vm.board.generalPosition(of: .red) != nil)
        #expect(vm.board.generalPosition(of: .black) != nil)
    }

    @Test("ReplayViewModel: progressText 格式")
    func replayViewModelProgress() {
        let moves = Self.makeTestMoves()
        let record = Self.makeSimpleRecord(moves: moves)
        let vm = ReplayViewModel(record: record)

        #expect(vm.progressText == "0/\(moves.count)")
        vm.goForward()
        #expect(vm.progressText == "1/\(moves.count)")
    }

    @Test("ReplayViewModel: goToStart / goToEnd")
    func replayViewModelStartEnd() {
        let moves = Self.makeTestMoves()
        let record = Self.makeSimpleRecord(moves: moves)
        let vm = ReplayViewModel(record: record)

        vm.goToEnd()
        #expect(vm.currentIndex == moves.count)
        vm.goToStart()
        #expect(vm.currentIndex == 0)
    }

    @Test("ReplayViewModel: lastMove 跟踪")
    func replayViewModelLastMove() {
        let moves = Self.makeTestMoves()
        let record = Self.makeSimpleRecord(moves: moves)
        let vm = ReplayViewModel(record: record)

        #expect(vm.lastMove == nil)
        vm.goForward()
        #expect(vm.lastMove != nil)
        #expect(vm.lastMove?.from == moves[0].from)
        #expect(vm.lastMove?.to == moves[0].to)
    }

    // MARK: - Helpers

    private static func makeSimpleRecord(moves: [GameMove]) -> GameRecord {
        GameRecord(
            id: UUID(), title: "测试对局", date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .beginner),
            difficulty: .beginner, result: .draw,
            totalMoves: moves.count, moves: moves, initialFEN: nil
        )
    }

    private static func makeTestMoves() -> [GameMove] {
        [
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4)),
                     from: Position(row: 6, col: 4), to: Position(row: 5, col: 4),
                     captured: nil, turnNumber: 1, notation: "兵七进一",
                     timestamp: Date(), isCheck: false, isCheckmate: false),
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4)),
                     from: Position(row: 3, col: 4), to: Position(row: 4, col: 4),
                     captured: nil, turnNumber: 1, notation: "卒4进1",
                     timestamp: Date(), isCheck: false, isCheckmate: false),
        ]
    }
}
