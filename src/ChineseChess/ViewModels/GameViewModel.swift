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
    var difficulty: AIDifficulty = .medium
    var humanSide: Side = {
        let saved = UserDefaults.standard.string(forKey: "chinesechess.humanSide") ?? "red"
        return saved == "black" ? .black : .red
    }()
    var hintMove: (from: Position, to: Position)? = nil

    // P1-2: 外部引擎 fallback 提示（非 nil 时 UI 弹 alert）
    var engineFallbackMessage: String? = nil

    // Q4: 闪电局模式
    var isBlitzMode: Bool = false
    var blitzTimeLimitSeconds: Int = 300  // 双方各 5 分钟

    // Q4: 大师挑战模式（输了不扣统计）
    var isMasterChallenge: Bool = false

    // P2 修复：持有 observer token，deinit 时移除
    @ObservationIgnored nonisolated(unsafe) private var fallbackObserver: NSObjectProtocol?

    private var gameVersion: Int = 0
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
        // P1-2: 监听外部引擎 fallback 通知
        fallbackObserver = NotificationCenter.default.addObserver(
            forName: EngineRouter.fallbackNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.engineFallbackMessage = L10n.shared.t("engine.fallbackMessage")
            }
        }
    }

    deinit {
        if let observer = fallbackObserver {
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

        // Phase 3: 生成棋谱（在 execute 之前，需要走前的 board 状态）
        let notation = NotationGenerator.notation(for: move, on: board)

        board.execute(move)

        // Phase 3: 记录 GameMove
        let turnNumber = (gameMoves.count / 2) + 1
        let opponent = (piece.side == .red) ? Side.black : Side.red
        let isCheck = MoveValidator.isInCheck(opponent, on: board)

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
            isCheckmate: false   // 将在 checkGameState 后更新
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

        checkGameState()

        // 更新最后一步的 isCheckmate 标记
        if gameState != .playing {
            gameMoves[gameMoves.count - 1].isCheckmate = true
        }

        // Phase 3: 记录统计
        if gameState != .playing {
            recordGameResult()
            stopClock()
        }

        if gameState == .playing {
            hintMove = nil
            switchClock()
            triggerAIMove()
        }
    }

    // R2: undoMove 用 board.moveHistory 的 captured 精确匹配
    func undoMove() {
        guard !isThinking, gameState == .playing else { return }
        SoundEngine.shared.playUndo()

        // 撤销一对（玩家+AI）
        guard board.moveHistory.count >= 2 else { return }
        if let aiMove = board.undoLastMove() {
            removeCapturedRecord(for: aiMove)
            if !gameMoves.isEmpty { gameMoves.removeLast() }
        }
        if let playerMove = board.undoLastMove() {
            removeCapturedRecord(for: playerMove)
            if !gameMoves.isEmpty { gameMoves.removeLast() }
        }

        // P1: 同步棋钟 — 先保存当前时段，再回退到玩家方计时
        accumulateCurrentTurnTime()
        clockRunningSide = humanSide
        clockStartTime = Date()

        selectedPosition = nil
        legalMovesForSelected = []
        hintMove = nil
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
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
        hintMove = nil
        isBlitzMode = false
        isMasterChallenge = false
        resetClock()

        // v3.1 Phase 2c: 引擎切换 + newGame
        EngineRouter.shared.newGame()

        // v3.0 Phase 5: 玩家执黑时 AI（红方）先行
        // 注意：switchEngineIfNeeded 在 triggerAIMove 中调用，确保引擎准备好再求走法
        if humanSide == .black {
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
            
            // 确保引擎切换完成
            _ = await EngineRouter.shared.switchEngineIfNeeded()
            
            let engine = EngineRouter.shared.activeEngine()
            // P0 修复：FEN 已代表当前局面，moveHistory 会重复执行走法导致 nil
            let fen = FENParser.generate(board: self.board)
            
            let uciMove = await engine.bestMove(
                fen: fen,
                moveHistory: [],
                difficulty: currentDifficulty,
                timeLimitMs: 0
            )
            
            guard self.gameVersion == currentVersion else {
                self.stopThinking()
                return
            }
            
            if let uciMove = uciMove,
               let move = UCIMoveConverter.move(from: uciMove, on: self.board) {
                self.hintMove = (from: move.from, to: move.to)
            } else {
                self.engineFallbackMessage = L10n.shared.t("engine.hintFailed")
            }
            self.stopThinking()
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
            
            // P0 修复：确保是 AI 的回合（不是玩家的回合）
            guard self.board.currentTurn != humanSide else {
                self.stopThinking()
                return
            }
            
            // 确保引擎切换完成
            _ = await EngineRouter.shared.switchEngineIfNeeded()
            
            let engine = EngineRouter.shared.activeEngine()
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
                self.stopThinking()
                return
            }
            
            if let uciMove = uciMove {
                if let move = UCIMoveConverter.move(from: uciMove, on: self.board) {
                    let mainPiece = self.board.pieces.first { $0.id == move.piece.id }
                    if let mainPiece = mainPiece {
                        // P0 修复：验证 AI 返回的走法是 AI 的棋（不是玩家的棋）
                        guard mainPiece.side == self.board.currentTurn else {
                            // 外部引擎返回了错误的走法（走的是玩家的棋）
                            self.stopThinking()
                            return
                        }

                        let captured = self.board.piece(at: move.to)

                        // 生成棋谱（execute 之前）
                        let aiMove = Move(piece: mainPiece, from: mainPiece.position, to: move.to, captured: captured)
                        let notation = NotationGenerator.notation(for: aiMove, on: self.board)

                        self.board.execute(aiMove)

                        // 记录 AI 的 GameMove
                        let turnNumber = (self.gameMoves.count / 2) + 1
                        let isCheck = MoveValidator.isInCheck(humanSide, on: self.board)

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
                            isCheckmate: false
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
                self.engineFallbackMessage = L10n.shared.t("engine.aiMoveFailed")
            }
            
            self.stopThinking()
            self.checkGameState()

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
            gameState = .draw
            isInCheck = false
        } else if MoveValidator.isInCheck(currentSide, on: board) {
            isInCheck = true
            SoundEngine.shared.playCheck()
        } else {
            isInCheck = false
        }
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

        // Phase 4: 自动保存历史对局
        if gameState != .playing, let record = buildGameRecord() {
            GameHistoryStore.shared.addRecord(record)
        }
    }

    // MARK: - 对局回放

    /// 生成当前对局的回放记录
    func buildGameRecord() -> GameRecord? {
        guard !gameMoves.isEmpty else { return nil }
        return GameRecord(
            id: UUID(),
            title: String(format: L10n.shared.t("game.vsAITitle"), formatShortDate()),
            date: Date(),
            redPlayer: PlayerInfo(name: L10n.shared.t("player.red"), isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(
                name: String(format: L10n.shared.t("player.aiLabel"), difficulty.displayName),
                isAI: true,
                difficulty: difficulty
            ),
            difficulty: difficulty,
            result: gameState,
            totalMoves: gameMoves.count,
            moves: gameMoves,
            initialFEN: nil
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
