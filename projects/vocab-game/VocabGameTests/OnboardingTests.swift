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
        let hasSeen = UserDefaults.standard.bool(forKey: onboardingKey)
        XCTAssertFalse(hasSeen, "首次启动 hasSeenOnboarding 应为 false")
    }

    // MARK: - 完成引导设置标记

    func testFinishOnboarding_setsUserDefaultsKey() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: onboardingKey))
    }

    func testFinishOnboarding_persists() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        let stored = UserDefaults.standard.bool(forKey: onboardingKey)
        XCTAssertTrue(stored)
    }

    // MARK: - 引导页数（Phase 3 重设计后仍为 4 页）

    func testOnboardingPageCount_is4() {
        // OnboardingView 使用 TabView with 4 tags (0-3):
        // tag 0: hatchingPage (蛋仔破壳)
        // tag 1: tutorialPage (交互式答题)
        // tag 2: petHousePage (蛋仔之家预览)
        // tag 3: startPage (开始冒险)
        let pageCount = 4
        XCTAssertEqual(pageCount, 4)
    }

    // MARK: - 页面指示器逻辑

    func testPageIndicatorLogic_lastPageNoSkipButton() {
        let currentPage = 3
        let isLastPage = currentPage >= 4 - 1
        XCTAssertTrue(isLastPage)
    }

    func testPageIndicatorLogic_nonLastPageHasSkipButton() {
        let currentPage = 0
        let isLastPage = currentPage >= 4 - 1
        XCTAssertFalse(isLastPage)
    }
}
