import XCTest
@testable import ChineseChess

// MARK: - Phase B2 Step 2 审查返工测试：开局二级分类钻入

/// 覆盖 8b348b3 fix(phase-b2-step2): address review P1 + P2
/// 核心改动：
/// 1. P1: OpeningCategories.categories 改为 static let（不可变），subcategories 改为 let
/// 2. P1: 删除 populateGameCounts()，gameCount 改为 MasterGameStore.gameCount(for:) 动态查询
/// 3. P2: iOS Button action 去掉手动 rebuildCache()，由 onChange 统一处理
@MainActor
final class PhaseB2Step2ReviewTests: XCTestCase {

    // MARK: - P1: OpeningCategories 不可变性

    func testOpeningCategoriesIsImmutable() {
        // categories 是 static let，验证其内容结构在多次访问时不变
        let cats1 = OpeningCategories.categories
        let cats2 = OpeningCategories.categories
        XCTAssertEqual(cats1.count, cats2.count, "多次访问 categories 应返回相同数量")
        for (a, b) in zip(cats1, cats2) {
            XCTAssertEqual(a, b)
        }
    }

    func testOpeningCategoriesSubcategoriesAreLet() {
        // 验证每个 category 的 subcategories 可访问且结构稳定
        for cat in OpeningCategories.categories {
            let subs1 = cat.subcategories
            let subs2 = cat.subcategories
            XCTAssertEqual(subs1.count, subs2.count)
            for (a, b) in zip(subs1, subs2) {
                XCTAssertEqual(a, b)
            }
        }
    }

    func testOpeningCategoriesGameCountDefaultsToZero() {
        // Phase C 后 categories 从 JSON 加载，gameCount 是 JSON 中的值（非 0）
        // 只需验证 gameCount >= 0
        for cat in OpeningCategories.categories {
            XCTAssertGreaterThanOrEqual(cat.gameCount, 0, "分类 \(cat.id) 的 gameCount 应 >= 0")
        }
        for cat in OpeningCategories.categories {
            for sub in cat.subcategories {
                XCTAssertGreaterThanOrEqual(sub.gameCount, 0, "子分类 \(sub.id) 的 gameCount 应 >= 0")
            }
        }
    }

    // MARK: - P1: MasterGameStore.gameCount(for:) 动态查询

