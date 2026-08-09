import XCTest
@testable import ChineseChess

// MARK: - v3.7.0 Phase 2 补充测试：导出/分享、数据源切换、isAI/name 语义、段位门禁

final class V370Phase2SupplementTests: XCTestCase {
    private var savedHumanSide: String?

    override func setUp() {
        super.setUp()
        savedHumanSide = UserDefaults.standard.string(forKey: "chinesechess.humanSide")
        UserDefaults.standard.set("red", forKey: "chinesechess.humanSide")
    }

    override func tearDown() {
        if let saved = savedHumanSide {
            UserDefaults.standard.set(saved, forKey: "chinesechess.humanSide")
        } else {
            UserDefaults.standard.removeObject(forKey: "chinesechess.humanSide")
        }
        super.tearDown()
    }

    // MARK: - 2. 导出/分享功能：RecordPanelView onExportRequest 连接验证

    /// 验证 GameViewModel.buildGameRecord() 在有人机对弈走法时返回有效 GameRecord
    @MainActor
    func testBuildGameRecord_ReturnsValidRecord_WhenMovesExist() {
        let vm = GameViewModel()
        // 模拟走一步棋（红方炮二平五）
        let from = Position(row: 7, col: 7)
        let to = Position(row: 7, col: 4)
        guard let piece = vm.board.piece(at: from) else {
            XCTFail("红方炮不在 h2")
            return
        }
        let move = Move(piece: piece, from: from, to: to, captured: nil)
        vm.board.execute(move)
        let gameMove = GameMove(
            id: UUID(), piece: piece, from: from, to: to, captured: nil,
            turnNumber: 1, notation: "炮二平五", timestamp: Date(),
            isCheck: false, isCheckmate: false, halfmoveClock: 0
        )
        vm.gameMoves.append(gameMove)

        let record = vm.buildGameRecord()
        XCTAssertNotNil(record, "有走法时 buildGameRecord 应返回有效记录")
        XCTAssertEqual(record?.totalMoves, 1)
        XCTAssertEqual(record?.source, .versusAI)
    }

    /// 验证 buildGameRecord 在无走法时返回 nil
    @MainActor
    func testBuildGameRecord_ReturnsNil_WhenNoMoves() {
        let vm = GameViewModel()
        let record = vm.buildGameRecord()
        XCTAssertNil(record, "无走法时 buildGameRecord 应返回 nil")
    }

    /// 验证 PGNExporter 对 GameRecord 能正常导出
    @MainActor
    func testPGNExporter_ProducesNonEmptyString() {
        let vm = GameViewModel()
        let from = Position(row: 7, col: 7)
        let to = Position(row: 7, col: 4)
        guard let piece = vm.board.piece(at: from) else {
            XCTFail("红方炮不在 h2")
            return
        }
        let move = Move(piece: piece, from: from, to: to, captured: nil)
        vm.board.execute(move)
        let gameMove = GameMove(
            id: UUID(), piece: piece, from: from, to: to, captured: nil,
            turnNumber: 1, notation: "炮二平五", timestamp: Date(),
            isCheck: false, isCheckmate: false, halfmoveClock: 0
        )
        vm.gameMoves.append(gameMove)

        guard let record = vm.buildGameRecord() else {
            XCTFail("buildGameRecord 应返回有效记录")
            return
        }
        let pgn = PGNExporter.export(record)
        XCTAssertFalse(pgn.isEmpty, "PGN 导出不应为空字符串")
    }

    // MARK: - 3. GameRecordStore 数据源切换验证

    /// 验证 GameRecordStore.addRecord 写入后 summaries 更新
    func testGameRecordStore_AddRecord_UpdatesSummaries() {
        let store = GameRecordStore.shared
        let initialCount = store.count

        let record = makeTestRecord()
        store.addRecord(record)

        XCTAssertEqual(store.count, initialCount + 1, "addRecord 后 count 应 +1")
        XCTAssertEqual(store.summaries.first?.id, record.id, "最新记录应在 summaries 最前面")

        // 清理
        store.deleteRecord(id: record.id)
        XCTAssertEqual(store.count, initialCount, "deleteRecord 后 count 应恢复")
    }

