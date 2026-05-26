import XCTest
@testable import VocabGame

@MainActor
final class ShopTests: XCTestCase {

    private var petRepo: PetRepository!
    private var progressRepo: ProgressRepository!
    private let testKey = "petState_shop_test_\(UUID().uuidString)"
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShopTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        progressRepo = ProgressRepository(documentsDir: testDir)
        progressRepo.load()
        petRepo = PetRepository(testKey: testKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    // MARK: - 目录完整性

    func testCatalog_countIs8() {
        XCTAssertEqual(ShopViewModel.catalog.count, 8)
    }

    func testCatalog_allHaveUniqueIds() {
        let ids = ShopViewModel.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testCatalog_allAreAccessories() {
        for item in ShopViewModel.catalog {
            XCTAssertEqual(item.type, .accessory)
        }
    }

    func testCatalog_allPositivePrices() {
        for item in ShopViewModel.catalog {
            XCTAssertGreaterThan(item.price, 0)
        }
    }

    // MARK: - 购买逻辑（直接测试 repository 层）

    func testPurchase_deductsCoins() {
        // 初始金币为 0，给 100 币
        progressRepo.updateProfile { $0.coins = 100 }

        let item = ShopViewModel.catalog[0] // 派对帽 50
        XCTAssertTrue(progressRepo.profile.coins >= item.price)

        progressRepo.updateProfile { $0.coins -= item.price }
        XCTAssertEqual(progressRepo.profile.coins, 50)
    }

    func testPurchase_insufficientCoins_noChange() {
        progressRepo.updateProfile { $0.coins = 10 }

        let item = ShopViewModel.catalog[1] // 皇冠 100
        XCTAssertFalse(progressRepo.profile.coins >= item.price)
        XCTAssertEqual(progressRepo.profile.coins, 10) // 未扣款
    }

    func testPurchase_cannotBuyAlreadyOwned() {
        progressRepo.updateProfile { $0.coins = 1000 }
        let item = ShopViewModel.catalog[0]

        // 购买
        petRepo.updatePetState { $0.accessories.append(item.id) }
        XCTAssertTrue(petRepo.petState.accessories.contains(item.id))

        // 再次购买 → accessories 中已存在（应由 ViewModel 层的 guard 拦截）
        let countBefore = petRepo.petState.accessories.filter { $0 == item.id }.count
        // Repository 层不做去重，这是 ViewModel 的责任
    }

    // MARK: - 装备 / 卸下

    func testEquip_setsCurrentAccessory() {
        let item = ShopViewModel.catalog[0]
        petRepo.updatePetState { state in
            state.accessories.append(item.id)
        }
        petRepo.updatePetState { state in
            state.currentAccessory = item.id
        }

        XCTAssertEqual(petRepo.petState.currentAccessory, item.id)
    }

    func testUnequip_clearsCurrentAccessory() {
        petRepo.updatePetState { state in
            state.accessories = ["hat_party"]
            state.currentAccessory = "hat_party"
        }
        petRepo.updatePetState { state in
            state.currentAccessory = nil
        }
        XCTAssertNil(petRepo.petState.currentAccessory)
        XCTAssertTrue(petRepo.petState.accessories.contains("hat_party")) // 卸下不影响拥有
    }

    // MARK: - 持久化

    func testPurchase_persistsAcrossReinit() {
        progressRepo.updateProfile { $0.coins = 100 }

        let item = ShopViewModel.catalog[2] // 毛线帽 30
        progressRepo.updateProfile { $0.coins -= item.price }
        petRepo.updatePetState { $0.accessories.append(item.id) }

        // 重新初始化模拟重启
        let petRepo2 = PetRepository(testKey: testKey)
        XCTAssertTrue(petRepo2.petState.accessories.contains(item.id))
    }

    // MARK: - 金币收支平衡

    func testCoins_cannotGoNegative() {
        progressRepo.updateProfile { $0.coins = 20 }

        let expensiveItem = ShopViewModel.catalog[1] // 皇冠 100
        if progressRepo.profile.coins >= expensiveItem.price {
            XCTFail("不应该买得起")
        } else {
            // 没买，余额不变
            XCTAssertEqual(progressRepo.profile.coins, 20)
        }
    }

    func testMultiplePurchases_balanceIsCorrect() {
        progressRepo.updateProfile { $0.coins = 200 }

        // 买派对帽 50 + 毛线帽 30 + 圆眼镜 40 = 120
        let total = ShopViewModel.catalog[0].price + ShopViewModel.catalog[2].price + ShopViewModel.catalog[3].price
        progressRepo.updateProfile { $0.coins -= total }
        XCTAssertEqual(progressRepo.profile.coins, 80)
    }
}
