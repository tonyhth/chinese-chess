import Testing
import Foundation
@testable import ChineseChess

// MARK: - PuzzleStore / Puzzle 数据测试

@Suite("PuzzleStore Tests")
struct PuzzleStoreTests {

    @Test("残局数据加载")
    func testPuzzleLoad() {
        let store = PuzzleStore.shared
        #expect(!store.puzzles.isEmpty, "No puzzles loaded")
    }

    @Test("残局数据字段完整")
    func testPuzzleFields() {
        let store = PuzzleStore.shared
        for puzzle in store.puzzles {
            #expect(!puzzle.id.isEmpty)
            #expect(!puzzle.name.isEmpty)
            #expect(!puzzle.initialFEN.isEmpty)
            #expect(puzzle.difficulty >= 1 && puzzle.difficulty <= 5)
            #expect(puzzle.maxMoves > 0)
            #expect(puzzle.playerSide == "red" || puzzle.playerSide == "black")
        }
    }

    @Test("每个残局 FEN 可解析")
    func testFENParseable() {
        let store = PuzzleStore.shared
        for puzzle in store.puzzles {
            let parsed = FENParser.parse(fen: puzzle.initialFEN)
            #expect(parsed != nil, "Puzzle \(puzzle.id) FEN failed to parse")
            #expect((parsed?.pieces.count ?? 0) >= 2, "Puzzle \(puzzle.id) has too few pieces")
        }
    }

    @Test("按 ID 查询")
    func testPuzzleById() {
        let store = PuzzleStore.shared
        guard let first = store.puzzles.first else { return }
        let found = store.puzzle(byId: first.id)
        #expect(found?.id == first.id)
    }

    @Test("分类查询")
    func testPuzzleByCategory() {
        let store = PuzzleStore.shared
        let cats = store.categories
        #expect(!cats.isEmpty)
        for cat in cats {
            let list = store.puzzles(byCategory: cat)
            #expect(!list.isEmpty)
            for p in list {
                #expect(p.category == cat)
            }
        }
    }
}

// MARK: - PuzzleViewModel 测试

@Suite("PuzzleViewModel Tests")
struct PuzzleViewModelTests {

    @Test("残局初始化状态正确")
    func testInitState() {
        guard let puzzle = PuzzleStore.shared.puzzles.first else {
            #expect(Bool(false), "No puzzles available")
            return
        }
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing)
        #expect(vm.gameMoves.isEmpty)
        #expect(vm.playerSide == puzzle.side)
    }

    @Test("选择玩家棋子返回合法走法")
    func testSelectPiece() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else {
            #expect(Bool(false), "No red-side puzzle found")
            return
        }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let redPieces = vm.board.pieces.filter { $0.side == .red }
        guard let piece = redPieces.first else {
            #expect(Bool(false), "No red pieces found")
            return
        }
        let moves = vm.selectPiece(at: piece.position)
        #expect(!moves.isEmpty)
    }

    @Test("不能选对方棋子")
    func testCannotSelectOpponent() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let blackPieces = vm.board.pieces.filter { $0.side == .black }
        guard let piece = blackPieces.first else { return }
        let moves = vm.selectPiece(at: piece.position)
        #expect(moves.isEmpty)
    }

    @Test("进度记录和读取")
    func testProgressRecord() {
        let store = PuzzleStore.shared
        let progress = PuzzleProgress(puzzleId: "test_puzzle", isCompleted: true, bestMoves: 5, completedAt: Date())
        store.recordProgress(progress)
        let read = store.progress(for: "test_puzzle")
        #expect(read?.isCompleted == true)
        #expect(read?.bestMoves == 5)
        // 清理
        store.recordProgress(PuzzleProgress(puzzleId: "test_puzzle", isCompleted: false, bestMoves: nil, completedAt: nil))
    }
}

// MARK: - ReplayViewModel 测试

@Suite("ReplayViewModel Tests")
struct ReplayViewModelTests {

