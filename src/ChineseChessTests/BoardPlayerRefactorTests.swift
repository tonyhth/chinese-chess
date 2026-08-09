import Foundation
import Testing
@testable import ChineseChess

// MARK: - BoardPlayer 接入重构测试
//
// 覆盖：
// 1. BoardPlayer 核心逻辑（autoRestart、private callbacks、只读 lastMove）
// 2. DemoViewModel 委托 BoardPlayer（播放/暂停/步进/重置/点评/连播）
// 3. ReplayViewModel 委托 BoardPlayer（播放/暂停/步进/跳转/速度）
// 4. P0 修复：ReplayViewModel 末尾按播放不应从头重放
// 5. DemoMoveSource / ReplayMoveSource 走法源正确性

// ============================================================
// 辅助方法
// ============================================================

extension BoardPlayerRefactorTests {

    /// 构造有 N 步走法的 GameRecord（从标准初始局面推演合法走法）
    static func makeGameRecord(moves count: Int) -> (GameRecord, Board) {
        let board = Board(fen: FENParser.standardInitial)
        var gameMoves: [GameMove] = []

        for i in 0..<count {
            let side: Side = (i % 2 == 0) ? .red : .black
            let allMoves = MoveValidator.allLegalMoves(for: side, on: board)
            guard let mv = allMoves.first else { break }
            board.execute(mv)
            gameMoves.append(GameMove(
                id: UUID(),
                piece: mv.piece,
                from: mv.from,
                to: mv.to,
                captured: mv.captured,
                turnNumber: i / 2 + 1,
                notation: "",
                timestamp: Date(),
                isCheck: false,
                isCheckmate: false,
                halfmoveClock: 0
            ))
        }

        let record = GameRecord(
            title: "测试棋局",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow,
            result: .redWon,
            totalMoves: gameMoves.count,
            moves: gameMoves,
            initialFEN: FENParser.standardInitial,
            source: .versusAI
        )
        return (record, board)
    }

    /// 构造测试用 Puzzle
    static func makeTestPuzzle(
        solution: [String] = ["h2e2", "h9g7", "e2e6"],
        category: String = "Basic",
        initialFEN: String = "r1bakab1r/9/4c4/p3p1p1p/2pn5/6P2/P1P1P3P/2N1C4/9/R1BAKAB1R w - - 0 1"
    ) -> Puzzle {
        Puzzle(
            id: "test-puzzle",
            name: "Test Puzzle",
            category: category,
            difficulty: 1,
            stars: 3,
            description: "Test",
            playerSide: "red",
            initialFEN: initialFEN,
            solution: solution,
            hints: nil,
            maxMoves: 10
        )
    }

    /// 空解法 Puzzle
    static func makeEmptyPuzzle() -> Puzzle {
        Puzzle(
            id: "empty-puzzle",
            name: "Empty",
            category: "Free",
            difficulty: 1,
            stars: 1,
            description: "Empty",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: [],
            hints: nil,
            maxMoves: 0
        )
    }

    /// 构造只有 1 步的 BoardPlayer（标准初始局面第一步合法走法）
    func makeSingleMoveBoardPlayer(autoRestart: Bool = true) -> BoardPlayer {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let mv = legalMoves.first else {
            fatalError("初始局面应有合法走法")
        }
        let source = DemoMoveSource(moves: [mv], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)
        player.autoRestart = autoRestart
        return player
    }
}

// ============================================================
// 1. BoardPlayer 核心逻辑
// ============================================================

@MainActor
@Suite("BoardPlayer Core", .serialized)
struct BoardPlayerRefactorTests {

    // MARK: - autoRestart

    @Test("autoRestart 默认 true")
    func autoRestart_defaultTrue() {
        let player = makeSingleMoveBoardPlayer()
        #expect(player.autoRestart == true)
    }

    @Test("autoRestart=false 时末尾 play 不重放")
    func autoRestart_false_noReplay() {
        let player = makeSingleMoveBoardPlayer(autoRestart: false)

        // 走到最后
        player.stepForward()
        #expect(player.currentIndex == 1)
        #expect(!player.canGoForward)

        // 末尾按 play 不应重放
        player.play()
        #expect(!player.isPlaying)
        #expect(player.currentIndex == 1)  // 仍在末尾
    }