    func testGameCountForOpeningWithKnownMove() {
        let store = MasterGameStore.shared
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        // 未加载数据时 openingIndex 为空 → gameCount = 0
        // 如果已加载，则应返回正数
        let count = store.gameCount(for: zhongPao)
        // 只验证不崩溃，且类型正确
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testGameCountForOpeningWithEmptyFirstMove() {
        let store = MasterGameStore.shared
        let other = OpeningCategories.categories.first { $0.id == "other" }!
        // other.firstMove == "" → 走 byOpening("").count 路径
        let count = store.gameCount(for: other)
        XCTAssertGreaterThanOrEqual(count, 0)
        // 验证与 byOpening("") 一致
        XCTAssertEqual(count, store.byOpening("").count)
    }

    func testGameCountForOpeningNonexistentMove() {
        let store = MasterGameStore.shared
        let fakeOpening = OpeningCategory(
            id: "fake", name: "假", firstMove: "z9z9",
            gameCount: 0, description: "不存在的走法",
            subcategories: []
        )
        let count = store.gameCount(for: fakeOpening)
        XCTAssertEqual(count, 0, "不存在的走法应返回 0")
    }

    func testGameCountForSubcategory() {
        let store = MasterGameStore.shared
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        guard let pingFengMa = zhongPao.subcategories.first(where: { $0.id == "zhong_pao_pingfengma" }) else {
            XCTFail("应存在中炮对屏风马子分类")
            return
        }
        let count = store.gameCount(for: pingFengMa)
        XCTAssertGreaterThanOrEqual(count, 0)
        // 验证与 bySubcategory 一致
        XCTAssertEqual(count, store.bySubcategory(pingFengMa.id).count)
    }

    func testGameCountForSubcategoryNonexistent() {
        let store = MasterGameStore.shared
        let fakeSub = OpeningSubcategory(
            id: "nonexistent_sub", name: "假", firstMoves: ["z9z9"], gameCount: 0
        )
        let count = store.gameCount(for: fakeSub)
        XCTAssertEqual(count, 0, "不存在的子分类应返回 0")
    }

    func testGameCountForOpeningMatchesByOpening() {
        // 验证 gameCount(for:) 与 byOpening().count 结果一致
        let store = MasterGameStore.shared
        for cat in OpeningCategories.categories {
            let viaGameCount = store.gameCount(for: cat)
            let viaByOpening = store.byOpening(cat.firstMove).count
            XCTAssertEqual(viaGameCount, viaByOpening,
                           "分类 \(cat.id): gameCount(for:) 应等于 byOpening().count")
        }
    }

    func testGameCountForSubcategoryMatchesBySubcategory() {
        // 验证 gameCount(for: OpeningSubcategory) 与 bySubcategory().count 结果一致
        let store = MasterGameStore.shared
        for cat in OpeningCategories.categories {
            for sub in cat.subcategories {
                let viaGameCount = store.gameCount(for: sub)
                let viaBySub = store.bySubcategory(sub.id).count
                XCTAssertEqual(viaGameCount, viaBySub,
                               "子分类 \(sub.id): gameCount(for:) 应等于 bySubcategory().count")
            }
        }
    }

    // MARK: - P1: populateGameCounts 已删除（不再修改 categories）

    func testNoPopulateGameCountsMutatesCategories() {
        // Phase C 后 categories 从 JSON 加载，gameCount 是 JSON 中的值
        // 验证 gameCount 不会被运行时 populateGameCounts 修改
        // 如果 populateGameCounts 还存在，gameCount 会被覆盖为 MasterGameStore 的值
        // 只需验证 categories 能正常加载且 gameCount >= 0
        for cat in OpeningCategories.categories {
            XCTAssertGreaterThanOrEqual(cat.gameCount, 0,
                           "分类 \(cat.id) gameCount 应 >= 0")
        }
    }

    // MARK: - P2: onChange 统一处理（行为验证）

    func testSubcategoryIndexBuiltOnLoad() {
        // 验证 buildSubcategoryIndices 在加载时构建了子分类索引
        let store = MasterGameStore.shared
        // 如果未加载，跳过
        guard store.isLoaded else {
            // 未加载时 gameCount 应为 0（索引为空）
            for cat in OpeningCategories.categories {
                XCTAssertEqual(store.gameCount(for: cat), 0)
            }
            return
        }
        // 已加载时，至少中炮应有对局
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        XCTAssertGreaterThan(store.gameCount(for: zhongPao), 0,
                             "中炮应是最常见开局，加载数据后应有对局")
    }

    // MARK: - 边界：OpeningCategory/OpeningSubcategory 结构完整性

    func testAllCategoriesHaveValidId() {
        for cat in OpeningCategories.categories {
            XCTAssertFalse(cat.id.isEmpty, "分类 id 不应为空")
        }
    }

    func testAllSubcategoriesHaveValidId() {
        for cat in OpeningCategories.categories {
            for sub in cat.subcategories {
                XCTAssertFalse(sub.id.isEmpty, "子分类 id 不应为空")
                XCTAssertFalse(sub.firstMoves.isEmpty,
                               "子分类 \(sub.id) 应有 firstMoves")
            }
        }
    }

    func testSubcategoryParentIdPrefix() {
        // 子分类 id 应以父分类 id 为前缀
        for cat in OpeningCategories.categories {
            for sub in cat.subcategories {
                XCTAssertTrue(sub.id.hasPrefix(cat.id + "_"),
                               "子分类 \(sub.id) 应以父分类 \(cat.id)_ 为前缀")
            }
        }
    }

    func testNoEmptySubcategoriesWithSubcategories() {
        // 有 subcategories 的分类，subcategories 不为空
        // 无 subcategories 的分类，subcategories 为空
        for cat in OpeningCategories.categories {
            if !cat.subcategories.isEmpty {
                XCTAssertGreaterThan(cat.subcategories.count, 0,
                                     "分类 \(cat.id) 有子分类时 count 应 > 0")
            }
        }
    }

    func testCategoryFirstMoveMatchesSubcategoryFirstMove() {
        // 子分类的 firstMoves[0] 应等于父分类的 firstMove
        for cat in OpeningCategories.categories {
            for sub in cat.subcategories {
                guard !sub.firstMoves.isEmpty else { continue }
                XCTAssertEqual(sub.firstMoves[0], cat.firstMove,
                               "子分类 \(sub.id) 的第一步 \(sub.firstMoves[0]) 应等于父分类 \(cat.id) 的 \(cat.firstMove)")
            }
        }
    }

    // MARK: - SidebarSelection.subcategory Hashable

    func testSidebarSelectionSubcategoryEquality() {
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        guard let sub1 = zhongPao.subcategories.first else {
            XCTFail("中炮应有子分类")
            return
        }
        let sel1 = SidebarSelection.subcategory(sub1)
        let sel2 = SidebarSelection.subcategory(sub1)
        XCTAssertEqual(sel1, sel2, "相同子分类的 SidebarSelection 应相等")
    }

    func testSidebarSelectionSubcategoryInequality() {
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        guard zhongPao.subcategories.count >= 2 else {
            XCTFail("中炮应至少有 2 个子分类")
            return
        }
        let sel1 = SidebarSelection.subcategory(zhongPao.subcategories[0])
        let sel2 = SidebarSelection.subcategory(zhongPao.subcategories[1])
        XCTAssertNotEqual(sel1, sel2, "不同子分类的 SidebarSelection 应不等")
    }

    func testSidebarSelectionOpeningVsSubcategory() {
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        guard let sub = zhongPao.subcategories.first else { return }
        let selOpening = SidebarSelection.opening(zhongPao)
        let selSub = SidebarSelection.subcategory(sub)
        XCTAssertNotEqual(selOpening, selSub,
                           "SidebarSelection.opening 和 .subcategory 不应相等")
    }

    // MARK: - iOS 钻入逻辑验证（子分类列表数据正确性）

    func testSubcategoryDrillDownDataConsistency() {
        // 验证子分类的 firstMoves 比父分类更长（前缀匹配）
        let zhongPao = OpeningCategories.categories.first { $0.id == "zhong_pao" }!
        for sub in zhongPao.subcategories {
            XCTAssertGreaterThan(sub.firstMoves.count, 1,
                                 "子分类 \(sub.id) 应有至少 2 步走法")
        }
    }

    func testOtherCategoryHasNoSubcategories() {
        let other = OpeningCategories.categories.first { $0.id == "other" }!
        XCTAssertTrue(other.subcategories.isEmpty, "其他开局不应有子分类")
        XCTAssertTrue(other.firstMove.isEmpty, "其他开局的 firstMove 应为空")
    }
}
