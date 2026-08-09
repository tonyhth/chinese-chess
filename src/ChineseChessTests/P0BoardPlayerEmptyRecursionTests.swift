import Testing
@testable import ChineseChess

// MARK: - P0 修复验证：BoardPlayer.play() 空棋谱无限递归栈溢出
//
// Git commit: 42bf971 fix(boardplayer): prevent infinite recursion on empty move list
// 修复内容：第72行新增 `guard canGoForward else { return }`
//
// 测试重点：
// 1. 空棋谱场景：play() 不栈溢出、不崩溃
// 2. 正常棋谱场景：play()/pause() 功能不受影响
// 3. 边界场景：单步棋谱 play() 完成后行为正确

@MainActor
@Suite("P0 BoardPlayer Empty Move Recursion Fix", .serialized)
struct P0BoardPlayerEmptyRecursionTests {

    // ============================================================
    // 辅助
    // ============================================================

    /// 创建空棋谱的 BoardPlayer（DemoMoveSource，0 步）
    private func makeEmptyDemoPlayer(autoRestart: Bool = true) -> BoardPlayer {
        let source = DemoMoveSource(moves: [], initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)
        player.autoRestart = autoRestart
        return player
    }

    /// 创建空棋谱的 BoardPlayer（ReplayMoveSource，0 步）
    private func makeEmptyReplayPlayer() -> BoardPlayer {
        let record = GameRecord(
            title: "空棋局",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow,
            result: .redWon,
            totalMoves: 0,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        let source = ReplayMoveSource(gameMoves: record.moves, initialFEN: record.initialFEN ?? FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)
        player.autoRestart = false  // ReplayViewModel 默认 autoRestart=false
        return player
    }

    /// 创建有 N 步走法的 BoardPlayer
    private func makePlayerWithMoves(_ count: Int, autoRestart: Bool = true) -> BoardPlayer {
        let board = Board(fen: FENParser.standardInitial)
        var moves: [Move] = []
        for i in 0..<count {
            let side: Side = (i % 2 == 0) ? .red : .black
            let allMoves = MoveValidator.allLegalMoves(for: side, on: board)
            guard let mv = allMoves.first else { break }
            board.execute(mv)
            moves.append(mv)
        }
        let source = DemoMoveSource(moves: moves, initialFEN: FENParser.standardInitial)
        let player = BoardPlayer(moveSource: source, initialFEN: FENParser.standardInitial)
        player.autoRestart = autoRestart
        return player
    }

    // ============================================================
    // 1. 空棋谱场景 — 核心回归测试
    // ============================================================

    @Test("空棋谱 play() 不崩溃（autoRestart=true，原 P0 场景）")
    func emptyMoveListPlayNoCrash() async {
        let player = makeEmptyDemoPlayer(autoRestart: true)
        // 修复前：play() → resetToStart() → canGoForward=false → autoRestart → play() → 无限递归 → 栈溢出
        // 修复后：play() → canGoForward=false → autoRestart → resetToStart() → canGoForward=false → return
        player.play()
        // 如果到这里没崩溃，说明修复生效
        #expect(!player.isPlaying)
        #expect(player.currentIndex == 0)
        #expect(player.totalSteps == 0)
    }

    @Test("空棋谱 play() 不崩溃（autoRestart=false）")
    func emptyMoveListPlayNoRestart() async {
        let player = makeEmptyDemoPlayer(autoRestart: false)
        player.play()
        // autoRestart=false，直接在第一个 guard 返回
        #expect(!player.isPlaying)
        #expect(player.currentIndex == 0)
    }

    @Test("空棋谱 ReplayMoveSource play() 不崩溃")
    func emptyReplayPlayNoCrash() async {
        let player = makeEmptyReplayPlayer()
        player.play()
        #expect(!player.isPlaying)
        #expect(player.currentIndex == 0)
    }

    @Test("空棋谱连续多次 play() 不崩溃")
    func emptyMoveListMultiplePlays() async {
        let player = makeEmptyDemoPlayer(autoRestart: true)
        // 反复调用，确保没有累积状态问题
        for _ in 0..<10 {
            player.play()
        }
        #expect(!player.isPlaying)
        #expect(player.currentIndex == 0)
    }

    @Test("空棋谱 togglePlay() 不崩溃")
    func emptyMoveListTogglePlay() async {
        let player = makeEmptyDemoPlayer(autoRestart: true)
        player.togglePlay()  // isPlaying=false → play()
        #expect(!player.isPlaying)
        player.togglePlay()  // 仍然 isPlaying=false → play()
        #expect(!player.isPlaying)
    }

    @Test("空棋谱 canGoForward 为 false")
    func emptyMoveListCannotGoForward() async {
        let player = makeEmptyDemoPlayer()
        #expect(!player.canGoForward)
        #expect(!player.canGoBack)
        #expect(player.totalSteps == 0)
    }

    // ============================================================
    // 2. 正常棋谱场景 — 功能不受影响
    // ============================================================

    @Test("正常棋谱 play() 进入播放状态")
    func normalMoveListPlayWorks() async throws {
        let player = makePlayerWithMoves(6)
        #expect(player.canGoForward)
        player.play()
        #expect(player.isPlaying)
        player.pause()
        #expect(!player.isPlaying)
    }

    @Test("正常棋谱 pause() 正确暂停")
    func normalMoveListPauseWorks() async throws {
        let player = makePlayerWithMoves(6)
        player.play()
        #expect(player.isPlaying)
        player.pause()
        #expect(!player.isPlaying)
    }

    @Test("正常棋谱 togglePlay() 切换播放/暂停")
    func normalMoveListTogglePlay() async throws {
        let player = makePlayerWithMoves(6)
        player.togglePlay()
        #expect(player.isPlaying)
        player.togglePlay()
        #expect(!player.isPlaying)
    }

    @Test("正常棋谱 stepForward/stepBackward 正常工作")
    func normalMoveListStepWorks() async throws {
        let player = makePlayerWithMoves(4)
        #expect(player.currentIndex == 0)
        player.stepForward()
        #expect(player.currentIndex == 1)
        player.stepForward()
        #expect(player.currentIndex == 2)
        player.stepBackward()
        #expect(player.currentIndex == 1)
    }

    @Test("正常棋谱 resetToStart 后 play() 正常播放")
    func normalMoveListResetAndPlay() async throws {
        let player = makePlayerWithMoves(4)
        player.stepForward()
        player.stepForward()
        #expect(player.currentIndex == 2)
        player.resetToStart()
        #expect(player.currentIndex == 0)
        player.play()
        #expect(player.isPlaying)
    }

    // ============================================================
    // 3. 边界场景 — 单步棋谱
    // ============================================================

    @Test("单步棋谱 play() 开始播放")
    func singleMovePlayStarts() async throws {
        let player = makePlayerWithMoves(1)
        player.play()
        #expect(player.isPlaying)
        player.pause()
    }

    @Test("单步棋谱 play() 完成后 autoRestart 重新播放")
    func singleMovePlayAutoRestart() async throws {
        let player = makePlayerWithMoves(1, autoRestart: true)
        // 走完唯一一步
        player.stepForward()
        #expect(player.currentIndex == 1)
        #expect(!player.canGoForward)
        // 末尾按播放：autoRestart=true → resetToStart() → play()
        player.play()
        #expect(player.isPlaying)
        #expect(player.currentIndex == 0)  // resetToStart 后从 0 开始
        player.pause()
    }

    @Test("单步棋谱 play() 完成后 autoRestart=false 不重放")
    func singleMovePlayNoRestart() async throws {
        let player = makePlayerWithMoves(1, autoRestart: false)
        player.stepForward()
        #expect(!player.canGoForward)
        player.play()
        // autoRestart=false，在末尾直接 return
        #expect(!player.isPlaying)
    }

    // ============================================================
    // 4. 状态一致性 — 空棋谱的各种操作组合
    // ============================================================

    @Test("空棋谱 stepForward 不推进")
    func emptyStepForwardNoOp() async {
        let player = makeEmptyDemoPlayer()
        player.stepForward()
        #expect(player.currentIndex == 0)
    }

    @Test("空棋谱 resetToStart 无副作用")
    func emptyResetNoSideEffect() async {
        let player = makeEmptyDemoPlayer()
        player.resetToStart()
        #expect(player.currentIndex == 0)
        #expect(!player.isPlaying)
    }

    @Test("空棋谱 jumpTo 任意索引不越界")
    func emptyJumpToAnyIndex() async {
        let player = makeEmptyDemoPlayer()
        player.jumpTo(index: 0)
        #expect(player.currentIndex == 0)
        player.jumpTo(index: 5)  // 应该被 clamp 到 0
        #expect(player.currentIndex == 0)
    }

    @Test("空棋谱 goToEnd 不崩溃")
    func emptyGoToEnd() async {
        let player = makeEmptyDemoPlayer()
        player.goToEnd()
        #expect(player.currentIndex == 0)
        #expect(!player.isPlaying)
    }

    @Test("空棋谱 progressText 显示 0/0")
    func emptyProgressText() async {
        let player = makeEmptyDemoPlayer()
        #expect(player.progressText == "0/0")
    }
}