    @Test("autoRestart=true 时末尾 play 从头重放")
    func autoRestart_true_replayFromStart() {
        let player = makeSingleMoveBoardPlayer(autoRestart: true)

        // 走到最后
        player.stepForward()
        #expect(player.currentIndex == 1)

        // 末尾按 play 应重置并开始播放
        player.play()
        #expect(player.isPlaying)
        #expect(player.currentIndex == 0)  // 先 resetToStart 再 play
    }

    // MARK: - 只读 lastMove

    @Test("lastMove 初始为 nil")
    func lastMove_initialNil() {
        let source = DemoMoveSource(moves: [], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)
        #expect(player.lastMove == nil)
    }

    @Test("stepForward 后 lastMove 有值")
    func lastMove_afterStepForward() {
        let player = makeSingleMoveBoardPlayer()

        player.stepForward()
        #expect(player.lastMove != nil)
    }

    @Test("resetToStart 后 lastMove 归 nil")
    func lastMove_resetToNil() {
        let player = makeSingleMoveBoardPlayer()

        player.stepForward()
        #expect(player.lastMove != nil)
        player.resetToStart()
        #expect(player.lastMove == nil)
    }

    @Test("stepBackward 后 lastMove 更新")
    func lastMove_afterStepBackward() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard legalMoves.count >= 2 else {
            Issue.record("初始局面至少应有 2 个合法走法")
            return
        }
        let moves = Array(legalMoves.prefix(2))
        let source = DemoMoveSource(moves: moves, initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)

