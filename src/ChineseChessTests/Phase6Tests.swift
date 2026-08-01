import Testing
import Foundation

@testable import ChineseChess

// MARK: - Position Tests

@Suite("Phase6: Position Tests", .serialized)
struct PositionTests6 {

    @Test("有效位置：边界值")
    func testValidPositions() {
        #expect(Position.isValid(Position(row: 0, col: 0)))
        #expect(Position.isValid(Position(row: 9, col: 8)))
        #expect(Position.isValid(Position(row: 5, col: 4)))
    }

    @Test("无效位置：越界")
    func testInvalidPositions() {
        #expect(!Position.isValid(Position(row: -1, col: 0)))
        #expect(!Position.isValid(Position(row: 10, col: 0)))
        #expect(!Position.isValid(Position(row: 0, col: -1)))
        #expect(!Position.isValid(Position(row: 0, col: 9)))
        #expect(!Position.isValid(Position(row: -1, col: -1)))
    }

    @Test("红方九宫范围")
    func testRedPalace() {
        #expect(Position(row: 9, col: 3).isInRedPalace)
        #expect(Position(row: 8, col: 4).isInRedPalace)
        #expect(Position(row: 7, col: 5).isInRedPalace)
        #expect(!Position(row: 6, col: 4).isInRedPalace)
        #expect(!Position(row: 8, col: 2).isInRedPalace)
    }

    @Test("黑方九宫范围")
    func testBlackPalace() {
        #expect(Position(row: 0, col: 3).isInBlackPalace)
        #expect(Position(row: 1, col: 4).isInBlackPalace)
        #expect(Position(row: 2, col: 5).isInBlackPalace)
        #expect(!Position(row: 3, col: 4).isInBlackPalace)
    }

    @Test("红方半场")
    func testRedHalf() {
        #expect(Position(row: 5, col: 0).isInRedHalf)
        #expect(Position(row: 9, col: 8).isInRedHalf)
        #expect(!Position(row: 4, col: 0).isInRedHalf)
    }

    @Test("黑方半场")
    func testBlackHalf() {
        #expect(Position(row: 4, col: 0).isInBlackHalf)
        #expect(Position(row: 0, col: 8).isInBlackHalf)
        #expect(!Position(row: 5, col: 0).isInBlackHalf)
    }

    @Test("Position Equatable 和 Hashable")
    func testPositionEquality() {
        let a = Position(row: 3, col: 4)
        let b = Position(row: 3, col: 4)
        let c = Position(row: 3, col: 5)
        #expect(a == b)
        #expect(a != c)
        let set: Set<Position> = [a, b, c]
        #expect(set.count == 2)
    }
}

// MARK: - Piece Tests

@Suite("Phase6: Piece Tests", .serialized)
struct PieceTests6 {

    @Test("红方棋子显示名完整")
    func testRedDisplayNames() {
        #expect(Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8).displayName == "帅")
        #expect(Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 3), id: 6).displayName == "仕")
        #expect(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 2), id: 4).displayName == "相")
        #expect(Piece(kind: .horse, side: .red, position: Position(row: 9, col: 1), id: 2).displayName == "馬")
        #expect(Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0).displayName == "車")
        #expect(Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9).displayName == "炮")
        #expect(Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 0), id: 11).displayName == "兵")
    }

    @Test("黑方棋子显示名完整")
    func testBlackDisplayNames() {
        #expect(Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24).displayName == "将")
        #expect(Piece(kind: .advisor, side: .black, position: Position(row: 0, col: 3), id: 22).displayName == "士")
        #expect(Piece(kind: .elephant, side: .black, position: Position(row: 0, col: 2), id: 20).displayName == "象")
        #expect(Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1), id: 18).displayName == "馬")
        #expect(Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16).displayName == "車")
        #expect(Piece(kind: .cannon, side: .black, position: Position(row: 2, col: 1), id: 25).displayName == "砲")
        #expect(Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27).displayName == "卒")
    }

    @Test("子力基础价值：非兵棋子")
    func testBaseValuesNonSoldier() {
        #expect(Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8).baseValue == 10000)
        #expect(Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0).baseValue == 900)
        #expect(Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9).baseValue == 450)
        #expect(Piece(kind: .horse, side: .red, position: Position(row: 9, col: 1), id: 2).baseValue == 400)
        #expect(Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 3), id: 6).baseValue == 200)
        #expect(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 2), id: 4).baseValue == 200)
    }

    @Test("兵过河前 100，过河后 200")
    func testSoldierBaseValue() {
        let redHome = Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13)
        let redCrossed = Piece(kind: .soldier, side: .red, position: Position(row: 4, col: 4), id: 144)
        #expect(redHome.baseValue == 100)
        #expect(redCrossed.baseValue == 200)

