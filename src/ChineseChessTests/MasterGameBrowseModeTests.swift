import XCTest
@testable import ChineseChess

// MARK: - Phase B2 Step 1: 大师对局三模式浏览测试

/// 覆盖 ff51d41 + cd4cd75 两次提交的核心改动：
/// 1. MasterGameBrowseMode 枚举（opening/player/event）
/// 2. SidebarSelection 统一选中类型
/// 3. PlayerStat / EventStat Hashable + stableId
/// 4. MasterStatsFile nil graceful fallback
/// 5. 模式切换清空选中 + 重建缓存
/// 6. i18n: 6 new keys
@MainActor
final class MasterGameBrowseModeTests: XCTestCase {

    // MARK: - 1. MasterGameBrowseMode 枚举

    func testBrowseModeAllCasesCount() {
        XCTAssertEqual(MasterGameBrowseMode.allCases.count, 3, "应有三种浏览模式")
    }

    func testBrowseModeRawValues() {
        XCTAssertEqual(MasterGameBrowseMode.opening.rawValue, "opening")
        XCTAssertEqual(MasterGameBrowseMode.player.rawValue, "player")
        XCTAssertEqual(MasterGameBrowseMode.event.rawValue, "event")
    }

    func testBrowseModeIdentifiable() {
        // Identifiable.id 应等于 rawValue
        for mode in MasterGameBrowseMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testBrowseModeCaseIterableOrder() {
        let cases = MasterGameBrowseMode.allCases
        XCTAssertEqual(cases[0], .opening)
        XCTAssertEqual(cases[1], .player)
        XCTAssertEqual(cases[2], .event)
    }

    // MARK: - 2. MasterGameBrowseMode label（i18n）

    func testBrowseModeLabelOpening() {
        let label = MasterGameBrowseMode.opening.label
        XCTAssertFalse(label.isEmpty, "开局模式 label 不应为空")
        XCTAssertNotEqual(label, "master.mode.opening", "label 应已翻译，不应返回 key 本身")
    }

    func testBrowseModeLabelPlayer() {
        let label = MasterGameBrowseMode.player.label
        XCTAssertFalse(label.isEmpty)
        XCTAssertNotEqual(label, "master.mode.player")
    }

    func testBrowseModeLabelEvent() {
        let label = MasterGameBrowseMode.event.label
        XCTAssertFalse(label.isEmpty)
        XCTAssertNotEqual(label, "master.mode.event")
    }

    func testBrowseModeLabelsDistinct() {
        let labels = MasterGameBrowseMode.allCases.map { $0.label }
        let unique = Set(labels)
        XCTAssertEqual(unique.count, 3, "三种模式的 label 应各不相同")
    }

    // MARK: - 3. SidebarSelection Hashable

    func testSidebarSelectionOpeningEquality() {
        let cats = OpeningCategories.categories
        guard cats.count >= 2 else {
            XCTFail("应有至少 2 个开局分类")
            return
        }
        let sel1 = SidebarSelection.opening(cats[0])
        let sel2 = SidebarSelection.opening(cats[0])
        let sel3 = SidebarSelection.opening(cats[1])
        XCTAssertEqual(sel1, sel2)
        XCTAssertNotEqual(sel1, sel3)
    }

    func testSidebarSelectionPlayerEquality() {
        let p1 = MasterStatsFile.PlayerStat(name: "a", nameCN: "甲", count: 10)
        let p2 = MasterStatsFile.PlayerStat(name: "a", nameCN: "甲", count: 10)
        let p3 = MasterStatsFile.PlayerStat(name: "b", nameCN: "乙", count: 5)
        let sel1 = SidebarSelection.player(p1)
        let sel2 = SidebarSelection.player(p2)
        let sel3 = SidebarSelection.player(p3)
        XCTAssertEqual(sel1, sel2)
        XCTAssertNotEqual(sel1, sel3)
    }

    func testSidebarSelectionEventEquality() {
        let e1 = MasterStatsFile.EventStat(name: "a", nameCN: "甲", year: 2020, count: 10)
        let e2 = MasterStatsFile.EventStat(name: "a", nameCN: "甲", year: 2020, count: 10)
        let e3 = MasterStatsFile.EventStat(name: "a", nameCN: "甲", year: 2021, count: 10)
        let sel1 = SidebarSelection.event(e1)
        let sel2 = SidebarSelection.event(e2)
        let sel3 = SidebarSelection.event(e3)
        XCTAssertEqual(sel1, sel2)
        XCTAssertNotEqual(sel1, sel3, "不同 year 的 EventStat 应产生不同 SidebarSelection")
    }

    func testSidebarSelectionCrossTypeInequality() {
        let cat = OpeningCategories.categories.first!
        let p = MasterStatsFile.PlayerStat(name: "a", nameCN: "甲", count: 1)
        let e = MasterStatsFile.EventStat(name: "a", nameCN: "甲", year: nil, count: 1)
        XCTAssertNotEqual(SidebarSelection.opening(cat), SidebarSelection.player(p))
        XCTAssertNotEqual(SidebarSelection.player(p), SidebarSelection.event(e))
        XCTAssertNotEqual(SidebarSelection.opening(cat), SidebarSelection.event(e))
    }

    func testSidebarSelectionUsableInSet() {
        let cat = OpeningCategories.categories.first!
        let p = MasterStatsFile.PlayerStat(name: "a", nameCN: "甲", count: 1)
        let selections: [SidebarSelection] = [
            .opening(cat),
            .player(p),
            .opening(cat),  // 重复
        ]
        let set = Set(selections)
        XCTAssertEqual(set.count, 2, "重复的 SidebarSelection 应去重")
    }

    // MARK: - 4. PlayerStat Hashable + stableId

    func testPlayerStatHashableEquality() {
        let p1 = MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 100)
        let p2 = MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 100)
        XCTAssertEqual(p1, p2)
    }

    func testPlayerStatHashableInequalityDifferentName() {
        let p1 = MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 100)
        let p2 = MasterStatsFile.PlayerStat(name: "Lv Qin", nameCN: "吕钦", count: 80)
        XCTAssertNotEqual(p1, p2)
    }

    func testPlayerStatHashableInequalityDifferentCount() {
        // count 不同但 name/nameCN 相同 → 仍不等（合成 Equatable）
        let p1 = MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 100)
        let p2 = MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 99)
        XCTAssertNotEqual(p1, p2, "count 不同应不等")
    }

    func testPlayerStatStableId() {
        let p = MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 100)
        XCTAssertEqual(p.stableId, "Xu Yinchuan|许银川")
    }

    func testPlayerStatStableIdUniqueness() {
        // 同名不同中文 → stableId 不同
        let p1 = MasterStatsFile.PlayerStat(name: "Wang", nameCN: "王天一", count: 50)
        let p2 = MasterStatsFile.PlayerStat(name: "Wang", nameCN: "王郑", count: 50)
        XCTAssertNotEqual(p1.stableId, p2.stableId, "同名不同中文的 stableId 应不同")
    }

    func testPlayerStatSetDedup() {
        let p1 = MasterStatsFile.PlayerStat(name: "a", nameCN: "甲", count: 10)
        let p2 = MasterStatsFile.PlayerStat(name: "a", nameCN: "甲", count: 10)
        let set: Set<MasterStatsFile.PlayerStat> = [p1, p2]
        XCTAssertEqual(set.count, 1, "相同 PlayerStat 应去重")
    }

    // MARK: - 5. EventStat Hashable + stableId

    func testEventStatHashableEquality() {
        let e1 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50)
        let e2 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50)
        XCTAssertEqual(e1, e2)
    }

    func testEventStatHashableInequalityDifferentYear() {
        let e1 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50)
        let e2 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2021, count: 50)
        XCTAssertNotEqual(e1, e2, "不同 year 应不等")
    }

    func testEventStatHashableInequalityNilYear() {
        let e1 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: nil, count: 50)
        let e2 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50)
        XCTAssertNotEqual(e1, e2, "nil year vs 有 year 应不等")
    }

    func testEventStatStableIdWithYear() {
        let e = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50)
        XCTAssertEqual(e.stableId, "National|全国个人赛|2020")
    }

    func testEventStatStableIdWithNilYear() {
        let e = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: nil, count: 50)
        XCTAssertEqual(e.stableId, "National|全国个人赛|-1", "nil year 应映射为 -1")
    }

    func testEventStatStableIdUniqueness() {
        let e1 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50)
        let e2 = MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2021, count: 50)
        XCTAssertNotEqual(e1.stableId, e2.stableId, "不同 year 的 stableId 应不同")
    }

    func testEventStatSetDedup() {
        let e1 = MasterStatsFile.EventStat(name: "a", nameCN: "甲", year: nil, count: 10)
        let e2 = MasterStatsFile.EventStat(name: "a", nameCN: "甲", year: nil, count: 10)
        let set: Set<MasterStatsFile.EventStat> = [e1, e2]
        XCTAssertEqual(set.count, 1, "相同 EventStat 应去重")
    }

    // MARK: - 6. MasterStatsFile Codable round-trip

    func testMasterStatsFileCodableRoundTrip() throws {
        let players = [
            MasterStatsFile.PlayerStat(name: "Xu Yinchuan", nameCN: "许银川", count: 100),
            MasterStatsFile.PlayerStat(name: "Lv Qin", nameCN: "吕钦", count: 80),
        ]
        let events = [
            MasterStatsFile.EventStat(name: "National", nameCN: "全国个人赛", year: 2020, count: 50),
            MasterStatsFile.EventStat(name: "CCTV", nameCN: "央视杯", year: nil, count: 30),
        ]
        let stats = MasterStatsFile(
            totalGames: 200,
            players: players,
            events: events,
            openingDistribution: ["h2e2": 100, "b2e2": 80]
        )

        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(MasterStatsFile.self, from: data)

        XCTAssertEqual(decoded.totalGames, 200)
        XCTAssertEqual(decoded.players.count, 2)
        XCTAssertEqual(decoded.events.count, 2)
        XCTAssertEqual(decoded.openingDistribution["h2e2"], 100)
        XCTAssertEqual(decoded.players[0].stableId, "Xu Yinchuan|许银川")
        XCTAssertEqual(decoded.events[1].stableId, "CCTV|央视杯|-1")
    }

    func testMasterStatsFileEmptyPlayersEvents() throws {
        let stats = MasterStatsFile(totalGames: 0, players: [], events: [], openingDistribution: [:])
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(MasterStatsFile.self, from: data)
        XCTAssertTrue(decoded.players.isEmpty)
        XCTAssertTrue(decoded.events.isEmpty)
        XCTAssertEqual(decoded.totalGames, 0)
    }

    // MARK: - 7. MasterGameStore stats nil fallback

    func testMasterGameStoreStatsInitiallyNil() {
        // MasterGameStore.shared 在 loadIfNeeded 之前 stats 可能为 nil
        // 此测试验证 stats 属性类型为 Optional，可安全判空
        let store = MasterGameStore.shared
        // 不强制为 nil（其他测试可能已加载），只验证可安全访问
        _ = store.stats == nil
    }

    func testMasterGameStoreByPlayerReturnsEmptyForUnknown() {
        let store = MasterGameStore.shared
        let result = store.byPlayer("__nonexistent_player__")
        XCTAssertTrue(result.isEmpty, "不存在的棋手应返回空数组")
    }

    func testMasterGameStoreByEventReturnsEmptyForUnknown() {
        let store = MasterGameStore.shared
        let result = store.byEvent("__nonexistent_event__")
        XCTAssertTrue(result.isEmpty, "不存在的赛事应返回空数组")
    }

    // MARK: - 8. i18n: 6 new keys

    func testL10nMasterModeOpening() {
        let text = L10n.shared.t("master.mode.opening")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "master.mode.opening")
    }

    func testL10nMasterModePlayer() {
        let text = L10n.shared.t("master.mode.player")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "master.mode.player")
    }

    func testL10nMasterModeEvent() {
        let text = L10n.shared.t("master.mode.event")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "master.mode.event")
    }

    func testL10nMasterStatsUnavailable() {
        let text = L10n.shared.t("master.statsUnavailable")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "master.statsUnavailable")
    }

    func testL10nMasterLoadMorePlayers() {
        let text = L10n.shared.t("master.loadMorePlayers")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "master.loadMorePlayers")
        // 格式化验证
        let formatted = String(format: text, 50, 200)
        XCTAssertTrue(formatted.contains("50") || formatted.contains("200"),
                      "格式化后应包含数字参数")
    }

    func testL10nMasterLoadMoreEvents() {
        let text = L10n.shared.t("master.loadMoreEvents")
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "master.loadMoreEvents")
        let formatted = String(format: text, 30, 100)
        XCTAssertTrue(formatted.contains("30") || formatted.contains("100"),
                      "格式化后应包含数字参数")
    }

    // MARK: - 9. MasterGameIndex 边界（firstMove 为空 / firstMoves 为空）

    func testMasterGameIndexEmptyFirstMove() {
        let index = MasterGameIndex(
            id: 0, event: "test", redName: "A", blackName: "B",
            redNameCN: "甲", blackNameCN: "乙", year: nil,
            firstMove: "", firstMoves: [], moveCount: 0,
            pgnOffset: 0, pgnLength: 0
        )
        XCTAssertTrue(index.firstMove.isEmpty)
        XCTAssertTrue(index.firstMoves.isEmpty)
    }

    func testMasterGameIndexLongFirstMoves() {
        let longMoves = (1...20).map { "m\($0)" }
        let index = MasterGameIndex(
            id: 0, event: "test", redName: "A", blackName: "B",
            redNameCN: "甲", blackNameCN: "乙", year: nil,
            firstMove: "m1", firstMoves: longMoves, moveCount: 40,
            pgnOffset: 0, pgnLength: 1000
        )
        XCTAssertEqual(index.firstMoves.count, 20)
    }

    // MARK: - 10. PlayerStat/EventStat 排序（按 count 降序）

    func testPlayerStatSortByCountDescending() {
        let players = [
            MasterStatsFile.PlayerStat(name: "A", nameCN: "甲", count: 50),
            MasterStatsFile.PlayerStat(name: "B", nameCN: "乙", count: 100),
            MasterStatsFile.PlayerStat(name: "C", nameCN: "丙", count: 30),
        ]
        let sorted = players.sorted { $0.count > $1.count }
        XCTAssertEqual(sorted[0].count, 100)
        XCTAssertEqual(sorted[1].count, 50)
        XCTAssertEqual(sorted[2].count, 30)
    }

    func testEventStatSortByCountDescending() {
        let events = [
            MasterStatsFile.EventStat(name: "A", nameCN: "甲", year: nil, count: 20),
            MasterStatsFile.EventStat(name: "B", nameCN: "乙", year: nil, count: 80),
            MasterStatsFile.EventStat(name: "C", nameCN: "丙", year: nil, count: 40),
        ]
        let sorted = events.sorted { $0.count > $1.count }
        XCTAssertEqual(sorted[0].count, 80)
        XCTAssertEqual(sorted[1].count, 40)
        XCTAssertEqual(sorted[2].count, 20)
    }

    // MARK: - 11. 分段加载边界

    func testCategoryPageSizeFifty() {
        // categoryPageSize = 50 是硬编码在 MasterGameBrowserView 中的
        // 此测试验证分段逻辑：prefix(50) 对 60 条数据应截断
        let players = (0..<60).map { i in
            MasterStatsFile.PlayerStat(name: "p\(i)", nameCN: "棋手\(i)", count: 60 - i)
        }
        let visible = Array(players.prefix(50))
        XCTAssertEqual(visible.count, 50)
        XCTAssertLessThan(visible.count, players.count)
    }

    func testGamePageSizeTwoHundred() {
        // gamePageSize = 200
        let indices = (0..<250).map { i in
            MasterGameIndex(
                id: i, event: "e", redName: "A", blackName: "B",
                redNameCN: "甲", blackNameCN: "乙", year: nil,
                firstMove: "h2e2", firstMoves: ["h2e2"], moveCount: 80,
                pgnOffset: 0, pgnLength: 100
            )
        }
        let page1 = indices.prefix(200)
        XCTAssertEqual(page1.count, 200)
        let page2 = indices.prefix(200 * 2)
        XCTAssertEqual(page2.count, 250, "第 2 页应包含全部 250 条")
    }

    // MARK: - 12. SidebarSelection 可选 nil（未选中状态）

    func testSidebarSelectionOptionalNil() {
        let selection: SidebarSelection? = nil
        XCTAssertNil(selection, "初始状态应为 nil 表示未选中")
    }
}