        player.stepForward()  // index 1
        player.stepForward()  // index 2
        #expect(player.lastMove != nil)
        player.stepBackward()  // index 1
        #expect(player.lastMove != nil)
        player.stepBackward()  // index 0
        #expect(player.lastMove == nil)
    }

    // MARK: - 闭包回调

    @Test("onMoveExecutedHandler 在 stepForward 时触发")
    func onMoveExecutedHandler_stepForward() {
        let player = makeSingleMoveBoardPlayer()

        var callbackMove: Move?
        var callbackIndex: Int?
        player.onMoveExecutedHandler = { (move: Move, index: Int) in
            callbackMove = move
            callbackIndex = index
        }

        player.stepForward()
        #expect(callbackMove != nil)
        #expect(callbackIndex == 0)
    }

    @Test("onPlaybackCompleteHandler 在播放完成时触发")
    func onPlaybackCompleteHandler_fires() async {
        let player = makeSingleMoveBoardPlayer()
        player.speed = 100.0  // 极速，1 步瞬间完成

        var completeCalled = false
        player.onPlaybackCompleteHandler = {
            completeCalled = true
        }

        player.play()
        // 等待异步任务完成
        try? await Task.sleep(for: .milliseconds(200))

        #expect(completeCalled)
    }

    // MARK: - 基础导航

    @Test("stepForward/sttepBackward 索引正确")
    func stepForwardBackward_indexCorrect() {
        let board = Board(fen: FENParser.standardInitial)
        var legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard legalMoves.count >= 3 else {
            Issue.record("初始局面至少应有 3 个合法走法")
            return
        }
        let moves = Array(legalMoves.prefix(3))
        let source = DemoMoveSource(moves: moves, initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)

        #expect(player.currentIndex == 0)
        player.stepForward()
        #expect(player.currentIndex == 1)
        player.stepForward()
        #expect(player.currentIndex == 2)
        player.stepBackward()
        #expect(player.currentIndex == 1)
    }

    @Test("jumpTo clamp 边界")
    func jumpTo_clampBoundaries() {
        let player = makeSingleMoveBoardPlayer()

        player.jumpTo(index: -1)
        #expect(player.currentIndex == 0)

        player.jumpTo(index: 100)
        #expect(player.currentIndex == 1)  // clamp 到 totalMoves
    }

    @Test("goToEnd 到最后一步")
    func goToEnd() {
        let player = makeSingleMoveBoardPlayer()

        player.goToEnd()
        #expect(player.currentIndex == 1)
        #expect(!player.canGoForward)
        #expect(!player.isPlaying)  // goToEnd 应停止播放
    }

    // MARK: - 速度

    @Test("speed 影响 stepInterval")
    func speed_affectsStepInterval() {
        let source = DemoMoveSource(moves: [], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)

        player.speed = 2.0
        #expect(player.stepInterval == 0.5)
        player.speed = 0.5
        #expect(player.stepInterval == 2.0)
    }

    // MARK: - progressText

    @Test("progressText 格式正确")
    func progressText_format() {
        let player = makeSingleMoveBoardPlayer()

        #expect(player.progressText == "0/1")
        player.stepForward()
        #expect(player.progressText == "1/1")
    }

    // MARK: - canGoForward/canGoBack

    @Test("canGoForward/canGoBack 初始状态")
    func canGo_initialState() {
        let player = makeSingleMoveBoardPlayer()
        #expect(player.canGoForward)
        #expect(!player.canGoBack)
    }

    @Test("canGoForward/canGoBack 末尾状态")
    func canGo_atEnd() {
        let player = makeSingleMoveBoardPlayer()
        player.stepForward()
        #expect(!player.canGoForward)
        #expect(player.canGoBack)
    }

    // MARK: - pause 停止播放

    @Test("pause 停止自动播放")
    func pause_stopsAutoPlay() {
        let player = makeSingleMoveBoardPlayer()
        player.play()
        #expect(player.isPlaying)
        player.pause()
        #expect(!player.isPlaying)
    }

    // MARK: - togglePlay

    @Test("togglePlay 切换播放状态")
    func togglePlay_switches() {
        let player = makeSingleMoveBoardPlayer()
        #expect(!player.isPlaying)
        player.togglePlay()
        #expect(player.isPlaying)
        player.togglePlay()
        #expect(!player.isPlaying)
    }

    // MARK: - stepForward/stepBackward 停止播放

    @Test("stepForward 停止自动播放")
    func stepForward_stopsAutoPlay() {
        let player = makeSingleMoveBoardPlayer()
        player.play()
        player.stepForward()
        #expect(!player.isPlaying)
    }

    @Test("stepBackward 停止自动播放")
    func stepBackward_stopsAutoPlay() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard legalMoves.count >= 2 else {
            Issue.record("初始局面至少应有 2 个合法走法")
            return
        }
        let moves = Array(legalMoves.prefix(2))
        let source = DemoMoveSource(moves: moves, initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)

        player.stepForward()
        player.stepForward()
        player.stepBackward()
        #expect(!player.isPlaying)
    }

    // MARK: - 空走法源

    @Test("空走法源 play 无效果")
    func emptySource_play_noEffect() {
        let source = DemoMoveSource(moves: [], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)

        player.play()
        #expect(!player.isPlaying)  // canGoForward=false，不启动播放
    }

    @Test("空走法源 stepForward 无效果")
    func emptySource_stepForward_noEffect() {
        let source = DemoMoveSource(moves: [], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)

        player.stepForward()
        #expect(player.currentIndex == 0)
    }
}

// ============================================================
// 2. DemoViewModel 委托测试
// ============================================================

@MainActor
@Suite("DemoViewModel Delegation", .serialized)
struct DemoViewModelDelegationTests {

    private func makeVM(solution: [String] = ["h2e2", "h9g7", "e2e6"]) -> DemoViewModel {
        let puzzle = BoardPlayerRefactorTests.makeTestPuzzle(solution: solution)
        return DemoViewModel(puzzle: puzzle)
    }

    // MARK: - 初始状态

    @Test("DemoVM 初始状态正确")
    func init_correctState() {
        let vm = makeVM()
        #expect(vm.playState == .idle)
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
        #expect(vm.speed == .normal)
        #expect(vm.isAutoAdvance == true)
        #expect(!vm.isPlaying)
        #expect(vm.boardPlayer.autoRestart == true)  // Demo 模式 autoRestart=true
    }