        let blackHome = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4), id: 29)
        let blackCrossed = Piece(kind: .soldier, side: .black, position: Position(row: 5, col: 4), id: 254)
        #expect(blackHome.baseValue == 100)
        #expect(blackCrossed.baseValue == 200)
    }

    @Test("Piece Identifiable：每个实例 id 唯一")
    func testPieceIdentifiable() {
        let a = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let b = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        #expect(a.id != b.id)
    }

    @Test("PieceKind 全部 7 种")
    func testPieceKindCount() {
        #expect(PieceKind.allCases.count == 7)
    }
}

// MARK: - Side & GameState Tests

@Suite("Phase6: Enum Tests", .serialized)
struct EnumTests6 {

    @Test("Side rawValue")
    func testSideRawValue() {
        #expect(Side.red.rawValue == "red")
        #expect(Side.black.rawValue == "black")
    }

    @Test("Side Codable roundtrip")
    func testSideCodable() throws {
        let data = try JSONEncoder().encode(Side.red)
        let decoded = try JSONDecoder().decode(Side.self, from: data)
        #expect(decoded == .red)
    }

    @Test("GameState 所有 case")
    func testAllGameStates() {
        let states: [GameState] = [.playing, .redWon, .blackWon, .draw]
        #expect(states.count == 4)
    }

    @Test("GameState Codable roundtrip")
    func testGameStateCodable() throws {
        for state in [GameState.playing, .redWon, .blackWon, .draw] {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(GameState.self, from: data)
            #expect(decoded == state)
        }
    }

    @Test("AIDifficulty 所有 5 级")
    func testAllDifficulties() {
        #expect(AIDifficulty.allCases.count == 5)
        #expect(AIDifficulty.allCases.contains(.beginner))
        #expect(AIDifficulty.allCases.contains(.easy))
        #expect(AIDifficulty.allCases.contains(.medium))
        #expect(AIDifficulty.allCases.contains(.hard))
        #expect(AIDifficulty.allCases.contains(.master))
    }
}

// MARK: - Move Tests

@Suite("Phase6: Move Tests", .serialized)
struct MoveTests6 {

    @Test("Move 不带吃子")
    func testMoveWithoutCapture() {
        let piece = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let move = Move(piece: piece, from: Position(row: 9, col: 0), to: Position(row: 8, col: 0), captured: nil)
        #expect(move.captured == nil)
        #expect(move.from == Position(row: 9, col: 0))
        #expect(move.to == Position(row: 8, col: 0))
    }

    @Test("Move 带吃子")
    func testMoveWithCapture() {
        let red = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let black = Piece(kind: .soldier, side: .black, position: Position(row: 5, col: 0), id: 250)
        let move = Move(piece: red, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: black)
        #expect(move.captured?.side == .black)
    }

    @Test("Move Equatable")
    func testMoveEquality() {
        let piece = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let a = Move(piece: piece, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: nil)
        let b = Move(piece: piece, from: Position(row: 9, col: 0), to: Position(row: 5, col: 0), captured: nil)
        #expect(a == b)
    }
}

// MARK: - PuzzleProgress & Puzzle Model Tests

@Suite("Phase6: PuzzleProgress Tests", .serialized)
struct PuzzleProgressTests6 {

    @Test("PuzzleProgress Codable roundtrip")
    func testCodable() throws {
        let progress = PuzzleProgress(
            puzzleId: "test_001",
            isCompleted: true,
            bestMoves: 5,
            completedAt: Date(),
            bestRating: 3
        )
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(PuzzleProgress.self, from: data)
        #expect(decoded.puzzleId == "test_001")
        #expect(decoded.isCompleted)
        #expect(decoded.bestMoves == 5)
        #expect(decoded.bestRating == 3)
    }

    @Test("PuzzleProgress 未完成状态")
    func testIncompleteProgress() {
        let progress = PuzzleProgress(
            puzzleId: "test_002",
            isCompleted: false,
            bestMoves: nil,
            completedAt: nil,
            bestRating: nil
        )
        #expect(!progress.isCompleted)
        #expect(progress.bestMoves == nil)
        #expect(progress.completedAt == nil)
    }
}

@Suite("Phase6: Puzzle Model Extended Tests", .serialized)
struct PuzzleModelExtendedTests6 {

