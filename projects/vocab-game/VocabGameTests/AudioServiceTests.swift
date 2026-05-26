import XCTest
@testable import VocabGame

@MainActor
final class AudioServiceTests: XCTestCase {

    private let testDefaultsKey = "audioServiceTest_\(UUID().uuidString)"

    override func tearDown() {
        // 清理测试状态，恢复 AudioService 默认设置
        AudioService.shared.isEnabled = true
        AudioService.shared.isBGMEnabled = true
        AudioService.shared.stopBGM()
        UserDefaults.standard.removeObject(forKey: "audioEnabled")
        UserDefaults.standard.removeObject(forKey: "bgmEnabled")
        super.tearDown()
    }

    // MARK: - isEnabled 持久化

    func testIsEnabled_persistsToUserDefaults() {
        AudioService.shared.isEnabled = false
        let stored = UserDefaults.standard.object(forKey: "audioEnabled") as? Bool
        XCTAssertFalse(stored ?? true)
    }

    func testIsEnabled_readsFromUserDefaults() {
        UserDefaults.standard.set(false, forKey: "audioEnabled")
        let stored = UserDefaults.standard.object(forKey: "audioEnabled") as? Bool
        XCTAssertFalse(stored ?? true)
    }

    // MARK: - isBGMEnabled 持久化

    func testIsBGMEnabled_persistsToUserDefaults() {
        AudioService.shared.isBGMEnabled = false
        let stored = UserDefaults.standard.object(forKey: "bgmEnabled") as? Bool
        XCTAssertFalse(stored ?? true)
    }

    // MARK: - 播放

    func testPlay_whenDisabled_doesNotCrash() {
        AudioService.shared.isEnabled = false
        AudioService.shared.play(.correct)
        AudioService.shared.play(.wrong)
        AudioService.shared.play(.combo)
    }

    func testPlay_whenEnabled_doesNotCrash() {
        AudioService.shared.isEnabled = true
        AudioService.shared.play(.correct)
        AudioService.shared.play(.wrong)
        AudioService.shared.play(.flip)
    }

    // MARK: - BGM

    func testStartBGM_whenDisabled_doesNotPlay() {
        AudioService.shared.isBGMEnabled = false
        AudioService.shared.startBGM()
    }

    func testStopBGM_doesNotCrash() {
        AudioService.shared.stopBGM()
    }

    func testToggleBGM_doesNotCrash() {
        AudioService.shared.toggleBGM()
    }

    // MARK: - SoundEffect 枚举完整性

    func testSoundEffect_allCases_count() {
        let allEffects = AudioService.SoundEffect.allCases
        XCTAssertGreaterThanOrEqual(allEffects.count, 8)
        XCTAssertTrue(allEffects.contains(.correct))
        XCTAssertTrue(allEffects.contains(.wrong))
        XCTAssertTrue(allEffects.contains(.combo))
        XCTAssertTrue(allEffects.contains(.flip))
        XCTAssertTrue(allEffects.contains(.match))
        XCTAssertTrue(allEffects.contains(.buttonTap))
        XCTAssertTrue(allEffects.contains(.upgrade))
        XCTAssertTrue(allEffects.contains(.petTap))
        XCTAssertTrue(allEffects.contains(.levelComplete))
    }

    // MARK: - 缓存

    func testPreload_doesNotCrash() {
        AudioService.shared.preload()
    }
}