    @Test("DemoVM 空解法不崩溃")
    func init_emptySolution_noCrash() {
        let puzzle = BoardPlayerRefactorTests.makeEmptyPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)
        #expect(vm.totalSteps == 0)
        #expect(!vm.canGoForward)
        #expect(!vm.canGoBack)
    }

    // MARK: - 转发属性

    @Test("DemoVM board 转发自 BoardPlayer")
    func board_forwarded() {
        let vm = makeVM()
        #expect(vm.board.pieces.count == vm.boardPlayer.board.pieces.count)
    }

    @Test("DemoVM currentIndex 转发自 BoardPlayer")
    func currentIndex_forwarded() {
        let vm = makeVM()
        vm.stepForward()
        #expect(vm.currentIndex == vm.boardPlayer.currentIndex)
        #expect(vm.currentIndex == 1)
    }

    @Test("DemoVM lastMove 转发自 BoardPlayer（只读）")
    func lastMove_forwarded_readOnly() {
        let vm = makeVM()
        #expect(vm.lastMove == nil)
        vm.stepForward()
        #expect(vm.lastMove != nil)
        #expect(vm.lastMove?.from == vm.boardPlayer.lastMove?.from)
        #expect(vm.lastMove?.to == vm.boardPlayer.lastMove?.to)
    }

    @Test("DemoVM canGoForward/canGoBack 转发正确")
    func canGo_forwarded() {
        let vm = makeVM(solution: ["h2e2"])
        #expect(vm.canGoForward)
        #expect(!vm.canGoBack)
        vm.stepForward()
        #expect(!vm.canGoForward)
        #expect(vm.canGoBack)
    }

    // MARK: - 播放控制

    @Test("DemoVM play/pause 状态正确")
    func playPause_state() {
        let vm = makeVM()
        vm.play()
        #expect(vm.playState == .playing)
        #expect(vm.isPlaying)
        vm.pause()
        #expect(vm.playState == .idle)
        #expect(!vm.isPlaying)
    }

    @Test("DemoVM togglePlay 切换状态")
    func togglePlay_switches() {
        let vm = makeVM()
        vm.togglePlay()
        #expect(vm.isPlaying)
        vm.togglePlay()
        #expect(!vm.isPlaying)
    }

    @Test("DemoVM stepForward 递增并停止播放")
    func stepForward_increments() {
        let vm = makeVM()
        vm.play()
        vm.stepForward()
        #expect(vm.currentIndex == 1)
        #expect(!vm.isPlaying)
        #expect(vm.playState == .idle)
    }

    @Test("DemoVM stepBackward 递减")
    func stepBackward_decrements() {
        let vm = makeVM()
        vm.stepForward()
        vm.stepForward()
        vm.stepBackward()
        #expect(vm.currentIndex == 1)
    }

    @Test("DemoVM resetToStart 重置所有状态")
    func resetToStart_resetsAll() {
        let vm = makeVM()
        vm.stepForward()
        vm.stepForward()
        vm.play()
        vm.resetToStart()
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
        #expect(vm.playState == .idle)
        #expect(vm.currentCommentary == nil)
    }

    // MARK: - 速度同步

    @Test("DemoVM speed 同步到 BoardPlayer")
    func speed_syncToBoardPlayer() {
        let vm = makeVM()
        #expect(vm.boardPlayer.speed == 1.0)  // normal
        vm.speed = .fast
        #expect(vm.boardPlayer.speed == 2.0)
        vm.speed = .turbo
        #expect(vm.boardPlayer.speed == 3.0)
    }

    // MARK: - 连播

    @Test("DemoVM toggleAutoAdvance 切换")
    func toggleAutoAdvance() {
        let vm = makeVM()
        #expect(vm.isAutoAdvance)
        vm.toggleAutoAdvance()
        #expect(!vm.isAutoAdvance)
        vm.toggleAutoAdvance()
        #expect(vm.isAutoAdvance)
    }

    // MARK: - 播放完成回调

    @Test("DemoVM 播放完成后进入 showingResult")
    func playbackComplete_showingResult() async {
        let vm = makeVM(solution: ["h2e2"])
        vm.boardPlayer.speed = 100.0  // 极速

        vm.play()
        try? await Task.sleep(for: .milliseconds(200))

        #expect(vm.playState == .showingResult)
    }

    // MARK: - progressText

    @Test("DemoVM progressText 包含步数信息")
    func progressText_containsSteps() {
        let vm = makeVM(solution: ["h2e2", "h9g7"])
        #expect(vm.progressText.contains("0"))
        #expect(vm.progressText.contains("2"))
        vm.stepForward()
        #expect(vm.progressText.contains("1"))
    }

    // MARK: - validStepCount

    @Test("DemoVM validStepCount 转发自 BoardPlayer")
    func validStepCount_forwarded() {
        let vm = makeVM(solution: ["h2e2", "h9g7"])
        #expect(vm.validStepCount == 2)
        #expect(vm.validStepCount == vm.boardPlayer.totalSteps)
    }
}

