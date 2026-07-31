import Testing
@testable import ChineseChess

// MARK: - DemoViewModel 核心逻辑测试

@MainActor
@Suite("Phase 1 Demo Auto-play", .serialized)
struct DemoViewModelTests {

    /// 标准 FEN + 炮八平五（h2e2）→ 马8进7（h0g2）→ 炮五进四（e2e6）
    /// 在标准开局 FEN 上，h2e2 是红方右炮平中，h0g2 是黑方马跳
    private func makeTestPuzzle(solution: [String] = ["h2e2", "h0g2", "e2e6"],
                                 category: String = "Basic",
                                 playerSide: String = "red") -> Puzzle {
        Puzzle(
            id: "test-puzzle",
            name: "Test Puzzle",
            category: category,
            difficulty: 1,
            stars: 3,
            description: "Test",
            playerSide: playerSide,
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: solution,
            hints: nil,
            maxMoves: 10
        )
    }

    private func makeEmptySolutionPuzzle() -> Puzzle {
        Puzzle(
            id: "freeplay-puzzle",
            name: "Free Play",
            category: "Free",
            difficulty: 1,
            stars: 1,
            description: "Free",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: [],
            hints: nil,
            maxMoves: 0
        )
    }

    @Test("DemoViewModel init state correct")
    func init_correctState() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        #expect(vm.playState == .idle)
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
        #expect(vm.isAutoAdvance == true)
        #expect(!vm.isPlaying)
    }

    @Test("DemoViewModel empty solution no crash")
    func init_emptySolution_noCrash() {
        let puzzle = makeEmptySolutionPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        #expect(vm.totalSteps == 0)
        #expect(!vm.canGoForward)
        #expect(!vm.canGoBack)
    }

    @Test("stepForward increments index and sets lastMove")
    func stepForward_incrementsIndex() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        #expect(vm.currentIndex == 0)
        vm.stepForward()
        #expect(vm.currentIndex == 1)
        #expect(vm.lastMove != nil)
    }

    @Test("stepForward stops auto-play")
    func stepForward_stopsAutoPlay() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.play()
        #expect(vm.isPlaying)
        vm.stepForward()
        #expect(!vm.isPlaying)
        #expect(vm.playState == .idle)
    }

    @Test("stepBackward decrements index")
    func stepBackward_decrements() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.stepForward()
        vm.stepForward()
        #expect(vm.currentIndex == 2)

        vm.stepBackward()
        #expect(vm.currentIndex == 1)
    }

    @Test("stepBackward at start is no-op")
    func stepBackward_atStart_noOp() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.stepBackward()
        #expect(vm.currentIndex == 0)
    }

    @Test("stepForward at end is no-op")
    func stepForward_atEnd_noOp() {
        let puzzle = makeTestPuzzle(solution: ["h2e2"])
        let vm = DemoViewModel(puzzle: puzzle)

        vm.stepForward()
        #expect(vm.currentIndex == 1)
        #expect(!vm.canGoForward)

        vm.stepForward()
        #expect(vm.currentIndex == 1)
    }

    @Test("play sets playing state")
    func play_setsPlayingState() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.play()
        #expect(vm.playState == .playing)
        #expect(vm.isPlaying)
    }

    @Test("pause returns to idle")
    func pause_returnsToIdle() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.play()
        vm.pause()
        #expect(vm.playState == .idle)
        #expect(!vm.isPlaying)
    }

    @Test("resetToStart resets all state")
    func resetToStart_resetsState() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.stepForward()
        vm.stepForward()
        vm.play()
        vm.resetToStart()

        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
        #expect(vm.playState == .idle)
        #expect(vm.currentCommentary == nil)
    }

    @Test("togglePlay idle to playing")
    func togglePlay_idleToPlaying() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.togglePlay()
        #expect(vm.isPlaying)
    }

    @Test("togglePlay playing to idle")
    func togglePlay_playingToIdle() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        vm.togglePlay()
        vm.togglePlay()
        #expect(!vm.isPlaying)
    }

    @Test("DemoSpeed stepInterval correct")
    func demoSpeed_stepInterval() {
        #expect(DemoSpeed.slow.stepInterval == 2.0)
        #expect(DemoSpeed.normal.stepInterval == 1.0)
        #expect(DemoSpeed.fast.stepInterval == 0.5)
    }

    @Test("DemoSpeed commentaryDuration linked to speed")
    func demoSpeed_commentaryDuration() {
        #expect(DemoSpeed.slow.commentaryDuration == 4.0)
        #expect(DemoSpeed.normal.commentaryDuration == 2.0)
        #expect(DemoSpeed.fast.commentaryDuration == 1.0)
    }

    @Test("toggleAutoAdvance toggles state")
    func toggleAutoAdvance() {
        let puzzle = makeTestPuzzle()
        let vm = DemoViewModel(puzzle: puzzle)

        #expect(vm.isAutoAdvance == true)
        vm.toggleAutoAdvance()
        #expect(vm.isAutoAdvance == false)
        vm.toggleAutoAdvance()
        #expect(vm.isAutoAdvance == true)
    }

    @Test("progressText contains step info")
    func progressText_format() {
        let puzzle = makeTestPuzzle(solution: ["h2e2", "h0g2"])
        let vm = DemoViewModel(puzzle: puzzle)

        // progressText 格式：第 X/Y 步
        #expect(vm.progressText.contains("0"))
        #expect(vm.progressText.contains("2"))
        vm.stepForward()
        #expect(vm.progressText.contains("1"))
    }
}

