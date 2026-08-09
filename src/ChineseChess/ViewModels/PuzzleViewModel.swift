import Foundation

// MARK: - Phase 0: 残局游戏模式

/// 残局游戏模式
enum PuzzlePlayMode {
    case guided    // 按步骤引导
    case freePlay  // 自由对弈 vs AI
}

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
    var gameState: PuzzleState = .playing {
        didSet {
            if gameState == .success {
                recordCompletion()
            }
        }
    }
    var hintIndex: Int = 0
    var currentHint: String?
    var isThinking: Bool = false
    var completionRating: Int = 0
    var solutionHint: String?  // 实时提示:有更优走法时显示

    /// 当前提示会话内的偏移量(每次走棋/悔棋重置为 0)
    private var hintOffsetInSession: Int = 0
    var isInCheck: Bool = false
    var selectedPosition: Position?
    var legalMovesForSelected: [Position] = []

    /// 提示高亮的起止位置(from, to),供 ChessBoardView 蓝色高亮显示
    var hintMove: (from: Position, to: Position)?

    /// v4.0 Phase 3 #7: 残局三级渐进提示
    /// 0=无提示, 1=方向提示文字, 2=关键棋子提示文字, 3=完整走法+高亮
    var hintLevel: Int = 0

    /// solution 步序指针(独立于 gameMoves.count)
    /// 每次走对 +1,undo -1
    var solutionStepIndex: Int = 0

    /// 走错回退锁(独立于 isThinking,避免 "AI 思考中" 文案混淆)
    var isProcessingWrongMove: Bool = false

    // MARK: - Phase 0: 模式切换

    /// 当前游戏模式（引导式/自由对弈）
    var playMode: PuzzlePlayMode

    /// 切换模式时保存的 solutionStepIndex（从 freePlay 切回 guided 时恢复）
    private var savedSolutionStepIndex: Int = 0

    // #8: TT 内存优化 — 使用 EngineRouter 共享实例
    // private let aiEngine = AIEngine() — 已删除，改为从 EngineRouter 获取
    private var puzzleVersion: Int = 0
    private var cachedSolutionRecord: GameRecord?

    /// 和局检测:局面历史(用于长将检测)
    private var positionHistory: [String] = []
    /// 和局检测:无吃子/无兵移动回合数
    private var halfmoveClock: Int = 0
    /// 是否已显示超步警告
    private var hasShownMaxMovesWarning: Bool = false

    enum PuzzleState: Equatable {
        case playing
        case success
        case failed
        case draw
        case showingHint
        case maxMovesWarning  // 超过建议步数警告(自由对弈模式)
        case wrongMove       // guided 模式走错(短暂状态,0.8s 自动回退后回到 playing)
    }

    /// 是否为每日挑战模式（由 DailyChallengeView 传入）
    let isDailyChallenge: Bool

    init(puzzle: Puzzle, isDailyChallenge: Bool = false) {
        self.puzzle = puzzle
        self.playerSide = puzzle.side
        self.board = Board(fen: puzzle.initialFEN)
        self.playMode = (puzzle.effectiveMode == .guided) ? .guided : .freePlay
        self.isDailyChallenge = isDailyChallenge
        self.positionHistory = [boardFingerprint()]
    }

    // MARK: - 防守方 AI 难度映射

    private var defenderDifficulty: AIDifficulty {
        // 星级→AI搜索深度映射（v6.0: 新枚举名）
        switch puzzle.stars {
        case 1: return .novice        // depth 2
        case 2: return .beginner      // depth 3
        case 3: return .amateurLow    // depth 4
        case 4: return .amateurMid    // depth 5
        case 5: return .amateurHigh   // depth 6
        default: return .beginner
        }
    }

    // MARK: - 引导模式判定

    /// solution 数据异常降级标记
    private var solutionDegraded: Bool = false

    private var isGuidedMode: Bool {
        playMode == .guided && !puzzle.solution.isEmpty && !solutionDegraded
    }

    // MARK: - 统一点击处理(由 ChessBoardView 调用)

    func handleSquareTap(at pos: Position) {
        guard gameState == .playing, !isThinking, !isProcessingWrongMove else { return }

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
        guard gameState == .playing, !isThinking, !isProcessingWrongMove else { return [] }
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
            isCheck: isCheck, isCheckmate: false, halfmoveClock: 0
        )
        gameMoves.append(gameMove)

        // 更新将军状态
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)

        if let captured = captured {
            SoundEngine.shared.playCapture()
        } else {
            SoundEngine.shared.playMove()
        }

        // 更新局面历史(和局检测)
        updatePositionHistory(captured: captured, movedPiece: piece)

        // === guided 模式:走对/走错判定 ===
        if isGuidedMode {
            let playerMoveIndex = gameMoves.filter { $0.piece.side == playerSide }.count - 1
            let expectedICCS = currentPlayerSolutionMove(playerMoveIndex)

            if let expected = expectedICCS, ICCSParser.iccsString(from: from, to: to) == expected {
                // ✅ 走对了
                solutionHint = nil
                handleCorrectMove(playerMoveIndex)
            } else if let expected = expectedICCS {
                // ❌ 走错了
                handleWrongMove(expectedICCS: expected)
                return  // 不继续触发 AI
            } else {
                // 超出 solution 范围,按 freePlay 处理
                triggerDefenderMove()
                return
            }
            return
        }

        // === freePlay 模式:保持现有逻辑 ===

        hintOffsetInSession = 0
        hintLevel = 0

        // 实时解法提示:检查是否走了推荐走法
        let playerMoveIndex = gameMoves.filter { $0.piece.side == playerSide }.count - 1
        if !isRecommendedMove(at: playerMoveIndex) {
            solutionHint = L10n.shared.t("puzzle.betterMoveAvailable")
        } else {
            solutionHint = nil
        }

        // 检查是否将死对方
        let defenderSide: Side = (playerSide == .red) ? .black : .red
        if MoveValidator.isCheckmate(defenderSide, on: board) {
            gameState = .success
            gameMoves[gameMoves.count - 1].isCheckmate = true
            completionRating = calculateRating()
            return
        }

        // Phase 3.5: sequence 局走完推荐步数即通关
        if puzzle.solutionType == "sequence" && !puzzle.solution.isEmpty {
            let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
            let solutionPlayerMoveCount = playerSolutionMoves.count
            if playerMoveCount >= solutionPlayerMoveCount {
                gameState = .success
                completionRating = calculateRating()
                return
            }
        }

        // FINAL-006 子集 B: draw 局玩家走对 solution[0] → 守和成功
        if puzzle.solutionType == "draw" && !puzzle.solution.isEmpty {
            let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
            if playerMoveCount == 1 {
                let lastMove = gameMoves.last
                let expectedFirst = puzzle.solution[0]
                if let last = lastMove {
                    let actualICCS = ICCSParser.iccsString(from: last.from, to: last.to)
                    if actualICCS == expectedFirst {
                        gameState = .success
                        completionRating = calculateRating()
                        return
                    }
                }
            }
        }

        // 检查是否超过最大步数
        if gameMoves.count >= puzzle.effectiveMaxMoves {
            if playMode == .freePlay {
                // 自由对弈模式:超步只警告,不失败
                if !hasShownMaxMovesWarning {
                    hasShownMaxMovesWarning = true
                    gameState = .maxMovesWarning
                }
            } else {
                gameState = .failed
                return
            }
        }

        // 和局检测(仅自由对弈模式)
        if playMode == .freePlay && checkDraw() {
            gameState = .draw
            return
        }

        // AI 防守方自动应将
        triggerDefenderMove()
    }

    // MARK: - Guided 模式:走对/走错处理

    /// 获取当前玩家应走的 solution 步
    private func currentPlayerSolutionMove(_ moveIndex: Int) -> String? {
        guard moveIndex < playerSolutionMoves.count else { return nil }
        return playerSolutionMoves[moveIndex]
    }

    /// 走对后的处理
    private func handleCorrectMove(_ moveIndex: Int) {
        // 推进 solution 指针（玩家步也推进）
        solutionStepIndex += 1
        hintOffsetInSession = 0
        hintLevel = 0

        // 检查是否将死对方(提前通关)
        let defenderSide: Side = (playerSide == .red) ? .black : .red
        if MoveValidator.isCheckmate(defenderSide, on: board) {
            gameState = .success
            gameMoves[gameMoves.count - 1].isCheckmate = true
            completionRating = calculateRating()
            return
        }

        // 检查是否走完 solution 中所有玩家方步数
        let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
        let solutionPlayerMoveCount = playerSolutionMoves.count
        if playerMoveCount >= solutionPlayerMoveCount {
            gameState = .success
            completionRating = calculateRating()
            return
        }

        // AI 防守方按 solution 应对
        triggerSolutionDefenderMove()
    }

    /// AI 防守方按 solution 走棋(guided 模式核心改造)
    private func triggerSolutionDefenderMove() {
        guard isGuidedMode else {
            triggerDefenderMove()  // freePlay 模式:保持搜索引擎
            return
        }

        isThinking = true
        let currentVersion = puzzleVersion

        // 用 solutionStepIndex 取 AI 步
        guard solutionStepIndex < puzzle.solution.count else {
            isThinking = false
            return
        }

        let iccs = puzzle.solution[solutionStepIndex]

        Task.detached {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s 模拟思考

            await MainActor.run { [weak self] in
                guard let self, self.puzzleVersion == currentVersion else { return }

                guard let move = ICCSParser.parse(iccs, on: self.board) else {
                    // solution 数据异常:降级为 freePlay 模式
                    self.solutionDegraded = true
                    self.solutionHint = L10n.shared.t("puzzle.solutionDegraded")
                    self.isThinking = false
                    self.triggerDefenderMove()
                    return
                }

                let captured = self.board.piece(at: move.to)
                let notation = NotationGenerator.notation(for: move, on: self.board)
                self.board.execute(move)

                let isCheck = MoveValidator.isInCheck(self.playerSide, on: self.board)
                let turnNumber = (self.gameMoves.count / 2) + 1

                let gameMove = GameMove(
                    id: UUID(), piece: move.piece, from: move.from, to: move.to,
                    captured: captured, turnNumber: turnNumber, notation: notation,
                    timestamp: Date(), isCheck: isCheck, isCheckmate: false, halfmoveClock: 0
                )
                self.gameMoves.append(gameMove)

                // solution 步序指针 +1
                self.solutionStepIndex += 1

                self.isInCheck = MoveValidator.isInCheck(self.board.currentTurn, on: self.board)

                if let captured = captured {
                    SoundEngine.shared.playCapture()
                } else {
                    SoundEngine.shared.playMove()
                }

                if MoveValidator.isCheckmate(self.playerSide, on: self.board) {
                    self.gameMoves[self.gameMoves.count - 1].isCheckmate = true
                    self.gameState = .failed
                }

                self.isThinking = false
            }
        }
    }

    /// 走错的处理:高亮正确走法 + 0.8s 自动回退
    private func handleWrongMove(expectedICCS: String) {
        // 高亮正确走法（用独立推演，不依赖走错后的 board 状态）
        if let info = getSolutionInfo(at: solutionStepIndex) {
            hintMove = (from: info.from, to: info.to)
        }

        // 文字反馈(1-based:"第1步走法不对" 语义正确)
        let stepIndex = gameMoves.filter { $0.piece.side == playerSide }.count
        // 用独立推演获取中文棋谱(不依赖走错后的 board 状态)
        if let info = getSolutionInfo(at: solutionStepIndex) {
            solutionHint = String(format: L10n.shared.t("puzzle.wrongMove"),
                                  stepIndex, info.notation)
        } else {
            solutionHint = String(format: L10n.shared.t("puzzle.wrongMove"),
                                  stepIndex, expectedICCS)
        }

        // 播放错误音效(复用 undo 音效)
        SoundEngine.shared.playUndo()

        // 锁定棋盘(独立状态,不触发 "AI 思考中" 文案)
        isProcessingWrongMove = true
        gameState = .wrongMove

        // 0.8s 后自动回退
        let currentVersion = puzzleVersion
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { [weak self] in
                guard let self, self.puzzleVersion == currentVersion else { return }
                guard self.gameState == .wrongMove else { return }

                self.board.undoLastMove()
                if !self.gameMoves.isEmpty { self.gameMoves.removeLast() }
                self.solutionHint = nil
                self.hintMove = nil
                self.isInCheck = MoveValidator.isInCheck(self.board.currentTurn, on: self.board)
                self.isProcessingWrongMove = false
                self.hintOffsetInSession = 0
                self.hintLevel = 0
                self.gameState = .playing
            }
        }
    }

    // MARK: - 防守方 AI (freePlay)

    private func triggerDefenderMove() {
        isThinking = true
        let snapshot = board.snapshot()
        let difficulty = defenderDifficulty
        let currentVersion = puzzleVersion

        // 0.2: freePlay 模式优先用 EngineRouter（可能是 Pikafish）
        let useEngineRouter = playMode == .freePlay
        // #8: nativeEngine 改为在 Task 内获取，避免 MainActor 同步调用问题
        let boardSnapshot = board.snapshot()
        let currentFEN = FENParser.generate(board: board)
        Task.detached {
            // #8: 从 EngineRouter 获取共享实例，避免独立 TT
            let nativeEngine = await MainActor.run { EngineRouter.shared.getNativeEngine() }
            var move: Move?
            if useEngineRouter {
                let engine = await MainActor.run { EngineRouter.shared.activeEngine() }
                let uciMove = await engine.bestMove(
                    fen: currentFEN,
                    moveHistory: [],
                    difficulty: difficulty,
                    timeLimitMs: 0
                )
                if let uci = uciMove {
                    move = await MainActor.run {
                        UCIMoveConverter.move(from: uci, on: boardSnapshot)
                    }
                }
                // Pikafish fallback 到自研引擎
                if move == nil {
                    move = await nativeEngine.bestMove(for: snapshot, difficulty: difficulty, isIOS: Self._isIOS)
                }
            } else {
                move = await nativeEngine.bestMove(for: snapshot, difficulty: difficulty, isIOS: Self._isIOS)
            }
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
                            timestamp: Date(), isCheck: isCheck, isCheckmate: false, halfmoveClock: 0
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
                            self.isThinking = false
                            return
                        }

                        // 更新局面历史(和局检测)
                        self.updatePositionHistory(captured: captured, movedPiece: mainPiece)

                        // 和局检测(自由对弈模式)
                        if self.playMode == .freePlay && self.checkDraw() {
                            self.gameState = .draw
                            self.isThinking = false
                            return
                        }
                    }
                }
                self.isThinking = false

                // 再次检查步数
                if self.gameState == .playing && self.gameMoves.count >= self.puzzle.effectiveMaxMoves {
                    if self.playMode == .freePlay {
                        if !self.hasShownMaxMovesWarning {
                            self.hasShownMaxMovesWarning = true
                            self.gameState = .maxMovesWarning
                        }
                    } else {
                        self.gameState = .failed
                    }
                }
            }
        }
    }

    // MARK: - 和局检测辅助方法

    /// 局面指纹(棋子位置+轮次),用于长将检测
    private func boardFingerprint() -> String {
        var fp = board.currentTurn == .red ? "w" : "b"
        for row in 0..<10 {
            for col in 0..<9 {
                if let piece = board.piece(at: Position(row: row, col: col)) {
                    fp += "\(row)\(col)\(piece.kind == .general ? "K" : piece.kind == .chariot ? "R" : "X")\(piece.side == .red ? "r" : "b")"
                }
            }
        }
        return fp
    }

    /// 检查是否和局
    private func checkDraw() -> Bool {
        let currentFp = boardFingerprint()
        let count = positionHistory.filter { $0 == currentFp }.count
        if count >= 3 { return true }
        // 50 回合规则（100 半回合无吃子/无兵移动判和）
        if halfmoveClock >= 100 { return true }
        let offensiveKinds: Set<PieceKind> = [.chariot, .horse, .cannon, .soldier]
        let hasOffensive = board.pieces.contains { offensiveKinds.contains($0.kind) }
        if !hasOffensive { return true }
        return false
    }

    /// 更新局面历史
    private func updatePositionHistory(captured: Piece?, movedPiece: Piece) {
        let isPawn = movedPiece.kind == .soldier
        if captured != nil || isPawn {
            halfmoveClock = 0
            positionHistory = [boardFingerprint()]
        } else {
            halfmoveClock += 1
            positionHistory.append(boardFingerprint())
        }
    }

    func dismissMaxMovesWarning() {
        gameState = .playing
    }

    // MARK: - Phase 0: 模式切换

    /// 切换到自由对弈模式
    func switchToFreePlay() {
        guard playMode == .guided else { return }
        savedSolutionStepIndex = solutionStepIndex
        playMode = .freePlay
    }

    /// 切换回引导式模式（恢复到切换前的 solutionStepIndex）
    func switchToGuided() {
        guard playMode == .freePlay else { return }
        playMode = .guided
        solutionStepIndex = savedSolutionStepIndex
    }

    /// 是否可以切换模式（freePlay 残局不能切到 guided）
    var canSwitchToGuided: Bool {
        !puzzle.solution.isEmpty
    }

    /// 是否可以切换到 freePlay
    var canSwitchToFreePlay: Bool {
        playMode == .guided
    }

    // MARK: - 悔棋

    func undoMove() {
        guard !isProcessingWrongMove else { return }
        guard !isThinking, gameState == .playing || gameState == .showingHint else { return }

        if isGuidedMode {
            // guided 模式:撤销一对步(玩家 + AI)
            if board.moveHistory.count >= 2 {
                board.undoLastMove()
                board.undoLastMove()
                if gameMoves.count >= 2 {
                    gameMoves.removeLast(2)
                }
                // solution 指针回退 2(玩家步 + AI 步)
                solutionStepIndex = max(0, solutionStepIndex - 2)
            } else if board.moveHistory.count >= 1 {
                board.undoLastMove()
                if !gameMoves.isEmpty { gameMoves.removeLast() }
                solutionStepIndex = max(0, solutionStepIndex - 1)
            }
        } else {
            // freePlay 模式:保持现有 undo 逻辑
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
        }

        currentHint = nil
        solutionHint = nil
        hintMove = nil
        hintOffsetInSession = 0
        hintLevel = 0
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
        gameState = .playing
    }

    // MARK: - 提示

    func showHint() {
        // Phase 3.5: hint 类型(无 solution 的纯提示局)保持原有行为
        if puzzle.solutionType == "hint" {
            if let hints = puzzle.hints, !hints.isEmpty {
                currentHint = hints[min(hintIndex, hints.count - 1)]
                hintIndex += 1
            } else {
                currentHint = L10n.shared.t("puzzle.noMoreHints")
            }
            gameState = .showingHint
            return
        }

        // v4.0 Phase 3 #7: 三级渐进提示
        // hintLevel: 0→1→2→3（到 3 不再增加）
        if hintLevel < 3 { hintLevel += 1 }

        switch hintLevel {
        case 1:
            // Level 1: 方向提示文字，不设 hintMove
            currentHint = generateDirectionHint()
            hintMove = nil
            gameState = .showingHint
        case 2:
            // Level 2: 关键棋子提示文字，不设 hintMove
            currentHint = generatePieceHint()
            hintMove = nil
            gameState = .showingHint
        default:
            // Level 3: 完整走法 + 高亮（原有 step-by-step 逻辑）
            showFullMoveHint()
        }
    }

    // MARK: - v4.0 Phase 3 #7: 渐进提示生成

    /// Level 1: 生成方向性提示文字
    /// 优先使用 puzzle.hints[0]，无则从当前 solution 步自动生成
    private func generateDirectionHint() -> String {
        // 优先使用 puzzle.hints 第一条
        if let hints = puzzle.hints, hints.count >= 1 {
            return hints[0]
        }

        // 从当前 solution 步自动生成
        guard let currentMove = getCurrentSolutionMove() else {
            return L10n.shared.t("puzzle.noMoreHints")
        }

        // 判断是否将军：推演到当前步执行后检查对方是否被将军
        let opponent: Side = (playerSide == .red) ? .black : .red
        // 推演到当前步之前的局面
        var pushBoard = Board(fen: puzzle.initialFEN)
        let curStep = currentSolutionStep()
        for i in 0..<curStep {
            if let m = ICCSParser.parse(puzzle.solution[i], on: pushBoard) {
                pushBoard.execute(m)
            }
        }
        pushBoard.execute(currentMove)
        let isCheckMove = MoveValidator.isInCheck(opponent, on: pushBoard)

        if isCheckMove {
            return L10n.shared.t("puzzle.hint.direction.check")
        }

        // 判断方向：以棋盘列分左中右
        let toCol = currentMove.to.col
        let fromCol = currentMove.from.col
        // 判断是否向前推进
        let isAdvancing = (playerSide == .red) ? currentMove.to.row < currentMove.from.row : currentMove.to.row > currentMove.from.row
        if abs(toCol - fromCol) <= 1 && isAdvancing {
            return L10n.shared.t("puzzle.hint.direction.advance")
        }
        if toCol <= 2 {
            return L10n.shared.t("puzzle.hint.direction.leftFlank")
        } else if toCol >= 6 {
            return L10n.shared.t("puzzle.hint.direction.rightFlank")
        } else {
            return L10n.shared.t("puzzle.hint.direction.center")
        }
    }

    /// Level 2: 生成关键棋子提示文字
    /// 优先使用 puzzle.hints[1]，无则从当前 solution 步提取棋子类型
    /// 注：三级渐进提示设计只消费 hints 前 2 条，第 3 条+ 不展示
    private func generatePieceHint() -> String {
        // 优先使用 puzzle.hints 第二条
        if let hints = puzzle.hints, hints.count >= 2 {
            return hints[1]
        }

        // 从当前 solution 步提取棋子类型
        guard let currentMove = getCurrentSolutionMove() else {
            return L10n.shared.t("puzzle.noMoreHints")
        }

        let kind = currentMove.piece.kind
        let key: String
        switch kind {
        case .chariot:  key = "puzzle.hint.piece.chariot"
        case .cannon:   key = "puzzle.hint.piece.cannon"
        case .horse:    key = "puzzle.hint.piece.horse"
        case .soldier:  key = "puzzle.hint.piece.soldier"
        case .general:  key = "puzzle.hint.piece.general"
        case .advisor:  key = "puzzle.hint.piece.advisor"
        case .elephant: key = "puzzle.hint.piece.elephant"
        }
        return L10n.shared.t(key)
    }

    /// Level 3: 完整走法 + 高亮（原有 step-by-step 逻辑）
    private func showFullMoveHint() {
        if puzzle.solution.isEmpty {
            currentHint = L10n.shared.t("puzzle.noMoreHints")
            hintMove = nil
            gameState = .showingHint
            return
        }

        let baseStep = currentSolutionStep()
        let solIdx = baseStep + hintOffsetInSession

        if solIdx < puzzle.solution.count {
            if let info = getSolutionInfo(at: solIdx) {
                hintMove = (from: info.from, to: info.to)
                currentHint = String(format: L10n.shared.t("puzzle.hintStep"), solIdx + 1, info.notation)
            } else {
                hintMove = nil
                currentHint = L10n.shared.t("puzzle.noMoreHints")
            }
            hintOffsetInSession += 1
        } else {
            currentHint = L10n.shared.t("puzzle.noMoreHints")
            hintMove = nil
        }
        gameState = .showingHint
    }

    /// 获取当前 solution 步的 Move 信息（从初始局面推演到当前步）
    private func getCurrentSolutionMove() -> Move? {
        let step = currentSolutionStep()
        guard step < puzzle.solution.count else { return nil }
        var tempBoard = Board(fen: puzzle.initialFEN)
        for (i, iccs) in puzzle.solution.enumerated() {
            guard let move = ICCSParser.parse(iccs, on: tempBoard) else { return nil }
            if i == step {
                return move
            }
            tempBoard.execute(move)
        }
        return nil
    }

    // MARK: - Solution 推演辅助

    /// 当前游戏进度对应的 solution 步序号
    private func currentSolutionStep() -> Int {
        if isGuidedMode {
            return solutionStepIndex
        }
        return min(gameMoves.count, puzzle.solution.count)
    }

    /// 从初始局面推演获取指定步的完整信息
    /// 返回:棋子起止位置 + 中文棋谱
    /// 不依赖当前 board 状态,避免 parse 失败
    private func getSolutionInfo(at step: Int) -> (from: Position, to: Position, notation: String)? {
        var tempBoard = Board(fen: puzzle.initialFEN)
        for (i, iccs) in puzzle.solution.enumerated() {
            guard let move = ICCSParser.parse(iccs, on: tempBoard) else {
                #if DEBUG
                AppLog.puzzleVM.warning("getSolutionInfo: parse failed at step \(i), iccs=\(iccs)")
                #endif
                return nil
            }
            if i == step {
                let notation = NotationGenerator.notation(for: move, on: tempBoard)
                return (move.from, move.to, notation)
            }
            tempBoard.execute(move)
        }
        return nil
    }

    func dismissHint() {
        currentHint = nil
        hintMove = nil
        gameState = .playing
    }

    // MARK: - 解法验证 & 星级评分

    /// 对比玩家步数与 solution 长度,给出 1-3 星
    private func calculateRating() -> Int {
        guard !puzzle.solution.isEmpty else { return 3 }

        if puzzle.solutionType == "sequence" {
            // sequence 局:按是否每步都走了推荐走法评星
            // playerSolutionMoves 已包含所有玩家方步(从 solution 中提取)
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

        // checkmate 局:保持现有逻辑(按步数评星)
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
    /// 通过查看棋子颜色判断 side,不依赖 board.currentTurn
    /// 部分局有连续同方走法(如 RRB),所以不能用 turn 判断
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

            // Fallback: ICCSParser 失败时(如连续同方走法 turn 不匹配),手动安全解析
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
                // execute 多 toggle 了一次 turn,补偿回来
                board.toggleTurn()
            } else {
                break
            }
        }
        _cachedPlayerSolutionMoves = result
        return result
    }

    /// 验证指定步是否匹配 solution 推荐走法
    /// moveIndex: 玩家走法的序号(0-based,仅玩家方走法)
    func isRecommendedMove(at moveIndex: Int) -> Bool {
        guard moveIndex < playerSolutionMoves.count else { return true }  // 超出 solution 长度,不再约束
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

        // v3.7.0 Phase 3: 保存残局棋谱到 GameRecordStore
        // v3.7.1 A4: 同 puzzleId 去重，重玩时 updateRecord 替换
        if var record = buildSolutionRecord() {
            record.source = .puzzle
            record.puzzleId = puzzle.id
            record.title = String(format: L10n.shared.t("puzzle.recordTitle"), puzzle.name)
            if let existing = GameRecordStore.shared.findRecordByPuzzleId(puzzle.id) {
                // 重玩同一残局：用原 id 创建新记录替换
                let updated = GameRecord(
                    id: existing.id,
                    title: record.title,
                    date: record.date,
                    redPlayer: record.redPlayer,
                    blackPlayer: record.blackPlayer,
                    difficulty: record.difficulty,
                    result: record.result,
                    totalMoves: record.totalMoves,
                    moves: record.moves,
                    initialFEN: record.initialFEN,
                    source: record.source,
                    tags: record.tags,
                    puzzleId: record.puzzleId
                )
                GameRecordStore.shared.updateRecord(updated)
            } else {
                GameRecordStore.shared.addRecord(record)
            }
        }

        // P0-2 fix: 调用 AchievementChecker.checkAfterPuzzle 检查残局相关成就
        let store = PuzzleStore.shared
        let profile = PlayerProfileStore.shared.profile
        let puzzleType = puzzle.solutionType
        let chapterId = puzzle.category
        let newAchievements = AchievementChecker.checkAfterPuzzle(
            puzzleType: puzzleType,
            chapterId: chapterId,
            allPuzzleCount: store.totalPuzzles,
            completedCount: store.completedCount,
            profile: profile
        )
        for achievementId in newAchievements {
            AchievementManager.shared.unlock(achievementId)
        }

        // P0 fix: 每日挑战模式下补调 completeChallenge
        if isDailyChallenge {
            DailyChallengeManager.shared.completeChallenge(
                score: completionRating,
                puzzles: [puzzle]
            )
        }
    }

    // MARK: - 重置(puzzleVersion 防护)

    func resetPuzzle() {
        puzzleVersion += 1
        isThinking = false
        isProcessingWrongMove = false
        solutionStepIndex = 0
        solutionDegraded = false
        // 直接重建初始棋盘,避免 while-undo 状态累积风险和 O(n×pieces) 性能问题
        board = Board(fen: puzzle.initialFEN)
        isInCheck = false
        selectedPosition = nil
        legalMovesForSelected = []
        gameMoves = []
        gameState = .playing
        hintIndex = 0
        hintLevel = 0
        currentHint = nil
        solutionHint = nil
        hintMove = nil
        hintOffsetInSession = 0
        completionRating = 0
        positionHistory = [boardFingerprint()]
        halfmoveClock = 0
        hasShownMaxMovesWarning = false
        _cachedPlayerSolutionMoves = nil
    }

    // MARK: - 完美解法回放

    /// 构建标准解法的 GameRecord,用于回放
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
                timestamp: Date(), isCheck: isCheck, isCheckmate: isCheckmate, halfmoveClock: 0
            )
            moves.append(gameMove)
            if isCheckmate { break }
        }
        let isHumanRed = puzzle.side == .red
        let humanName = L10n.shared.t("player.human")
        let aiName = String(format: L10n.shared.t("player.aiLabel"), defenderDifficulty.displayName)
        let record = GameRecord(
            id: UUID(),
            title: String(format: L10n.shared.t("puzzle.solutionTitle"), puzzle.name),
            date: Date(),
            redPlayer: PlayerInfo(name: isHumanRed ? humanName : aiName, isAI: !isHumanRed, difficulty: isHumanRed ? nil : defenderDifficulty),
            blackPlayer: PlayerInfo(name: isHumanRed ? aiName : humanName, isAI: isHumanRed, difficulty: isHumanRed ? defenderDifficulty : nil),
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
