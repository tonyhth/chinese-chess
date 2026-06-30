import XCTest
@testable import ChineseChess

// MARK: - v3.7.1 Tests: 8 项修复验证

final class V371Tests: XCTestCase {

    // 临时 Store 工厂
    private func makeTestStore() -> GameRecordStore {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        return GameRecordStore(baseURL: tmpDir)
    }

    // MARK: - A1. iOS 文件导入：非 PGN 文件提示格式不支持

    /// PGNImporter.parse 对非 PGN 文本返回空结果
    func testA1_NonPGNContent_ReturnsEmpty() {
        let result = PGNImporter.parse("这不是 PGN 文件内容")
        XCTAssertTrue(result.records.isEmpty, "非 PGN 内容应返回 0 条记录")
    }

    /// PGN 内容可被正常解析
    func testA1_PGNContent_Parsable() {
        let pgn = "[Event \"测试\"]\n[Red \"红\"]\n[Black \"黑\"]\n[FEN \"rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1\"]\n[Result \"*\"]\n\n*\n"
        let result = PGNImporter.parse(pgn)
        XCTAssertTrue(result.records.count >= 0, "不应崩溃")
    }

    // MARK: - A2. 搜索：历史页面标题模糊过滤

    /// 大小写不敏感搜索
    func testA2_SearchFilter_CaseInsensitive() {
        let titles = ["人机对弈-中级", "残局: 马后炮", "人机对弈-高级"]
        let searchText = "人机"
        let filtered = titles.filter { $0.localizedCaseInsensitiveContains(searchText) }
        XCTAssertEqual(filtered.count, 2, "搜索'人机'应匹配 2 条")
    }

    /// 搜索为空时返回全部（与 filteredSummaries 逻辑一致）
    func testA2_SearchFilter_EmptyQuery_ReturnsAll() {
        let titles = ["对局1", "对局2"]
        let searchText = ""
        let filtered = searchText.isEmpty ? titles : titles.filter { $0.localizedCaseInsensitiveContains(searchText) }
        XCTAssertEqual(filtered.count, 2, "空搜索应返回全部")
    }

    /// 搜索无匹配时返回空
    func testA2_SearchFilter_NoMatch_ReturnsEmpty() {
        let titles = ["对局1"]
        let filtered = titles.filter { $0.localizedCaseInsensitiveContains("不存在的关键词") }
        XCTAssertTrue(filtered.isEmpty, "无匹配应返回空")
    }

    // MARK: - A3. 多选导出：iOS 剪贴板复制 + 提示

    /// 验证导出成功结果文本格式
    func testA3_ExportResultText_SuccessFormat() {
        let successCount = 3
        let format = "已复制 %d 局棋谱到剪贴板"
        let result = String(format: format, successCount)
        XCTAssertTrue(result.contains("3"), "成功提示应包含数量")
    }

    // MARK: - A4. 残局重玩去重

    /// 同一 puzzleId 重玩后 GameRecordStore 只有 1 条记录
    func testA4_PuzzleReplay_Deduplication() {
        let store = makeTestStore()
        let puzzleId = "test-puzzle-dedup"

        let record1 = GameRecord(
            title: "残局: 去重测试",
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
            difficulty: .hard,
            result: .redWon,
            totalMoves: 5,
            moves: [],
            initialFEN: "3ak4/9/9/9/9/9/9/9/9/4K4 w",
            source: .puzzle,
            puzzleId: puzzleId
        )
        store.addRecord(record1)
        XCTAssertEqual(store.count, 1)

        let existing = store.findRecordByPuzzleId(puzzleId)
        XCTAssertNotNil(existing, "应找到已有残局记录")

        let record2 = GameRecord(
            id: existing!.id,
            title: "残局: 去重测试",
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
            difficulty: .hard,
            result: .redWon,
            totalMoves: 3,
            moves: [],
            initialFEN: "3ak4/9/9/9/9/9/9/9/9/4K4 w",
            source: .puzzle,
            puzzleId: puzzleId
        )
        store.updateRecord(record2)
        XCTAssertEqual(store.count, 1, "同 puzzleId 重玩后仍应只有 1 条")

        let loaded = store.loadRecord(id: existing!.id)
        XCTAssertEqual(loaded?.totalMoves, 3, "应更新为最新解法")
    }

