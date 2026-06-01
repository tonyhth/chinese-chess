import Foundation

@Observable
class GameViewModel {
    var board: Board
    var selectedPosition: Position?
    var legalMovesForSelected: [Position] = []
    var capturedPieces: (red: [Piece], black: [Piece]) = (red: [], black: [])
    var gameState: GameState = .playing
    var isThinking: Bool = false
    var difficulty: AIDifficulty = .medium
    var gameMode: GameMode = .singlePlayer
    var moveHistory: [Move] {
        board.moveHistory
    }
    var currentTurn: Side {
        board.currentTurn
    }

    // Phase 3: 走法记录（含棋谱）
    var gameMoves: [GameMove] = []

    private let aiEngine = AIEngine()

    init() {
        self.board = Board()
    }

    // MARK: - 用户操作

    func selectPiece(at pos: Position) {
        guard !isThinking, gameState == .playing else { return }

        // 人机模式只允许红方操作
        if gameMode == .singlePlayer && board.currentTurn != .red { return }

        if let selected = selectedPosition, legalMovesForSelected.contains(pos) {
            movePiece(from: selected, to: pos)
            return
        }

        // 人机模式只能选红方棋子
        guard let piece = board.piece(at: pos) else {
            selectedPosition = nil
            legalMovesForSelected = []
            return
        }

        if gameMode == .singlePlayer && piece.side != .red {
            selectedPosition = nil
            legalMovesForSelected = []
            return
        }

        // 人人对战模式可以选双方棋子
        if gameMode == .localPVP && piece.side != board.currentTurn {
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

        // 人机模式只允许红方走棋
        if gameMode == .singlePlayer && piece.side != .red { return }
        // 人人对战只允许当前方走棋
        if gameMode == .localPVP && piece.side != board.currentTurn { return }

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
            if piece.side == .red {
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
        }

        if gameState == .playing && gameMode == .singlePlayer {
            triggerAIMove()
        }
    }

    // R2: undoMove 用 board.moveHistory 的 captured 精确匹配
    func undoMove() {
        guard !isThinking, gameState == .playing else { return }
        SoundEngine.shared.playUndo()

        if gameMode == .singlePlayer {
            // 人机模式：撤销一对（玩家+AI）
            guard board.moveHistory.count >= 2 else { return }
            if let aiMove = board.undoLastMove() {
                removeCapturedRecord(for: aiMove)
                if !gameMoves.isEmpty { gameMoves.removeLast() }
            }
            if let playerMove = board.undoLastMove() {
                removeCapturedRecord(for: playerMove)
                if !gameMoves.isEmpty { gameMoves.removeLast() }
            }
        } else {
            // 人人对战：只撤销一步
            guard board.moveHistory.count >= 1 else { return }
            if let move = board.undoLastMove() {
                removeCapturedRecord(for: move)
                if !gameMoves.isEmpty { gameMoves.removeLast() }
            }
        }

        selectedPosition = nil
        legalMovesForSelected = []
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
        guard !isThinking else { return }
        board = Board()
        selectedPosition = nil
        legalMovesForSelected = []
        capturedPieces = (red: [], black: [])
        gameState = .playing
        gameMoves = []
    }

    func setDifficulty(_ diff: AIDifficulty) {
        difficulty = diff
    }

    func setGameMode(_ mode: GameMode) {
        guard !isThinking else { return }
        gameMode = mode
        newGame()
    }

    // MARK: - AI

    private func triggerAIMove() {
        isThinking = true
        let snapshot = board.snapshot()
        let currentDifficulty = difficulty

        let engine = self.aiEngine
        Task.detached {
            let move = engine.bestMove(for: snapshot, difficulty: currentDifficulty)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let move = move {
                    let mainPiece = self.board.pieces.first { $0.id == move.piece.id }
                    if let mainPiece = mainPiece {
                        let captured = self.board.piece(at: move.to)

                        // 生成棋谱（execute 之前）
                        let aiMove = Move(piece: mainPiece, from: mainPiece.position, to: move.to, captured: captured)
                        let notation = NotationGenerator.notation(for: aiMove, on: self.board)

                        self.board.execute(aiMove)

                        // 记录 AI 的 GameMove
                        let turnNumber = (self.gameMoves.count / 2) + 1
                        let isCheck = MoveValidator.isInCheck(.red, on: self.board)

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
                            self.capturedPieces.black.append(captured)
                            SoundEngine.shared.playCapture()
                        } else {
                            SoundEngine.shared.playMove()
                        }
                    }
                }
                self.isThinking = false
                self.checkGameState()

                // 更新最后一步 isCheckmate
                if self.gameState != .playing && !self.gameMoves.isEmpty {
                    self.gameMoves[self.gameMoves.count - 1].isCheckmate = true
                }

                if self.gameState != .playing {
                    self.recordGameResult()
                }
            }
        }
    }

    // MARK: - 游戏状态检查

    private func checkGameState() {
        let currentSide = board.currentTurn
        if MoveValidator.isCheckmate(currentSide, on: board) {
            gameState = (currentSide == .red) ? .blackWon : .redWon
            // 将死时只播放胜负音效，不叠加 checkmate
            if gameState == .redWon {
                SoundEngine.shared.playVictory()
            } else {
                SoundEngine.shared.playDefeat()
            }
        } else if MoveValidator.isStalemate(currentSide, on: board) {
            gameState = .draw
        } else if MoveValidator.isInCheck(currentSide, on: board) {
            SoundEngine.shared.playCheck()
        }
    }

    // MARK: - 统计记录

    private func recordGameResult() {
        switch gameMode {
        case .singlePlayer:
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
        case .localPVP:
            let isDraw = (gameState == .draw)
            StatsManager.shared.recordPVPGame(draw: isDraw)
        }
    }

    // MARK: - 对局回放

    /// 生成当前对局的回放记录
    func buildGameRecord() -> GameRecord? {
        guard !gameMoves.isEmpty else { return nil }
        return GameRecord(
            id: UUID(),
            title: "\(gameMode == .singlePlayer ? "人机对局" : "人人对局") \(formatShortDate())",
            date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(
                name: gameMode == .singlePlayer ? "AI-\(difficulty.rawValue)" : "黑方",
                isAI: gameMode == .singlePlayer,
                difficulty: gameMode == .singlePlayer ? difficulty : nil
            ),
            difficulty: gameMode == .singlePlayer ? difficulty : nil,
            gameMode: gameMode,
            result: gameState,
            totalMoves: gameMoves.count,
            moves: gameMoves,
            initialFEN: nil
        )
    }

    private func formatShortDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date())
    }
}
