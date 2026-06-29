import XCTest
@testable import ChineseChess

// MARK: - v3.7.0 Phase 1 Tests: 存储引擎 + 数据模型 + PGN 格式

final class V370Phase1Tests: XCTestCase {

    // ============================================================
    // 1. GameRecord Codable 向后兼容
    // ============================================================

    /// 旧格式 JSON（无 source/tags/puzzleId）解码不崩溃，且默认值正确
    func testGameRecord_OldFormatDecode_Defaults() throws {
        let oldJSON = """
        {
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "title": "第 1 局",
            "date": 700000000.0,
            "redPlayer": {"name": "玩家", "isAI": false, "difficulty": null},
            "blackPlayer": {"name": "AI-高级", "isAI": true, "difficulty": "hard"},
            "difficulty": "hard",
            "result": "redWon",
            "totalMoves": 10,
            "moves": [],
            "initialFEN": null
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let record = try JSONDecoder().decode(GameRecord.self, from: data)

        XCTAssertEqual(record.source, .versusAI, "source 应默认为 versusAI")
        XCTAssertEqual(record.tags, [], "tags 应默认为空数组")
        XCTAssertNil(record.puzzleId, "puzzleId 应默认为 nil")
        XCTAssertEqual(record.title, "第 1 局")
        XCTAssertEqual(record.totalMoves, 10)
    }

    /// 新格式 JSON（含所有字段）解码正确
    func testGameRecord_NewFormatDecode_AllFields() throws {
        let newJSON = """
        {
            "id": "B2C3D4E5-F6A7-8901-BCDE-F12345678901",
            "title": "残局练习",
            "date": 700000000.0,
            "redPlayer": {"name": "红方", "isAI": false, "difficulty": null},
            "blackPlayer": {"name": "黑方", "isAI": false, "difficulty": null},
            "difficulty": "medium",
            "result": "draw",
            "totalMoves": 5,
            "moves": [],
            "initialFEN": "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            "source": "puzzle",
            "tags": ["精彩", "复盘"],
            "puzzleId": "puzzle-001"
        }
        """
        let data = newJSON.data(using: .utf8)!
        let record = try JSONDecoder().decode(GameRecord.self, from: data)

        XCTAssertEqual(record.source, .puzzle)
        XCTAssertEqual(record.tags, ["精彩", "复盘"])
        XCTAssertEqual(record.puzzleId, "puzzle-001")
        XCTAssertEqual(record.result, .draw)
    }

    /// Round-trip: encode → decode 保持一致
    func testGameRecord_RoundTrip() throws {
        let record = sample(source: .puzzle, result: .redWon, tags: ["test"], puzzleId: "p-42")
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(GameRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.source, record.source)
        XCTAssertEqual(decoded.tags, record.tags)
        XCTAssertEqual(decoded.puzzleId, record.puzzleId)
        XCTAssertEqual(decoded.title, record.title)
        XCTAssertEqual(decoded.totalMoves, record.totalMoves)
    }

    /// 部分新字段（只有 source，没有 tags 和 puzzleId）
    func testGameRecord_PartialNewFields() throws {
        let partialJSON = """
        {
            "id": "C3D4E5F6-A7B8-9012-CDEF-123456789012",
            "title": "导入棋谱",
            "date": 700000000.0,
            "redPlayer": {"name": "红方", "isAI": false, "difficulty": null},
            "blackPlayer": {"name": "黑方", "isAI": false, "difficulty": null},
            "difficulty": "medium",
            "result": "redWon",
            "totalMoves": 3,
            "moves": [],
            "source": "imported"
        }
        """
        let data = partialJSON.data(using: .utf8)!
        let record = try JSONDecoder().decode(GameRecord.self, from: data)

        XCTAssertEqual(record.source, .imported)
        XCTAssertEqual(record.tags, [])
        XCTAssertNil(record.puzzleId)
    }

    // ============================================================
    // 2. RecordSource 枚举
    // ============================================================

    func testRecordSource_AllCases() {
        let allCases: [RecordSource] = [.versusAI, .puzzle, .imported, .freePlay]
        for source in allCases {
            let encoded = try? JSONEncoder().encode(source)
            XCTAssertNotNil(encoded)
            let decoded = try? JSONDecoder().decode(RecordSource.self, from: encoded!)
            XCTAssertEqual(decoded, source)
        }
    }

    // ============================================================
    // 3. FENParser.isStandardInitial
    // ============================================================

    func testFENParser_IsStandardInitial_True() {
        XCTAssertTrue(FENParser.isStandardInitial(FENParser.standardInitial))
    }

    func testFENParser_IsStandardInitial_NonStandard() {
        let nonStandard = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        XCTAssertFalse(FENParser.isStandardInitial(nonStandard))
    }

    func testFENParser_IsStandardInitial_InvalidFEN() {
        XCTAssertFalse(FENParser.isStandardInitial("invalid-fen"))
    }

    func testFENParser_IsStandardInitial_EmptyString() {
        XCTAssertFalse(FENParser.isStandardInitial(""))
    }

    // ============================================================
    // 4. GameRecordStore CRUD
    // ============================================================

    func testGameRecordStore_AddAndLoad() throws {
        let store = testStore()
        let record = sample(title: "测试对局")

        store.addRecord(record)

        XCTAssertEqual(store.count, 1)
        let loaded = store.loadRecord(id: record.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.title, "测试对局")
        XCTAssertEqual(loaded?.source, record.source)
    }

    func testGameRecordStore_Deduplication() throws {
        let store = testStore()
        let record = sample(title: "重复测试")

        store.addRecord(record)
        store.addRecord(record)

        XCTAssertEqual(store.count, 1, "同 id 重复添加应只保留一条")
    }

    func testGameRecordStore_UpdateRecord() throws {
        let store = testStore()
        let record = sample(title: "原标题")

        store.addRecord(record)
        var updated = record
        updated.title = "新标题"
        updated.tags = ["复盘"]
        store.updateRecord(updated)

        let loaded = store.loadRecord(id: record.id)
        XCTAssertEqual(loaded?.title, "新标题")
        XCTAssertEqual(loaded?.tags, ["复盘"])
    }

    func testGameRecordStore_DeleteRecord() throws {
        let store = testStore()
        let record = sample()

        store.addRecord(record)
        XCTAssertEqual(store.count, 1)

        store.deleteRecord(id: record.id)
        XCTAssertEqual(store.count, 0)
        XCTAssertNil(store.loadRecord(id: record.id))
    }

    func testGameRecordStore_ClearAll() throws {
        let store = testStore()

        for i in 0..<5 {
            store.addRecord(sample(title: "局\(i)"))
        }
        XCTAssertEqual(store.count, 5)

        store.clearAll()
        XCTAssertEqual(store.count, 0)
    }

    func testGameRecordStore_SummariesOrder() throws {
        let store = testStore()

        let older = sample(title: "旧局", date: Date(timeIntervalSince1970: 700000000))
        let newer = sample(title: "新局", date: Date(timeIntervalSince1970: 800000000))

        store.addRecord(older)
        store.addRecord(newer)

        let summaries = store.loadSummaries()
        XCTAssertEqual(summaries.first?.title, "新局")
        XCTAssertEqual(summaries.last?.title, "旧局")
    }

    func testGameRecordStore_ReloadSummaries() throws {
        let store = testStore()
        store.addRecord(sample(title: "持久化测试"))

        store.reloadSummaries()
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.loadSummaries().first?.title, "持久化测试")
    }

    func testGameRecordStore_LoadNonexistent() throws {
        let store = testStore()
        XCTAssertNil(store.loadRecord(id: UUID()))
    }

    func testGameRecordStore_DeleteNonexistent() throws {
        let store = testStore()
        store.deleteRecord(id: UUID())
        XCTAssertEqual(store.count, 0)
    }

    // ============================================================
    // 5. FENRebuilder
    // ============================================================

    func testFENRebuilder_InitialState() {
        let fen = FENParser.standardInitial
        let result = FENRebuilder.computeFEN(initialFEN: fen, moves: [], before: 0)
        XCTAssertEqual(result, fen, "index=0 应返回初始 FEN")
    }

    func testFENRebuilder_SingleMove() {
        let initialFEN = FENParser.standardInitial
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7)),
            from: Position(row: 7, col: 7),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )

        let result = FENRebuilder.computeFEN(initialFEN: initialFEN, moves: [move], before: 1)
        XCTAssertNotEqual(result, initialFEN)

        // 验证与手动执行一致
        let board = Board(fen: initialFEN)
        let piece = board.piece(at: Position(row: 7, col: 7))!
        let m = Move(piece: piece, from: Position(row: 7, col: 7), to: Position(row: 7, col: 4), captured: nil)
        board.execute(m)
        let expected = FENParser.generate(board: board)
        XCTAssertEqual(result, expected)
    }

    func testFENRebuilder_OutOfBounds() {
        let fen = FENParser.standardInitial
        let result = FENRebuilder.computeFEN(initialFEN: fen, moves: [], before: 5)
        XCTAssertEqual(result, fen, "越界 index 应返回初始 FEN")
    }

    func testFENRebuilder_ComputeAllFENs() {
        let initialFEN = FENParser.standardInitial
        let move1 = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7)),
            from: Position(row: 7, col: 7),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )

        let fens = FENRebuilder.computeAllFENs(initialFEN: initialFEN, moves: [move1])
        XCTAssertEqual(fens.count, 2, "1 步走法应产生 2 个 FEN（初始 + 走后）")
        XCTAssertEqual(fens[0], initialFEN)
    }

    func testFENRebuilder_InvalidFENFallback() {
        let invalidFEN = "totally-invalid"
        let result = FENRebuilder.computeFEN(initialFEN: invalidFEN, moves: [], before: 0)
        XCTAssertEqual(result, invalidFEN, "index=0 应返回传入的 FEN（即使无效）")
    }

    // ============================================================
    // 6. PGN 导出
    // ============================================================

    func testPGNExport_BasicStructure() {
        let record = sample(source: .versusAI)
        let pgn = PGNExporter.export(record)

        XCTAssertTrue(pgn.contains("[Event \"人机对弈\"]"))
        XCTAssertTrue(pgn.contains("[Site \"中国象棋\"]"))
        XCTAssertTrue(pgn.contains("[Red \"玩家\"]"))
        XCTAssertTrue(pgn.contains("[Black \"AI-高级\"]"))
        XCTAssertTrue(pgn.contains("[Result \"1-0\"]"))
        XCTAssertTrue(pgn.contains("[Format \"ICCS\"]"))
        XCTAssertTrue(pgn.contains("[Source \"versusAI\"]"))
    }

    func testPGNExport_PuzzleRecord() {
        let record = sample(source: .puzzle, puzzleId: "puz-1")
        let pgn = PGNExporter.export(record)

        XCTAssertTrue(pgn.contains("[Event \"残局练习\"]"))
        XCTAssertTrue(pgn.contains("[PuzzleId \"puz-1\"]"))
        XCTAssertTrue(pgn.contains("[Source \"puzzle\"]"))
    }

    func testPGNExport_ImportedSource_NoDifficultyTag() {
        let record = sample(source: .imported, difficulty: .hard)
        let pgn = PGNExporter.export(record)

        XCTAssertTrue(pgn.contains("[Event \"导入棋谱\"]"))
        XCTAssertFalse(pgn.contains("[Difficulty"), "imported 来源不应输出 Difficulty 标签")
        XCTAssertTrue(pgn.contains("[Source \"imported\"]"))
    }

    func testPGNExport_StandardInitial_NoFENTag() {
        let record = sample(initialFEN: FENParser.standardInitial)
        let pgn = PGNExporter.export(record)

        XCTAssertFalse(pgn.contains("[FEN"), "标准开局不应输出 FEN 标签")
    }

    func testPGNExport_NonStandardInitial_WithFENTag() {
        let customFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let record = sample(initialFEN: customFEN)
        let pgn = PGNExporter.export(record)

        XCTAssertTrue(pgn.contains("[FEN \""), "非标准开局应输出 FEN 标签")
    }

    func testPGNExport_ICCSMapping() {
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7)),
            from: Position(row: 7, col: 7),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )
        let record = sample(moves: [move])
        let pgn = PGNExporter.export(record)

        XCTAssertTrue(pgn.contains("1. h2e2"), "ICCS 走法应为 h2e2（row 7 → ICCS row 2）")
    }

    func testPGNExport_ICCSMapping_Row0AndRow9() {
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0)),
            from: Position(row: 9, col: 0),
            to: Position(row: 5, col: 0),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )
        let record = sample(moves: [move])
        let pgn = PGNExporter.export(record)

        XCTAssertTrue(pgn.contains("a0a4"), "row=9 → ICCS 0, row=5 → ICCS 4")
    }

    func testPGNExport_ResultMarkers() {
        let blackWonRecord = sample(result: .blackWon)
        XCTAssertTrue(PGNExporter.export(blackWonRecord).contains("0-1"))

        let drawRecord = sample(result: .draw)
        XCTAssertTrue(PGNExporter.export(drawRecord).contains("1/2-1/2"))

        let playingRecord = sample(result: .playing)
        XCTAssertTrue(PGNExporter.export(playingRecord).contains("*"))
    }

    func testPGNExport_BatchExport() {
        let records = [sample(title: "局1"), sample(title: "局2")]
        let pgn = PGNExporter.exportBatch(records)
        let gameCount = pgn.components(separatedBy: "[Event ").count - 1
        XCTAssertEqual(gameCount, 2, "批量导出应产生 2 局")
    }

    func testPGNExport_BatchSafeExport() {
        let emptyRecord = sample(moves: [])
        let normalRecord = sample(moves: oneMoveList())

        let (pgn, failedCount) = PGNExporter.exportBatchSafe([emptyRecord, normalRecord])
        XCTAssertEqual(failedCount, 1, "空走法记录应算作失败")
        XCTAssertTrue(pgn.contains("[Red \"玩家\"]"), "正常记录应仍在输出中")
    }

    // ============================================================
    // 7. PGN 导入
    // ============================================================

    func testPGNImport_SingleGame() {
        let pgn = """
        [Event "人机对弈"]
        [Site "中国象棋"]
        [Date "2026.01.15"]
        [Round "1"]
        [Red "测试红方"]
        [Black "测试黑方"]
        [Result "1-0"]
        [Format "ICCS"]
        [Source "versusAI"]

        1. h2e2 b9c7 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.warnings.count, 0)

