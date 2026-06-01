import XCTest
@testable import VocabGame

final class PetStatePhase2Tests: XCTestCase {

    /// 创建无经验加成的 PetState
    private func noBonusPet() -> PetState {
        var pet = PetState()
        pet.satiety = 50
        return pet
    }

    // MARK: - addExp 返回 Bool

    func testAddExp_noLevelUp_returnsFalse() {
        var pet = noBonusPet()
        let didLevelUp = pet.addExp(50)
        XCTAssertFalse(didLevelUp)
    }

    func testAddExp_levelUp_returnsTrue() {
        var pet = noBonusPet()
        let didLevelUp = pet.addExp(100)
        XCTAssertTrue(didLevelUp)
    }

    func testAddExp_multipleLevelUps_returnsTrue() {
        var pet = noBonusPet()
        let didLevelUp = pet.addExp(350)
        XCTAssertTrue(didLevelUp)
        XCTAssertEqual(pet.level, 3)
    }

    func testAddExp_atMaxLevel_returnsFalse() {
        var pet = PetState()
        pet.level = 5
        let didLevelUp = pet.addExp(1000)
        XCTAssertFalse(didLevelUp)
        XCTAssertEqual(pet.level, 5)
    }

    func testAddExp_exactlyAtThreshold_returnsTrue() {
        var pet = noBonusPet()
        pet.level = 2
        let didLevelUp = pet.addExp(250)
        XCTAssertTrue(didLevelUp)
        XCTAssertEqual(pet.level, 3)
        XCTAssertEqual(pet.exp, 0)
    }

    // MARK: - 装饰相关

    func testAccessories_initialEmpty() {
        let pet = PetState()
        XCTAssertTrue(pet.accessories.isEmpty)
    }

    func testAccessories_canAdd() {
        var pet = PetState()
        pet.accessories.append("hat_party")
        XCTAssertEqual(pet.accessories.count, 1)
    }

    func testCurrentAccessory_initialNil() {
        let pet = PetState()
        XCTAssertNil(pet.currentAccessory)
    }

    func testCurrentAccessory_canSet() {
        var pet = PetState()
        pet.accessories.append("hat_crown")
        pet.currentAccessory = "hat_crown"
        XCTAssertEqual(pet.currentAccessory, "hat_crown")
    }

    // MARK: - Codable with accessories

    func testCodable_withAccessories() throws {
        var pet = noBonusPet()
        pet.addExp(200) // 200 with satiety≤50 → 200 exactly → L1→2(100), L2→3 needs 250, so L2 with 100 exp
        pet.accessories = ["hat_party", "glasses_round"]
        pet.currentAccessory = "hat_party"

        let data = try JSONEncoder().encode(pet)
        let decoded = try JSONDecoder().decode(PetState.self, from: data)

        XCTAssertEqual(decoded.accessories, ["hat_party", "glasses_round"])
        XCTAssertEqual(decoded.currentAccessory, "hat_party")
        XCTAssertEqual(decoded.level, 2, "200 exp → L1→2(100) → L2 exp=100")
        XCTAssertEqual(decoded.exp, 100)
    }
}
