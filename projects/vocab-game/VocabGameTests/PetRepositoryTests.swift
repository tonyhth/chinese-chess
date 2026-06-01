import XCTest
@testable import VocabGame

final class PetRepositoryTests: XCTestCase {

    private var repo: PetRepository!
    private let testKey = "petState_test_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        repo = PetRepository(testKey: testKey)
        // 关闭经验加成以保持原有测试预期
        repo.updatePetState { $0.satiety = 50 }
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

        let repo2 = PetRepository(testKey: testKey)
        // repo2 初始化时会 decaySatiety，satiety 可能影响经验
        // satiety=50 经过 reload 后可能 decay 但初始 satiety=50,lastFedTime=now → 0h decay → 50
        XCTAssertEqual(repo2.petState.level, 2)
        XCTAssertEqual(repo2.petState.mood, .excited)
    }

    // MARK: - 饱腹度经验加成

    func testAddExp_withSatietyBonus() {
        repo.updatePetState { $0.satiety = 80 }
        repo.addExp(100) // 100 * 1.2 = 120 → level up + 20 leftover
        XCTAssertEqual(repo.petState.level, 2)
        XCTAssertEqual(repo.petState.exp, 20)
    }
}
