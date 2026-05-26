import XCTest
@testable import VocabGame

final class PetRepositoryTests: XCTestCase {

    private var repo: PetRepository!
    private let testKey = "petState_test_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        repo = PetRepository(testKey: testKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        repo = nil
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialState() {
        XCTAssertEqual(repo.petState.level, 1)
        XCTAssertEqual(repo.petState.exp, 0)
        XCTAssertEqual(repo.petState.mood, .normal)
    }

    // MARK: - addExp

    func testAddExp() {
        repo.addExp(50)
        XCTAssertEqual(repo.petState.exp, 50)
    }

    func testAddExp_levelUp() {
        repo.addExp(100)
        XCTAssertEqual(repo.petState.level, 2)
        XCTAssertEqual(repo.petState.exp, 0)
    }

    // MARK: - updateMood

    func testUpdateMood() {
        repo.updateMood(.happy)
        XCTAssertEqual(repo.petState.mood, .happy)
    }

    // MARK: - calculateMood

    func testCalculateMood_neverPlayed_isSad() {
        let profile = PlayerProfile()
        let mood = repo.calculateMood(profile: profile, hasMistakeWords: false)
        XCTAssertEqual(mood, .sad)
    }

    func testCalculateMood_excitedOverridesAll() {
        let profile = PlayerProfile()
        let mood = repo.calculateMood(profile: profile, hasMistakeWords: true, hasTriggeredExcited: true)
        XCTAssertEqual(mood, .excited)
    }

    func testCalculateMood_playedToday_noMistakes_isHappy() {
        var profile = PlayerProfile()
        profile.lastPlayDate = Date()
        let mood = repo.calculateMood(profile: profile, hasMistakeWords: false)
        XCTAssertEqual(mood, .happy)
    }

    func testCalculateMood_playedToday_hasMistakes_isNormal() {
        var profile = PlayerProfile()
        profile.lastPlayDate = Date()
        let mood = repo.calculateMood(profile: profile, hasMistakeWords: true)
        XCTAssertEqual(mood, .normal)
    }

    func testCalculateMood_notPlayedToday_isSad() {
        var profile = PlayerProfile()
        profile.lastPlayDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let mood = repo.calculateMood(profile: profile, hasMistakeWords: false)
        XCTAssertEqual(mood, .sad)
    }

    // MARK: - 持久化

    func testSaveAndReload() {
        repo.addExp(150)
        repo.updateMood(.excited)

        // 重新创建 repo 模拟重启
        let repo2 = PetRepository(testKey: testKey)
        XCTAssertEqual(repo2.petState.level, 2)
        XCTAssertEqual(repo2.petState.exp, 50)
        XCTAssertEqual(repo2.petState.mood, .excited)
    }
}
