import Foundation

// MARK: - BoardPlayer（通用棋盘播放器）

/// 从 DemoViewModel 和 ReplayViewModel 抽取的通用播放逻辑
/// Phase 2：消除重复代码，统一播放控制
@MainActor
@Observable
class BoardPlayer {
    // MARK: - 核心状态

    private(set) var board: Board
    private(set) var currentIndex: Int = 0  // 当前步数索引（0 = 初始局面）
    var lastMove: (from: Position, to: Position)? = nil

    // MARK: - 走法源

    /// 走法提供者（抽象：DemoViewModel 用 Move[]，ReplayViewModel 用 GameRecord.moves）
    let moveSource: BoardPlayerMoveSource

    // MARK: - 闭包回调（供 ViewModel 使用，无需子类化）

    var onMoveExecutedHandler: ((Move, Int) -> Void)?
    var onPlaybackCompleteHandler: (() -> Void)?

    // MARK: - 播放状态

    private(set) var isPlaying: Bool = false
    var speed: Double = 1.0  // 速度倍率

    private var autoPlayTask: Task<Void, Never>?

    // MARK: - 快照优化（长棋谱回退性能）

    private var snapshots: [Int: Board] = [:]
    private let snapshotInterval = 20
    private let maxSnapshotCount = 20
    private var useSnapshots: Bool = false

    // MARK: - 计算属性

    var totalSteps: Int { moveSource.totalMoves }
    var canGoForward: Bool { currentIndex < moveSource.totalMoves }
    var canGoBack: Bool { currentIndex > 0 }

    var stepInterval: Double { 1.0 / speed }

    var progressText: String {
        "\(currentIndex)/\(totalSteps)"
    }

    // MARK: - Init

    init(moveSource: BoardPlayerMoveSource, initialFEN: String, useSnapshots: Bool = false) {
        self.moveSource = moveSource
        self.board = Board(fen: initialFEN)
        self.useSnapshots = useSnapshots
    }

    // MARK: - 播放控制

    func play() {
        guard canGoForward else {
            // 已到末尾，重新开始并自动播放
            resetToStart()
            play()
            return
        }
        isPlaying = true
        startAutoPlay()
    }

    func pause() {
        isPlaying = false
        stopAutoPlay()
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func resetToStart() {
        stopAutoPlay()
        currentIndex = 0
        board = Board(fen: moveSource.initialFEN)
        lastMove = nil
        isPlaying = false
        snapshots.removeAll()
    }

    func goToEnd() {
        stopAutoPlay()
        isPlaying = false
        let target = moveSource.totalMoves
        rebuildBoard(upTo: target)
        currentIndex = target
        lastMove = target > 0 ? moveSource.lastMovePosition(at: target - 1) : nil
        // 拍快照，方便后续 stepBackward
        if useSnapshots {
            takeSnapshotIfNeeded(at: target)
        }
    }

    func stepForward() {
        guard canGoForward else { return }
        stopAutoPlay()
        isPlaying = false
        executeMove(at: currentIndex)
        currentIndex += 1
    }

    func stepBackward() {
        guard canGoBack else { return }
        stopAutoPlay()
        isPlaying = false
        currentIndex -= 1
        rebuildBoard(upTo: currentIndex)
        lastMove = currentIndex > 0 ? moveSource.lastMovePosition(at: currentIndex - 1) : nil
    }

    func jumpTo(index: Int) {
        stopAutoPlay()
        isPlaying = false
        let clamped = max(0, min(index, moveSource.totalMoves))
        rebuildBoard(upTo: clamped)
        currentIndex = clamped
        lastMove = clamped > 0 ? moveSource.lastMovePosition(at: clamped - 1) : nil
    }

    // MARK: - 自动播放

    private func startAutoPlay() {
        autoPlayTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while self.canGoForward && !Task.isCancelled {
                self.executeMove(at: self.currentIndex)
                self.currentIndex += 1

                if self.currentIndex >= self.moveSource.totalMoves {
                    // 棋局播放完毕
                    self.isPlaying = false
                    self.onPlaybackComplete()
                    break
                }

                do {
                    try await Task.sleep(for: .seconds(self.stepInterval))
                } catch {
                    break
                }
            }
            if self.isPlaying {
                self.isPlaying = false
            }
        }
    }

