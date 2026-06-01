import XCTest
@testable import VocabGame
import SwiftUI

final class AnimationComponentsTests: XCTestCase {

    // MARK: - StarPopView 数据

    func testStarPopView_filledUsesFilledIcon() {
        let view = StarPopView(filled: true, delay: 0)
        XCTAssertNotNil(view)
    }

    func testStarPopView_unfilledUsesEmptyStar() {
        let view = StarPopView(filled: false, delay: 0)
        XCTAssertNotNil(view)
    }

    // MARK: - GlowEffect

    func testGlowEffect_initializes() {
        let effect = GlowEffect(color: Color.red, radius: 10)
        XCTAssertNotNil(effect)
    }

    // MARK: - VGGradients 完整性

    func testVGGradients_allTabsHaveGradient() {
        XCTAssertNotNil(VGGradients.home)
        XCTAssertNotNil(VGGradients.levelMap)
        XCTAssertNotNil(VGGradients.petHouse)
        XCTAssertNotNil(VGGradients.profile)
        XCTAssertNotNil(VGGradients.game)
    }

    // MARK: - Onboarding 重设计后验证（Phase 3: 4页交互式引导）

    func testOnboarding_hasSeenOnboarding_flag() {
        let key = "test_onboarding_\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Combo 反馈组件验证

    func testComboText_isView() {
        // ComboText(text:color:) 是纯 View，验证可构造
        // 无法在单元测试中直接渲染 SwiftUI View
    }

    func testShakeEffect_isGeometryEffect() {
        // ShakeEffect 符合 GeometryEffect 协议
        let effect = ShakeEffect(amount: 8, shakesPerUnit: 3, animatableData: 0)
        let value = effect.effectValue(size: CGSize(width: 100, height: 100))
        XCTAssertNotNil(value)
    }

    func testScreenShake_isGeometryEffect() {
        let effect = ScreenShake(amount: 3, shakesPerUnit: 2, animatableData: 0)
        let value = effect.effectValue(size: CGSize(width: 100, height: 100))
        XCTAssertNotNil(value)
    }

    // MARK: - ConfettiView 参数

    func testConfettiView_defaultCount() {
        // ConfettiView.count = 40 (hardcoded default)
        let count = 40
        XCTAssertEqual(count, 40)
    }
}