    /// 验证 GameRecordStore.loadRecord 按需加载完整记录
    func testGameRecordStore_LoadRecord_ReturnsFullRecord() {
        let store = GameRecordStore.shared
        let record = makeTestRecord()
        store.addRecord(record)

        let loaded = store.loadRecord(id: record.id)
        XCTAssertNotNil(loaded, "loadRecord 应返回完整记录")
        XCTAssertEqual(loaded?.id, record.id)
        XCTAssertEqual(loaded?.totalMoves, record.totalMoves)
        XCTAssertEqual(loaded?.source, record.source)

        // 清理
        store.deleteRecord(id: record.id)
    }

    /// 验证 GameRecordStore id 去重
    func testGameRecordStore_AddRecord_DeduplicatesById() {
        let store = GameRecordStore.shared
        let initialCount = store.count

        let record = makeTestRecord()
        store.addRecord(record)
        XCTAssertEqual(store.count, initialCount + 1)

        // 再次添加同 id 记录
        store.addRecord(record)
        XCTAssertEqual(store.count, initialCount + 1, "同 id 不应重复写入")

        // 清理
        store.deleteRecord(id: record.id)
    }

    /// 验证 RecordSummary 从 GameRecord 正确提取
    func testRecordSummary_FromGameRecord() {
        let record = makeTestRecord()
        let summary = RecordSummary(from: record)
        XCTAssertEqual(summary.id, record.id)
        XCTAssertEqual(summary.title, record.title)
        XCTAssertEqual(summary.result, record.result)
        XCTAssertEqual(summary.totalMoves, record.totalMoves)
        XCTAssertEqual(summary.difficulty, record.difficulty)
        XCTAssertEqual(summary.source, record.source)
    }

    // MARK: - 4. isAI/name 语义验证

    /// 验证 buildGameRecord 根据 humanSide 推导 isAI 和 name
    /// humanSide == .red → 红方是人类，黑方是 AI
    @MainActor
    func testBuildGameRecord_isAI_Semantics_HumanRed() {
        let vm = GameViewModel()
        // GameViewModel 默认 humanSide == .red
        // 先走一步让 buildGameRecord 返回非 nil
        let from = Position(row: 7, col: 7)
        let to = Position(row: 7, col: 4)
        guard let piece = vm.board.piece(at: from) else {
            XCTFail("红方炮不在 h2")
            return
        }
        let move = Move(piece: piece, from: from, to: to, captured: nil)
        vm.board.execute(move)
        vm.gameMoves.append(GameMove(
            id: UUID(), piece: piece, from: from, to: to, captured: nil,
            turnNumber: 1, notation: "炮二平五", timestamp: Date(),
            isCheck: false, isCheckmate: false, halfmoveClock: 0
        ))

        guard let record = vm.buildGameRecord() else {
            XCTFail("buildGameRecord 应返回有效记录")
            return
        }
        XCTAssertFalse(record.redPlayer.isAI, "红方是人类时 redPlayer.isAI 应为 false")
        XCTAssertTrue(record.blackPlayer.isAI, "红方是人类时 blackPlayer.isAI 应为 true")
    }