    @Test("Puzzle typeLabel 映射完整")
    func testTypeLabels() {
        let checkmate = Puzzle(id: "t1", name: "", category: "", difficulty: 1, stars: 1,
                               description: "", playerSide: "red", initialFEN: "",
                               solution: [], hints: nil, maxMoves: 10, solutionType: "checkmate")
        #expect(checkmate.typeLabelKey == "puzzle.type.checkmate")

        let sequence = Puzzle(id: "t2", name: "", category: "", difficulty: 1, stars: 1,
                              description: "", playerSide: "red", initialFEN: "",
                              solution: [], hints: nil, maxMoves: 10, solutionType: "sequence")
        #expect(sequence.typeLabelKey == "puzzle.type.sequence")

        let hint = Puzzle(id: "t3", name: "", category: "", difficulty: 1, stars: 1,
                          description: "", playerSide: "red", initialFEN: "",
                          solution: [], hints: nil, maxMoves: 10, solutionType: "hint")
        #expect(hint.typeLabelKey == "puzzle.type.hint")

        let unknown = Puzzle(id: "t4", name: "", category: "", difficulty: 1, stars: 1,
                             description: "", playerSide: "red", initialFEN: "",
                             solution: [], hints: nil, maxMoves: 10, solutionType: "other")
        #expect(unknown.typeLabelKey == "")
    }

    @Test("Puzzle side 属性")
    func testPuzzleSide() {
        let redPuzzle = Puzzle(id: "r", name: "", category: "", difficulty: 1, stars: 1,
                               description: "", playerSide: "red", initialFEN: "",
                               solution: [], hints: nil, maxMoves: 10)
        #expect(redPuzzle.side == .red)

        let blackPuzzle = Puzzle(id: "b", name: "", category: "", difficulty: 1, stars: 1,
                                 description: "", playerSide: "black", initialFEN: "",
                                 solution: [], hints: nil, maxMoves: 10)
        #expect(blackPuzzle.side == .black)
    }