        let record = result.records[0]
        XCTAssertEqual(record.redPlayer.name, "测试红方")
        XCTAssertEqual(record.blackPlayer.name, "测试黑方")
        XCTAssertEqual(record.result, .redWon)
        XCTAssertEqual(record.source, .versusAI)
        XCTAssertEqual(record.moves.count, 2, "应解析出 2 步走法")
    }

    func testPGNImport_DefaultValues() {
        let pgn = """
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        let record = result.records[0]
        XCTAssertEqual(record.title, "导入棋谱", "缺少 Event 标签应默认为 '导入棋谱'")
        XCTAssertEqual(record.source, .imported, "缺少 Source 标签应默认为 imported")
        XCTAssertEqual(record.difficulty, .medium, "缺少 Difficulty 标签应默认为 medium")
    }

    func testPGNImport_MultipleGames() {
        let pgn = """
        [Event "局1"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 1-0

        [Event "局2"]
        [Red "红方"]
        [Black "黑方"]
        [Result "0-1"]

        1. i9i7 0-1
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 2, "应解析出 2 局")
        XCTAssertEqual(result.records[0].title, "局1")
        XCTAssertEqual(result.records[1].title, "局2")
    }

    func testPGNImport_IllegalMove_SkipsGame() {
        let pgn = """
        [Event "非法走法局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. z9z9 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 0, "非法走法应导致该局被跳过")
        XCTAssertTrue(result.warnings.count > 0, "应有警告信息")
    }

    func testPGNImport_FENTag_NonStandard() {
        let customFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let pgn = """
        [Event "残局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [FEN "\(customFEN)"]
        [Source "puzzle"]

        1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records[0].initialFEN, customFEN)
    }

    func testPGNImport_FENTag_Standard_ShouldBeNull() {
        let pgn = """
        [Event "标准开局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [FEN "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"]
        [Source "versusAI"]

        1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        XCTAssertNil(result.records[0].initialFEN, "非 imported 来源 + 标准开局 → initialFEN 应为 nil")
    }

    func testPGNImport_ImportedSource_StandardFEN_ShouldKeep() {
        let standardFEN = FENParser.standardInitial
        let pgn = """
        [Event "导入"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [FEN "\(standardFEN)"]
        [Source "imported"]

        1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        XCTAssertNotNil(result.records[0].initialFEN, "imported 来源有 FEN 标签时，应保留 initialFEN")
    }

    func testPGNImport_ImportedSource_NoFENTag_ShouldBeNull() {
        let pgn = """
        [Event "导入"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [Source "imported"]

        1. h2e2 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        XCTAssertNil(result.records[0].initialFEN, "imported 来源无 FEN 标签 → initialFEN 应为 nil")
    }

    func testPGNImport_PuzzleId() {
        let pgn = """
        [Event "残局练习"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [PuzzleId "puzzle-42"]
        [Source "puzzle"]

        1-0
        """
        let result = PGNImporter.parse(pgn)
        XCTAssertEqual(result.records[0].puzzleId, "puzzle-42")
    }

    func testPGNImport_DateParsing() {
        let pgn = """
        [Event "测试日期"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [Date "2026.07.11"]

        1-0
        """
        let result = PGNImporter.parse(pgn)
        let record = result.records[0]

        let calendar = Calendar.current
        let year = calendar.component(.year, from: record.date)
        XCTAssertEqual(year, 2026)
    }

    func testPGNImport_InvalidDate_Fallback() {
        let pgn = """
        [Event "无效日期"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]
        [Date "????.??.??"]

        1-0
        """
        let result = PGNImporter.parse(pgn)
        let record = result.records[0]

        let now = Date()
        XCTAssertLessThanOrEqual(abs(record.date.timeIntervalSince(now)), 60, "无效日期应 fallback 到当前时间")
    }

    func testPGNImport_UnknownResult_Playing() {
        let pgn = """
        [Event "未知结果"]
        [Red "红方"]
        [Black "黑方"]
        [Result "abandoned"]

        1. h2e2 *
        """
        let result = PGNImporter.parse(pgn)
        XCTAssertEqual(result.records[0].result, .playing, "未知结果标记应视为 playing")
    }

    // ============================================================
    // 8. PGN Round-trip（导出 → 导入）
    // ============================================================

    func testPGNRoundTrip_StandardGame() {
        let original = sample(source: .versusAI, tags: ["精彩"])

        let pgn = PGNExporter.export(original)
        let importResult = PGNImporter.parse(pgn)

        XCTAssertEqual(importResult.records.count, 1)
        let imported = importResult.records[0]

        XCTAssertEqual(imported.redPlayer.name, original.redPlayer.name)
        XCTAssertEqual(imported.blackPlayer.name, original.blackPlayer.name)
        XCTAssertEqual(imported.result, original.result)
        XCTAssertEqual(imported.source, original.source)
        XCTAssertEqual(imported.moves.count, original.moves.count)
    }

    func testPGNRoundTrip_PuzzleGame() {
        let customFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let original = sample(source: .puzzle, result: .draw, initialFEN: customFEN, puzzleId: "puz-99")

        let pgn = PGNExporter.export(original)
        let importResult = PGNImporter.parse(pgn)

        XCTAssertEqual(importResult.records.count, 1)
        let imported = importResult.records[0]

        XCTAssertEqual(imported.source, .puzzle)
        XCTAssertEqual(imported.puzzleId, "puz-99")
        XCTAssertEqual(imported.result, .draw)
        XCTAssertEqual(imported.initialFEN, customFEN)
    }

    func testPGNRoundTrip_WithMoves() {
        let move1 = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7)),
            from: Position(row: 7, col: 7),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )
        let move2 = GameMove(
            id: UUID(),
            piece: Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1)),
            from: Position(row: 0, col: 1),
            to: Position(row: 2, col: 2),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )

        let original = sample(moves: [move1, move2])

        let pgn = PGNExporter.export(original)
        let importResult = PGNImporter.parse(pgn)

        XCTAssertEqual(importResult.records.count, 1)
        let imported = importResult.records[0]

        XCTAssertEqual(imported.moves.count, 2)
        XCTAssertEqual(imported.moves[0].from, Position(row: 7, col: 7))
        XCTAssertEqual(imported.moves[0].to, Position(row: 7, col: 4))
        XCTAssertEqual(imported.moves[1].from, Position(row: 0, col: 1))
        XCTAssertEqual(imported.moves[1].to, Position(row: 2, col: 2))
    }

    // ============================================================
    // 9. PGN 导入容错
    // ============================================================

    func testPGNImport_MultipleGames_PartialFailure() {
        let pgn = """
        [Event "合法局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 1-0

        [Event "非法局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. z9z9 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1, "应只保留合法局")
        XCTAssertEqual(result.records[0].title, "合法局")
        XCTAssertTrue(result.warnings.count > 0, "非法局应产生警告")
    }

    func testPGNImport_EmptyInput() {
        let result = PGNImporter.parse("")
        XCTAssertEqual(result.records.count, 0)
        XCTAssertEqual(result.warnings.count, 0)
    }

    func testPGNImport_CommentsAndAnnotationsIgnored() {
        let pgn = """
        [Event "注释测试"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 {好棋} b9c7 (1... a9a7) 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records[0].moves.count, 2, "注释和变着不应计入走法")
    }

    func testPGNImport_MoveTokenTooShort() {
        let pgn = """
        [Event "短token"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. ab 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 0, "短 token 应视为非法走法")
        XCTAssertTrue(result.warnings.count > 0)
    }

    func testPGNImport_ICCSRowRangeValidation() {
        // ICCS 列 a-i 合法，j 超出范围
        let pgn = """
        [Event "越界列号"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. j0e2 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 0, "ICCS 列 j 应视为非法")
        XCTAssertTrue(result.warnings.count > 0)
    }

    func testPGNImport_ICCSRowZero_IsLegal() {
        // 5fc9567 修正：ICCS 行号范围 0-9（P1-2 的 1-9 限制是错的）
        // b0c2 = 黑方马从 row=0(黑方底线) 起步，是合法走法
        let pgn = """
        [Event "ICCS row=0"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 b0c2 1-0
        """
        let result = PGNImporter.parse(pgn)

        XCTAssertEqual(result.records.count, 1, "ICCS 行号 0 应合法")
        XCTAssertEqual(result.records[0].moves.count, 2, "应解析出 2 步走法")
        // b0c2: ICCS col b=1, row 0 → Board row=9-0=9, col=1 → (9,1)
        //        ICCS col c=2, row 2 → Board row=9-2=7, col=2 → (7,2)
        XCTAssertEqual(result.records[0].moves[1].from, Position(row: 9, col: 1))
        XCTAssertEqual(result.records[0].moves[1].to, Position(row: 7, col: 2))
    }

    // ============================================================
    // 10. GameHistoryStore deprecated 标记
    // ============================================================

    func testGameHistoryStore_DeprecatedAnnotation() {
        let defaults = UserDefaults(suiteName: "test.deprecated.v370")!
        let store = GameHistoryStore(defaults: defaults)
        XCTAssertEqual(store.count, 0)
        defaults.removeSuite(named: "test.deprecated.v370")
    }

    // ============================================================
    // 11. RecordSummary
    // ============================================================

    func testRecordSummary_FromRecord() {
        let record = sample(source: .puzzle, difficulty: .hard, result: .draw)
        let summary = RecordSummary(from: record)

        XCTAssertEqual(summary.id, record.id)
        XCTAssertEqual(summary.title, record.title)
        XCTAssertEqual(summary.date, record.date)
        XCTAssertEqual(summary.result, GameState.draw)
        XCTAssertEqual(summary.totalMoves, record.totalMoves)
        XCTAssertEqual(summary.difficulty, AIDifficulty.hard)
        XCTAssertEqual(summary.source, RecordSource.puzzle)
    }

    // ============================================================
    // 12. 边界测试
    // ============================================================

    func testGameRecordStore_LargeNumberOfRecords() {
        let store = testStore()

        for i in 0..<100 {
            store.addRecord(sample(title: "局\(i)"))
        }
        XCTAssertEqual(store.count, 100)

        let midRecord = store.loadSummaries()[50]
        store.deleteRecord(id: midRecord.id)
        XCTAssertEqual(store.count, 99)
    }

    func testGameRecord_EmptyTags() {
        let record = sample(tags: [])
        XCTAssertTrue(record.tags.isEmpty)
    }

    func testGameRecord_NilPuzzleId() {
        let record = sample(puzzleId: nil)
        XCTAssertNil(record.puzzleId)
    }

    func testPGNExport_EmptyMoves_StillExports() {
        let record = sample(moves: [])
        let pgn = PGNExporter.export(record)
        XCTAssertTrue(pgn.contains("[Event"))
    }

    // ============================================================
    // Helpers — 使用内部构建器避免参数顺序问题
    // ============================================================

    /// 构建测试用 GameRecord，所有字段都有默认值
    private func sample(
        title: String = "测试对局",
        date: Date = Date(),
        source: RecordSource = .versusAI,
        difficulty: AIDifficulty = .hard,
        result: GameState = .redWon,
        initialFEN: String? = nil,
        moves: [GameMove] = [],
        tags: [String] = [],
        puzzleId: String? = nil
    ) -> GameRecord {
        GameRecord(
            title: title,
            date: date,
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI-高级", isAI: true, difficulty: difficulty),
            difficulty: difficulty,
            result: result,
            totalMoves: moves.count,
            moves: moves,
            initialFEN: initialFEN,
            source: source,
            tags: tags,
            puzzleId: puzzleId
        )
    }

    /// 含 1 步走法的列表
    private func oneMoveList() -> [GameMove] {
        [GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7)),
            from: Position(row: 7, col: 7),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1, notation: "", timestamp: Date(), isCheck: false, isCheckmate: false
        )]
    }

    /// 使用 shared 实例测试（测试前清空，测试后不清理以防影响其他测试）
    private func testStore() -> GameRecordStore {
        let store = GameRecordStore.shared
        store.clearAll()
        return store
    }
}
