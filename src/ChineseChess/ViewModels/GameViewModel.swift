import Foundation

@Observable
@MainActor
class GameViewModel {
    /// 编译时平台标记
    private static let _isIOS: Bool = {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }()

    var board: Board
    var selectedPosition: Position?
    var legalMovesForSelected: [Position] = []
    var capturedPieces: (red: [Piece], black: [Piece]) = (red: [], black: [])
    var gameState: GameState = .playing
    var isThinking: Bool = false
    var showResignConfirm: Bool = false
    
    // Phase 2.1: AI 思考计时器
    var thinkingStartTime: Date? = nil
    
    // Phase 2.3: 棋钟（对局双方用时）
    var redClockSeconds: Int = 0
    var blackClockSeconds: Int = 0
    /// 当前计时方的计时起始时间
    var clockStartTime: Date? = nil
    /// 当前正在计时的方（解决走子后 currentTurn 已翻转的问题）
    var clockRunningSide: Side = .red
    
    /// 当前轮次已走棋时间（供 UI 刷新计算）
    var currentTurnElapsedSeconds: Int {
        guard let start = clockStartTime else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }
    
    /// 棋钟：切换到下一方的计时
    private func switchClock() {
        // 先把当前方的时间累加
        accumulateCurrentTurnTime()
        // 切换到对方计时
        clockRunningSide = (clockRunningSide == .red) ? .black : .red
        clockStartTime = Date()
    }
    
    /// 棋钟：累加当前方的已用时间
    private func accumulateCurrentTurnTime() {
        guard let start = clockStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        if clockRunningSide == .red {
            redClockSeconds += elapsed
        } else {
            blackClockSeconds += elapsed
        }
        clockStartTime = nil

        // Q4 P2: 闪电局超时判负
        if isBlitzMode {
            let limit = blitzTimeLimitSeconds
            if clockRunningSide == .red && redClockSeconds >= limit {
                gameState = .blackWon  // 红方超时，黑方胜
                stopClock()
            } else if clockRunningSide == .black && blackClockSeconds >= limit {
                gameState = .redWon  // 黑方超时，红方胜
                stopClock()
            }
        }
    }
    
    /// 棋钟：停止计时（游戏结束时调用）
    private func stopClock() {
        accumulateCurrentTurnTime()
    }
    
    /// 棋钟：重置并开始红方计时
    private func resetClock() {
        redClockSeconds = 0
        blackClockSeconds = 0
        clockRunningSide = .red
        clockStartTime = Date()
    }
    
    /// 计算已思考秒数（供 UI 绑定刷新）
    var thinkingElapsedSeconds: Int {
        guard let start = thinkingStartTime else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }
    
    /// 标记开始思考
    private func startThinking() {
        isThinking = true
        thinkingStartTime = Date()
    }
    
    /// 标记思考结束
    private func stopThinking() {
        isThinking = false
        thinkingStartTime = nil
    }
    var isProcessingWrongMove: Bool = false
    var isInCheck: Bool = false
    var difficulty: AIDifficulty = .amateurLow
    private var userDidSetDifficulty = false
    var humanSide: Side = {
        let saved = UserDefaults.standard.string(forKey: "chinesechess.humanSide") ?? "red"
        return saved == "black" ? .black : .red
    }()
    var hintMove: (from: Position, to: Position)? = nil
    var hintText: String? = nil

    // 和棋检测：重复局面 fingerprint 计数
    private var halfmoveClock: Int = 0
    private var positionFingerprints: [String: Int] = [:]
    /// 长将判负：连续将军步数（设计文档建议 N=6，3 个完整回合）
    private let perpetualCheckThreshold = 6
    /// v4.0 Phase 6: 长捉判负阈值（与长将一致）
    private let perpetualChaseThreshold = 6

    // P1-2: 外部引擎 fallback 提示（非 nil 时 UI 弹 alert）
    var engineFallbackMessage: String? = nil

    // P0-1 fix: 长将判负首次触发弹窗（非 nil 时 UI 弹 alert）
    var perpetualCheckMessage: String? = nil
    /// v4.0 Phase 6: 长捉判负提示
    var perpetualChaseMessage: String? = nil

    // Q4: 闪电局模式
    var isBlitzMode: Bool = false
    var blitzTimeLimitSeconds: Int = 300  // 双方各 5 分钟

    // Q4: 大师挑战模式（输了不扣统计）
    var isMasterChallenge: Bool = false

