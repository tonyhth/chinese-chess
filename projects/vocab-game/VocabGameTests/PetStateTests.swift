import XCTest
@testable import VocabGame

final class PetStateTests: XCTestCase {

    /// 辅助：创建无经验加成的 PetState（satiety ≤ 50）
    private func noBonusPet() -> PetState {
        var pet = PetState()
        pet.satiety = 50
        return pet
    }

    // MARK: - 初始状态

    func testInitialState() {
        let pet = PetState()
        XCTAssertEqual(pet.level, 1)
        XCTAssertEqual(pet.exp, 0)
        XCTAssertEqual(pet.mood, .normal)
        XCTAssertTrue(pet.accessories.isEmpty)
        XCTAssertNil(pet.currentAccessory)
        XCTAssertEqual(pet.satiety, 100)
    }

    // MARK: - 经验值 & 升级（无加成）

    func testAddExp_noLevelUp() {
        var pet = noBonusPet()
        pet.addExp(50)
        XCTAssertEqual(pet.level, 1)
        XCTAssertEqual(pet.exp, 50)
    }

    func testAddExp_levelUpOnce() {
        var pet = noBonusPet()
        pet.addExp(100)
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_exactThreshold_resetsExp() {
        var pet = noBonusPet()
        pet.addExp(100)
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_overflowCarriesOver() {
        var pet = noBonusPet()
        pet.addExp(150)
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 50)
    }

    func testAddExp_multipleLevelUps() {
        var pet = noBonusPet()
        pet.addExp(100 + 250)
        XCTAssertEqual(pet.level, 3)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_allLevels() {
        var pet = noBonusPet()
        pet.addExp(1850)
        XCTAssertEqual(pet.level, 5)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_pastMaxLevel_noCrash() {
        var pet = noBonusPet()
        pet.addExp(10000)
        XCTAssertEqual(pet.level, 5)
    }

    func testAddExp_incremental() {
        var pet = noBonusPet()
        pet.addExp(30)
        pet.addExp(30)
        pet.addExp(40)
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 0)
    }

    // MARK: - 饱腹度经验加成

    func testAddExp_withSatietyBonus() {
        var pet = PetState()
        pet.satiety = 80 // > 50 → 1.2x
        pet.addExp(100) // 100 * 1.2 = 120 → level up + 20 leftover
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 20)
    }

    // MARK: - expForNextLevel / expProgress

    func testExpForNextLevel_atLevel1() {
        let pet = PetState()
        XCTAssertEqual(pet.expForNextLevel, 100)
    }

    func testExpForNextLevel_atLevel5_isNil() {
        var pet = noBonusPet()
        pet.addExp(1850)
        XCTAssertNil(pet.expForNextLevel)
    }

    func testExpProgress() {
        var pet = noBonusPet()
        pet.addExp(50)
        XCTAssertEqual(pet.expProgress, 0.5, accuracy: 0.01)
    }

    func testExpProgress_atMaxLevel_is1() {
        var pet = noBonusPet()
        pet.addExp(1850)
        XCTAssertEqual(pet.expProgress, 1.0)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        var pet = noBonusPet()
        pet.addExp(120)
        pet.mood = .happy
        pet.accessories = ["hat"]

        let data = try JSONEncoder().encode(pet)
        let decoded = try JSONDecoder().decode(PetState.self, from: data)

        XCTAssertEqual(decoded.level, pet.level)
        XCTAssertEqual(decoded.exp, pet.exp)
        XCTAssertEqual(decoded.mood, pet.mood)
        XCTAssertEqual(decoded.accessories, pet.accessories)
    }
}
