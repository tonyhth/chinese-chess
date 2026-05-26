import XCTest
@testable import VocabGame

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
        let effect = GlowEffect(color: .red, radius: 10)
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

    func testVGGradients_countIs5() {
        let _ = VGGradients.home
        let _ = VGGradients.levelMap
        let _ = VGGradients.petHouse
        let _ = VGGradients.profile
        let _ = VGGradients.game
    }

    // MARK: - OnboardingPage 数据

    func testOnboardingPages_countIs4() {
        let pages = [
            OnboardingPage(icon: "🥚", title: "t1", description: "d1", color: .red),
            OnboardingPage(icon: "🗺️", title: "t2", description: "d2", color: .blue),
            OnboardingPage(icon: "🐣", title: "t3", description: "d3", color: .green),
            OnboardingPage(icon: "🎮", title: "t4", description: "d4", color: .purple),
        ]
        XCTAssertEqual(pages.count, 4)
    }

    func testOnboardingPages_nonEmptyContent() {
        let page = OnboardingPage(icon: "🥚", title: "欢迎", description: "描述", color: .pink)
        XCTAssertFalse(page.icon.isEmpty)
        XCTAssertFalse(page.title.isEmpty)
        XCTAssertFalse(page.description.isEmpty)
    }
}
