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

    /// Phase D: 走法文本列表（用于 iOS 棋谱面板）
    /// 使用 NotationGenerator 生成传统中文记谱法
    var moveNotations: [String] {
        var board = Board(fen: item.initialFEN)
        return moves.map { move in
            let notation = NotationGenerator.notation(for: move, on: board)
            board.execute(move)
            return notation
        }
    }

    // MARK: - Demo 特有状态

    private(set) var playState: DemoPlayState = .idle
    var speed: DemoSpeed = .normal {
        didSet { boardPlayer.speed = speed.rawValue }
    }

    // 连播
    var isAutoAdvance: Bool = true
    private(set) var resultDisplayTimer: Task<Void, Never>?

    /// 连播回调：通知父视图加载下一局
    /// 设计决策：使用回调驱动而非 onChange 监听，因为 playItem() 替换 viewModel 后 onChange 绑定失效
    var onAutoAdvanceHandler: (() -> Void)?

    // 点评
    private(set) var currentCommentary: CommentaryItem?
    private var commentaryHideTask: Task<Void, Never>?

    // 弃子点评（预计算）
    private var sacrificeCommentaries: [Int: CommentaryItem] = [:]

    // DemoConfig 集成
    /// 点评时暂停播放（仅 checkmate 和 sacrifice 暂停，check/keyMove 不暂停）
    var pauseOnCommentary: Bool = true
    /// 是否显示点评气泡
    var showCommentary: Bool = true
    /// 智能点评开关（MasterGameCommentator 异步引擎分析）
    var smartCommentaryEnabled: Bool = false

    /// 趋势分析器（智能点评时使用）
    private var trendAnalyzer = TrendAnalyzer()

    // pauseOnCommentary 暂停恢复状态
    private var wasPausedByCommentary: Bool = false

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

        // 读取 DemoConfig
        let config = DemoConfig.load()
        self.speed = config.demoSpeed
        self.isAutoAdvance = config.autoNextPuzzle
        self.pauseOnCommentary = config.pauseOnCommentary
        self.showCommentary = config.showCommentary
        self.smartCommentaryEnabled = config.smartCommentaryEnabled

        // 智能点评：预计算 FEN 和 UCI
        precomputeAnalysisData()
    }

    /// 便利初始化：从 Puzzle 创建（向后兼容）
    convenience init(puzzle: Puzzle) {
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        self.init(item: .puzzle(puzzle), moves: convertResult.moves)
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

        // 连播：3 秒结果展示后自动加载下一局（P0-3: 统一 3 秒）
        if isAutoAdvance {
            let delay = 3.0
            resultDisplayTimer = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(delay))
                    playState = .transitioning
                    onAutoAdvanceHandler?()  // 通知父视图加载下一局
                } catch {}
            }
        }
    }

    // MARK: - 智能点评（异步引擎分析）

    /// 预计算的 FEN 列表（每步执行前的 FEN）
    private var fenList: [String] = []
    /// 预计算的 UCI 走法列表
    private var uciMoves: [String] = []

    /// 在 moves 加载完成后预计算 FEN 和 UCI
    private func precomputeAnalysisData() {
        guard smartCommentaryEnabled else { fenList = []; uciMoves = []; return }
        var board = Board(fen: item.initialFEN)
        fenList = [FENParser.generate(board: board)]
        uciMoves = []

        for move in moves {
            uciMoves.append(UCIMoveConverter.uciString(from: move))
            board.execute(move)
            fenList.append(FENParser.generate(board: board))
        }
    }

    /// 异步分析当前步骤（智能点评）
    private func analyzeCurrentStep() {
        guard smartCommentaryEnabled else { return }
        guard currentIndex >= 0, currentIndex < uciMoves.count else { return }

        let idx = currentIndex
        let fenBefore = fenList[idx]
        let history = Array(uciMoves[0..<idx])
        let playerMove = uciMoves[idx]

        Task { [weak self] in
            guard let commentary = await MasterGameCommentator.shared.analyzeStep(
                fenBefore: fenBefore,
                playerMove: playerMove,
                moveHistory: history
            ) else { return }

            await MainActor.run {
                guard let self = self else { return }
                // 跳步保护：用户还在这一步才显示
                guard self.currentIndex == idx else { return }
                // 同步点评优先：如果当前已有同步点评（将军/弃子/将死），跳过
                if let existing = self.currentCommentary {
                    switch existing.type {
                    case .check, .checkmate, .sacrifice:
                        return  // 同步点评在显示，跳过
                    case .capture, .threat, .crossing:
                        return  // 轻量级点评在显示，跳过
                    default:
                        break
                    }
                }

                // 更新趋势分析器
                self.trendAnalyzer.record(delta: commentary.evalDelta)

                // 检查趋势
                let trend = self.trendAnalyzer.trend
                if let trendText = TrendAnalyzer.commentary(for: trend) {
                    // 趋势点评追加在走法点评之后
                    let combinedText = commentary.text + "\n" + trendText
                    self.showCommentary(CommentaryItem(type: commentary.type, text: combinedText))
                } else {
                    self.showCommentary(commentary)
                }
            }
        }
    }

    // MARK: - 点评

    private func updateCommentary(for move: Move, moveIndex: Int) {
        // showCommentary=false 时不生成点评
        guard showCommentary else {
            #if DEBUG
            AppLog.commentary.info("[Commentary] showCommentary=false, skip move #\(moveIndex)")
            #endif
            return
        }

        // Phase 2：弃子点评优先（预计算，O(1) 查找）
        if let sacrificeItem = sacrificeCommentaries[moveIndex] {
            #if DEBUG
            AppLog.commentary.info("[Commentary] sacrifice hit at move #\(moveIndex)")
            #endif
            showCommentary(sacrificeItem)
            return
        }
        // Phase 1：规则推断（将军/将死/最后一步）
        if let item = CommentaryEngine.evaluate(move: move, on: board, moveIndex: moveIndex, totalMoves: moves.count) {
            #if DEBUG
            AppLog.commentary.info("[Commentary] rule hit at move #\(moveIndex): \(item.text)")
            #endif
            showCommentary(item)
            return
        }

        #if DEBUG
        AppLog.commentary.info("[Commentary] no sync commentary at move #\(moveIndex), trying lightweight")
        #endif

        // Phase 3：轻量级点评（吃子/捉子/过河）
        if let lightItem = CommentaryEngine.evaluateLightweight(move: move, on: board, moveIndex: moveIndex, totalMoves: moves.count) {
            #if DEBUG
            AppLog.commentary.info("[Commentary] lightweight hit at move #\(moveIndex): \(lightItem.text)")
            #endif
            showCommentary(lightItem)
            return
        }

        #if DEBUG
        AppLog.commentary.info("[Commentary] no commentary at move #\(moveIndex), trying async smart=\(self.smartCommentaryEnabled)")
        #endif

        // 同步无结果 → 异步智能点评
        analyzeCurrentStep()
    }

    private func showCommentary(_ item: CommentaryItem) {
        // showCommentary=false 时不显示
        guard showCommentary else { return }

        currentCommentary = item

        // pauseOnCommentary：仅 checkmate 和 sacrifice 暂停播放
        // P0-5: check/keyMove 不暂停，避免连播时频繁暂停
        if pauseOnCommentary && playState == .playing {
            switch item.type {
            case .checkmate, .sacrifice:
                pause()
                wasPausedByCommentary = true
            case .check, .keyMove, .mistake, .capture, .threat, .crossing:
                break  // 不暂停
            }
        }

        commentaryHideTask?.cancel()
        commentaryHideTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(speed.commentaryDuration))
                if !Task.isCancelled {
                    currentCommentary = nil
                    // pauseOnCommentary: 点评消失后恢复播放
                    if wasPausedByCommentary {
                        wasPausedByCommentary = false
                        // 仅在连播/播放状态下恢复，用户手动暂停的不恢复
                        if isAutoAdvance {
                            play()
                        }
                    }
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
