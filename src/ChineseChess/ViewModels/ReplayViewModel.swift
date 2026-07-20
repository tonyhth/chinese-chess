import Foundation

@MainActor
@Observable
class ReplayViewModel {
    private(set) var record: GameRecord
    private(set) var displayTitle: String  // C4: 可更新的显示标题

    // MARK: - BoardPlayer 委托

    let boardPlayer: BoardPlayer

    // MARK: - 转发属性（公开 API 不变）

    var board: Board { boardPlayer.board }
    var currentIndex: Int { boardPlayer.currentIndex }
    var lastMove: (from: Position, to: Position)? {
        get { boardPlayer.lastMove }
        set { boardPlayer.lastMove = newValue }
    }

    var canGoBack: Bool { boardPlayer.canGoBack }
    var canGoForward: Bool { boardPlayer.canGoForward }

    var isAutoPlaying: Bool {
        get { boardPlayer.isPlaying }
        set { /* 观察者兼容，实际由 boardPlayer 驱动 */ }
    }

    var autoPlaySpeed: Double {
        get { boardPlayer.speed }
        set { boardPlayer.speed = newValue }
    }

    // MARK: - Init

    init(record: GameRecord) {
        self.record = record
        self.displayTitle = record.title
        let initialFEN = record.initialFEN ?? FENParser.standardInitial
        let moveSource = ReplayMoveSource(gameMoves: record.moves, initialFEN: initialFEN)
        self.boardPlayer = BoardPlayer(moveSource: moveSource, initialFEN: initialFEN, useSnapshots: true)
    }

    // MARK: - 重命名（C4）

    func rename(_ newTitle: String) {
        guard !newTitle.isEmpty else { return }
        displayTitle = newTitle
        record = GameRecord(
            id: record.id,
            title: newTitle,
            date: record.date,
            redPlayer: record.redPlayer,
            blackPlayer: record.blackPlayer,
            difficulty: record.difficulty,
            result: record.result,
            totalMoves: record.totalMoves,
            moves: record.moves,
            initialFEN: record.initialFEN,
            source: record.source,
            tags: record.tags,
            puzzleId: record.puzzleId
        )
        GameRecordStore.shared.updateRecord(record)
    }

    // MARK: - 导航

    func goToStart() {
        boardPlayer.resetToStart()
    }

    func goToEnd() {
        boardPlayer.goToEnd()
    }

    func goForward() {
        boardPlayer.stepForward()
    }

    func goBack() {
        boardPlayer.stepBackward()
    }

    func jumpTo(index: Int) {
        boardPlayer.jumpTo(index: index)
    }

    // MARK: - 自动播放

    func toggleAutoPlay() {
        boardPlayer.togglePlay()
    }

    // MARK: - 当前步信息

    var currentMove: GameMove? {
        guard currentIndex > 0, currentIndex <= record.moves.count else { return nil }
        return record.moves[currentIndex - 1]
    }

    var progressText: String {
        "\(currentIndex)/\(record.moves.count)"
    }
}
