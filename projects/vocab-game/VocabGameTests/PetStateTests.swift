import XCTest
@testable import VocabGame

final class PetStateTests: XCTestCase {

    // MARK: - 初始状态

    func testInitialState() {
        let pet = PetState()
        XCTAssertEqual(pet.level, 1)
        XCTAssertEqual(pet.exp, 0)
        XCTAssertEqual(pet.mood, .normal)
        XCTAssertTrue(pet.accessories.isEmpty)
        XCTAssertNil(pet.currentAccessory)
    }

    // MARK: - 经验值 & 升级

    func testAddExp_noLevelUp() {
        var pet = PetState()
        pet.addExp(50)
        XCTAssertEqual(pet.level, 1)
        XCTAssertEqual(pet.exp, 50)
    }

    func testAddExp_levelUpOnce() {
        var pet = PetState()
        pet.addExp(100) // threshold for level 1→2
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_exactThreshold_resetsExp() {
        var pet = PetState()
        pet.addExp(100)
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_overflowCarriesOver() {
        var pet = PetState()
        pet.addExp(150) // 100 for L1→2, 50 leftover
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 50)
    }

    func testAddExp_multipleLevelUps() {
        var pet = PetState()
        pet.addExp(100 + 250) // L1→2 + L2→3
        XCTAssertEqual(pet.level, 3)
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_allLevels() {
        var pet = PetState()
        // thresholds: 100, 250, 500, 1000 = 1850 total
        pet.addExp(1850)
        XCTAssertEqual(pet.level, 5) // max level
        XCTAssertEqual(pet.exp, 0)
    }

    func testAddExp_pastMaxLevel_noCrash() {
        var pet = PetState()
        pet.addExp(10000)
        XCTAssertEqual(pet.level, 5)
    }

    func testAddExp_incremental() {
        var pet = PetState()
        pet.addExp(30)
        pet.addExp(30)
        pet.addExp(40)
        XCTAssertEqual(pet.level, 2)
        XCTAssertEqual(pet.exp, 0)
    }

    // MARK: - expForNextLevel / expProgress

    func testExpForNextLevel_atLevel1() {
        let pet = PetState()
        XCTAssertEqual(pet.expForNextLevel, 100)
    }

    func testExpForNextLevel_atLevel5_isNil() {
        var pet = PetState()
        pet.addExp(1850)
        XCTAssertNil(pet.expForNextLevel)
    }

    func testExpProgress() {
        var pet = PetState()
        pet.addExp(50)
        XCTAssertEqual(pet.expProgress, 0.5, accuracy: 0.01)
    }

    func testExpProgress_atMaxLevel_is1() {
        var pet = PetState()
        pet.addExp(1850)
        XCTAssertEqual(pet.expProgress, 1.0)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        var pet = PetState()
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