    // v4.0 Phase 5: 每日挑战模式扩展
    /// 当前挑战模式（nil = 正常对弈）
    var challengeMode: DailyChallengeMode? = nil
    /// 当前挑战的 puzzle（供 recordGameResult 调用 completeChallenge）
    private var challengePuzzle: Puzzle? = nil
    /// 一步杀模式标记
    var isOneStepMateMode: Bool = false
    /// 挑战结果
    var challengeResult: ChallengeResult? = nil
    /// 走法违反提示
    var showChallengeRuleViolation: Bool = false
    /// Puzzle 候选为空提示（V-C5）
    var showChallengeUnavailable: Bool = false

    // P2 修复：持有 observer token，deinit 时移除
    @ObservationIgnored nonisolated(unsafe) private var fallbackObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var assessmentObserver: NSObjectProtocol?

    // Phase B3 Step 3: 开局教练模式配置
    // 非nil时，GameViewModel 不自动触发AI走法，由外部（CoachGameView）控制AI走法
    var coachConfig: CoachConfig? = nil

    private var gameVersion: Int = 0
    private var materialTracker = MaterialTracker()
    var moveHistory: [Move] {
        board.moveHistory
    }
    var currentTurn: Side {
        board.currentTurn
    }

    // Phase 3: 走法记录（含棋谱）
    var gameMoves: [GameMove] = []