// ============================================================
// 3. ReplayViewModel 委托测试
// ============================================================

@MainActor
@Suite("ReplayViewModel Delegation", .serialized)
struct ReplayViewModelDelegationTests {

    private func makeVM(moves count: Int = 10) -> ReplayViewModel {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: count)
        return ReplayViewModel(record: record)
    }

    // MARK: - 初始状态

    @Test("ReplayVM 初始状态正确")
    func init_correctState() {
        let vm = makeVM()
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
        #expect(!vm.isAutoPlaying)
        #expect(vm.canGoForward)
        #expect(!vm.canGoBack)
        #expect(vm.boardPlayer.autoRestart == false)  // Replay 模式 autoRestart=false
    }

    // MARK: - 转发属性

    @Test("ReplayVM board 转发自 BoardPlayer")
    func board_forwarded() {
        let vm = makeVM()
        #expect(vm.board.pieces.count == vm.boardPlayer.board.pieces.count)
    }

    @Test("ReplayVM currentIndex 转发自 BoardPlayer")
    func currentIndex_forwarded() {
        let vm = makeVM()
        vm.goForward()
        #expect(vm.currentIndex == vm.boardPlayer.currentIndex)
    }

    @Test("ReplayVM lastMove 转发自 BoardPlayer（只读）")
    func lastMove_forwarded() {
        let vm = makeVM()
        #expect(vm.lastMove == nil)
        vm.goForward()
        #expect(vm.lastMove != nil)
    }

    @Test("ReplayVM isAutoPlaying 转发自 BoardPlayer.isPlaying")
    func isAutoPlaying_forwarded() {
        let vm = makeVM()
        #expect(!vm.isAutoPlaying)
        vm.toggleAutoPlay()
        #expect(vm.isAutoPlaying)
        #expect(vm.isAutoPlaying == vm.boardPlayer.isPlaying)
    }

    // MARK: - 导航

    @Test("ReplayVM goForward/goBack 索引正确")
    func goForwardBack_index() {
        let vm = makeVM()
        vm.goForward()
        #expect(vm.currentIndex == 1)
        vm.goForward()
        #expect(vm.currentIndex == 2)
        vm.goBack()
        #expect(vm.currentIndex == 1)
    }

    @Test("ReplayVM goToStart 重置到初始")
    func goToStart() {
        let vm = makeVM()
        vm.goForward()
        vm.goForward()
        vm.goToStart()
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
    }

    @Test("ReplayVM goToEnd 到最后")
    func goToEnd() {
        let vm = makeVM(moves: 5)
        vm.goToEnd()
        #expect(vm.currentIndex == 5)
        #expect(!vm.canGoForward)
        #expect(!vm.isAutoPlaying)  // goToEnd 应停止播放
    }

    @Test("ReplayVM jumpTo 正确跳转")
    func jumpTo_correct() {
        let vm = makeVM(moves: 10)
        vm.jumpTo(index: 5)
        #expect(vm.currentIndex == 5)
        vm.jumpTo(index: 0)
        #expect(vm.currentIndex == 0)
        vm.jumpTo(index: 10)
        #expect(vm.currentIndex == 10)
    }

    @Test("ReplayVM jumpTo clamp 边界")
    func jumpTo_clamp() {
        let vm = makeVM(moves: 5)
        vm.jumpTo(index: -1)
        #expect(vm.currentIndex == 0)
        vm.jumpTo(index: 100)
        #expect(vm.currentIndex == 5)
    }

    // MARK: - 速度控制

    @Test("ReplayVM autoPlaySpeed 同步到 BoardPlayer")
    func autoPlaySpeed_sync() {
        let vm = makeVM()
        #expect(vm.autoPlaySpeed == 1.0)
        vm.autoPlaySpeed = 2.0
        #expect(vm.boardPlayer.speed == 2.0)
        vm.autoPlaySpeed = 0.5
        #expect(vm.boardPlayer.speed == 0.5)
    }

    // MARK: - currentMove

    @Test("ReplayVM currentMove 返回正确的 GameMove")
    func currentMove_correct() {
        let vm = makeVM(moves: 5)
        #expect(vm.currentMove == nil)  // currentIndex=0 时无当前步
        vm.goForward()
        #expect(vm.currentMove != nil)
        #expect(vm.currentIndex == 1)
    }

    // MARK: - progressText

    @Test("ReplayVM progressText 格式正确")
    func progressText_format() {
        let vm = makeVM(moves: 10)
        #expect(vm.progressText == "0/10")
        vm.goForward()
        #expect(vm.progressText == "1/10")
        vm.goToEnd()
        #expect(vm.progressText == "10/10")
    }

    // MARK: - 空棋局

    @Test("ReplayVM 空棋局不崩溃")
    func emptyRecord_noCrash() {
        let record = GameRecord(
            title: "空",
            redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow,
            result: .redWon,
            totalMoves: 0,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        let vm = ReplayViewModel(record: record)
        #expect(vm.currentIndex == 0)
        #expect(!vm.canGoForward)
        #expect(!vm.canGoBack)
        vm.goToEnd()
        #expect(vm.currentIndex == 0)
    }

    // MARK: - 单步棋局

    @Test("ReplayVM 单步棋局导航正确")
    func singleMove_navigation() {
        let vm = makeVM(moves: 1)
        vm.goForward()
        #expect(vm.currentIndex == 1)
        #expect(!vm.canGoForward)
        vm.goBack()
        #expect(vm.currentIndex == 0)
        #expect(!vm.canGoBack)
    }

    // MARK: - 重命名

    @Test("ReplayVM rename 更新标题")
    func rename_updatesTitle() {
        let vm = makeVM()
        vm.rename("新标题")
        #expect(vm.displayTitle == "新标题")
    }

    @Test("ReplayVM rename 空字符串不更新")
    func rename_empty_noUpdate() {
        let vm = makeVM()
        let original = vm.displayTitle
        vm.rename("")
        #expect(vm.displayTitle == original)
    }
}

