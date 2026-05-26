import XCTest
@testable import VocabGame

final class PetRepositoryPhase2Tests: XCTestCase {

    private var repo: PetRepository!
    private let testKey = "pet_repo_p2_test_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        repo = PetRepository(testKey: testKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        super.tearDown()
    }

    // MARK: - updatePetState

    func testUpdatePetState_modifiesState() {
        repo.updatePetState { state in
            state.accessories.append("hat_party")
            state.currentAccessory = "hat_party"
        }
        XCTAssertTrue(repo.petState.accessories.contains("hat_party"))
        XCTAssertEqual(repo.petState.currentAccessory, "hat_party")
    }

    // MARK: - addExp returns Bool

    func testAddExp_returnsBool() {
        let didLevelUp = repo.addExp(50)
        XCTAssertFalse(didLevelUp)
    }

    func testAddExp_levelUp_returnsTrue() {
        let didLevelUp = repo.addExp(100)
        XCTAssertTrue(didLevelUp)
        XCTAssertEqual(repo.petState.level, 2)
    }

    // MARK: - 持久化 accessories

    func testAccessories_persistAcrossReinit() {
        repo.updatePetState { state in
            state.accessories = ["hat_party", "hat_crown"]
            state.currentAccessory = "hat_crown"
        }

        let repo2 = PetRepository(testKey: testKey)
        XCTAssertEqual(repo2.petState.accessories, ["hat_party", "hat_crown"])
        XCTAssertEqual(repo2.petState.currentAccessory, "hat_crown")
    }

    func testEquipAndUnequip_persist() {
        repo.updatePetState { state in
            state.accessories = ["glasses_round"]
            state.currentAccessory = "glasses_round"
        }

        repo.updatePetState { state in
            state.currentAccessory = nil
        }

        let repo2 = PetRepository(testKey: testKey)
        XCTAssertTrue(repo2.petState.accessories.contains("glasses_round"))
        XCTAssertNil(repo2.petState.currentAccessory)
    }
}
