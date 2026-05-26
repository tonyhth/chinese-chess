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
    var moveHistory: [Move] {
        board.moveHistory
    }
    var currentTurn: Side {
        board.currentTurn
    }

    private let aiEngine = AIEngine()

    init() {
        self.board = Board()
    }

    // MARK: - 用户操作

    func selectPiece(at pos: Position) {
        guard !isThinking, gameState == .playing else { return }
        guard board.currentTurn == .red else { return }

        if let selected = selectedPosition, legalMovesForSelected.contains(pos) {
            movePiece(from: selected, to: pos)
            return
        }

        guard let piece = board.piece(at: pos), piece.side == .red else {
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
        guard let piece = board.piece(at: from), piece.side == .red else { return }

        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        guard MoveValidator.isLegal(move, on: board) else { return }

        board.execute(move)

        if let captured = captured {
            capturedPieces.red.append(captured)
            SoundEngine.shared.playCapture()
        } else {
            SoundEngine.shared.playMove()
        }

        selectedPosition = nil
        legalMovesForSelected = []

        checkGameState()

        if gameState == .playing {
            triggerAIMove()
        }
    }

    // R2: undoMove 用 board.moveHistory 的 captured 精确匹配
    func undoMove() {
        guard !isThinking, gameState == .playing else { return }
        guard board.moveHistory.count >= 2 else { return }

        // 撤销 AI 的走法（黑方）
        if let aiMove = board.undoLastMove() {
            removeCapturedRecord(for: aiMove)
        }
        // 撤销玩家的走法（红方）
        if let playerMove = board.undoLastMove() {
            removeCapturedRecord(for: playerMove)
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
    }

    func setDifficulty(_ diff: AIDifficulty) {
        difficulty = diff
    }

    // MARK: - AI

    private func triggerAIMove() {
        isThinking = true
        let snapshot = board.snapshot()
        let currentDifficulty = difficulty

        let engine = self.aiEngine  // 捕获成员变量（struct 值拷贝）
        Task.detached {
            let move = engine.bestMove(for: snapshot, difficulty: currentDifficulty)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let move = move {
                    let mainPiece = self.board.pieces.first { $0.id == move.piece.id }
                    if let mainPiece = mainPiece {
                        let captured = self.board.piece(at: move.to)
                        let mainMove = Move(piece: mainPiece, from: mainPiece.position, to: move.to, captured: captured)
                        self.board.execute(mainMove)

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
            }
        }
    }

    // MARK: - 游戏状态检查

    private func checkGameState() {
        let currentSide = board.currentTurn
        if MoveValidator.isCheckmate(currentSide, on: board) {
            gameState = (currentSide == .red) ? .blackWon : .redWon
        } else if MoveValidator.isStalemate(currentSide, on: board) {
            gameState = .draw
        }
    }
}
