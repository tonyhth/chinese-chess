import Foundation
import Testing
@testable import ChineseChess

@Suite("v2.2.18 方案B: ReplayBoardView 独立回放棋盘测试", .serialized)
@MainActor
struct V2218ReplayBoardViewTests {

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
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13),
                     from: Position(row: 6, col: 4), to: Position(row: 5, col: 4),
                     captured: nil, turnNumber: 1, notation: "兵七进一",
                     timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4), id: 29),
                     from: Position(row: 3, col: 4), to: Position(row: 4, col: 4),
                     captured: nil, turnNumber: 1, notation: "卒4进1",
                     timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
        ]
    }
}