// ============================================================
// 4. P0 修复验证：ReplayViewModel 末尾按播放不应从头重放
// ============================================================

@MainActor
@Suite("P0: Replay No Auto-Restart", .serialized)
struct ReplayNoAutoRestartTests {

    @Test("ReplayVM autoRestart=false 末尾 play 不重放")
    func replay_endNoAutoRestart() {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 3)
        let vm = ReplayViewModel(record: record)

        // 走到最后
        vm.goToEnd()
        #expect(vm.currentIndex == 3)
        #expect(!vm.canGoForward)

        // 在末尾按播放（toggleAutoPlay）
        vm.toggleAutoPlay()

        // 因为 autoRestart=false，不应从头重放
        #expect(!vm.isAutoPlaying)
        #expect(vm.currentIndex == 3)  // 仍在末尾
    }

    @Test("BoardPlayer autoRestart=false 末尾 play 无效果")
    func boardPlayer_noAutoRestart_playAtEnd() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let mv = legalMoves.first else {
            Issue.record("初始局面应有合法走法")
            return
        }
        let source = DemoMoveSource(moves: [mv], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)
        player.autoRestart = false

        player.stepForward()
        #expect(!player.canGoForward)
        player.play()
        #expect(!player.isPlaying)
        #expect(player.currentIndex == 1)
    }

    @Test("ReplayVM 中途暂停后再播放可以继续")
    func replay_pauseThenPlay_continues() async {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 10)
        let vm = ReplayViewModel(record: record)
        vm.autoPlaySpeed = 100.0

        vm.toggleAutoPlay()  // 开始播放
        #expect(vm.isAutoPlaying)

        try? await Task.sleep(for: .milliseconds(100))
        let idx = vm.currentIndex
        #expect(idx > 0)  // 至少走了一步

        vm.toggleAutoPlay()  // 暂停
        #expect(!vm.isAutoPlaying)

        // 再播放可以继续
        vm.toggleAutoPlay()
        #expect(vm.isAutoPlaying)
    }
}

