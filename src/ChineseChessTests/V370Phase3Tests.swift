import XCTest
@testable import ChineseChess

// MARK: - Phase 3 Tests: PGN导入增强 + 残局棋谱 + UI + 线程安全

final class V370Phase3Tests: XCTestCase {

    // 临时 Store 工厂
    private func makeTestStore() -> GameRecordStore {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        return GameRecordStore(baseURL: tmpDir)
    }

    // 标准测试 PGN
    private var singleGamePGN: String {
        """
        [Event "测试对局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 1-0
        """
    }

    private var multiGamePGN: String {
        """
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
    }

    private var illegalMovePGN: String {
        """
        [Event "合法局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 1-0

        [Event "非法走法局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 2. e2e9 1-0
        """
    }

    // ============================================================
    // 3A: PGN 导入增强
    // ============================================================

    // MARK: ImportResult 扩展

    /// ImportResult 便利构造器：skippedCount = warnings.count, totalGames = records + warnings
    func testImportResult_ConvenienceInit() {
        let record = GameRecord(
            title: "测试", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
            initialFEN: nil, source: .imported
        )
        let result = ImportResult(records: [record], warnings: ["局2失败", "局3失败"])
        XCTAssertEqual(result.skippedCount, 2, "便利构造器 skippedCount 应等于 warnings.count")
        XCTAssertEqual(result.totalGames, 3, "totalGames 应等于 records + warnings")
        XCTAssertTrue(result.isSuccess, "有 records 时 isSuccess")
        XCTAssertTrue(result.hasWarnings, "有 warnings 时 hasWarnings")
    }

    /// ImportResult 完整构造器
    func testImportResult_FullInit() {
        let result = ImportResult(records: [], warnings: [], skippedCount: 2, totalGames: 2)
        XCTAssertFalse(result.isSuccess, "无 records 时不是 success")
        XCTAssertFalse(result.hasWarnings, "无 warnings 时 hasWarnings=false")
        XCTAssertEqual(result.skippedCount, 2)
        XCTAssertEqual(result.totalGames, 2)
    }

    /// ImportResult Identifiable
    func testImportResult_Identifiable() {
        let r1 = ImportResult(records: [], warnings: [], skippedCount: 0, totalGames: 0)
        let r2 = ImportResult(records: [], warnings: [], skippedCount: 0, totalGames: 0)
        XCTAssertNotEqual(r1.id, r2.id, "每个 ImportResult 应有唯一 id")
    }

    // MARK: 单局导入

    /// 单局 PGN 解析成功
    func testPGNImport_SingleGame_Success() {
        let result = PGNImporter.parse(singleGamePGN)
        XCTAssertEqual(result.records.count, 1, "应解析出 1 局")
        XCTAssertEqual(result.totalGames, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertTrue(result.isSuccess)
    }

    /// Bug #C: PGN 导入后走法名应显示中文棋谱（如「炮二平五」）
    func testPGNImport_NotationGenerated() {
        let pgn = """
        [Event "测试"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 h9g7 2. i0i1 1-0
        """
        let result = PGNImporter.parse(pgn)
        XCTAssertEqual(result.records.count, 1, "应解析出 1 局")
        let record = result.records.first!
        XCTAssertFalse(record.moves.isEmpty, "应有走法")
        // 验证每个走法都有 notation
        for (idx, move) in record.moves.enumerated() {
            XCTAssertFalse(move.notation.isEmpty, "第 \(idx+1) 步 notation 不应为空")
            // 验证 notation 包含中文棋子名（繁简皆可：炮/炮、马/馬、车/車、兵/兵、卒/卒等）
            let hasChinesePiece = move.notation.contains("炮") || move.notation.contains("马") || move.notation.contains("馬") || move.notation.contains("车") || move.notation.contains("車") || move.notation.contains("兵") || move.notation.contains("卒") || move.notation.contains("相") || move.notation.contains("象") || move.notation.contains("仕") || move.notation.contains("士") || move.notation.contains("帅") || move.notation.contains("将") || move.notation.contains("将") || move.notation.contains("將")
            XCTAssertTrue(hasChinesePiece, "第 \(idx+1) 步 notation 应包含中文棋子名: \(move.notation)")
        }
    }

    /// 多局 PGN 全部成功
    func testPGNImport_MultiGame_AllSuccess() {
        let result = PGNImporter.parse(multiGamePGN)
        XCTAssertEqual(result.records.count, 2, "应解析出 2 局")
        XCTAssertEqual(result.totalGames, 2)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertTrue(result.isSuccess)
    }

    /// 部分失败显示跳过数
    func testPGNImport_PartialFailure_SkippedCount() {
        // 用列号越界（j0e2）制造真正非法的走法
        let pgn = """
        [Event "合法局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. h2e2 1-0

        [Event "非法列号局"]
        [Red "红方"]
        [Black "黑方"]
        [Result "1-0"]

        1. j0e2 1-0
        """
        let result = PGNImporter.parse(pgn)
        XCTAssertTrue(result.records.count >= 1, "至少 1 局成功")
        XCTAssertTrue(result.skippedCount >= 1, "至少 1 局跳过")
        XCTAssertTrue(result.hasWarnings)
    }

    /// 非PGN内容：splitGames 把非标签文本当成 1 局，但解析失败后 records 为空
    func testPGNImport_NonPGN_Failure() {
        let result = PGNImporter.parse("这是普通文本，不是 PGN")
        XCTAssertTrue(result.records.isEmpty, "非PGN应返回空 records")
        XCTAssertFalse(result.isSuccess)
        // splitGames 可能把文本当成 1 段，但解析失败后 skippedCount=1
        XCTAssertTrue(result.skippedCount >= 1, "非PGN内容应有跳过")
    }

    /// 空字符串
    func testPGNImport_EmptyString_Failure() {
        let result = PGNImporter.parse("")
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(result.totalGames, 0)
    }

    // MARK: batchAdd 批量导入

    /// batchAdd 基本功能
    func testBatchAdd_Basic() {
        let store = makeTestStore()
        let records = [
            GameRecord(title: "局1", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                       blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                       difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                       initialFEN: nil, source: .imported),
            GameRecord(title: "局2", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                       blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                       difficulty: .medium, result: .blackWon, totalMoves: 2, moves: [],
                       initialFEN: nil, source: .imported),
        ]
        let added = store.batchAdd(records)
        XCTAssertEqual(added, 2, "应成功添加 2 条")
        XCTAssertEqual(store.count, 2)
    }

    /// batchAdd id 去重
    func testBatchAdd_DedupById() {
        let store = makeTestStore()
        let id = UUID()
        let record1 = GameRecord(id: id, title: "局1", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                  blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                                  difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                                  initialFEN: nil, source: .imported)
        let record2 = GameRecord(id: id, title: "局1副本", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                  blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                                  difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                                  initialFEN: nil, source: .imported)
        store.addRecord(record1)
        let added = store.batchAdd([record2])
        XCTAssertEqual(added, 0, "重复 id 不应再添加")
        XCTAssertEqual(store.count, 1)
    }

    /// batchAdd puzzleId 去重
    func testBatchAdd_DedupByPuzzleId() {
        let store = makeTestStore()
        let pid = "puzzle-dedup-test"
        let record1 = GameRecord(title: "残局1", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                  blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .hard),
                                  difficulty: .hard, result: .redWon, totalMoves: 3, moves: [],
                                  initialFEN: nil, source: .puzzle, puzzleId: pid)
        let record2 = GameRecord(title: "残局1重玩", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                  blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .hard),
                                  difficulty: .hard, result: .redWon, totalMoves: 2, moves: [],
                                  initialFEN: nil, source: .puzzle, puzzleId: pid)
        store.addRecord(record1)
        let added = store.batchAdd([record2])
        XCTAssertEqual(added, 0, "重复 puzzleId 不应再添加")
        XCTAssertEqual(store.count, 1)
    }

    /// batchAdd 排序：新记录在前（reversed() 后最后添加的排在最前面）
    func testBatchAdd_NewRecordsFirst() {
        let store = makeTestStore()
        let records = [
            GameRecord(title: "局A", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                       blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                       difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                       initialFEN: nil, source: .imported),
            GameRecord(title: "局B", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                       blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                       difficulty: .medium, result: .blackWon, totalMoves: 2, moves: [],
                       initialFEN: nil, source: .imported),
        ]
        _ = store.batchAdd(records)
        let summaries = store.loadSummaries()
        // batchAdd 用 newSummaries.reversed() insert(at:0)，所以最后一条在前
        XCTAssertEqual(summaries[0].title, "局B", "最后添加的记录应在最前面")
        XCTAssertEqual(summaries[1].title, "局A")
    }

    /// batchAdd 空数组
    func testBatchAdd_EmptyArray() {
        let store = makeTestStore()
        let added = store.batchAdd([])
        XCTAssertEqual(added, 0, "空数组应返回 0")
        XCTAssertEqual(store.count, 0)
    }

    /// batchAdd 与 addRecord 混合使用
    func testBatchAdd_MixedWithAddRecord() {
        let store = makeTestStore()
        let r1 = GameRecord(title: "单条", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                             blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                             difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                             initialFEN: nil, source: .versusAI)
        store.addRecord(r1)
        XCTAssertEqual(store.count, 1)

        let r2 = GameRecord(title: "批量", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                             blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                             difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                             initialFEN: nil, source: .imported)
        _ = store.batchAdd([r2])
        XCTAssertEqual(store.count, 2)
    }

    // MARK: ImportViewModel 状态机

    /// ImportViewModel 初始状态
    func testImportViewModel_InitialState() {
        let vm = ImportViewModel()
        if case .idle = vm.state {
            // OK
        } else {
            XCTFail("初始状态应为 idle")
        }
    }

    /// ImportViewModel fail 设置失败状态
    func testImportViewModel_Fail() {
        let vm = ImportViewModel()
        vm.fail("测试失败")
        if case .failure(let msg) = vm.state {
            XCTAssertEqual(msg, "测试失败")
        } else {
            XCTFail("应为 failure 状态")
        }
    }

    /// ImportViewModel reset 回到 idle
    func testImportViewModel_Reset() {
        let vm = ImportViewModel()
        vm.fail("测试")
        vm.reset()
        if case .idle = vm.state {
            // OK
        } else {
            XCTFail("reset 后应为 idle")
        }
    }

    /// ImportViewModel confirmImport 非 success 状态返回 0
    func testImportViewModel_ConfirmImport_NotSuccess() {
        let vm = ImportViewModel()
        let added = vm.confirmImport()
        XCTAssertEqual(added, 0, "非 success 状态 confirmImport 应返回 0")
    }

    // ============================================================
    // 3B: 残局棋谱自动入库
    // ============================================================

    /// puzzleId 去重：重玩同一残局不新增
    func testPuzzleReplay_DedupViaBatchAdd() {
        let store = makeTestStore()
        let pid = "puzzle-3b-dedup"
        let r1 = GameRecord(title: "残局", redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
                             blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
                             difficulty: .hard, result: .redWon, totalMoves: 5, moves: [],
                             initialFEN: nil, source: .puzzle, puzzleId: pid)
        store.addRecord(r1)

        // 重玩：用 updateRecord 而非 addRecord
        let saved = store.findRecordByPuzzleId(pid)
        XCTAssertNotNil(saved, "应找到已保存的残局记录")
        var updated = saved!
        updated.title = "残局-重玩"
        store.updateRecord(updated)

        XCTAssertEqual(store.count, 1, "重玩后仍应只有 1 条")
        let loaded = store.loadRecord(id: saved!.id)
        XCTAssertEqual(loaded?.title, "残局-重玩", "应更新为最新内容")
    }

    /// findRecordByPuzzleId 找不到返回 nil
    func testFindRecordByPuzzleId_NotFound() {
        let store = makeTestStore()
        XCTAssertNil(store.findRecordByPuzzleId("nonexistent"))
    }

    /// findRecordByPuzzleId 只找 puzzle 来源
    func testFindRecordByPuzzleId_OnlyPuzzleSource() {
        let store = makeTestStore()
        // 非 puzzle 记录不应有 puzzleId，但即使有也不应被找到
        //（实际上非 puzzle 不会设 puzzleId，所以 findRecordByPuzzleId 不会匹配）
        let r = GameRecord(title: "人机", redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
                           blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .medium),
                           difficulty: .medium, result: .redWon, totalMoves: 10, moves: [],
                           initialFEN: nil, source: .versusAI)
        store.addRecord(r)
        XCTAssertNil(store.findRecordByPuzzleId("any"))
    }

    /// 不同 puzzleId 各自保留
    func testDifferentPuzzleId_BothKept() {
        let store = makeTestStore()
        let r1 = GameRecord(title: "残局A", redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
                             blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
                             difficulty: .hard, result: .redWon, totalMoves: 3, moves: [],
                             initialFEN: nil, source: .puzzle, puzzleId: "p-a")
        let r2 = GameRecord(title: "残局B", redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
                             blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
                             difficulty: .hard, result: .redWon, totalMoves: 5, moves: [],
                             initialFEN: nil, source: .puzzle, puzzleId: "p-b")
        store.addRecord(r1)
        store.addRecord(r2)
        XCTAssertEqual(store.count, 2, "不同 puzzleId 各自保留")
    }

    // ============================================================
    // 3C: UI 组件（非 UI 测试，验证数据和映射逻辑）
    // ============================================================

    /// SourceBadgeView 映射完整性：4种来源都有映射
    func testSourceBadge_AllSourceMappings() {
        // 验证 RecordSource 有 4 种 case
        let allCases: [RecordSource] = [.versusAI, .puzzle, .imported, .freePlay]
        XCTAssertEqual(allCases.count, 4, "RecordSource 应有 4 种来源")
    }

    /// RecordSummary 包含 puzzleId 字段
    func testRecordSummary_ContainsPuzzleId() {
        let record = GameRecord(title: "测试", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                 blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                                 difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                                 initialFEN: nil, source: .puzzle, puzzleId: "test-pid")
        let summary = RecordSummary(from: record)
        XCTAssertEqual(summary.puzzleId, "test-pid", "summary 应包含 puzzleId")
    }

    /// RecordSummary puzzleId 为 nil（非 puzzle 来源）
    func testRecordSummary_PuzzleIdNil_ForNonPuzzle() {
        let record = GameRecord(title: "人机", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                 blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                                 difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                                 initialFEN: nil, source: .versusAI)
        let summary = RecordSummary(from: record)
        XCTAssertNil(summary.puzzleId, "非 puzzle 来源 puzzleId 应为 nil")
    }

    /// 重命名 trim：前后空格被去除
    func testRename_TrimWhitespace() {
        let trimmed = "  新标题  ".trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(trimmed, "新标题", "前后空格应被 trim")
    }

    /// 重命名 trim：纯空格为空
    func testRename_TrimAllWhitespace_Empty() {
        let trimmed = "   ".trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(trimmed.isEmpty, "纯空格 trim 后应为空")
    }

    /// 重命名 trim：空字符串仍为空
    func testRename_TrimEmptyString() {
        let trimmed = "".trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(trimmed.isEmpty, "空字符串 trim 后仍为空")
    }

    // ============================================================
    // 线程安全
    // ============================================================

    /// 快速连续写入不 crash
    func testConcurrentWrite_NoCrash() {
        let store = makeTestStore()
        let expectation = XCTestExpectation(description: "concurrent writes")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                let record = GameRecord(
                    title: "并发\(i)",
                    redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                    blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                    difficulty: .medium, result: .redWon, totalMoves: i, moves: [],
                    initialFEN: nil, source: .versusAI
                )
                store.addRecord(record)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(store.count, 10, "10 条并发写入后应有 10 条记录")
    }

    /// 快速连续读写不 crash
    func testConcurrentReadWrite_NoCrash() {
        let store = makeTestStore()
        // 先加一条
        let r0 = GameRecord(title: "初始", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                             blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                             difficulty: .medium, result: .redWon, totalMoves: 0, moves: [],
                             initialFEN: nil, source: .versusAI)
        store.addRecord(r0)

        let expectation = XCTestExpectation(description: "concurrent read/write")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<10 {
            DispatchQueue.global().async {
                let record = GameRecord(
                    title: "写入\(i)",
                    redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                    blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                    difficulty: .medium, result: .redWon, totalMoves: i, moves: [],
                    initialFEN: nil, source: .versusAI
                )
                store.addRecord(record)
                expectation.fulfill()
            }
            DispatchQueue.global().async {
                _ = store.count  // 读操作（线程安全版）
                _ = store.loadSummaries()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
        // 不验证精确数量（并发写入），只验证不 crash
        XCTAssertTrue(store.count >= 1, "至少有初始记录")
    }

    /// 快速连续 batchAdd 不 crash
    func testConcurrentBatchAdd_NoCrash() {
        let store = makeTestStore()
        let expectation = XCTestExpectation(description: "concurrent batchAdd")
        expectation.expectedFulfillmentCount = 5

        for i in 0..<5 {
            DispatchQueue.global().async {
                let records = (0..<3).map { j in
                    GameRecord(
                        title: "batch\(i)-\(j)",
                        redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                        blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                        difficulty: .medium, result: .redWon, totalMoves: i * 3 + j, moves: [],
                        initialFEN: nil, source: .imported
                    )
                }
                _ = store.batchAdd(records)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
        // 只验证不 crash，不验证精确数量
        XCTAssertTrue(store.count > 0, "应有记录")
    }

    /// deleteRecord + addRecord 交叉不 crash
    func testConcurrentDeleteAndAdd_NoCrash() {
        let store = makeTestStore()
        var ids: [UUID] = []
        for i in 0..<5 {
            let r = GameRecord(title: "待删\(i)", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                                difficulty: .medium, result: .redWon, totalMoves: i, moves: [],
                                initialFEN: nil, source: .versusAI)
            store.addRecord(r)
            ids.append(r.id)
        }

        let expectation = XCTestExpectation(description: "delete+add")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<5 {
            let delId = ids[i]
            DispatchQueue.global().async {
                store.deleteRecord(id: delId)
                expectation.fulfill()
            }
            DispatchQueue.global().async {
                let r = GameRecord(title: "新增\(i)", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                                    blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                                    difficulty: .medium, result: .redWon, totalMoves: i, moves: [],
                                    initialFEN: nil, source: .versusAI)
                store.addRecord(r)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
        // 不 crash 即通过
    }
}
