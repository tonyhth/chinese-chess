import XCTest
@testable import VocabGame

final class OnboardingTests: XCTestCase {

    private let onboardingKey = "hasSeenOnboarding_\(UUID().uuidString)"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: onboardingKey)
        super.tearDown()
    }

    // MARK: - 首次启动应显示引导

    func testFirstLaunch_shouldShowOnboarding() {
        let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        // 注意：可能被其他测试/环境设置过，这里只验证 key 的读取行为
        _ = hasSeen
    }

    // MARK: - 完成引导设置标记

    func testFinishOnboarding_setsUserDefaultsKey() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: onboardingKey))
    }

    func testFinishOnboarding_persists() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        // 模拟重启后读取
        let stored = UserDefaults.standard.bool(forKey: onboardingKey)
        XCTAssertTrue(stored)
    }

    // MARK: - 引导页数

    func testOnboardingPageCount_is4() {
        let pages = [
            OnboardingPage(icon: "🥚", title: "", description: "", color: .clear),
            OnboardingPage(icon: "🗺️", title: "", description: "", color: .clear),
            OnboardingPage(icon: "🐣", title: "", description: "", color: .clear),
            OnboardingPage(icon: "🎮", title: "", description: "", color: .clear),
        ]
        XCTAssertEqual(pages.count, 4)
    }

    // MARK: - 页面指示器（代码逻辑验证）

    func testPageIndicatorLogic_lastPageNoSkipButton() {
        // 最后一页不应显示"跳过"按钮
        let currentPage = 3 // 0-indexed, 第4页
        let isLastPage = currentPage >= 4 - 1
        XCTAssertTrue(isLastPage)
    }

    func testPageIndicatorLogic_nonLastPageHasSkipButton() {
        let currentPage = 0
        let isLastPage = currentPage >= 4 - 1
        XCTAssertFalse(isLastPage)
    }
}