// ============================================================
// 5. DemoMoveSource / ReplayMoveSource 测试
// ============================================================

@MainActor
@Suite("MoveSource Correctness", .serialized)
struct MoveSourceTests {

    @Test("DemoMoveSource totalMoves 正确")
    func demoMoveSource_totalMoves() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard legalMoves.count >= 2 else {
            Issue.record("初始局面至少应有 2 个合法走法")
            return
        }
        let moves = Array(legalMoves.prefix(2))
        let source = DemoMoveSource(moves: moves, initialFEN: FENParser.standardInitial)
        #expect(source.totalMoves == 2)
        #expect(source.initialFEN == FENParser.standardInitial)
    }

    @Test("DemoMoveSource move(at:) 返回正确走法")
    func demoMoveSource_moveAt() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let mv = legalMoves.first else {
            Issue.record("初始局面应有合法走法")
            return
        }
        let source = DemoMoveSource(moves: [mv], initialFEN: FENParser.standardInitial)
        let result = source.move(at: 0, on: board)
        #expect(result.from == mv.from)
        #expect(result.to == mv.to)
    }

    @Test("DemoMoveSource lastMovePosition 返回正确位置")
    func demoMoveSource_lastMovePosition() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let mv = legalMoves.first else {
            Issue.record("初始局面应有合法走法")
            return
        }
        let source = DemoMoveSource(moves: [mv], initialFEN: FENParser.standardInitial)
        let pos = source.lastMovePosition(at: 0)
        #expect(pos != nil)
        #expect(pos?.from == mv.from)
        #expect(pos?.to == mv.to)
    }

    @Test("DemoMoveSource lastMovePosition 越界返回 nil")
    func demoMoveSource_lastMovePosition_outOfBounds() {
        let source = DemoMoveSource(moves: [], initialFEN: FENParser.standardInitial)
        #expect(source.lastMovePosition(at: 0) == nil)
        #expect(source.lastMovePosition(at: -1) == nil)
    }

    @Test("ReplayMoveSource totalMoves 正确")
    func replayMoveSource_totalMoves() {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 5)
        let source = ReplayMoveSource(gameMoves: record.moves, initialFEN: record.initialFEN ?? FENParser.standardInitial)
        #expect(source.totalMoves == 5)
    }

    @Test("ReplayMoveSource move(at:) 从 board 获取 piece")
    func replayMoveSource_moveAt_usesBoardPiece() {
        let board = Board(fen: FENParser.standardInitial)
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let mv = legalMoves.first else {
            Issue.record("初始局面应有合法走法")
            return
        }
        // 创建 GameMove（piece 的 id 来自外部 board）
        let gm = GameMove(
            id: UUID(),
            piece: mv.piece,
            from: mv.from,
            to: mv.to,
            captured: mv.captured,
            turnNumber: 1,
            notation: "",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )
        let source = ReplayMoveSource(gameMoves: [gm], initialFEN: FENParser.standardInitial)
        // 在内部 board 上获取走法
        let freshBoard = Board(fen: FENParser.standardInitial)
        let result = source.move(at: 0, on: freshBoard)
        // piece 应该用 board 上的（id 匹配），而非 gm.piece（id 可能不匹配）
        #expect(result.from == gm.from)
        #expect(result.to == gm.to)
    }

    @Test("ReplayMoveSource lastMovePosition 正确")
    func replayMoveSource_lastMovePosition() {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 3)
        let source = ReplayMoveSource(gameMoves: record.moves, initialFEN: record.initialFEN ?? FENParser.standardInitial)
        let pos = source.lastMovePosition(at: 0)
        #expect(pos != nil)
        #expect(pos?.from == record.moves[0].from)
        #expect(pos?.to == record.moves[0].to)
    }

    @Test("ReplayMoveSource lastMovePosition 越界返回 nil")
    func replayMoveSource_lastMovePosition_outOfBounds() {
        let source = ReplayMoveSource(gameMoves: [], initialFEN: FENParser.standardInitial)
        #expect(source.lastMovePosition(at: 0) == nil)
    }
}

