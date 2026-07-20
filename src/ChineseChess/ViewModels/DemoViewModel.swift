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

/// 演示 ViewModel（残局 + 大师棋谱通用）
/// 播放逻辑委托给 BoardPlayer，本类保留 Demo 特有状态
@MainActor
@Observable
class DemoViewModel {
    let item: DemoItemWrapper

    // MARK: - BoardPlayer 委托

    let boardPlayer: BoardPlayer

    // MARK: - 转发属性（公开 API 不变）

    var board: Board { boardPlayer.board }
    var currentIndex: Int { boardPlayer.currentIndex }
    var lastMove: (from: Position, to: Position)? { boardPlayer.lastMove }

    var totalSteps: Int { boardPlayer.totalSteps }
    var canGoForward: Bool { boardPlayer.canGoForward }
    var canGoBack: Bool { boardPlayer.canGoBack }
    var isPlaying: Bool { playState == .playing }

    var progressText: String {
        String(localized: "第 \(currentIndex)/\(totalSteps) 步")
    }

    /// 解析后的有效步数
    var validStepCount: Int { boardPlayer.totalSteps }

    // MARK: - Demo 特有状态

    private(set) var playState: DemoPlayState = .idle
    var speed: DemoSpeed = .normal {
        didSet { boardPlayer.speed = speed.rawValue }
    }

    // 连播
    private(set) var isAutoAdvance: Bool = true
    private(set) var resultDisplayTimer: Task<Void, Never>?

    // 点评
    private(set) var currentCommentary: CommentaryItem?
    private var commentaryHideTask: Task<Void, Never>?

    // 弃子点评（预计算）
    private var sacrificeCommentaries: [Int: CommentaryItem] = [:]

    // 内部引用 moves 用于点评
    private let moves: [Move]

    // MARK: - Init

    /// 通用初始化：接收 DemoItemWrapper + 预计算的 Move 列表
    init(item: DemoItemWrapper, moves: [Move]) {
        self.item = item
        self.moves = moves
        let moveSource = DemoMoveSource(moves: moves, initialFEN: item.initialFEN)
        self.boardPlayer = BoardPlayer(moveSource: moveSource, initialFEN: item.initialFEN)
        self.boardPlayer.autoRestart = true

        // Phase 2：预计算弃子点评
        self.sacrificeCommentaries = CommentaryEngine.generateSacrificeCommentaries(
            moves: moves, initialFEN: item.initialFEN
        )

        // 桥接速度
        self.boardPlayer.speed = speed.rawValue

        // 走法执行回调 → 点评
        self.boardPlayer.onMoveExecutedHandler = { [weak self] move, moveIndex in
            self?.handleMoveExecuted(move: move, moveIndex: moveIndex)
        }

        // 播放完成回调
        self.boardPlayer.onPlaybackCompleteHandler = { [weak self] in
            self?.handlePlaybackComplete()
        }
    }

    /// 便利初始化：从 Puzzle 创建（向后兼容）
    convenience init(puzzle: Puzzle) {
        let moves = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        self.init(item: .puzzle(puzzle), moves: moves)
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
            break
        case .transitioning:
            break
        }
    }

    func play() {
        playState = .playing
        boardPlayer.play()
    }

    func pause() {
        playState = .idle
        boardPlayer.pause()
    }

    func resetToStart() {
        boardPlayer.resetToStart()
        playState = .idle
        currentCommentary = nil
    }

    func stepForward() {
        boardPlayer.stepForward()
        playState = .idle
    }

    func stepBackward() {
        boardPlayer.stepBackward()
        playState = .idle
    }

    // MARK: - BoardPlayer 回调

    private func handleMoveExecuted(move: Move, moveIndex: Int) {
        updateCommentary(for: move, moveIndex: moveIndex)
    }

    private func handlePlaybackComplete() {
        playState = .showingResult
        onPuzzleComplete()
    }

    // MARK: - 棋局完成

    private func onPuzzleComplete() {
        // 展示最后一步点评（将死/关键步）
        let lastMoveIndex = moves.count - 1
        let lastMove = moves[lastMoveIndex]
        if let item = CommentaryEngine.evaluate(move: lastMove, on: board, moveIndex: lastMoveIndex, totalMoves: moves.count) {
            showCommentary(item)
        }

        // 连播：残局 3 秒 / 大师棋谱 8 秒
        if isAutoAdvance {
            let delay = item.autoAdvanceDelay
            resultDisplayTimer = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(delay))
                    playState = .transitioning
                } catch {}
            }
        }
    }

    // MARK: - 点评

    private func updateCommentary(for move: Move, moveIndex: Int) {
        // Phase 2：弃子点评优先（预计算，O(1) 查找）
        if let sacrificeItem = sacrificeCommentaries[moveIndex] {
            showCommentary(sacrificeItem)
            return
        }
        // Phase 1：规则推断（将军/将死/最后一步）
        if let item = CommentaryEngine.evaluate(move: move, on: board, moveIndex: moveIndex, totalMoves: moves.count) {
            showCommentary(item)
        }
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
