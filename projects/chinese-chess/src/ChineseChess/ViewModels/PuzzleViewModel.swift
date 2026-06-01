import Foundation

@Observable
class PuzzleViewModel {
    let puzzle: Puzzle
    let board: Board
    let playerSide: Side

    var gameMoves: [GameMove] = []
    var gameState: PuzzleState = .playing
    var hintIndex: Int = 0
    var currentHint: String?
    var isThinking: Bool = false
    var completionRating: Int = 0
    var solutionHint: String?  // 实时提示：有更优走法时显示

    private let aiEngine = AIEngine()

    enum PuzzleState: Equatable {
        case playing
        case success
        case failed
        case showingHint
    }

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.playerSide = puzzle.side
        self.board = Board(fen: puzzle.initialFEN)
    }

    // MARK: - 防守方 AI 难度映射

    private var defenderDifficulty: AIDifficulty {
        switch puzzle.difficulty {
        case 1: return .beginner
        case 2: return .easy
        case 3: return .medium
        case 4: return .hard
        default: return .easy
        }
    }

    // MARK: - 玩家走棋

    func selectPiece(at pos: Position) -> [Position] {
        guard gameState == .playing, !isThinking else { return [] }
        guard board.currentTurn == playerSide else { return [] }

        guard let piece = board.piece(at: pos), piece.side == playerSide else {
            return []
        }

        let moves = MoveValidator.legalMoves(for: piece, on: board)
        return moves.map { $0.to }
    }

    func movePiece(from: Position, to: Position) {
        guard gameState == .playing, !isThinking else { return }
        guard let piece = board.piece(at: from), piece.side == playerSide else { return }

        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        guard MoveValidator.isLegal(move, on: board) else { return }

        // 生成棋谱
        let notation = NotationGenerator.notation(for: move, on: board)

        board.execute(move)

        // 记录 GameMove
        let opponent = (piece.side == .red) ? Side.black : Side.red
        let isCheck = MoveValidator.isInCheck(opponent, on: board)
        let turnNumber = (gameMoves.count / 2) + 1

        let gameMove = GameMove(
            id: UUID(), piece: piece, from: from, to: to, captured: captured,
            turnNumber: turnNumber, notation: notation, timestamp: Date(),
            isCheck: isCheck, isCheckmate: false
        )
        gameMoves.append(gameMove)

        if let captured = captured {
            SoundEngine.shared.playCapture()
        } else {
            SoundEngine.shared.playMove()
        }

        // 实时解法提示：检查是否走了推荐走法
        let playerMoveIndex = gameMoves.filter { $0.piece.side == playerSide }.count - 1
        if !isRecommendedMove(at: playerMoveIndex) {
            solutionHint = "💡 有更优走法"
        } else {
            solutionHint = nil
        }

        // 检查是否将死对方
        let defenderSide: Side = (playerSide == .red) ? .black : .red
        if MoveValidator.isCheckmate(defenderSide, on: board) {
            gameState = .success
            gameMoves[gameMoves.count - 1].isCheckmate = true
            completionRating = calculateRating()
            recordCompletion()
            return
        }

        // 检查是否超过最大步数
        if gameMoves.count >= puzzle.maxMoves {
            gameState = .failed
            return
        }

        // AI 防守方自动应将
        triggerDefenderMove()
    }

    // MARK: - 防守方 AI

    private func triggerDefenderMove() {
        isThinking = true
        let snapshot = board.snapshot()
        let difficulty = defenderDifficulty

        let engine = self.aiEngine
        Task.detached {
            let move = engine.bestMove(for: snapshot, difficulty: difficulty)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let move = move {
                    let mainPiece = self.board.pieces.first { $0.id == move.piece.id }
                    if let mainPiece = mainPiece {
                        let captured = self.board.piece(at: move.to)
                        let aiMove = Move(piece: mainPiece, from: mainPiece.position, to: move.to, captured: captured)
                        let notation = NotationGenerator.notation(for: aiMove, on: self.board)

                        self.board.execute(aiMove)

                        let isCheck = MoveValidator.isInCheck(self.playerSide, on: self.board)
                        let turnNumber = (self.gameMoves.count / 2) + 1

                        let gameMove = GameMove(
                            id: UUID(), piece: mainPiece, from: aiMove.from, to: aiMove.to,
                            captured: captured, turnNumber: turnNumber, notation: notation,
                            timestamp: Date(), isCheck: isCheck, isCheckmate: false
                        )
                        self.gameMoves.append(gameMove)

                        if let captured = captured {
                            SoundEngine.shared.playCapture()
                        } else {
                            SoundEngine.shared.playMove()
                        }

                        // 检查 AI 是否将死了玩家
                        if MoveValidator.isCheckmate(self.playerSide, on: self.board) {
                            self.gameState = .failed
                            self.gameMoves[self.gameMoves.count - 1].isCheckmate = true
                        }
                    }
                }
                self.isThinking = false

                // 再次检查步数
                if self.gameState == .playing && self.gameMoves.count >= self.puzzle.maxMoves {
                    self.gameState = .failed
                }
            }
        }
    }

    // MARK: - 悔棋

    func undoMove() {
        guard !isThinking, gameState == .playing || gameState == .showingHint else { return }
        // 撤销一对（AI + 玩家）
        if board.moveHistory.count >= 2 {
            board.undoLastMove()
            board.undoLastMove()
            if gameMoves.count >= 2 {
                gameMoves.removeLast(2)
            }
        } else if board.moveHistory.count >= 1 {
            board.undoLastMove()
            if !gameMoves.isEmpty { gameMoves.removeLast() }
        }
        currentHint = nil
        gameState = .playing
    }

    // MARK: - 提示

    func showHint() {
        guard hintIndex < puzzle.hints?.count ?? 0 else {
            currentHint = "暂无更多提示"
            gameState = .showingHint
            return
        }
        currentHint = puzzle.hints?[hintIndex] ?? "继续进攻"
        hintIndex += 1
        gameState = .showingHint
    }

    func dismissHint() {
        currentHint = nil
        gameState = .playing
    }

    // MARK: - 解法验证 & 星级评分

    /// 对比玩家步数与 solution 长度，给出 1-3 星
    private func calculateRating() -> Int {
        guard !puzzle.solution.isEmpty else { return 3 }
        let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
        let solutionMoveCount = puzzle.solution.count
        // 与最优解法对比
        if playerMoveCount <= solutionMoveCount {
            return 3  // 完美
        } else if playerMoveCount <= solutionMoveCount + 2 {
            return 2  // 不错
        } else {
            return 1  // 过关
        }
    }

    /// ICCS 坐标：列 a-i (col 0-8)，行 0-9（0=红方底线 row=9）
    private static func iccsString(from: Position, to: Position) -> String {
        let files = "abcdefghi"
        let fromStr = "\(files[files.index(files.startIndex, offsetBy: from.col)])\(9 - from.row)"
        let toStr = "\(files[files.index(files.startIndex, offsetBy: to.col)])\(9 - to.row)"
        return "\(fromStr)\(toStr)"
    }

    /// 验证指定步是否匹配 solution 推荐走法
    func isRecommendedMove(at moveIndex: Int) -> Bool {
        guard moveIndex < puzzle.solution.count else { return true }  // 超出 solution 长度，不再约束
        // 只筛选玩家走法
        let playerMoves = gameMoves.filter { $0.piece.side == playerSide }
        guard moveIndex < playerMoves.count else { return false }
        let move = playerMoves[moveIndex]
        let iccs = Self.iccsString(from: move.from, to: move.to)
        return puzzle.solution[moveIndex] == iccs
    }

    // MARK: - 进度记录

    private func recordCompletion() {
        let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
        let progress = PuzzleProgress(
            puzzleId: puzzle.id,
            isCompleted: true,
            bestMoves: playerMoveCount,
            completedAt: Date()
        )
        PuzzleStore.shared.recordProgress(progress)
    }
}
