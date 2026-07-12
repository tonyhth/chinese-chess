import Foundation

// MARK: - 演示速度档位

/// 离散速度档位，替代 Double 类型速度值
enum DemoSpeed: Double, CaseIterable, Identifiable {
    case slow = 0.5
    case normal = 1.0
    case fast = 2.0
    case turbo = 3.0

    var id: Double { rawValue }

    /// 每步间隔（秒）
    var stepInterval: Double {
        1.0 / rawValue
    }

    /// 点评气泡显示时长（秒），与速度联动
    var commentaryDuration: Double {
        // 基础 2 秒，速度越快显示越短
        max(0.8, 2.0 / rawValue)
    }

    var label: String {
        switch self {
        case .slow: return "0.5x"
        case .normal: return "1x"
        case .fast: return "2x"
        case .turbo: return "3x"
        }
    }
}

// MARK: - 演示状态

enum DemoPlayState {
    case idle           // 初始/暂停
    case playing        // 播放中
    case showingResult  // 棋局结束，展示结果
    case transitioning  // 切换到下一局
}

// MARK: - DemoViewModel

/// 残局自动演示 ViewModel
/// 内部独立实现播放逻辑，不抽取 BoardPlayer
/// 用 `// ReplayViewModel-sync` 标记与 ReplayViewModel 共享的逻辑点
@Observable
class DemoViewModel {
    let puzzle: Puzzle
    private(set) var board: Board
    private(set) var currentIndex: Int = 0  // 当前步数索引（0 = 初始局面）
    var lastMove: (from: Position, to: Position)? = nil

    // 播放状态
    private(set) var playState: DemoPlayState = .idle
    var speed: DemoSpeed = .normal

    // 连播
    private(set) var isAutoAdvance: Bool = true
    private(set) var resultDisplayTimer: Task<Void, Never>?

    // 解析后的走法
    private let moves: [Move]  // 内部用 Move 执行

    // 自动播放
    private var autoPlayTask: Task<Void, Never>?

    // 点评
    private(set) var currentCommentary: CommentaryItem?
    private var commentaryHideTask: Task<Void, Never>?

    // MARK: - 计算属性

    var totalSteps: Int { moves.count }
    var canGoForward: Bool { currentIndex < moves.count }
    var canGoBack: Bool { currentIndex > 0 }
    var isPlaying: Bool { playState == .playing }

    var progressText: String {
        String(localized: "第 \(currentIndex)/\(totalSteps) 步")
    }

    /// 解析后的有效步数（可能 < puzzle.solution.count，如果有解析失败）
    var validStepCount: Int { moves.count }

    // MARK: - Init

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.board = Board(fen: puzzle.initialFEN)
        self.moves = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
    }

    // MARK: - 播放控制

    func togglePlay() {
        switch playState {
        case .idle, .playing:
            if playState == .playing {
                pause()
            } else {
                play()
            }
        case .showingResult:
            // 结果展示中，点击进入下一局
            break
        case .transitioning:
            break
        }
    }

    func play() {
        guard canGoForward else {
            // 已到末尾，重新开始
            resetToStart()
            return
        }
        playState = .playing
        startAutoPlay()
    }

    func pause() {
        playState = .idle
        stopAutoPlay()
    }

    func resetToStart() {
        stopAutoPlay()
        currentIndex = 0
        board = Board(fen: puzzle.initialFEN)
        lastMove = nil
        playState = .idle
        currentCommentary = nil
    }

    func stepForward() {
        guard canGoForward else { return }
        executeCurrentMove()
    }

    func stepBackward() {
        guard canGoBack else { return }
        stopAutoPlay()
        playState = .idle
        currentIndex -= 1
        rebuildBoard(upTo: currentIndex)
        lastMove = currentIndex > 0 ? (from: moves[currentIndex - 1].from, to: moves[currentIndex - 1].to) : nil
    }

    // MARK: - 自动播放

    // ReplayViewModel-sync: 与 ReplayViewModel.startAutoPlay 逻辑相同
    private func startAutoPlay() {
        autoPlayTask = Task { @MainActor in
            while canGoForward && !Task.isCancelled {
                executeCurrentMove()

                if currentIndex >= moves.count {
                    // 棋局播放完毕
                    playState = .showingResult
                    onPuzzleComplete()
                    break
                }

                do {
                    try await Task.sleep(for: .seconds(speed.stepInterval))
                } catch {
                    break
                }
            }
            if playState == .playing {
                playState = .idle
            }
        }
    }

    private func stopAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
    }

    // MARK: - 走法执行

    // ReplayViewModel-sync: 与 ReplayViewModel.goForward 逻辑相同
    private func executeCurrentMove() {
        guard currentIndex < moves.count else { return }
        let move = moves[currentIndex]
        board.execute(move)
        lastMove = (from: move.from, to: move.to)
        currentIndex += 1

        // 点评推断
        updateCommentary(for: move, moveIndex: currentIndex - 1)
    }

    // MARK: - 棋局完成

    private func onPuzzleComplete() {
        // 展示最后一步点评（将死/关键步）
        if let checkSide = detectCheck() {
            if MoveValidator.isCheckmate(checkSide, on: board) {
                showCommentary(CommentaryItem(type: .checkmate(side: checkSide)))
                return
            }
        }
        showCommentary(CommentaryItem(type: .keyMove))

        // 连播：3 秒后自动进入下一局
        if isAutoAdvance {
            resultDisplayTimer = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(3.0))
                    playState = .transitioning
                } catch {}
            }
        }
    }

    // MARK: - 点评

    private func updateCommentary(for move: Move, moveIndex: Int) {
        // 检查将军
        if let checkSide = detectCheck() {
            // 将军：检查是否将死
            if MoveValidator.isCheckmate(checkSide, on: board) {
                showCommentary(CommentaryItem(type: .checkmate(side: checkSide)))
            } else {
                showCommentary(CommentaryItem(type: .check(side: checkSide)))
            }
            return
        }

        // 最后一步（非将死）
        if moveIndex == moves.count - 1 {
            showCommentary(CommentaryItem(type: .keyMove))
        }
    }

    private func detectCheck() -> Side? {
        // 走棋后，检查对方是否被将军
        // 刚走完 currentIndex 步，当前该对方走
        let currentSide = board.currentTurn
        // currentSide 是下一步要走的一方，被将军的是 currentSide
        if MoveValidator.isInCheck(currentSide, on: board) {
            return currentSide
        }
        return nil
    }

    private func showCommentary(_ item: CommentaryItem) {
        currentCommentary = item
        commentaryHideTask?.cancel()
        commentaryHideTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(speed.commentaryDuration))
                if !Task.isCancelled {
                    currentCommentary = nil
                }
            } catch {}
        }
    }

    // MARK: - 局面重建

    // ReplayViewModel-sync: 与 ReplayViewModel.rebuildBoard 逻辑相同
    private func rebuildBoard(upTo index: Int) {
        board = Board(fen: puzzle.initialFEN)
        for i in 0..<index {
            guard i < moves.count else { break }
            board.execute(moves[i])
        }
    }

    // MARK: - 连播控制

    func toggleAutoAdvance() {
        isAutoAdvance.toggle()
    }

    /// 请求跳转到下一局（由外层 PuzzleDemoView 调用）
    func requestNextPuzzle() {
        resultDisplayTimer?.cancel()
        playState = .transitioning
    }
}
