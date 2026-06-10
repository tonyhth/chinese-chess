import Foundation

@Observable
class ReplayViewModel {
    let record: GameRecord
    private(set) var board: Board
    private(set) var currentIndex: Int = 0  // 当前步数索引（0 = 初始局面）
    var lastMove: (from: Position, to: Position)? = nil

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < record.moves.count }
    var isAutoPlaying: Bool = false
    var autoPlaySpeed: Double = 1.0  // 速度倍率（2.0 = 两倍速）

    private var stepInterval: Double {
        1.0 / autoPlaySpeed  // 基础 1 秒/步，倍率越高越快
    }

    private var snapshots: [Int: Board] = [:]
    private let snapshotInterval = 20
    private var autoPlayTask: Task<Void, Never>?

    init(record: GameRecord) {
        self.record = record
        self.board = Board(fen: record.initialFEN ?? FENParser.standardInitial)
    }

    // MARK: - 导航

    func goToStart() {
        stopAutoPlay()
        currentIndex = 0
        board = Board(fen: record.initialFEN ?? FENParser.standardInitial)
        lastMove = nil
    }

    func goToEnd() {
        stopAutoPlay()
        let target = record.moves.count
        rebuildBoard(upTo: target)
        currentIndex = target
    }

    func goForward() {
        guard canGoForward else { return }
        let move = record.moves[currentIndex]
        let piece = board.piece(at: move.from) ?? move.piece
        let captured = board.piece(at: move.to)
        let m = Move(piece: piece, from: move.from, to: move.to, captured: captured)
        board.execute(m)
        takeSnapshotIfNeeded(at: currentIndex)
        lastMove = (from: move.from, to: move.to)
        currentIndex += 1
    }

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        rebuildBoard(upTo: currentIndex)
        lastMove = currentIndex > 0 ? (from: record.moves[currentIndex - 1].from, to: record.moves[currentIndex - 1].to) : nil
    }

    func jumpTo(index: Int) {
        stopAutoPlay()
        let clamped = max(0, min(index, record.moves.count))
        rebuildBoard(upTo: clamped)
        currentIndex = clamped
        lastMove = clamped > 0 ? (from: record.moves[clamped - 1].from, to: record.moves[clamped - 1].to) : nil
    }

    // MARK: - 自动播放

    func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
        } else {
            startAutoPlay()
        }
    }

    private func startAutoPlay() {
        isAutoPlaying = true
        autoPlayTask = Task { @MainActor in
            while canGoForward && !Task.isCancelled {
                goForward()
                do {
                    try await Task.sleep(for: .seconds(stepInterval))
                } catch {
                    // CancellationError: 退出循环
                    break
                }
            }
            isAutoPlaying = false
        }
    }

    private func stopAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
        isAutoPlaying = false
    }

    // MARK: - 当前步信息

    var currentMove: GameMove? {
        guard currentIndex > 0, currentIndex <= record.moves.count else { return nil }
        return record.moves[currentIndex - 1]
    }

    var progressText: String {
        "\(currentIndex)/\(record.moves.count)"
    }

    // MARK: - 内部：局面重建

    private func rebuildBoard(upTo index: Int) {
        // 找到最近的快照
        let snapIdx = (index / snapshotInterval) * snapshotInterval
        let startBoard: Board
        if let snap = snapshots[snapIdx] {
            startBoard = snap.snapshot()
        } else {
            startBoard = Board(fen: record.initialFEN ?? FENParser.standardInitial)
        }

        board = startBoard

        // 从 snapIdx 到 index 逐步执行
        for i in snapIdx..<index {
            guard i < record.moves.count else { break }
            let move = record.moves[i]
            let piece = board.piece(at: move.from) ?? move.piece
            let captured = board.piece(at: move.to)
            let m = Move(piece: piece, from: move.from, to: move.to, captured: captured)
            board.execute(m)
        }
    }

    private func takeSnapshotIfNeeded(at index: Int) {
        if index % snapshotInterval == 0 && index > 0 {
            snapshots[index] = board.snapshot()
        }
    }
}