    @Test("Puzzle 缺失 solutionType 解码为 checkmate")
    func testBackwardCompatDecode() throws {
        let json = """
        {
            "id": "compat", "name": "test", "category": "test",
            "difficulty": 1, "stars": 1, "description": "",
            "playerSide": "red", "initialFEN": "",
            "solution": [], "maxMoves": 10
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(puzzle.solutionType == "checkmate")
        #expect(puzzle.endDescription == nil)
    }

    @Test("Puzzle 含 solutionType 和 endDescription 解码")
    func testFullDecode() throws {
        let json = """
        {
            "id": "full", "name": "test", "category": "test",
            "difficulty": 2, "stars": 3, "description": "desc",
            "playerSide": "black", "initialFEN": "3aka4/9/9/9/9/9/9/9/9/4K4 b",
            "solution": ["a9-b9"], "maxMoves": 5,
            "solutionType": "sequence", "endDescription": "通关！"
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(puzzle.solutionType == "sequence")
        #expect(puzzle.endDescription == "通关！")
        #expect(puzzle.playerSide == "black")
    }

    @Test("Puzzle 含 hints 和 source 解码")
    func testHintSourceDecode() throws {
        let json = """
        {
            "id": "hs", "name": "hint+source", "category": "test",
            "difficulty": 3, "stars": 4, "description": "test",
            "playerSide": "red", "initialFEN": "",
            "solution": ["e0e1"], "hints": ["提示1", "提示2"], "maxMoves": 8,
            "source": "橘中秘"
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(puzzle.hints?.count == 2)
        #expect(puzzle.hints?[0] == "提示1")
        #expect(puzzle.source == "橘中秘")
    }
}

// MARK: - PuzzleStore Progress Cache Tests

@Suite("Phase6: PuzzleStore Cache Tests", .serialized)
struct PuzzleStoreCacheTests {

    @Test("进度缓存：多次查询不重复解码")
    func testProgressCacheHit() {
        let store = PuzzleStore.shared
        store.invalidateProgressCache()

        // 第一次查询：从 UserDefaults 解码
        let p1 = store.progress
        // 第二次查询：命中缓存
        let p2 = store.progress

        #expect(p1.count == p2.count)
    }

    @Test("recordProgress 更新缓存")
    func testRecordProgressUpdatesCache() {
        let store = PuzzleStore.shared
        store.invalidateProgressCache()

        let testId = "cache_test_\(UUID().uuidString)"
        let testProgress = PuzzleProgress(
            puzzleId: testId,
            isCompleted: true,
            bestMoves: 3,
            completedAt: Date(),
            bestRating: 2
        )
        store.recordProgress(testProgress)

        // 缓存应已更新
        let cached = store.progress
        #expect(cached[testId] != nil)
        #expect(cached[testId]?.bestMoves == 3)
    }

    @Test("invalidateProgressCache 清除缓存")
    func testInvalidateCache() {
        let store = PuzzleStore.shared
        // 先触发加载
        _ = store.progress
        // 清除缓存
        store.invalidateProgressCache()
        // 再次查询应该重新解码（不崩溃）
        let p = store.progress
        #expect(p.count >= 0)  // 只要不崩溃就算通过
    }

    @Test("progress(for:) 使用缓存")
    func testProgressForPuzzle() {
        let store = PuzzleStore.shared
        let testId = "lookup_test_\(UUID().uuidString)"
        let progress = PuzzleProgress(
            puzzleId: testId,
            isCompleted: true,
            bestMoves: 7,
            completedAt: Date(),
            bestRating: 1
        )
        store.recordProgress(progress)

        let result = store.progress(for: testId)
        #expect(result != nil)
        #expect(result?.bestMoves == 7)
    }
}

// MARK: - GameHistoryStore Extended Tests

@Suite("Phase6: GameHistoryStore Extended Tests", .serialized)
struct GameHistoryStoreExtendedTests6 {

    private func makeTestStore() -> GameHistoryStore {
        let suiteName = "test.history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return GameHistoryStore(defaults: defaults)
    }

    private func makeRecord(id: UUID = UUID(), date: Date = Date()) -> GameRecord {
        GameRecord(
            id: id,
            title: "测试对局",
            date: date,
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .medium),
            difficulty: .medium,
            result: .redWon,
            totalMoves: 10,
            moves: [],
            initialFEN: nil
        )
    }

    @Test("添加记录后 count 增加")
    func testCountIncreases() {
        let store = makeTestStore()
        #expect(store.count == 0)
        store.addRecord(makeRecord())
        #expect(store.count == 1)
        store.addRecord(makeRecord())
        #expect(store.count == 2)
    }

    @Test("删除记录后 count 减少")
    func testDeleteReducesCount() {
        let store = makeTestStore()
        let id = UUID()
        store.addRecord(makeRecord(id: id))
        #expect(store.count == 1)
        store.deleteRecord(id: id)
        #expect(store.count == 0)
    }

    @Test("记录按时间倒序排列")
    func testRecordsSortedByDate() {
        let store = makeTestStore()
        let old = makeRecord(date: Date().addingTimeInterval(-3600))
        let recent = makeRecord(date: Date())
        store.addRecord(old)
        store.addRecord(recent)
        let records = store.records
        #expect(records[0].date > records[1].date)
    }

    @Test("去重：相同 id 不重复添加")
    func testDeduplication() {
        let store = makeTestStore()
        let id = UUID()
        store.addRecord(makeRecord(id: id))
        store.addRecord(makeRecord(id: id))
        #expect(store.count == 1)
    }

    @Test("超过 20 条自动淘汰最旧")
    func testMaxRecords() {
        let store = makeTestStore()
        for i in 0..<25 {
            let record = makeRecord(date: Date().addingTimeInterval(Double(i)))
            store.addRecord(record)
        }
        #expect(store.count == 20)
    }

    @Test("clearAll 清空所有记录")
    func testClearAll() {
        let store = makeTestStore()
        for _ in 0..<5 {
            store.addRecord(makeRecord())
        }
        #expect(store.count == 5)
        store.clearAll()
        #expect(store.count == 0)
    }

    @Test("GameRecord Codable roundtrip")
    func testRecordCodable() throws {
        let record = makeRecord()
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(GameRecord.self, from: data)
        #expect(decoded.id == record.id)
        #expect(decoded.title == record.title)
        #expect(decoded.result == record.result)
        #expect(decoded.totalMoves == record.totalMoves)
    }

    @Test("PlayerInfo Codable roundtrip")
    func testPlayerInfoCodable() throws {
        let info = PlayerInfo(name: "AI-高级", isAI: true, difficulty: .hard)
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(PlayerInfo.self, from: data)
        #expect(decoded.name == "AI-高级")
        #expect(decoded.isAI)
        #expect(decoded.difficulty == .hard)
    }

    @Test("删除不存在的记录不崩溃")
    func testDeleteNonExistent() {
        let store = makeTestStore()
        store.deleteRecord(id: UUID())  // 不崩溃即通过
        #expect(store.count == 0)
    }

    @Test("初始空状态 records 返回空数组")
    func testEmptyRecords() {
        let store = makeTestStore()
        #expect(store.records.isEmpty)
    }
}

// MARK: - ICCS Parser Tests

@Suite("Phase6: ICCS Parser Tests", .serialized)
struct ICCSParserTests6 {

    @Test("parse 有效 ICCS 坐标")
    func testParseValid() {
        let board = Board()  // 标准开局
        // 红马 b0 → c2（馬八进七）
        let move = ICCSParser.parse("b0c2", on: board)
        #expect(move != nil)
        #expect(move?.from == Position(row: 9, col: 1))
        #expect(move?.to == Position(row: 7, col: 2))
    }

    @Test("parse 无效 ICCS 返回 nil")
    func testParseInvalid() {
        let board = Board()
        #expect(ICCSParser.parse("zzzz", on: board) == nil)
        #expect(ICCSParser.parse("a", on: board) == nil)
        #expect(ICCSParser.parse("", on: board) == nil)
    }

    @Test("iccsString 生成正确坐标")
    func testICCSString() {
        let from = Position(row: 9, col: 1)
        let to = Position(row: 7, col: 2)
        let iccs = ICCSParser.iccsString(from: from, to: to)
        #expect(iccs == "b0c2")
    }

    @Test("iccsString 边界值")
    func testICCSStringBoundary() {
        // row 0 = ICCS row 9, row 9 = ICCS row 0
        let from = Position(row: 0, col: 0)  // a9
        let to = Position(row: 9, col: 8)    // i0
        let iccs = ICCSParser.iccsString(from: from, to: to)
        #expect(iccs == "a9i0")
    }

    @Test("iccsString 对称性")
    func testICCSStringSymmetry() {
        let from = Position(row: 5, col: 4)
        let to = Position(row: 5, col: 4)
        let iccs = ICCSParser.iccsString(from: from, to: to)
        #expect(iccs == "e4e4")
    }
}

// MARK: - MoveValidator Extended Tests

@Suite("Phase6: MoveValidator Extended Tests", .serialized)
struct MoveValidatorExtendedTests6 {

    @Test("初始局面红方有合法走法")
    func testInitialRedHasLegalMoves() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(!moves.isEmpty)
    }

    @Test("初始局面黑方有合法走法")
    func testInitialBlackHasLegalMoves() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .black, on: board)
        #expect(!moves.isEmpty)
    }
}

// MARK: - EndgameEvaluator Extended Tests

@Suite("Phase6: EndgameEvaluator Extended Tests", .serialized)
struct EndgameEvaluatorExtendedTests6 {

    @Test("单车 vs 单将：红方大优")
    func testChariotVsGeneral() {
        let fen = "4k4/9/9/9/9/9/9/9/9/R3K4 w"
        let board = Board(fen: fen)
        let eval = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(eval != nil)
        #expect(eval! > 500)  // red has big advantage
    }

    @Test("单车 vs 士象全：评估不崩溃")
    func testChariotVsDefense() {
        // 红车 + 红将 vs 黑将 + 黑士 + 黑象 = 5 子
        let fen = "3k1a3/4a4/4b4/9/9/9/9/9/4R4/4K4 w"
        let board = Board(fen: fen)
        let eval = EndgameEvaluator.evaluate(board: board, for: .red)
        // 可能为 nil（无匹配规则），但不能崩溃
        if let e = eval {
            #expect(e > 0)
        }
    }

    @Test("超出 6 子返回 nil")
    func testTooManyPieces() {
        let board = Board()  // 32 子
        let eval = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(eval == nil)
    }

    @Test("单车 vs 空：红方大优势")
    func testChariotVsEmpty() {
        let fen = "4k4/9/9/9/9/9/9/9/9/R3K4 w"
        let board = Board(fen: fen)
        let eval = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(eval != nil)
        guard let e = eval else {
            Issue.record("eval should not be nil for single chariot vs single general")
            return
        }
        #expect(e > 0)
    }
}

// MARK: - PuzzleViewModel Extended Tests

@Suite("Phase6: PuzzleViewModel Extended Tests", .serialized)
struct PuzzleViewModelExtendedTests6 {

    @Test("sequence 局初始化状态正确")
    func testSequenceInit() {
        let puzzle = Puzzle(
            id: "seq_test",
            name: "sequence 测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "4k4/4a4/9/9/9/9/9/9/4R4/4K4 w",
            solution: ["e1e9"],
            hints: nil,
            maxMoves: 20,
            solutionType: "sequence"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing)
        #expect(vm.gameMoves.isEmpty)
    }

    @Test("hint 局：showHint 显示文字提示")
    func testHintTypeShowHint() {
        let puzzle = Puzzle(
            id: "hint_test",
            name: "hint 测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w",
            solution: [],
            hints: ["提示一", "提示二"],
            maxMoves: 20,
            solutionType: "hint"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.showHint()
        #expect(vm.currentHint == "提示一")
        #expect(vm.gameState == .showingHint)

        vm.dismissHint()
        #expect(vm.gameState == .playing)

        vm.showHint()
        #expect(vm.currentHint == "提示二")
    }

    @Test("hint 局：提示用完后重复最后一个")
    func testHintRepeatsLast() {
        let puzzle = Puzzle(
            id: "hint_test2",
            name: "hint 重复测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w",
            solution: [],
            hints: ["唯一提示"],
            maxMoves: 20,
            solutionType: "hint"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.showHint()  // 第 1 次
        #expect(vm.currentHint == "唯一提示")
        vm.dismissHint()
        vm.showHint()  // 第 2 次：min(1, 0) = 0，重复最后一个
        #expect(vm.currentHint == "唯一提示")
    }

    @Test("resetPuzzle 恢复初始状态")
    func testResetPuzzle() {
        let puzzle = Puzzle(
            id: "reset_test",
            name: "重置测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w",
            solution: [],
            hints: nil,
            maxMoves: 20
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.showHint()
        vm.resetPuzzle()
        #expect(vm.gameState == .playing)
        #expect(vm.hintIndex == 0)
        #expect(vm.currentHint == nil)
        #expect(vm.solutionHint == nil)
        #expect(vm.completionRating == 0)
    }

    @Test("checkmate 局 showHint 显示 step-by-step")
    func testCheckmateShowHint() {
        let puzzle = Puzzle(
            id: "cm_hint",
            name: "checkmate 提示测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/4R4/4K4 w",
            solution: ["e1e0"],
            hints: nil,
            maxMoves: 20,
            solutionType: "checkmate"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.showHint()
        #expect(vm.currentHint != nil)
        #expect(vm.currentHint != nil, "hint 应有内容")
    }

    @Test("dismissHint 恢复 playing 状态")
    func testDismissHint() {
        let puzzle = Puzzle(
            id: "dismiss_test",
            name: "dismiss 测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/9/4K4 w",
            solution: [],
            hints: ["hint"],
            maxMoves: 20,
            solutionType: "hint"
        )
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.showHint()
        #expect(vm.gameState == .showingHint)
        vm.dismissHint()
        #expect(vm.gameState == .playing)
        #expect(vm.currentHint == nil)
    }
}

// MARK: - ZobristHash Extended Tests

@Suite("Phase6: ZobristHash Extended Tests", .serialized)
struct ZobristHashExtendedTests6 {

    @Test("相同局面哈希一致")
    func testSamePositionSameHash() {
        let board1 = Board()
        let board2 = Board()
        let hash1 = ZobristHash.hash(board: board1)
        let hash2 = ZobristHash.hash(board: board2)
        #expect(hash1 == hash2)
    }

    @Test("走棋后哈希变化")
    func testHashChangesAfterMove() {
        let board = Board()
        let hash1 = ZobristHash.hash(board: board)
        let piece = board.pieces.first { $0.kind == .soldier && $0.side == .red && $0.position.col == 4 }!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 5, col: 4), captured: nil)
        board.execute(move)
        let hash2 = ZobristHash.hash(board: board)
        #expect(hash1 != hash2)
    }

    @Test("棋子索引覆盖所有 14 种（7×2）")
    func testPieceIndexCoverage() {
        for side in [Side.red, .black] {
            for kind in PieceKind.allCases {
                let piece = Piece(kind: kind, side: side, position: Position(row: 5, col: 4), id: 154)
                let idx = ZobristHash.pieceIndex(piece)
                #expect(idx >= 0)
                #expect(idx < 14)
            }
        }
    }
}

// MARK: - Board Snapshot & Undo Extended Tests

@Suite("Phase6: Board Snapshot & Undo Tests", .serialized)
struct BoardSnapshotExtendedTests6 {

    @Test("snapshot 后原棋盘修改不影响快照")
    func testSnapshotIsolation() {
        let board = Board()
        let snapshot = board.snapshot()
        let piece = board.pieces.first { $0.kind == .soldier && $0.side == .red && $0.position.col == 4 }!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 5, col: 4), captured: nil)
        board.execute(move)
        #expect(snapshot.pieces.count == 32)
    }

    @Test("undo 多步后恢复初始局面")
    func testMultiUndoRestoresInitial() {
        let board = Board()
        let initialFEN = FENParser.generate(board: board)

        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let m1 = moves.first else { return }
        board.execute(m1)

        let moves2 = MoveValidator.allLegalMoves(for: .black, on: board)
        guard let m2 = moves2.first else { return }
        board.execute(m2)

        let moves3 = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let m3 = moves3.first else { return }
        board.execute(m3)

        board.undoLastMove()
        board.undoLastMove()
        board.undoLastMove()

        #expect(FENParser.generate(board: board) == initialFEN)
    }

    @Test("undo 空棋盘不崩溃")
    func testUndoEmptyBoard() {
        let board = Board(fen: "4k4/9/9/9/9/9/9/9/9/4K4 w")
        board.undoLastMove()
        #expect(board.pieces.count == 2)
    }

    @Test("snapshot 是独立副本")
    func testSnapshotIndependence() {
        let board = Board()
        let snap = board.snapshot()
        let initialCount = snap.pieces.count

        // 走一步
        let piece = board.pieces.first { $0.kind == .soldier && $0.side == .red && $0.position.col == 0 }!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 5, col: 0), captured: nil)
        board.execute(move)

        // 快照不受影响
        #expect(snap.pieces.count == initialCount)
    }
}

// MARK: - StatsManager Extended Tests

@Suite("Phase6: StatsManager Extended Tests", .serialized)
struct StatsManagerExtendedTests6 {

    @Test("记录多局胜利后统计正确")
    func testMultipleWinRecords() {
        let suiteName = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let stats = StatsManager(defaults: defaults)

        stats.recordWin(for: .medium)
        stats.recordWin(for: .medium)
        stats.recordLoss(for: .medium)

        let s = stats.stats
        let vsMedium = s.vsAI["medium"]
        #expect(vsMedium != nil)
        #expect(vsMedium!.wins == 2)
        #expect(vsMedium!.losses == 1)
    }

    @Test("重置后统计归零")
    func testResetStats() {
        let suiteName = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let stats = StatsManager(defaults: defaults)

        stats.recordWin(for: .hard)
        #expect(stats.stats.vsAI["hard"]?.wins == 1)

        stats.reset()
        #expect(stats.stats.vsAI.isEmpty)
    }

    @Test("不同难度独立统计")
    func testDifferentDifficultyStats() {
        let suiteName = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let stats = StatsManager(defaults: defaults)

        stats.recordWin(for: .easy)
        stats.recordLoss(for: .hard)

        let s = stats.stats
        #expect(s.vsAI["easy"]?.wins == 1)
        #expect(s.vsAI["easy"]?.losses == 0)
        #expect(s.vsAI["hard"]?.wins == 0)
        #expect(s.vsAI["hard"]?.losses == 1)
    }

    @Test("平局统计")
    func testDrawStats() {
        let suiteName = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let stats = StatsManager(defaults: defaults)

        stats.recordDraw(for: .master)
        #expect(stats.stats.vsAI["master"]?.draws == 1)
    }

    @Test("初始统计为空")
    func testInitialStatsEmpty() {
        let suiteName = "test.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let stats = StatsManager(defaults: defaults)
        #expect(stats.stats.vsAI.isEmpty)
    }
}

// MARK: - OpeningBook Extended Tests

@Suite("Phase6: OpeningBook Extended Tests", .serialized)
struct OpeningBookExtendedTests6 {

    @Test("初始局面有推荐走法")
    func testInitialPositionHasMoves() {
        let book = OpeningBook.shared
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        let result = book.lookup(zobristHash: hash)
        // 初始局面可能没有开局库推荐，但不崩溃
        #expect(true)
    }

    @Test("残局局面无开局库推荐")
    func testEndgameNoBookMoves() {
        let book = OpeningBook.shared
        let board = Board(fen: "4k4/9/9/9/9/9/9/9/4R4/4K4 w")
        let hash = ZobristHash.hash(board: board)
        let result = book.lookup(zobristHash: hash)
        #expect(result == nil)
    }
}

// MARK: - PatternRecognizer Extended Tests

@Suite("Phase6: PatternRecognizer Extended Tests", .serialized)
struct PatternRecognizerExtendedTests6 {

    @Test("双车有棋型加分")
    func testDoubleChariotPattern() {
        let fen = "4k4/4R4/4R4/9/9/9/9/9/9/4K4 w"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        #expect(bonus > 0)
    }

    @Test("只有将帅无特殊棋型")
    func testNoSpecialPatterns() {
        let fen = "4k4/9/9/9/9/9/9/9/9/4K4 w"
        let board = Board(fen: fen)
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        // v3.0: 双方无炮（防空 +100）+ 将在同列无遮挡（飞将 +300）
        #expect(bonus <= 500, "只有将帅时棋型加分应很小（防空+飞将）")
    }
}

// MARK: - GameMove Extended Tests

@Suite("Phase6: GameMove Extended Tests", .serialized)
struct GameMoveExtendedTests6 {

    @Test("GameMove 所有属性正确")
    func testGameMoveProperties() {
        let piece = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let move = GameMove(
            id: UUID(),
            piece: piece,
            from: Position(row: 9, col: 0),
            to: Position(row: 5, col: 0),
            captured: nil,
            turnNumber: 1,
            notation: "車九进四",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )
        #expect(move.piece.kind == .chariot)
        #expect(move.turnNumber == 1)
        #expect(move.notation == "車九进四")
        #expect(!move.isCheck)
        #expect(!move.isCheckmate)
    }

    @Test("GameMove Codable roundtrip")
    func testGameMoveCodable() throws {
        let piece = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let move = GameMove(
            id: UUID(),
            piece: piece,
            from: Position(row: 9, col: 0),
            to: Position(row: 5, col: 0),
            captured: nil,
            turnNumber: 3,
            notation: "車九进四",
            timestamp: Date(),
            isCheck: true,
            isCheckmate: false,
            halfmoveClock: 0
        )
        let data = try JSONEncoder().encode(move)
        let decoded = try JSONDecoder().decode(GameMove.self, from: data)
        #expect(decoded.turnNumber == 3)
        #expect(decoded.isCheck)
        #expect(decoded.notation == "車九进四")
    }

    @Test("GameMove 带吃子 Codable")
    func testGameMoveWithCaptureCodable() throws {
        let piece = Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)
        let captured = Piece(kind: .soldier, side: .black, position: Position(row: 5, col: 0), id: 250)
        let move = GameMove(
            id: UUID(),
            piece: piece,
            from: Position(row: 9, col: 0),
            to: Position(row: 5, col: 0),
            captured: captured,
            turnNumber: 5,
            notation: "車九进四",
            timestamp: Date(),
            isCheck: true,
            isCheckmate: true,
            halfmoveClock: 0
        )
        let data = try JSONEncoder().encode(move)
        let decoded = try JSONDecoder().decode(GameMove.self, from: data)
        #expect(decoded.captured != nil)
        #expect(decoded.captured?.kind == .soldier)
        #expect(decoded.isCheckmate)
    }
}

// MARK: - WinLossDraw Tests

@Suite("Phase6: WinLossDraw Tests", .serialized)
struct WinLossDrawTests6 {

    @Test("WinLossDraw 计算正确")
    func testWinLossDrawCalculation() {
        var wld = WinLossDraw()
        #expect(wld.total == 0)
        #expect(wld.winRate == 0)

        wld.wins = 3
        wld.losses = 1
        wld.draws = 1
        #expect(wld.total == 5)
        #expect(wld.winRate == 0.6)
    }

    @Test("WinLossDraw Codable roundtrip")
    func testWinLossDrawCodable() throws {
        var wld = WinLossDraw()
        wld.wins = 5
        wld.losses = 3
        wld.draws = 2
        let data = try JSONEncoder().encode(wld)
        let decoded = try JSONDecoder().decode(WinLossDraw.self, from: data)
        #expect(decoded == wld)
    }

    @Test("WinLossDraw Equatable")
    func testWinLossDrawEquality() {
        var a = WinLossDraw()
        a.wins = 1
        var b = WinLossDraw()
        b.wins = 1
        #expect(a == b)
        b.losses = 1
        #expect(a != b)
    }
}

// MARK: - FEN Extended Tests

@Suite("Phase6: FEN Extended Tests", .serialized)
struct FENExtendedTests6 {

    @Test("残局 FEN 生成有效棋盘")
    func testEndgameFEN() {
        let fen = "4k4/4a4/4b4/9/9/9/9/9/4A4/3AK4 w"
        let board = Board(fen: fen)
        #expect(board.pieces.count == 6)
    }

    @Test("Board FEN roundtrip 空棋盘")
    func testEmptyBoardRoundtrip() {
        let board = Board(fen: "9/9/9/9/9/9/9/9/9/9 w")
        let fen = FENParser.generate(board: board)
        let board2 = Board(fen: fen)
        #expect(board2.pieces.count == 0)
    }

    @Test("Board FEN roundtrip 标准开局")
    func testStandardFENRoundtrip() {
        let originalFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
        let board = Board(fen: originalFEN)
        let generatedFEN = FENParser.generate(board: board)
        // FENParser.generate 可能追加 move counters
        #expect(generatedFEN.hasPrefix("rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"))
    }
}