    init() {
        self.board = Board()
        // v6.0: 监听引擎 fallback 通知（包含 originalLevel 和 fallbackLevel）
        fallbackObserver = NotificationCenter.default.addObserver(
            forName: EngineRouter.fallbackNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let original = notification.userInfo?["originalLevel"] as? AIDifficulty {
                    let fallback = notification.userInfo?["fallbackLevel"] as? AIDifficulty ?? .amateurHigh
                    self?.engineFallbackMessage = String(
                        format: L10n.shared.t("engine.fallbackLevel"),
                        original.displayName,
                        fallback.displayName
                    )
                } else {
                    self?.engineFallbackMessage = L10n.shared.t("engine.fallbackMessage")
                }
            }
        }
        // v6.0 Phase 5: 监听棋力评估推荐级别
        assessmentObserver = NotificationCenter.default.addObserver(
            forName: .setDifficultyFromAssessment,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let level = notification.userInfo?["level"] as? AIDifficulty {
                    self?.setDifficulty(level)
                }
            }
        }
    }

    deinit {
        if let observer = fallbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = assessmentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - 用户操作

    func selectPiece(at pos: Position) {
        guard !isThinking, gameState == .playing else { return }

        // v3.0 Phase 5: 玩家执 humanSide
        guard board.currentTurn == humanSide else { return }

        if let selected = selectedPosition, legalMovesForSelected.contains(pos) {
            movePiece(from: selected, to: pos)
            return
        }

        guard let piece = board.piece(at: pos), piece.side == humanSide else {
            selectedPosition = nil
            legalMovesForSelected = []
            return
        }

        selectedPosition = pos
        let moves = MoveValidator.legalMoves(for: piece, on: board)
        legalMovesForSelected = moves.map { $0.to }
    }

    func movePiece(from: Position, to: Position) {
        guard !isThinking, gameState == .playing else { return }

        let piece: Piece? = board.piece(at: from)
        guard let piece = piece else { return }

        guard piece.side == humanSide else { return }

        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        guard MoveValidator.isLegal(move, on: board) else { return }

        // v4.0 Phase 5: 挑战模式走法限制
        if !isChallengeMoveLegal(move) {
            showChallengeRuleViolation = true
            return
        }

        // Phase 3: 生成棋谱（在 execute 之前，需要走前的 board 状态）
        let notation = NotationGenerator.notation(for: move, on: board)

        board.execute(move)

        // #3 halfmoveClock 更新（吃子或兵移动时重置，否则递增）
        let isPawn = piece.kind == .soldier
        if captured != nil || isPawn {
            halfmoveClock = 0
        } else {
            halfmoveClock += 1
        }

        // Phase 3: 记录 GameMove
        let turnNumber = (gameMoves.count / 2) + 1
        let opponent = (piece.side == .red) ? Side.black : Side.red
        let isCheck = MoveValidator.isInCheck(opponent, on: board)

        // v4.0 Phase 6: 捉判断（P0-2 修正：只检查移动棋子本身）
        let (isChase, chaseTarget) = Self.isChasing(move, on: board)
        let chaseAttackerId = isChase ? piece.id : nil       // P0-1 修正：使用 Piece.id
        let chaseTargetId = isChase ? chaseTarget?.id : nil  // P0-1 修正：使用 Piece.id

        let gameMove = GameMove(
            id: UUID(),
            piece: piece,
            from: from,
            to: to,
            captured: captured,
            turnNumber: turnNumber,
            notation: notation,
            timestamp: Date(),
            isCheck: isCheck,
            isCheckmate: false,   // 将在 checkGameState 后更新
            halfmoveClock: halfmoveClock,
            isChase: isChase,
            chaseAttackerId: chaseAttackerId,
            chaseTargetId: chaseTargetId
        )
        gameMoves.append(gameMove)

        if let captured = captured {
            // 按被吃子的归属方存储（红方损失的子存入 red）
            if captured.side == .red {
                capturedPieces.red.append(captured)
            } else {
                capturedPieces.black.append(captured)
            }
            SoundEngine.shared.playCapture()
        } else {
            SoundEngine.shared.playMove()
        }

        selectedPosition = nil
        legalMovesForSelected = []

        // P0-1: 走棋后记录局面 fingerprint（在 checkGameState 之前，确保检测时计数已更新）
        recordPositionFingerprint()
        checkGameState()

        // P1: MaterialTracker 更新
        materialTracker.update(board: board, playerSide: humanSide)

        // 更新最后一步的 isCheckmate 标记
        if gameState != .playing {
            gameMoves[gameMoves.count - 1].isCheckmate = true
        }

        // v4.0 Phase 5: 一步杀模式判定（V-C2: isCheckmate 标记已更新）
        if isOneStepMateMode && gameMoves.count == 1 {
            if gameState != .playing {
                // 将死 → 成功
                challengeResult = .success
            } else {
                // 不是杀棋 → 失败
                challengeResult = .failure
                gameState = humanSide == .red ? .blackWon : .redWon
                recordGameResult()
                stopClock()
            }
        }

        // Phase 3: 记录统计
        if gameState != .playing {
            recordGameResult()
            stopClock()
        }

        if gameState == .playing {
            hintMove = nil
            hintText = nil
            switchClock()
            // Phase B3 Step 3: 开局教练模式下不自动触发AI走法，由 CoachGameView 控制
            if coachConfig == nil {
                triggerAIMove()
            }
        }
    }

    // R2: undoMove 用 board.moveHistory 的 captured 精确匹配
    func undoMove() {
        guard !isThinking, gameState == .playing else { return }
        SoundEngine.shared.playUndo()

        // 撤销一对（玩家+AI）
        guard board.moveHistory.count >= 2 else { return }

        // 在 undo 之前记录当前局面的 fingerprint，undo 后减去对应计数
        let fpBeforeUndo1 = boardFingerprint()
        if let aiMove = board.undoLastMove() {
            removeCapturedRecord(for: aiMove)
            if !gameMoves.isEmpty { gameMoves.removeLast() }
            positionFingerprints[fpBeforeUndo1, default: 0] -= 1
            if positionFingerprints[fpBeforeUndo1] ?? 0 <= 0 {
                positionFingerprints.removeValue(forKey: fpBeforeUndo1)
            }
        }

        let fpBeforeUndo2 = boardFingerprint()
        if let playerMove = board.undoLastMove() {
            removeCapturedRecord(for: playerMove)
            if !gameMoves.isEmpty { gameMoves.removeLast() }
            positionFingerprints[fpBeforeUndo2, default: 0] -= 1
            if positionFingerprints[fpBeforeUndo2] ?? 0 <= 0 {
                positionFingerprints.removeValue(forKey: fpBeforeUndo2)
            }
        }

        // #3: 恢复 halfmoveClock（从最后一条 GameMove 或初始值 0）
        if let lastMove = gameMoves.last {
            halfmoveClock = lastMove.halfmoveClock
        } else {
            halfmoveClock = 0
        }

        // P1: 同步棋钟 — 先保存当前时段，再回退到玩家方计时
        accumulateCurrentTurnTime()
        clockRunningSide = humanSide
        clockStartTime = Date()

        selectedPosition = nil
        legalMovesForSelected = []
        hintMove = nil
        hintText = nil
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
    }

    // MARK: - 认输

    func requestResign() {
        guard gameState == .playing, !isThinking else { return }
        showResignConfirm = true
    }

    func confirmResign() {
        showResignConfirm = false
        stopThinking()
        // 当前走方认输
        gameState = (board.currentTurn == .red) ? .blackWon : .redWon
        recordGameResult()
        stopClock()
        SoundEngine.shared.playDefeat()
    }

    func cancelResign() {
        showResignConfirm = false
    }

    /// 从 capturedPieces 中移除与 move.captured 匹配的记录（按 id 匹配而非 removeLast）
    private func removeCapturedRecord(for move: Move) {
        guard let captured = move.captured else { return }
        let targetSide = captured.side
        let list = (targetSide == .red) ? capturedPieces.red : capturedPieces.black
        // 从后往前找第一个 id 匹配的
        if let idx = list.lastIndex(where: { $0.id == captured.id }) {
            if targetSide == .red {
                capturedPieces.red.remove(at: idx)
            } else {
                capturedPieces.black.remove(at: idx)
            }
        }
    }

    func newGame() {
        gameVersion += 1
        stopThinking()
        board = Board()
        selectedPosition = nil
        legalMovesForSelected = []
        capturedPieces = (red: [], black: [])
        gameState = .playing
        isInCheck = false
        gameMoves = []
        materialTracker = MaterialTracker()
        hintMove = nil
        hintText = nil
        isBlitzMode = false
        isMasterChallenge = false
        coachConfig = nil
        // v4.0 Phase 5: 重置挑战模式状态
        challengeMode = nil
        challengePuzzle = nil
        isOneStepMateMode = false
        challengeResult = nil
        showChallengeRuleViolation = false
        showChallengeUnavailable = false
        positionFingerprints.removeAll()
        halfmoveClock = 0
        resetClock()
        // 记录初始局面 fingerprint
        recordPositionFingerprint()

        // Phase 3.4: 教练难度自动调节（段位+1）
        // 仅当用户未手动选过难度时才用段位推荐
        if !userDidSetDifficulty {
            difficulty = PlayerProfileStore.shared.profile.rank.recommendedCoachDifficulty
        }

        // v3.1 Phase 2c: 引擎切换 + newGame
        // v4.1 Bug 1 fix: 先停止在途搜索，再 newGame
        // stopSearchImmediate 是 nonisolated，可同步调用，pikafish_stop() 是原子 flag 设置
        if let emb = EngineRouter.shared.activeEngine() as? EmbeddedPikafishEngine {
            emb.stopSearchImmediate()
        }
        EngineRouter.shared.newGame()

        // v3.0 Phase 5: 玩家执黑时 AI（红方）先行
        // 注意：switchEngineIfNeeded 在 triggerAIMove 中调用，确保引擎准备好再求走法
        // Phase B3 Step 3: 开局教练模式下由 CoachGameView 控制 AI 先行
        if humanSide == .black && coachConfig == nil {
            triggerAIMove()
        }
    }

    // v3.0 Phase 5: 设置执边
    func setHumanSide(_ side: Side) {
        humanSide = side
        UserDefaults.standard.set(side == .red ? "red" : "black", forKey: "chinesechess.humanSide")
    }

    // v3.0 Phase 5: 加载上次执边选择
    private static func loadHumanSide() -> Side {
        let saved = UserDefaults.standard.string(forKey: "chinesechess.humanSide") ?? "red"
        return saved == "black" ? .black : .red
    }

    func setDifficulty(_ diff: AIDifficulty) {
        difficulty = diff
        userDidSetDifficulty = true
    }

    // MARK: - 提示

    func requestHint() {
        guard !isThinking, gameState == .playing else { return }
        startThinking()
        let currentDifficulty = difficulty
        let currentVersion = gameVersion

        // v3.1 Phase 2c: 使用 ChessEngine 协议
        Task { [weak self] in
            guard let self else { return }
            defer { self.stopThinking() }
            
            // v6.0: 确保引擎切换完成
            // hint 始终用 Pikafish 最强引擎（不受用户难度影响）
            let engine = await EngineRouter.shared.switchEngineIfNeeded()
            
            // P0 修复：gameVersion 检查
            guard self.gameVersion == currentVersion else { return }
            
            // P0 修复：FEN 已代表当前局面，moveHistory 会重复执行走法导致 nil
            let fen = FENParser.generate(board: self.board)
            
            let uciMove = await engine.bestMove(
                fen: fen,
                moveHistory: [],
                difficulty: .grandmaster,  // hint 始终用最强
                timeLimitMs: 0
            )
            
            guard self.gameVersion == currentVersion else {
                return
            }
            
            if let uciMove = uciMove,
               let move = UCIMoveConverter.move(from: uciMove, on: self.board) {
                self.hintMove = (from: move.from, to: move.to)
                // v3.9.1: 教练整合 hint，生成场景标题
                let hintExplanation = await CoachExplainer.shared.explainHint(
                    fen: fen,
                    bestMove: uciMove
                )
                self.hintText = hintExplanation.title
            } else {
                self.engineFallbackMessage = L10n.shared.t("engine.hintFailed")
            }
        }
    }

    // MARK: - AI

    private func triggerAIMove() {
        startThinking()
        let currentDifficulty = difficulty
        let currentVersion = gameVersion
        let humanSide = self.humanSide


        // v3.1 Phase 2c: 使用 ChessEngine 协议
        Task { [weak self] in
            guard let self else {
                return
            }
            defer { self.stopThinking() }
            
            // P0 修复：确保是 AI 的回合（不是玩家的回合）
            guard self.board.currentTurn != humanSide else {
                return
            }
            
            // v6.0: 确保引擎切换完成 + 按难度路由
            _ = await EngineRouter.shared.switchEngineIfNeeded()
            
            // v6.0: 专业级进入对弈前检查 Pikafish 可用性
            let availability = await EngineRouter.shared.validateEngineAvailability(for: currentDifficulty)
            if case .unavailable(let reason) = availability {
                self.stopThinking()
                switch reason {
                case .engineNotReady:
                    self.engineFallbackMessage = L10n.shared.t("engine.notReady")
                case .engineFailed:
                    self.engineFallbackMessage = L10n.shared.t("engine.engineFailed")
                }
                return
            }
            
            // P0 修复：gameVersion 检查 — 新对局可能已开始
            guard self.gameVersion == currentVersion else { return }
            
            // v6.0: 按难度获取引擎
            let engine = EngineRouter.shared.engineFor(difficulty: currentDifficulty)
            // P0 修复：FEN 已代表当前局面，moveHistory 会重复执行走法导致 nil
            let fen = FENParser.generate(board: self.board)
            
            let uciMove = await engine.bestMove(
                fen: fen,
                moveHistory: [],
                difficulty: currentDifficulty,
                timeLimitMs: 0
            )
            
            guard self.gameVersion == currentVersion else {
                // gameVersion 不匹配——新对局已开始
                return
            }
            
            if let uciMove = uciMove {
                if let move = UCIMoveConverter.move(from: uciMove, on: self.board) {
                    let mainPiece = self.board.pieces.first { $0.id == move.piece.id }
                    if let mainPiece = mainPiece {
                        // P0 修复：验证 AI 返回的走法是 AI 的棋（不是玩家的棋）
                        guard mainPiece.side == self.board.currentTurn else {
                            // 外部引擎返回了错误的走法（走的是玩家的棋）
                            return
                        }

                        let captured = self.board.piece(at: move.to)

                        // 生成棋谱（execute 之前）
                        let aiMove = Move(piece: mainPiece, from: mainPiece.position, to: move.to, captured: captured)
                        let notation = NotationGenerator.notation(for: aiMove, on: self.board)

                        self.board.execute(aiMove)

                        // #3 halfmoveClock 更新（AI 走棋）
                        let isPawn = mainPiece.kind == .soldier
                        if captured != nil || isPawn {
                            self.halfmoveClock = 0
                        } else {
                            self.halfmoveClock += 1
                        }

                        // 记录 AI 的 GameMove
                        let turnNumber = (self.gameMoves.count / 2) + 1
                        let isCheck = MoveValidator.isInCheck(self.humanSide, on: self.board)

                        let gameMove = GameMove(
                            id: UUID(),
                            piece: mainPiece,
                            from: aiMove.from,
                            to: aiMove.to,
                            captured: captured,
                            turnNumber: turnNumber,
                            notation: notation,
                            timestamp: Date(),
                            isCheck: isCheck,
                            isCheckmate: false,
                            halfmoveClock: self.halfmoveClock
                        )
                        self.gameMoves.append(gameMove)

                        if let captured = captured {
                            // 按被吃子的归属方存储（红方损失的子存入 red）
                            if captured.side == .red {
                                self.capturedPieces.red.append(captured)
                            } else {
                                self.capturedPieces.black.append(captured)
                            }
                            SoundEngine.shared.playCapture()
                        } else {
                            SoundEngine.shared.playMove()
                        }
                    } else {
                        // move.piece 在棋盘上找不到
                        AppLog.gameVM.error("AI move: piece not found on board")
                    }
                } else {
                    // UCI 走法解析失败
                    AppLog.gameVM.error("AI move: UCI parse failed for \(uciMove)")
                }
            } else {
                // 引擎返回 nil
                AppLog.gameVM.error("AI move: engine returned nil")
                
                // v6.0 P1-1: 专业级引擎失败时触发非静默 fallback
                if currentDifficulty.isProfessional {
                    // v6.2 P2-2: 通知监听通道为唯一写入方——handleEngineFailure 发 fallbackNotification，
                    // GVM 监听（init fallbackObserver）带 userInfo 精确构造同一消息，此处手动 set 为双写冗余，已删。
                    EngineRouter.shared.handleEngineFailure(difficulty: currentDifficulty)
                } else {
                    // 非专业级不触发 handleEngineFailure（无通知），失败消息需直接 set，否则静默失败
                    self.engineFallbackMessage = L10n.shared.t("engine.aiMoveFailed")
                }
            }
            
            // P0 修复：stopThinking 由 defer 保证，无需手动调用
            // P0-1: AI 走棋后记录局面 fingerprint
            self.recordPositionFingerprint()
            self.checkGameState()

            // P1: MaterialTracker 更新（AI 走棋后）
            self.materialTracker.update(board: self.board, playerSide: self.humanSide)

            // 更新最后一步 isCheckmate
            if self.gameState != .playing && !self.gameMoves.isEmpty {
                self.gameMoves[self.gameMoves.count - 1].isCheckmate = true
            }

            if self.gameState != .playing {
                self.recordGameResult()
                self.stopClock()
            } else {
                self.switchClock()
            }
        }
    }

    // MARK: - 游戏状态检查

    private func checkGameState() {
        let currentSide = board.currentTurn
        if MoveValidator.isCheckmate(currentSide, on: board) {
            gameState = (currentSide == .red) ? .blackWon : .redWon
            isInCheck = false
            // 将死时只播放胜负音效，不叠加 checkmate
            if gameState == .redWon {
                SoundEngine.shared.playVictory()
            } else {
                SoundEngine.shared.playDefeat()
            }
        } else if MoveValidator.isStalemate(currentSide, on: board) {
            // 困毙判负（中国象棋规则：无子可动方判负，不是和棋）
            gameState = (currentSide == .red) ? .blackWon : .redWon
            isInCheck = false
        } else {
            // 长将判负（中国象棋规则：连续将军+局面循环判将军方负）
            // 优先于三次重复判和：同一循环既是长将又是三次重复时，应判长将负
            if detectPerpetualCheck() {
                // currentSide = 长将方（被将军方走完最后一步应将后 turn 切换回来）
                // 长将方判负 → 对手赢
                gameState = (currentSide == .red) ? .blackWon : .redWon
                isInCheck = false

                // 首次触发长将判负时弹出解释弹窗
                if !UserDefaults.standard.bool(forKey: "chinesechess.perpetualCheckExplained") {
                    perpetualCheckMessage = L10n.shared.t("game.perpetualCheckMessage")
                    UserDefaults.standard.set(true, forKey: "chinesechess.perpetualCheckExplained")
                }

                if gameState == .redWon {
                    SoundEngine.shared.playVictory()
                } else {
                    SoundEngine.shared.playDefeat()
                }
                return
            }

            // v4.0 Phase 6: 长捉判负（优先于三次重复判和）
            if detectPerpetualChase() {
                gameState = (currentSide == .red) ? .blackWon : .redWon
                isInCheck = false
                perpetualChaseMessage = L10n.shared.t("game.perpetualChaseMessage")
                if gameState == .redWon {
                    SoundEngine.shared.playVictory()
                } else {
                    SoundEngine.shared.playDefeat()
                }
                return
            }

            // 三次重复局面判和
            let count = positionFingerprints[boardFingerprint(), default: 0]
            if count >= 3 {
                gameState = .draw
                isInCheck = false
                return
            }

            // 50 回合规则（100 半回合无吃子/无兵移动判和）
            if halfmoveClock >= 100 {
                gameState = .draw
                isInCheck = false
                return
            }

            if MoveValidator.isInCheck(currentSide, on: board) {
                isInCheck = true
                SoundEngine.shared.playCheck()
            } else {
                isInCheck = false
            }
        }

    }

    // MARK: - 和棋检测辅助

    /// P0-1: 生成局面 fingerprint（完整 FEN，含走子方）
    /// 同一棋盘布局但不同走子方 = 不同 fingerprint
    private func boardFingerprint() -> String {
        return FENParser.generate(board: board)
    }

    /// 记录当前局面 fingerprint（每步走棋后调用）
    private func recordPositionFingerprint() {
        let fp = boardFingerprint()
        positionFingerprints[fp, default: 0] += 1
    }

    /// 长将检测 — 同一方连续将军 + 局面重复
    /// 中国象棋规则：同一方连续将军且局面循环 → 判将军方负
    /// 必须同时满足：
    ///   1. 同一方最近 6 步中 ≥3 步将军
    ///   2. 当前局面重复 ≥3 次（排除合法连将杀战术）
    private func detectPerpetualCheck() -> Bool {
        guard gameMoves.count >= perpetualCheckThreshold else { return false }

        let recentMoves = Array(gameMoves.suffix(perpetualCheckThreshold))

        // 按走子方分组，检查是否有一方连续 3+ 步全部将军
        let sides = Set(recentMoves.map { $0.piece.side })
        for side in sides {
            let sideMoves = recentMoves.filter { $0.piece.side == side }
            // 条件1：同一方在最近 6 步中至少 3 步，且全部将军
            guard sideMoves.count >= 3 && sideMoves.allSatisfy({ $0.isCheck }) else { continue }

            // 条件2：当前局面重复 ≥3 次（说明是循环将军，非连将杀战术）
            let currentFP = boardFingerprint()
            if positionFingerprints[currentFP, default: 0] >= 3 {
                return true
            }
        }
        return false
    }

    // MARK: - v4.0 Phase 6: 长捉检测

    /// 长捉检测 — 同一攻击者连续捉同一目标 + 局面循环
    private func detectPerpetualChase() -> Bool {
        guard gameMoves.count >= perpetualChaseThreshold else { return false }

        let recentMoves = Array(gameMoves.suffix(perpetualChaseThreshold))

        // 按走子方分组，检查是否有一方连续捉
        let sides = Set(recentMoves.map { $0.piece.side })
        for side in sides {
            let sideChaseMoves = recentMoves.filter { $0.piece.side == side && $0.isChase }

            // 条件1：同一方在最近 6 步中至少 3 步是捉
            guard sideChaseMoves.count >= 3 else { continue }

            // 条件2：攻击者是同一枚（chaseAttackerId 相同）
            let attackerIds = sideChaseMoves.compactMap { $0.chaseAttackerId }
            guard Set(attackerIds).count == 1 else { continue }

            // 条件3：目标是同一枚（chaseTargetId 相同）
            let targetIds = sideChaseMoves.compactMap { $0.chaseTargetId }
            guard Set(targetIds).count == 1 else { continue }

            // 条件4：当前局面重复 ≥3 次
            let currentFP = boardFingerprint()
            if positionFingerprints[currentFP, default: 0] >= 3 {
                return true
            }
        }
        return false
    }

    /// 判断走法是否"捉"对方有价值棋子（P0-2 修正：只检查移动棋子本身）
    /// 返回 (isChase, target) — 攻击者就是移动棋子本身
    private static func isChasing(_ move: Move, on board: Board) -> (Bool, Piece?) {
        let snapshot = board.snapshot()
        snapshot.execute(move)

        // P0-2 修正：只检查移动后的棋子本身
        guard let movedPiece = snapshot.piece(at: move.to) else { return (false, nil) }

        let opponent: Side = (move.piece.side == .red) ? .black : .red
        let valuableTargets: [PieceKind] = [.chariot, .cannon, .horse]

        for target in snapshot.pieces(for: opponent) {
            guard valuableTargets.contains(target.kind) else { continue }
            if MoveValidator.canAttack(piece: movedPiece, target: target.position, on: snapshot) {
                return (true, target)
            }
        }
        return (false, nil)
    }

    // MARK: - 统计记录

    private func recordGameResult() {
        switch gameState {
        case .redWon:
            StatsManager.shared.recordWin(for: difficulty)
        case .blackWon:
            StatsManager.shared.recordLoss(for: difficulty)
        case .draw:
            StatsManager.shared.recordDraw(for: difficulty)
        case .playing:
            break
        }

        // Q3: 更新 PlayerProfile 连胜/击败难度/基础统计
        let playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
        let playerLost = (humanSide == .red && gameState == .blackWon) || (humanSide == .black && gameState == .redWon)

        PlayerProfileStore.shared.update { profile in
            if playerWon {
                profile.totalWins += 1
                profile.currentWinStreak += 1
                if profile.currentWinStreak > profile.maxWinStreak {
                    profile.maxWinStreak = profile.currentWinStreak
                }
                profile.beatenDifficulties.insert(difficulty.id)
            } else if playerLost {
                // Q4: 大师挑战输了不重置连胜（鼓励尝试）
                // bonusMasterNoPenalty（day60 奖励）更进一步：不记录败局
                let skipLoss = isMasterChallenge && PlayerProfileStore.shared.profile.bonusMasterNoPenalty
                if !skipLoss {
                    profile.totalLosses += 1
                }
                if !isMasterChallenge {
                    profile.currentWinStreak = 0
                }
            } else if gameState == .draw {
                profile.totalDraws += 1
                // 和局不影响 currentWinStreak（不加不减）
            }
        }

        // Q3: 行为成就检测
        if playerWon || playerLost {
            let playerMoves = gameMoves.filter { $0.piece.side == humanSide }
            var maxConsec = 0
            var currentConsec = 0
            for move in playerMoves {
                if move.isCheck {
                    currentConsec += 1
                    maxConsec = max(maxConsec, currentConsec)
                } else {
                    currentConsec = 0
                }
            }
            let result = GameResultInfo(
                isWin: playerWon,
                difficulty: difficulty,
                moveCount: gameMoves.count,
                playerMoveCount: playerMoves.count,
                elapsedSeconds: TimeInterval(redClockSeconds + blackClockSeconds),
                usedHint: hintMove != nil,
                checkmatePattern: AchievementChecker.detectCheckmatePattern(
                    lastMoves: gameMoves.suffix(6), playerSide: humanSide
                ),
                maxMaterialDeficit: materialTracker.maxDeficit,
                maxConsecutiveChecks: maxConsec
            )
            let newlyUnlocked = AchievementChecker.checkAfterGame(
                result: result, profile: PlayerProfileStore.shared.profile
            )
            for id in newlyUnlocked {
                AchievementManager.shared.unlock(id)
            }
        }

        // Phase 4: 自动保存历史对局
        if gameState != .playing, let record = buildGameRecord() {
            GameRecordStore.shared.addRecord(record)
        }

        // P1: 每日挑战完成通知
        if challengeMode != nil && gameState != .playing {
            let playerWon = (humanSide == .red && gameState == .redWon) || (humanSide == .black && gameState == .blackWon)
            // v4.1 Phase 2: 补全 endgameStart 和 cannonOnly 的 challengeResult 赋值
            // solveMate 的 challengeResult 在 executeMove 中已赋值，此处不覆盖
            if challengeResult == nil {
                challengeResult = playerWon ? .success : .failure
            }
            let puzzles: [Puzzle] = challengePuzzle.map { [$0] } ?? []
            DailyChallengeManager.shared.completeChallenge(score: playerWon ? 100 : 0, puzzles: puzzles)
        }
    }

    // MARK: - v4.0 Phase 5: 挑战模式加载

    /// 加载挑战模式游戏
    func loadChallenge(mode: DailyChallengeMode, puzzle: Puzzle?, difficulty: AIDifficulty) {
        // 重置状态
        newGame()
        challengeMode = mode
        challengePuzzle = puzzle
        challengeResult = nil
        showChallengeUnavailable = false
        showChallengeRuleViolation = false
        isOneStepMateMode = false

        switch mode {
        case .endgameStart:
            guard let puzzle = puzzle else {
                showChallengeUnavailable = true
                return
            }
            board = Board(fen: puzzle.initialFEN)
            humanSide = puzzle.side
            self.difficulty = difficulty
            isBlitzMode = false
            isMasterChallenge = false
            isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)

        case .solveMate:
            guard let puzzle = puzzle else {
                showChallengeUnavailable = true
                return
            }
            board = Board(fen: puzzle.initialFEN)
            humanSide = puzzle.side
            self.difficulty = difficulty
            isOneStepMateMode = true
            isBlitzMode = true
            blitzTimeLimitSeconds = 60
            isMasterChallenge = false
            isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)

        case .cannonOnly:
            // 标准初始局面
            self.difficulty = difficulty
            isBlitzMode = false
            isMasterChallenge = false

        default:
            // 其他模式不走此入口
            break
        }
    }

    // MARK: - v4.0 Phase 5: 走法限制

    /// 挑战模式走法合法性检查
    func isChallengeMoveLegal(_ move: Move) -> Bool {
        guard let mode = challengeMode else { return true }

        switch mode {
        case .cannonOnly:
            // 设计意图：炮为主力进攻，车/马限制为防守或跨区吃子
            // 兵/将/士/相保持正常走法（设计文档定义）
            let piece = move.piece
            // 炮无限制
            if piece.kind == .cannon { return true }
            // 车/马限制：只能己方半场移动或跨区吃子
            if piece.kind == .chariot || piece.kind == .horse {
                let toRow = move.to.row
                let isOwnHalf = piece.side == .red ? (toRow >= 5) : (toRow <= 4)
                let isCapturing = move.captured != nil
                return isOwnHalf || isCapturing
            }
            // 兵/将/士/相正常走法
            return true

        default:
            return true
        }
    }

    // MARK: - 对局回放

    /// 生成当前对局的回放记录
    func buildGameRecord() -> GameRecord? {
        guard !gameMoves.isEmpty else { return nil }
        let isHumanRed = humanSide == .red
        let humanName = L10n.shared.t("player.human")
        let aiName = String(format: L10n.shared.t("player.aiLabel"), difficulty.displayName)
        return GameRecord(
            id: UUID(),
            title: String(format: L10n.shared.t("game.vsAITitle"), formatShortDate()),
            date: Date(),
            redPlayer: PlayerInfo(
                name: isHumanRed ? humanName : aiName,
                isAI: !isHumanRed,
                difficulty: isHumanRed ? nil : difficulty
            ),
            blackPlayer: PlayerInfo(
                name: isHumanRed ? aiName : humanName,
                isAI: isHumanRed,
                difficulty: isHumanRed ? difficulty : nil
            ),
            difficulty: difficulty,
            result: gameState,
            totalMoves: gameMoves.count,
            moves: gameMoves,
            initialFEN: nil,
            source: .versusAI
        )
    }

    private func formatShortDate() -> String {
        // 跟随系统 Locale，R3-07 要求
        Date.now.formatted(
            .dateTime
            .month(.defaultDigits).day().hour().minute()
        )
    }
}
