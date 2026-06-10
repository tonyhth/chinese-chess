import Foundation

@Observable
class PuzzleViewModel {
    /// 编译时平台标记
    private static let _isIOS: Bool = {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }()

    let puzzle: Puzzle
    var board: Board
    let playerSide: Side

    var gameMoves: [GameMove] = []
    var gameState: PuzzleState = .playing
    var hintIndex: Int = 0
    var currentHint: String?
    var isThinking: Bool = false
    var completionRating: Int = 0
    var solutionHint: String?  // 实时提示：有更优走法时显示
    var isInCheck: Bool = false
    var selectedPosition: Position?
    var legalMovesForSelected: [Position] = []

    /// 提示高亮的起止位置（from, to），供 ChessBoardView 蓝色高亮显示
    var hintMove: (from: Position, to: Position)?

    private let aiEngine = AIEngine()
    private var puzzleVersion: Int = 0
    private var cachedSolutionRecord: GameRecord?

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

    // MARK: - 统一点击处理（由 ChessBoardView 调用）

    func handleSquareTap(at pos: Position) {
        guard gameState == .playing, !isThinking else { return }

        if let selected = selectedPosition, legalMovesForSelected.contains(pos) {
            movePiece(from: selected, to: pos)
            selectedPosition = nil
            legalMovesForSelected = []
            return
        }

        let legalMoves = selectPiece(at: pos)
        if !legalMoves.isEmpty {
            selectedPosition = pos
            legalMovesForSelected = legalMoves
        } else {
            selectedPosition = nil
            legalMovesForSelected = []
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

        // 更新将军状态
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)

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

        // Phase 3.5: sequence 局走完推荐步数即通关
        if puzzle.solutionType == "sequence" && !puzzle.solution.isEmpty {
            let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
            let solutionPlayerMoveCount = playerSolutionMoves.count
            if playerMoveCount >= solutionPlayerMoveCount {
                gameState = .success
                completionRating = calculateRating()
                recordCompletion()
                return
            }
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
        let currentVersion = puzzleVersion

        let engine = self.aiEngine
        Task.detached {
            let move = engine.bestMove(for: snapshot, difficulty: difficulty, isIOS: Self._isIOS)
            await MainActor.run { [weak self] in
                guard let self, self.puzzleVersion == currentVersion else { return }
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

                        // 更新将军状态
                        self.isInCheck = MoveValidator.isInCheck(self.board.currentTurn, on: self.board)

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
        solutionHint = nil
        hintMove = nil
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
        gameState = .playing
    }

    // MARK: - 提示

    func showHint() {
        // Phase 3.5: hint 类型显示文字提示（无 solution 的纯提示局）
        if puzzle.solutionType == "hint" {
            if let hints = puzzle.hints, !hints.isEmpty {
                currentHint = hints[min(hintIndex, hints.count - 1)]
                hintIndex += 1
            } else {
                currentHint = "暂无更多提示"
            }
            gameState = .showingHint
            return
        }

        // checkmate/sequence：优先显示 hints 文字提示，用完后再显示 step-by-step
        if let hints = puzzle.hints, !hints.isEmpty, hintIndex < hints.count {
            currentHint = hints[hintIndex]
            hintIndex += 1
            gameState = .showingHint
            return
        }

        // hints 用完或不存在：显示 step-by-step solution
        if puzzle.solution.isEmpty {
            currentHint = "暂无更多提示"
            gameState = .showingHint
            return
        }
        if hintIndex < puzzle.solution.count + (puzzle.hints?.count ?? 0) {
            let solIdx = hintIndex - (puzzle.hints?.count ?? 0)
            if solIdx >= 0 && solIdx < puzzle.solution.count {
                let iccs = puzzle.solution[solIdx]
                currentHint = "提示：第 \(solIdx + 1) 步 → \(iccs)"
                // 设置提示高亮位置
                if let move = ICCSParser.parse(iccs, on: board) {
                    hintMove = (from: move.from, to: move.to)
                } else {
                    hintMove = nil
                }
            } else {
                currentHint = "暂无更多提示"
                hintMove = nil
            }
            hintIndex += 1
        } else {
            currentHint = "暂无更多提示"
            hintMove = nil
        }
        gameState = .showingHint
    }

    func dismissHint() {
        currentHint = nil
        hintMove = nil
        gameState = .playing
    }

    // MARK: - 解法验证 & 星级评分

    /// 对比玩家步数与 solution 长度，给出 1-3 星
    private func calculateRating() -> Int {
        guard !puzzle.solution.isEmpty else { return 3 }

        if puzzle.solutionType == "sequence" {
            // sequence 局：按是否每步都走了推荐走法评星
            // playerSolutionMoves 已包含所有玩家方步（从 solution 中提取）
            let playerMoves = gameMoves.filter { $0.piece.side == playerSide }
            var matchCount = 0
            let solutionPlayerMoveCount = playerSolutionMoves.count
            for i in 0..<min(playerMoves.count, solutionPlayerMoveCount) {
                let iccs = ICCSParser.iccsString(from: playerMoves[i].from, to: playerMoves[i].to)
                if playerSolutionMoves[i] == iccs { matchCount += 1 }
            }
            let deviations = solutionPlayerMoveCount - matchCount
            if deviations == 0 { return 3 }      // 完美破解
            if deviations <= 2 { return 2 }       // 破解
            return 1                               // 过关
        }

        // checkmate 局：保持现有逻辑（按步数评星）
        // checkmate 局的 solution 通常只有红方步
        let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
        let solutionMoveCount = puzzle.solution.count
        if playerMoveCount <= solutionMoveCount {
            return 3  // 完美
        } else if playerMoveCount <= solutionMoveCount + 2 {
            return 2  // 不错
        } else {
            return 1  // 过关
        }
    }

    /// 从 solution 中提取玩家方走法序列
    /// 通过查看棋子颜色判断 side，不依赖 board.currentTurn
    /// 部分局有连续同方走法（如 RRB），所以不能用 turn 判断
    private var _cachedPlayerSolutionMoves: [String]?

    private var playerSolutionMoves: [String] {
        if let cached = _cachedPlayerSolutionMoves { return cached }
        guard !puzzle.solution.isEmpty else {
            _cachedPlayerSolutionMoves = []
            return []
        }
        var board = Board(fen: puzzle.initialFEN)
        var result: [String] = []
        for iccs in puzzle.solution {
            // 统一使用 ICCSParser 安全解析
            if let move = ICCSParser.parse(iccs, on: board) {
                if move.piece.side == playerSide {
                    result.append(iccs)
                }
                board.execute(move)
                continue
            }

            // Fallback: ICCSParser 失败时（如连续同方走法 turn 不匹配），手动安全解析
            guard iccs.count == 4 else { break }
            let chars = Array(iccs)
            guard let fromCol = ICCSParser.colFromChar(chars[0]),
                  let fromRowDigit = chars[1].wholeNumberValue, fromRowDigit >= 0, fromRowDigit <= 9,
                  let toCol = ICCSParser.colFromChar(chars[2]),
                  let toRowDigit = chars[3].wholeNumberValue, toRowDigit >= 0, toRowDigit <= 9
            else { break }

            let from = Position(row: 9 - fromRowDigit, col: fromCol)
            let to = Position(row: 9 - toRowDigit, col: toCol)

            if let piece = board.piece(at: from) {
                if piece.side == playerSide {
                    result.append(iccs)
                }
                let captured = board.piece(at: to)
                let move = Move(piece: piece, from: from, to: to, captured: captured)
                board.execute(move)
                // execute 多 toggle 了一次 turn，补偿回来
                board.toggleTurn()
            } else {
                break
            }
        }
        _cachedPlayerSolutionMoves = result
        return result
    }

    /// 验证指定步是否匹配 solution 推荐走法
    /// moveIndex: 玩家走法的序号（0-based，仅玩家方走法）
    func isRecommendedMove(at moveIndex: Int) -> Bool {
        guard moveIndex < playerSolutionMoves.count else { return true }  // 超出 solution 长度，不再约束
        // 只筛选玩家走法
        let playerMoves = gameMoves.filter { $0.piece.side == playerSide }
        guard moveIndex < playerMoves.count else { return false }
        let move = playerMoves[moveIndex]
        let iccs = ICCSParser.iccsString(from: move.from, to: move.to)
        return playerSolutionMoves[moveIndex] == iccs
    }

    // MARK: - 进度记录

    private func recordCompletion() {
        let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
        let progress = PuzzleProgress(
            puzzleId: puzzle.id,
            isCompleted: true,
            bestMoves: playerMoveCount,
            completedAt: Date(),
            bestRating: completionRating
        )
        PuzzleStore.shared.recordProgress(progress)
    }

    // MARK: - 重置（puzzleVersion 防护）

    func resetPuzzle() {
        puzzleVersion += 1
        // 直接重建初始棋盘，避免 while-undo 状态累积风险和 O(n×pieces) 性能问题
        board = Board(fen: puzzle.initialFEN)
        isInCheck = false
        selectedPosition = nil
        legalMovesForSelected = []
        gameMoves = []
        gameState = .playing
        hintIndex = 0
        currentHint = nil
        solutionHint = nil
        hintMove = nil
        completionRating = 0
    }

    // MARK: - 完美解法回放

    /// 构建标准解法的 GameRecord，用于回放
    func buildSolutionRecord() -> GameRecord? {
        if let cached = cachedSolutionRecord { return cached }
        guard !puzzle.solution.isEmpty else { return nil }
        var board = Board(fen: puzzle.initialFEN)
        var moves: [GameMove] = []
        var turnNumber = 1
        for (i, iccs) in puzzle.solution.enumerated() {
            guard let move = ICCSParser.parse(iccs, on: board) else {
                return nil  // 解法有非法走法
            }
            let notation = NotationGenerator.notation(for: move, on: board)
            let captured = board.piece(at: move.to)
            let side = board.currentTurn
            let opponent: Side = (side == .red) ? .black : .red
            let isCheck = MoveValidator.isInCheck(opponent, on: board)
            let isCheckmate = MoveValidator.isCheckmate(opponent, on: board)
            board.execute(move)
            let gameMove = GameMove(
                id: UUID(), piece: move.piece, from: move.from, to: move.to,
                captured: captured, turnNumber: i / 2 + 1, notation: notation,
                timestamp: Date(), isCheck: isCheck, isCheckmate: isCheckmate
            )
            moves.append(gameMove)
            if isCheckmate { break }
        }
        let record = GameRecord(
            id: UUID(),
            title: "完美解法: \(puzzle.name)",
            date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: defenderDifficulty),
            difficulty: defenderDifficulty,
            result: .redWon,
            totalMoves: moves.count,
            moves: moves,
            initialFEN: puzzle.initialFEN
        )
        cachedSolutionRecord = record
        return record
    }
}