    /// 验证 Puzzle 模式下 isAI 根据 puzzle.side 推导（红方玩家）
    func testPuzzleRecord_isAI_Semantics_HumanRed() {
        let puzzle = Puzzle(
            id: "test-p1",
            name: "测试残局",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: FENParser.standardInitial,
            solution: [],
            hints: nil,
            maxMoves: 10
        )
        let isHumanRed = puzzle.side == .red
        XCTAssertTrue(isHumanRed, "puzzle.side == .red 时 isHumanRed 应为 true")

        let record = GameRecord(
            id: UUID(),
            title: puzzle.name,
            date: Date(),
            redPlayer: PlayerInfo(name: "玩家", isAI: !isHumanRed, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI", isAI: isHumanRed, difficulty: nil),
            difficulty: .amateurLow,
            result: .playing,
            totalMoves: 0,
            moves: [],
            initialFEN: puzzle.initialFEN,
            source: .puzzle
        )
        XCTAssertFalse(record.redPlayer.isAI, "红方是人类时 redPlayer.isAI 应为 false")
        XCTAssertTrue(record.blackPlayer.isAI, "红方是人类时 blackPlayer.isAI 应为 true")
    }

    /// 验证 Puzzle 模式下 isAI 根据 puzzle.side 推导（黑方玩家）
    func testPuzzleRecord_isAI_Semantics_HumanBlack() {
        let puzzle = Puzzle(
            id: "test-p2",
            name: "测试残局黑方",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "black",
            initialFEN: FENParser.standardInitial,
            solution: [],
            hints: nil,
            maxMoves: 10
        )
        let isHumanRed = puzzle.side == .red
        XCTAssertFalse(isHumanRed, "puzzle.side == .black 时 isHumanRed 应为 false")

        let record = GameRecord(
            id: UUID(),
            title: puzzle.name,
            date: Date(),
            redPlayer: PlayerInfo(name: "AI", isAI: !isHumanRed, difficulty: nil),
            blackPlayer: PlayerInfo(name: "玩家", isAI: isHumanRed, difficulty: nil),
            difficulty: .amateurLow,
            result: .playing,
            totalMoves: 0,
            moves: [],
            initialFEN: puzzle.initialFEN,
            source: .puzzle
        )
        XCTAssertTrue(record.redPlayer.isAI, "黑方是人类时 redPlayer.isAI 应为 true")
        XCTAssertFalse(record.blackPlayer.isAI, "黑方是人类时 blackPlayer.isAI 应为 false")
    }

    // MARK: - 5. 段位门禁验证

    /// 验证 gameRecordExport 要求 .hanlin 段位
    func testGameRecordExport_RequiresHanlin() {
        XCTAssertEqual(UnlockedFeature.gameRecordExport.requiredRank, .hanlin,
                       "gameRecordExport 应要求翰林段位")
    }

    /// 验证 gameRecordImport 要求 .student 段位（最低段位即可）
    func testGameRecordImport_RequiresStudent() {
        XCTAssertEqual(UnlockedFeature.gameRecordImport.requiredRank, .student,
                       "gameRecordImport 应要求学童段位（无段位限制）")
    }

    /// 验证翰林段位可以导出
    func testHanlinRank_CanExport() {
        var profile = PlayerProfile()
        profile.rank = .hanlin
        profile.totalWins = 50
        XCTAssertTrue(profile.isFeatureUnlocked(.gameRecordExport),
                      "翰林段位应能导出棋谱")
    }

    /// 验证学童段位不能导出
    func testStudentRank_CannotExport() {
        let profile = PlayerProfile()
        XCTAssertFalse(profile.isFeatureUnlocked(.gameRecordExport),
                       "学童段位不应能导出棋谱")
    }

    /// 验证学童段位可以导入
    func testStudentRank_CanImport() {
        let profile = PlayerProfile()
        XCTAssertTrue(profile.isFeatureUnlocked(.gameRecordImport),
                      "学童段位应能导入棋谱")
    }

    /// 验证 gameRecordExport 和 gameRecordImport 标记为已实现
    func testGameRecordFeatures_AreImplemented() {
        XCTAssertTrue(UnlockedFeature.gameRecordExport.isImplemented,
                      "gameRecordExport 应标记为已实现")
        XCTAssertTrue(UnlockedFeature.gameRecordImport.isImplemented,
                      "gameRecordImport 应标记为已实现")
    }

    // MARK: - 辅助方法

    private func makeTestRecord() -> GameRecord {
        GameRecord(
            id: UUID(),
            title: "Phase2 Test Record",
            date: Date(),
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI-中级", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow,
            result: .redWon,
            totalMoves: 2,
            moves: [],
            source: .versusAI
        )
    }
}