// MARK: - CommentaryEngine 测试

@Suite("CommentaryEngine", .serialized)
struct CommentaryEngineTests {

    @Test("Non-check, non-last move returns nil")
    func evaluate_noCheckNotLast_returnsNil() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let move = moves.first else {
            Issue.record("Standard opening should have legal moves")
            return
        }

        let result = CommentaryEngine.evaluate(move: move, on: board, moveIndex: 3, totalMoves: 10)
        #expect(result == nil)
    }

    @Test("Last move non-check returns keyMove")
    func evaluate_lastMoveNonCheck_returnsKeyMove() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let move = moves.first else {
            Issue.record("Standard opening should have legal moves")
            return
        }

        let result = CommentaryEngine.evaluate(move: move, on: board, moveIndex: 9, totalMoves: 10)
        #expect(result != nil)
        if let item = result, case .keyMove = item.type {
            // correct
        } else if result != nil {
            Issue.record("Last move non-check should return keyMove")
        }
    }
}

// MARK: - DemoMoveConverter 测试

@Suite("DemoMoveConverter", .serialized)
struct DemoMoveConverterTests {

    @Test("Valid ICCS converts successfully")
    func convert_validICCS_success() {
        let board = Board()
        let result = DemoMoveConverter.convert(solution: ["h2e2"], on: board)
        #expect(result.moves.count == 1)
        #expect(result.isComplete == true)
    }

    @Test("Invalid ICCS stops conversion immediately")
    func convert_invalidICCS_stops() {
        let board = Board()
        let result = DemoMoveConverter.convert(solution: ["zz99", "h2e2"], on: board)
        #expect(result.moves.count == 0, "失败应立即终止，不保留任何有效步")
        #expect(result.isComplete == false)
        #expect(result.failedSteps == 2)
    }

    @Test("Empty solution returns empty result")
    func convert_emptySolution_emptyResult() {
        let board = Board()
        let result = DemoMoveConverter.convert(solution: [], on: board)
        #expect(result.moves.isEmpty)
        #expect(result.isComplete == true)
    }
}

// MARK: - PuzzleStore 演示模式查询测试

@Suite("PuzzleStore Demo Queries", .serialized)
struct PuzzleStoreDemoTests {

    @Test("demoPuzzles excludes empty-solution puzzles")
    func demoPuzzles_excludesEmptySolution() {
        let allPuzzles = PuzzleStore.shared.puzzles
        let demoPuzzles = PuzzleStore.shared.demoPuzzles

        for puzzle in demoPuzzles {
            #expect(!puzzle.solution.isEmpty)
        }

        #expect(demoPuzzles.count <= allPuzzles.count)
    }

    @Test("demoCategories are sorted unique categories from demoPuzzles")
    func demoCategories_correctAndSorted() {
        let demoPuzzles = PuzzleStore.shared.demoPuzzles
        let demoCategories = PuzzleStore.shared.demoCategories

        let expected = Array(Set(demoPuzzles.map { $0.category })).sorted()
        #expect(demoCategories == expected)
    }

    @Test("demoPuzzles(byCategory:) filters correctly")
    func demoPuzzles_byCategory_filtersCorrectly() {
        let categories = PuzzleStore.shared.demoCategories
        guard let firstCategory = categories.first else { return }

        let puzzles = PuzzleStore.shared.demoPuzzles(byCategory: firstCategory)
        for puzzle in puzzles {
            #expect(puzzle.category == firstCategory)
            #expect(!puzzle.solution.isEmpty)
        }
    }
}
