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
    var solutionHint: String?  // 实时提示:有更优走法时显示

    /// 当前提示会话内的偏移量(每次走棋/悔棋重置为 0)
    private var hintOffsetInSession: Int = 0
    var isInCheck: Bool = false
    var selectedPosition: Position?
    var legalMovesForSelected: [Position] = []

    /// 提示高亮的起止位置(from, to),供 ChessBoardView 蓝色高亮显示
    var hintMove: (from: Position, to: Position)?

    /// solution 步序指针(独立于 gameMoves.count)
    /// 每次走对 +1,undo -1
    var solutionStepIndex: Int = 0

    /// 走错回退锁(独立于 isThinking,避免 "AI 思考中" 文案混淆)
    var isProcessingWrongMove: Bool = false

    private let aiEngine = AIEngine()
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

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.playerSide = puzzle.side
        self.board = Board(fen: puzzle.initialFEN)
        self.positionHistory = [boardFingerprint()]
    }

    // MARK: - 防守方 AI 难度映射

    private var defenderDifficulty: AIDifficulty {
        // 星级→AI搜索深度映射
        switch puzzle.stars {
        case 1: return .beginner  // depth 2
        case 2: return .easy      // depth 3
        case 3: return .medium    // depth 4
        case 4: return .hard      // depth 5
        case 5: return .master    // depth 6
        default: return .easy
        }
    }

    // MARK: - 引导模式判定

    /// solution 数据异常降级标记
    private var solutionDegraded: Bool = false

    private var isGuidedMode: Bool {
        puzzle.effectiveMode == .guided && !puzzle.solution.isEmpty && !solutionDegraded
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
            if puzzle.effectiveMode == .freePlay {
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
        if puzzle.effectiveMode == .freePlay && checkDraw() {
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

        // 检查是否将死对方(提前通关)
        let defenderSide: Side = (playerSide == .red) ? .black : .red
        if MoveValidator.isCheckmate(defenderSide, on: board) {
            gameState = .success
            gameMoves[gameMoves.count - 1].isCheckmate = true
            completionRating = calculateRating()
            recordCompletion()
            return
        }

        // 检查是否走完 solution 中所有玩家方步数
        let playerMoveCount = gameMoves.filter { $0.piece.side == playerSide }.count
        let solutionPlayerMoveCount = playerSolutionMoves.count
        if playerMoveCount >= solutionPlayerMoveCount {
            gameState = .success
            completionRating = calculateRating()
            recordCompletion()
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
                    timestamp: Date(), isCheck: isCheck, isCheckmate: false
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

        let engine = self.aiEngine
        Task.detached {
            let move = await engine.bestMove(for: snapshot, difficulty: difficulty, isIOS: Self._isIOS)
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
                            self.isThinking = false
                            return
                        }

                        // 更新局面历史(和局检测)
                        self.updatePositionHistory(captured: captured, movedPiece: mainPiece)

                        // 和局检测(自由对弈模式)
                        if self.puzzle.effectiveMode == .freePlay && self.checkDraw() {
                            self.gameState = .draw
                            self.isThinking = false
                            return
                        }
                    }
                }
                self.isThinking = false

                // 再次检查步数
                if self.gameState == .playing && self.gameMoves.count >= self.puzzle.maxMoves {
                    if self.puzzle.effectiveMode == .freePlay {
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
        isInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
        gameState = .playing
    }

    // MARK: - 提示

    func showHint() {
        // Phase 3.5: hint 类型显示文字提示(无 solution 的纯提示局)
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

        // checkmate/sequence:优先显示 hints 文字提示,用完后再显示 step-by-step
        if let hints = puzzle.hints, !hints.isEmpty, hintIndex < hints.count {
            currentHint = hints[hintIndex]
            hintIndex += 1
            gameState = .showingHint
            return
        }

        // hints 用完或不存在:显示 step-by-step solution
        if puzzle.solution.isEmpty {
            currentHint = L10n.shared.t("puzzle.noMoreHints")
            gameState = .showingHint
            return
        }

        // 计算当前应提示的 solution 步序号(基于实际游戏进度)
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
                timestamp: Date(), isCheck: isCheck, isCheckmate: isCheckmate
            )
            moves.append(gameMove)
            if isCheckmate { break }
        }
        let record = GameRecord(
            id: UUID(),
            title: String(format: L10n.shared.t("puzzle.solutionTitle"), puzzle.name),
            date: Date(),
            redPlayer: PlayerInfo(name: L10n.shared.t("player.red"), isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: L10n.shared.t("player.black"), isAI: true, difficulty: defenderDifficulty),
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
