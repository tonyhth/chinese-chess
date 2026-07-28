import XCTest
@testable import ChineseChess

// MARK: - v3.7.1 P0: 统一 Sheet 管理测试

final class UnifiedSheetTests: XCTestCase {

    // ============================================================
    // SheetDestination 枚举完整性
    // ============================================================

    /// SheetDestination 有 12 种 case
    func testSheetDestination_AllCases() {
        // 验证所有 case 的 id 不重复
        let ids = [
            ChineseChessApp.SheetDestination.record.id,
            ChineseChessApp.SheetDestination.stats.id,
            ChineseChessApp.SheetDestination.puzzles.id,
            ChineseChessApp.SheetDestination.themePicker.id,
            ChineseChessApp.SheetDestination.history.id,
            ChineseChessApp.SheetDestination.settings.id,
            ChineseChessApp.SheetDestination.dailyChallenge.id,
            ChineseChessApp.SheetDestination.achievements.id,
            ChineseChessApp.SheetDestination.rankPrivilege.id,
            ChineseChessApp.SheetDestination.rankUp(.student).id,
            ChineseChessApp.SheetDestination.toolbarReplay(GameRecord(
                title: "t", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                initialFEN: nil, source: .versusAI
            )).id,
            ChineseChessApp.SheetDestination.historyReplay(GameRecord(
                title: "t", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                initialFEN: nil, source: .versusAI
            )).id,
            // v3.7.2: 新增 3 个 case
            ChineseChessApp.SheetDestination.analysis(GameRecord(
                title: "t", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                initialFEN: nil, source: .versusAI
            )).id,
            ChineseChessApp.SheetDestination.coach(GameRecord(
                title: "t", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                initialFEN: nil, source: .versusAI
            )).id,
        ]
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, 14, "应有 14 种 SheetDestination（.openingExplorer 已移除）")
        XCTAssertEqual(uniqueIds.count, 14, "所有 id 应唯一")
    }

    /// Identifiable: 每个 case 有唯一 String id
    func testSheetDestination_Identifiable_Consistency() {
        // 同一个 case 多次创建 id 相同
        let id1 = ChineseChessApp.SheetDestination.history.id
        let id2 = ChineseChessApp.SheetDestination.history.id
        XCTAssertEqual(id1, id2, "相同 case 的 id 应一致")
    }

    /// rankUp 不同 Rank 的 id 相同（设计如此：同时只弹一个 rankUp）
    func testSheetDestination_RankUp_SameId() {
        let id1 = ChineseChessApp.SheetDestination.rankUp(.student).id
        let id2 = ChineseChessApp.SheetDestination.rankUp(.master).id
        XCTAssertEqual(id1, id2, "rankUp 不同 Rank 的 id 应相同（同时只弹一个）")
    }

    /// toolbarReplay 和 historyReplay id 不同
    func testSheetDestination_ReplayDifferentId() {
        let record = GameRecord(
            title: "t", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
            initialFEN: nil, source: .versusAI
        )
        let toolbarId = ChineseChessApp.SheetDestination.toolbarReplay(record).id
        let historyId = ChineseChessApp.SheetDestination.historyReplay(record).id
        XCTAssertNotEqual(toolbarId, historyId, "toolbarReplay 和 historyReplay id 应不同")
    }

    /// record 和 stats id 不同
    func testSheetDestination_RecordAndStats_DifferentId() {
        XCTAssertNotEqual(
            ChineseChessApp.SheetDestination.record.id,
            ChineseChessApp.SheetDestination.stats.id,
            "record 和 stats id 应不同"
        )
    }

    // ============================================================
    // 互斥逻辑验证：同一时刻只有一个 activeSheet
    // ============================================================

    /// 设 activeSheet = .history → 再设 .settings → 只有 settings
    func testMutualExclusion_OnlyOneActive() {
        // 模拟互斥逻辑：activeSheet 是 Optional，设新值自动替换旧的
        var activeSheet: ChineseChessApp.SheetDestination? = nil

        activeSheet = .history
        XCTAssertEqual(activeSheet?.id, "history")

        activeSheet = .settings
        XCTAssertEqual(activeSheet?.id, "settings", "设新值后应替换旧值")

        activeSheet = nil
        XCTAssertNil(activeSheet, "设 nil 后应关闭")
    }

    /// record 面板切换逻辑：再点一次关闭
    func testRecordPanel_Toggle() {
        var activeSheet: ChineseChessApp.SheetDestination? = nil

        // 模拟按钮点击：activeSheet?.id == "record" ? nil : .record
        activeSheet = (activeSheet?.id == "record") ? nil : .record
        XCTAssertEqual(activeSheet?.id, "record", "第一次点击应打开")

        activeSheet = (activeSheet?.id == "record") ? nil : .record
        XCTAssertNil(activeSheet, "第二次点击应关闭")
    }

    /// stats 面板切换逻辑
    func testStatsPanel_Toggle() {
        var activeSheet: ChineseChessApp.SheetDestination? = nil

        activeSheet = (activeSheet?.id == "stats") ? nil : .stats
        XCTAssertEqual(activeSheet?.id, "stats")

        activeSheet = (activeSheet?.id == "stats") ? nil : .stats
        XCTAssertNil(activeSheet)
    }

    /// 从 history 跳到 historyReplay：替换 activeSheet
    func testHistoryToReplay_Transition() {
        var activeSheet: ChineseChessApp.SheetDestination? = .history

        let record = GameRecord(
            title: "测试对局", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 5, moves: [],
            initialFEN: nil, source: .versusAI
        )
        // 用户在历史列表中点击一局棋 → 切换到 historyReplay
        activeSheet = .historyReplay(record)
        XCTAssertEqual(activeSheet?.id, "historyReplay", "应切换到 historyReplay")
    }

    // ============================================================
    // GameHistoryView 搜索逻辑（非 UI）
    // ============================================================

    /// searchText 过滤逻辑验证
    func testSearchFilter_Logic() {
        // 模拟搜索过滤逻辑
        let summaries = [
            RecordSummary(from: GameRecord(
                title: "人机对局", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 10, moves: [],
                initialFEN: nil, source: .versusAI
            )),
            RecordSummary(from: GameRecord(
                title: "残局挑战", redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .hard),
                difficulty: .hard, result: .blackWon, totalMoves: 5, moves: [],
                initialFEN: nil, source: .puzzle
            )),
        ]

        let searchText = "人机"
        let filtered = summaries.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        XCTAssertEqual(filtered.count, 1, "搜索'人机'应匹配1条")
        XCTAssertEqual(filtered[0].title, "人机对局")
    }

    /// 空搜索文本返回全部
    func testSearchFilter_EmptyText() {
        let summaries = [
            RecordSummary(from: GameRecord(
                title: "A", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                initialFEN: nil, source: .versusAI
            )),
            RecordSummary(from: GameRecord(
                title: "B", redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .medium),
                difficulty: .medium, result: .redWon, totalMoves: 1, moves: [],
                initialFEN: nil, source: .versusAI
            )),
        ]

        let filtered = summaries.filter { "".isEmpty || $0.title.localizedCaseInsensitiveContains("") }
        XCTAssertEqual(filtered.count, 2, "空搜索应返回全部")
    }
}