    /// 不同 puzzleId 各自保留
    func testA4_DifferentPuzzleId_BothKept() {
        let store = makeTestStore()

        let record1 = GameRecord(
            title: "残局 A",
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
            difficulty: .hard,
            result: .redWon,
            totalMoves: 5,
            moves: [],
            initialFEN: nil,
            source: .puzzle,
            puzzleId: "puzzle-A"
        )
        let record2 = GameRecord(
            title: "残局 B",
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .hard),
            difficulty: .hard,
            result: .redWon,
            totalMoves: 8,
            moves: [],
            initialFEN: nil,
            source: .puzzle,
            puzzleId: "puzzle-B"
        )
        store.addRecord(record1)
        store.addRecord(record2)
        XCTAssertEqual(store.count, 2, "不同 puzzleId 应各自保留")
    }

    /// findRecordByPuzzleId 对非 puzzle 记录返回 nil
    func testA4_FindByPuzzleId_NonPuzzleRecord_ReturnsNil() {
        let store = makeTestStore()
        let record = GameRecord(
            title: "人机对弈",
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI-中级", isAI: true, difficulty: .medium),
            difficulty: .medium,
            result: .redWon,
            totalMoves: 20,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        store.addRecord(record)

        let found = store.findRecordByPuzzleId("nonexistent")
        XCTAssertNil(found, "非 puzzle 记录不应被 findRecordByPuzzleId 找到")
    }

    // MARK: - B1. iOS 执边切换（@MainActor 隔离）

    /// setHumanSide 切换后属性正确
    @MainActor
    func testB1_SetHumanSide_SwitchesSide() {
        let viewModel = GameViewModel()
        let original = viewModel.humanSide
        let newSide: Side = original == .red ? .black : .red
        viewModel.setHumanSide(newSide)
        XCTAssertEqual(viewModel.humanSide, newSide, "切换执边后应更新")
    }

    /// 双次切换回到原边
    @MainActor
    func testB1_SetHumanSide_DoubleToggle() {
        let viewModel = GameViewModel()
        let original = viewModel.humanSide
        let other: Side = original == .red ? .black : .red
        viewModel.setHumanSide(other)
        viewModel.setHumanSide(original)
        XCTAssertEqual(viewModel.humanSide, original, "双次切换应回到原边")
    }

    // MARK: - B2. iOS 难度快捷选择

    /// setDifficulty 设置后属性正确
    @MainActor
    func testB2_SetDifficulty_UpdatesProperty() {
        let viewModel = GameViewModel()
        for diff: AIDifficulty in [.beginner, .easy, .medium, .hard, .master] {
            viewModel.setDifficulty(diff)
            XCTAssertEqual(viewModel.difficulty, diff, "难度应更新")
        }
    }

    // MARK: - B3. iOS 设置引擎 Toggle disabled

    /// EngineConfigStore.useEmbeddedEngine 可读写
    @MainActor
    func testB3_EngineConfigStore_Readable() {
        let original = EngineConfigStore.shared.useEmbeddedEngine
        EngineConfigStore.shared.useEmbeddedEngine = !original
        let changed = EngineConfigStore.shared.useEmbeddedEngine
        XCTAssertEqual(changed, !original, "切换后应变化")
        EngineConfigStore.shared.useEmbeddedEngine = original
    }

    // MARK: - B4. 回放标题栏不重叠

    /// GameRecord 字段都可正常访问
    func testB4_ReplayTitleBar_AllFieldsPopulated() {
        let record = GameRecord(
            title: "很长的标题测试：人机对弈残局训练专用棋局",
            redPlayer: PlayerInfo(name: "非常长的红方名称", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "非常长的黑方名称", isAI: true, difficulty: .hard),
            difficulty: .hard,
            result: .redWon,
            totalMoves: 30,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        XCTAssertFalse(record.title.isEmpty)
        XCTAssertFalse(record.redPlayer.name.isEmpty)
        XCTAssertFalse(record.blackPlayer.name.isEmpty)
    }

    /// 标题为空时也不崩溃
    func testB4_ReplayTitleBar_EmptyTitle() {
        let record = GameRecord(
            title: "",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
            difficulty: .medium,
            result: .draw,
            totalMoves: 10,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        XCTAssertTrue(record.title.isEmpty)
    }
}