// ============================================================
// 6. 棋盘状态正确性（重构后回归验证）
// ============================================================

@MainActor
@Suite("BoardPlayer Board State Consistency", .serialized)
struct BoardPlayerStateTests {

    @Test("ReplayVM 逐步走 vs goToEnd 棋盘一致")
    func replay_stepByStep_equalsGoToEnd() {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 25)

        let vm1 = ReplayViewModel(record: record)
        while vm1.canGoForward { vm1.goForward() }

        let vm2 = ReplayViewModel(record: record)
        vm2.goToEnd()

        assertBoardEqual(vm1.board, vm2.board, "逐步走 vs goToEnd 棋盘应一致")
    }

    @Test("ReplayVM jumpTo 后棋盘与逐步走一致")
    func replay_jumpTo_matchesStepByStep() {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 25)

        // 逐步走到 22
        let refVM = ReplayViewModel(record: record)
        for _ in 0..<22 { refVM.goForward() }

        // jumpTo 到 22
        let vm = ReplayViewModel(record: record)
        vm.jumpTo(index: 22)

        assertBoardEqual(vm.board, refVM.board, "jumpTo(22) 棋盘应与逐步走到 22 一致")
    }

    @Test("ReplayVM 回退后棋盘正确")
    func replay_goBack_correct() {
        let (record, _) = BoardPlayerRefactorTests.makeGameRecord(moves: 25)

        // 基准：逐步走到 20
        let refVM = ReplayViewModel(record: record)
        for _ in 0..<20 { refVM.goForward() }

        // goToEnd → 回退 5 步
        let vm = ReplayViewModel(record: record)
        vm.goToEnd()
        for _ in 0..<5 { vm.goBack() }

        #expect(vm.currentIndex == 20)
        assertBoardEqual(vm.board, refVM.board, "回退到 20 棋盘应与逐步走到 20 一致")
    }

    @Test("ReplayVM 混合操作后棋盘正确")
    func replay_mixedNavigation() {
        let (record, finalBoard) = BoardPlayerRefactorTests.makeGameRecord(moves: 25)
        let vm = ReplayViewModel(record: record)

        vm.goForward()   // 1
        vm.goForward()   // 2
        vm.goForward()   // 3
        vm.jumpTo(index: 15)
        vm.goForward()   // 16
        vm.goBack()      // 15
        vm.goToEnd()     // 25

        #expect(vm.currentIndex == 25)
        assertBoardEqual(vm.board, finalBoard, "混合操作后棋盘应与真实推演一致")
    }

    @Test("DemoVM stepForward 棋盘状态正确")
    func demo_stepForward_boardState() {
        let puzzle = BoardPlayerRefactorTests.makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        // 不崩溃，棋盘有棋子
        #expect(vm.board.pieces.count > 0)
        vm.stepForward()
        #expect(vm.currentIndex == 1)
    }

    @Test("DemoVM resetToStart 棋盘回到初始")
    func demo_resetToStart_boardResets() {
        let puzzle = BoardPlayerRefactorTests.makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        let initialPieces = vm.board.pieces.count
        vm.stepForward()
        vm.stepForward()
        vm.resetToStart()
        #expect(vm.board.pieces.count == initialPieces)
    }

    // MARK: - 辅助比较方法

    private func assertBoardEqual(_ board1: Board, _ board2: Board, _ message: String) {
        #expect(board1.pieces.count == board2.pieces.count, "\(message) — 棋子数不一致")
        for piece in board1.pieces {
            let actual = board2.piece(at: piece.position)
            if actual?.kind != piece.kind || actual?.side != piece.side {
                Issue.record("\(message) — 位置 \(piece.position) 棋子不一致: expected \(piece.side) \(piece.kind), got \(String(describing: actual?.side)) \(String(describing: actual?.kind))")
            }
        }
    }
}
