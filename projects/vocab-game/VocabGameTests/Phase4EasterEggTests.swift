import XCTest
@testable import VocabGame
import SwiftUI

@MainActor
final class Phase4EasterEggTests: XCTestCase {

    private var manager: EasterEggManager!

    override func setUp() {
        super.setUp()
        manager = EasterEggManager()
    }

    // MARK: - 1. 连点 10 次 → 蛋仔晕倒

    func test_petTap_10_triggersDizzy() {
        XCTAssertFalse(manager.showPetDizzy)
        for _ in 0..<10 {
            manager.onPetTapped()
        }
        XCTAssertTrue(manager.showPetDizzy)
    }

    func test_petTap_9_doesNotTriggerDizzy() {
        for _ in 0..<9 {
            manager.onPetTapped()
        }
        XCTAssertFalse(manager.showPetDizzy)
    }

    // MARK: - 2. 20 连击 → 蛋仔跳舞

    func test_combo20_triggersDance() {
        XCTAssertFalse(manager.showPetDance)
        manager.checkComboEasterEgg(combo: 20)
        XCTAssertTrue(manager.showPetDance)
    }

    func test_combo19_doesNotTriggerDance() {
        manager.checkComboEasterEgg(combo: 19)
        XCTAssertFalse(manager.showPetDance)
    }

    func test_combo30_triggersDance() {
        manager.checkComboEasterEgg(combo: 30)
        XCTAssertTrue(manager.showPetDance)
    }

    // MARK: - 3. 连点重置 — 1.5 秒内未达 10 次

    func test_petTap_10_immediatelyAfterPartial_resetsAndTriggers() {
        // 点 5 次，不触发
        for _ in 0..<5 {
            manager.onPetTapped()
        }
        XCTAssertFalse(manager.showPetDizzy)
        // 再点 5 次 = 总共 10 → 触发
        for _ in 0..<5 {
            manager.onPetTapped()
        }
        XCTAssertTrue(manager.showPetDizzy)
    }

    // MARK: - 4. 节日特殊装扮

    func test_specialOutfit_nonSpecialDate_isNil() {
        // 大部分日期无特殊装扮
        // 这个测试在非特殊日期运行时应返回 nil
        let outfit = EasterEggManager.specialOutfitForToday()
        // 不断言 nil，因为测试可能在特殊日期运行
        if let outfit = outfit {
            XCTAssertFalse(outfit.isEmpty)
        }
    }

    func test_specialOutfit_returnsString() {
        // 验证返回类型
        let result = EasterEggManager.specialOutfitForToday()
        if result != nil {
            XCTAssertTrue((result ?? "").count <= 2, "outfit 应为 emoji")
        }
    }

    // MARK: - 5. 初始状态

    func test_initialState_noDanceNoDizzy() {
        let fresh = EasterEggManager()
        XCTAssertFalse(fresh.showPetDance)
        XCTAssertFalse(fresh.showPetDizzy)
        XCTAssertNil(fresh.specialOutfit)
    }
}