    private func stopAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
    }

    // MARK: - 走法执行

    private func executeMove(at index: Int) {
        guard index < moveSource.totalMoves else { return }
        let move = moveSource.move(at: index, on: board)
        board.execute(move)
        lastMove = (from: move.from, to: move.to)
        if useSnapshots {
            takeSnapshotIfNeeded(at: index)
        }
        // 通知观察者（用于点评等）
        onMoveExecuted(move: move, index: index)
    }

    func onMoveExecuted(move: Move, index: Int) {
        onMoveExecutedHandler?(move, index)
    }

    func onPlaybackComplete() {
        onPlaybackCompleteHandler?()
    }

    // MARK: - 局面重建

    func rebuildBoard(upTo index: Int) {
        if useSnapshots {
            rebuildWithSnapshots(upTo: index)
        } else {
            rebuildSimple(upTo: index)
        }
    }

    private func rebuildSimple(upTo index: Int) {
        board = Board(fen: moveSource.initialFEN)
        for i in 0..<index {
            guard i < moveSource.totalMoves else { break }
            let move = moveSource.move(at: i, on: board)
            board.execute(move)
        }
    }

    private func rebuildWithSnapshots(upTo index: Int) {
        // 找到最近的快照
        var snapIdx = (index / snapshotInterval) * snapshotInterval
        if snapIdx == index && snapIdx > 0 {
            snapIdx -= snapshotInterval
        }

        var startIndex: Int
        let startBoard: Board

        if snapIdx > 0, let snap = snapshots[snapIdx] {
            startBoard = snap.snapshot()
            startIndex = snapIdx + 1
        } else {
            startBoard = Board(fen: moveSource.initialFEN)
            startIndex = 0
        }

        board = startBoard
        for i in startIndex..<index {
            guard i < moveSource.totalMoves else { break }
            let move = moveSource.move(at: i, on: board)
            board.execute(move)
        }
    }

    private func takeSnapshotIfNeeded(at index: Int) {
        if index % snapshotInterval == 0 && index > 0 {
            // 淘汰旧快照，保持上限
            if snapshots.count >= maxSnapshotCount, let farthest = snapshots.keys.min(by: { abs($0 - index) > abs($1 - index) }) {
                snapshots.removeValue(forKey: farthest)
            }
            snapshots[index] = board.snapshot()
        }
    }
}

// MARK: - BoardPlayerMoveSource（走法源抽象）

/// 走法源协议：统一 DemoViewModel 的 Move[] 和 ReplayViewModel 的 GameRecord.moves
protocol BoardPlayerMoveSource {
    var totalMoves: Int { get }
    var initialFEN: String { get }

    /// 获取指定索引的走法（在指定棋盘状态下）
    func move(at index: Int, on board: Board) -> Move

    /// 获取指定索引走法的终点位置（用于 lastMove）
    func lastMovePosition(at index: Int) -> (from: Position, to: Position)?
}

// MARK: - DemoMoveSource（DemoViewModel 用）

/// 从 Puzzle.solution 构建的走法源
struct DemoMoveSource: BoardPlayerMoveSource {
    let moves: [Move]
    let initialFEN: String

    var totalMoves: Int { moves.count }

    func move(at index: Int, on board: Board) -> Move {
        moves[index]
    }

    func lastMovePosition(at index: Int) -> (from: Position, to: Position)? {
        guard index >= 0 && index < moves.count else { return nil }
        return (from: moves[index].from, to: moves[index].to)
    }
}

// MARK: - ReplayMoveSource（ReplayViewModel 用）

/// 从 GameRecord.moves 构建的走法源
struct ReplayMoveSource: BoardPlayerMoveSource {
    let gameMoves: [GameMove]
    let initialFEN: String

    var totalMoves: Int { gameMoves.count }

    func move(at index: Int, on board: Board) -> Move {
        let gm = gameMoves[index]
        let piece = board.piece(at: gm.from) ?? gm.piece
        let captured = board.piece(at: gm.to)
        return Move(piece: piece, from: gm.from, to: gm.to, captured: captured)
    }

    func lastMovePosition(at index: Int) -> (from: Position, to: Position)? {
        guard index >= 0 && index < gameMoves.count else { return nil }
        return (from: gameMoves[index].from, to: gameMoves[index].to)
    }
}