    private func makeTestRecord() -> GameRecord {
        let moves = [
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4)),
                     from: Position(row: 6, col: 4), to: Position(row: 5, col: 4), captured: nil,
                     turnNumber: 1, notation: "兵五进一", timestamp: Date(), isCheck: false, isCheckmate: false),
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4)),
                     from: Position(row: 3, col: 4), to: Position(row: 4, col: 4), captured: nil,
                     turnNumber: 1, notation: "卒5进1", timestamp: Date(), isCheck: false, isCheckmate: false),
        ]
        return GameRecord(
            id: UUID(), title: "测试对局", date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .medium),
            difficulty: .medium, gameMode: .singlePlayer,
            result: .redWon, totalMoves: 2, moves: moves,
            initialFEN: nil
        )
    }

    @Test("初始状态：currentIndex=0, canGoBack=false")
    func testInitialState() {
        let vm = ReplayViewModel(record: makeTestRecord())
        #expect(vm.currentIndex == 0)
        #expect(!vm.canGoBack)
        #expect(vm.canGoForward)
    }

    @Test("前进一步")
    func testGoForward() {
        let vm = ReplayViewModel(record: makeTestRecord())
        vm.goForward()
        #expect(vm.currentIndex == 1)
        #expect(vm.canGoBack)
    }

    @Test("前进到末尾不能再进")
    func testCannotGoForwardAtEnd() {
        let record = makeTestRecord()
        let vm = ReplayViewModel(record: record)
        for _ in 0..<record.moves.count {
            vm.goForward()
        }
        #expect(!vm.canGoForward)
    }

    @Test("前进后退后局面还原")
    func testGoBackRestores() {
        let vm = ReplayViewModel(record: makeTestRecord())
        vm.goForward()
        #expect(vm.currentIndex == 1)
        vm.goBack()
        #expect(vm.currentIndex == 0)
        #expect(!vm.canGoBack)
    }

    @Test("跳转到指定位置")
    func testJumpTo() {
        let record = makeTestRecord()
        let vm = ReplayViewModel(record: record)
        vm.jumpTo(index: record.moves.count)
        #expect(vm.currentIndex == record.moves.count)
        #expect(!vm.canGoForward)
    }

    @Test("跳转到开头")
    func testGoToStart() {
        let vm = ReplayViewModel(record: makeTestRecord())
        vm.goForward()
        vm.goForward()
        vm.goToStart()
        #expect(vm.currentIndex == 0)
    }

    @Test("跳转到末尾")
    func testGoToEnd() {
        let record = makeTestRecord()
        let vm = ReplayViewModel(record: record)
        vm.goToEnd()
        #expect(vm.currentIndex == record.moves.count)
    }

    @Test("progressText 显示正确")
    func testProgressText() {
        let record = makeTestRecord()
        let vm = ReplayViewModel(record: record)
        #expect(vm.progressText == "0/\(record.moves.count)")
        vm.goForward()
        #expect(vm.progressText == "1/\(record.moves.count)")
    }

    @Test("currentMove 返回正确的走法")
    func testCurrentMove() {
        let record = makeTestRecord()
        let vm = ReplayViewModel(record: record)
        #expect(vm.currentMove == nil)
        vm.goForward()
        #expect(vm.currentMove?.notation == "兵五进一")
    }
}

// MARK: - FEN + Puzzle 集成测试

@Suite("Puzzle FEN Integration Tests")
struct PuzzleFENIntegrationTests {

    @Test("每个残局 FEN 生成有效棋盘")
    func testFENGeneratesValidBoard() {
        let store = PuzzleStore.shared
        for puzzle in store.puzzles {
            guard let board = FENParser.parse(fen: puzzle.initialFEN) else {
                #expect(Bool(false), "Puzzle \(puzzle.id) FEN parse failed")
                continue
            }
            #expect(board.pieces.count >= 2, "Puzzle \(puzzle.id): only \(board.pieces.count) pieces")
            let hasRedGeneral = board.pieces.contains { $0.kind == .general && $0.side == .red }
            let hasBlackGeneral = board.pieces.contains { $0.kind == .general && $0.side == .black }
            #expect(hasRedGeneral, "Puzzle \(puzzle.id): missing red general")
            #expect(hasBlackGeneral, "Puzzle \(puzzle.id): missing black general")
        }
    }

    @Test("每个残局 solution ICCS 坐标匹配 FEN 棋子位置")
    func testSolutionMatchesFEN() {
        let store = PuzzleStore.shared
        for puzzle in store.puzzles {
            guard !puzzle.solution.isEmpty else { continue }  // 空solution跳过
            guard let board = FENParser.parse(fen: puzzle.initialFEN) else {
                #expect(Bool(false), "Puzzle \(puzzle.id): FEN parse failed")
                continue
            }
            
            // Build piece position map
            var positions: [String: Piece] = [:]
            for piece in board.pieces {
                positions["\(piece.position.row),\(piece.position.col)"] = piece
            }
            
            for (idx, move) in puzzle.solution.enumerated() {
                guard move.count == 4 else {
                    #expect(Bool(false), "Puzzle \(puzzle.id) move[\(idx)] invalid format: \(move)")
                    break
                }
                let chars = Array(move)
                let fromCol = Int(chars[0].asciiValue! - Character("a").asciiValue!)
                let fromRow = 9 - Int(String(chars[1]))!
                let toCol = Int(chars[2].asciiValue! - Character("a").asciiValue!)
                let toRow = 9 - Int(String(chars[3]))!
                
                #expect(fromRow != toRow || fromCol != toCol,
                    "Puzzle \(puzzle.id) move[\(idx)] \(move): from == to (原地不动)")
                let fromKey = "\(fromRow),\(fromCol)"
                guard let piece = positions[fromKey] else {
                    #expect(Bool(false), "Puzzle \(puzzle.id) move[\(idx)] \(move): no piece at (\(fromRow),\(fromCol))")
                    break
                }
                // Update position tracking
                positions.removeValue(forKey: fromKey)
                let toKey = "\(toRow),\(toCol)"
                positions.removeValue(forKey: toKey)  // captured
                positions[toKey] = piece
            }
        }
    }

    @Test("FEN roundtrip：解析→序列化→再解析")
    func testFENRoundtrip() {
        let store = PuzzleStore.shared
        for puzzle in store.puzzles {
            guard let board1 = FENParser.parse(fen: puzzle.initialFEN) else { continue }
            let fen2 = FENParser.generate(board: board1)
            guard let board2 = FENParser.parse(fen: fen2) else {
                #expect(Bool(false), "Puzzle \(puzzle.id) roundtrip FEN re-parse failed")
                continue
            }
            #expect(board1.pieces.count == board2.pieces.count,
                    "Puzzle \(puzzle.id): roundtrip piece count mismatch")
        }
    }
}
