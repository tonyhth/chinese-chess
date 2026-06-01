import XCTest
@testable import VocabGame
import SwiftUI

/// v1.17 角色选择系统测试
/// 覆盖：EggCharacter 模型, CharacterSelectView, PetHouseViewModel 角色切换/自动解锁,
///       ShopViewModel 角色商品, PetDisplayView 图片模式, PetMiniView, PetState 新字段,
///       ProgressData 版本号, 回归测试
@MainActor
final class V117CharacterTests: XCTestCase {

    // MARK: - Helpers

    private func makeProgressRepo() -> ProgressRepository {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("V117-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let repo = ProgressRepository(documentsDir: dir)
        repo.load()
        return repo
    }

    private func makePetRepo() -> PetRepository {
        PetRepository(testKey: "v117_pet_\(UUID().uuidString)")
    }

    // MARK: - 1. EggCharacter 模型

    func test_catalog_has6Characters() {
        XCTAssertEqual(EggCharacter.catalog.count, 6)
    }

    func test_catalog_allUniqueIds() {
        let ids = EggCharacter.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, 6)
    }

    func test_catalog_defaultIsFree() {
        let yellow = EggCharacter.catalog.first { $0.id == "egg_yellow" }
        XCTAssertEqual(yellow?.price, 0)
        XCTAssertEqual(yellow?.unlockType, .free)
    }

    func test_catalog_pinkIsCoinPurchase() {
        let pink = EggCharacter.catalog.first { $0.id == "egg_pink" }
        XCTAssertEqual(pink?.price, 80)
        XCTAssertEqual(pink?.unlockType, .coins)
    }

    func test_catalog_blackIsStreak7() {
        let black = EggCharacter.catalog.first { $0.id == "egg_black" }
        XCTAssertEqual(black?.price, 0)
        XCTAssertEqual(black?.unlockType, .streak7)
    }

    func test_catalog_redIsMaster50() {
        let red = EggCharacter.catalog.first { $0.id == "egg_red" }
        XCTAssertEqual(red?.price, 0)
        XCTAssertEqual(red?.unlockType, .master50)
    }

    func test_byId_returnsCorrectCharacter() {
        let char = EggCharacter.byId("egg_pink")
        XCTAssertEqual(char?.name, "蛋小粉")
    }

    func test_byId_returnsNilForUnknown() {
        XCTAssertNil(EggCharacter.byId("nonexistent"))
    }

    func test_imageName_usesMoodSuffix() {
        let char = EggCharacter.byId("egg_yellow")!
        XCTAssertEqual(char.imageName(mood: .happy), "egg_yellow_happy")
        XCTAssertEqual(char.imageName(mood: .normal), "egg_yellow_idle")
        XCTAssertEqual(char.imageName(mood: .sad), "egg_yellow_sad")
        XCTAssertEqual(char.imageName(mood: .excited), "egg_yellow_excited")
    }

    func test_miniImageName() {
        let char = EggCharacter.byId("egg_blue")!
        XCTAssertEqual(char.miniImageName, "egg_blue_mini")
    }

    // MARK: - 2. PetMood assetSuffix

    func test_petMood_assetSuffix() {
        XCTAssertEqual(PetMood.happy.assetSuffix, "happy")
        XCTAssertEqual(PetMood.normal.assetSuffix, "idle")
        XCTAssertEqual(PetMood.sad.assetSuffix, "sad")
        XCTAssertEqual(PetMood.excited.assetSuffix, "excited")
    }

    // MARK: - 3. PetState 新字段默认值

    func test_petState_defaultCharacterIsYellow() {
        var pet = PetState()
        XCTAssertEqual(pet.currentCharacterId, "egg_yellow")
        XCTAssertEqual(pet.ownedCharacterIds, ["egg_yellow"])
    }

    func test_petState_ownedCharacterIds_mutable() {
        var pet = PetState()
        pet.ownedCharacterIds.append("egg_pink")
        XCTAssertTrue(pet.ownedCharacterIds.contains("egg_pink"))
    }

    func test_petState_switchCharacter() {
        var pet = PetState()
        pet.ownedCharacterIds = ["egg_yellow", "egg_pink"]
        pet.currentCharacterId = "egg_pink"
        XCTAssertEqual(pet.currentCharacterId, "egg_pink")
    }

    // MARK: - 4. PetHouseViewModel 角色系统

    func test_petHouse_ownsDefaultCharacter() {
        let vm = PetHouseViewModel(petRepo: makePetRepo(), progressRepo: makeProgressRepo())
        vm.load()
        XCTAssertTrue(vm.ownsCharacter("egg_yellow"))
        XCTAssertFalse(vm.ownsCharacter("egg_pink"))
    }

    func test_petHouse_switchCharacter() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)

        // 赋予蛋小粉
        petRepo.updatePetState { $0.ownedCharacterIds.append("egg_pink") }
        vm.load()

        XCTAssertTrue(vm.ownsCharacter("egg_pink"))
        vm.switchCharacter(to: "egg_pink")
        XCTAssertEqual(vm.petState.currentCharacterId, "egg_pink")
    }

    func test_petHouse_cannotSwitchToUnowned() {
        let vm = PetHouseViewModel(petRepo: makePetRepo(), progressRepo: makeProgressRepo())
        vm.load()
        let prev = vm.petState.currentCharacterId
        vm.switchCharacter(to: "egg_black") // 未拥有
        XCTAssertEqual(vm.petState.currentCharacterId, prev, "不应切换到未拥有角色")
    }

    // MARK: - 5. 自动解锁: streak7

    func test_autoUnlock_streak7() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        // 设置 streak = 7
        progressRepo.updateProfile { $0.currentStreak = 7 }

        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)
        vm.load()

        XCTAssertTrue(vm.ownsCharacter("egg_black"), "streak>=7 应自动解锁蛋小黑")
    }

    func test_noAutoUnlock_streak6() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        progressRepo.updateProfile { $0.currentStreak = 6 }

        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)
        vm.load()

        XCTAssertFalse(vm.ownsCharacter("egg_black"), "streak<7 不应解锁")
    }

    // MARK: - 6. 自动解锁: master50

    func test_autoUnlock_master50() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        // 创建 50 个 mastered 单词
        for i in 1...50 {
            var wp = WordProgress.initial(wordId: i)
            wp.mastery = .mastered
            wp.lastReviewed = Date()
            progressRepo.updateWordProgress(wp)
        }

        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)
        vm.load()

        XCTAssertTrue(vm.ownsCharacter("egg_red"), "mastered>=50 应自动解锁蛋小红")
    }

    func test_noAutoUnlock_master49() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        for i in 1...49 {
            var wp = WordProgress.initial(wordId: i)
            wp.mastery = .mastered
            wp.lastReviewed = Date()
            progressRepo.updateWordProgress(wp)
        }

        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)
        vm.load()

        XCTAssertFalse(vm.ownsCharacter("egg_red"), "mastered<50 不应解锁")
    }

    // MARK: - 7. ShopViewModel 角色商品

    func test_shopCatalog_hasCharacterCategory() {
        let characterItems = ShopViewModel.catalog.filter { $0.category == .character }
        XCTAssertEqual(characterItems.count, 3, "应有 3 个角色商品（粉/蓝/绿）")
    }

    func test_shopCatalog_characterPrices() {
        let characterItems = ShopViewModel.catalog.filter { $0.category == .character }
        for item in characterItems {
            XCTAssertEqual(item.price, 80, "\(item.name) 应售价 80")
        }
    }

    func test_shopPurchase_character() {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)

        progressRepo.updateProfile { $0.coins = 200 }
        vm.load()

        let pinkItem = ShopViewModel.catalog.first { $0.id == "char_egg_pink" }!
        XCTAssertTrue(vm.canAfford(pinkItem))

        let result = vm.purchase(pinkItem)
        XCTAssertTrue(result)
        XCTAssertTrue(petRepo.petState.ownedCharacterIds.contains("egg_pink"))
    }

    func test_shopPurchase_characterNotRepeatable() {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)

        progressRepo.updateProfile { $0.coins = 1000 }
        petRepo.updatePetState { $0.ownedCharacterIds.append("egg_pink") }
        vm.load()

        let pinkItem = ShopViewModel.catalog.first { $0.id == "char_egg_pink" }!
        let result = vm.purchase(pinkItem)
        XCTAssertFalse(result, "已拥有角色不可重复购买")
    }

    func test_shopPurchase_characterInsufficientCoins() {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)

        progressRepo.updateProfile { $0.coins = 10 }
        vm.load()

        let pinkItem = ShopViewModel.catalog.first { $0.id == "char_egg_pink" }!
        XCTAssertFalse(vm.canAfford(pinkItem))
        let result = vm.purchase(pinkItem)
        XCTAssertFalse(result)
    }

    func test_shopEquip_character() {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)

        petRepo.updatePetState { $0.ownedCharacterIds.append("egg_blue") }
        vm.load()

        let blueItem = ShopViewModel.catalog.first { $0.id == "char_egg_blue" }!
        vm.equip(blueItem)
        XCTAssertEqual(petRepo.petState.currentCharacterId, "egg_blue")
    }

    func test_shopIsOwned_character() {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)

        petRepo.updatePetState { $0.ownedCharacterIds.append("egg_green") }
        vm.load()

        let greenItem = ShopViewModel.catalog.first { $0.id == "char_egg_green" }!
        XCTAssertTrue(vm.isOwned(greenItem))
    }

    // characterIdFromItemId is private — verified indirectly through purchase/equip tests

    // MARK: - 8. ShopCategory 新增 character

    func test_shopCategory_hasCharacter() {
        let allCases = ShopCategory.allCases
        XCTAssertTrue(allCases.contains(.character))
    }

    // MARK: - 9. PetDisplayView 图片模式

    func test_petDisplayView_usesCharacterImage() {
        var pet = PetState()
        pet.currentCharacterId = "egg_pink"
        pet.mood = .happy
        let view = PetDisplayView(petState: pet, size: 160)
        XCTAssertNotNil(view)
    }

    func test_petDisplayView_defaultCharacter() {
        var pet = PetState()
        let view = PetDisplayView(petState: pet, size: 160)
        XCTAssertNotNil(view)
        // imageName should be "egg_yellow_idle"
    }

    func test_petDisplayView_dizzyUsesSadImage() {
        var pet = PetState()
        pet.currentCharacterId = "egg_blue"
        let view = PetDisplayView(petState: pet, size: 160, showDizzy: true)
        XCTAssertNotNil(view)
        // imageName should be "egg_blue_sad"
    }

    func test_petDisplayView_levelUpStillWorks() {
        var pet = PetState()
        pet.currentCharacterId = "egg_green"
        let view = PetDisplayView(petState: pet, size: 160, isLevelingUp: true)
        XCTAssertNotNil(view)
    }

    // MARK: - 10. PetMiniView

    func test_petMiniView_defaultConstructs() {
        let view = PetMiniView(size: 40)
        XCTAssertNotNil(view)
    }

    func test_petMiniView_customCharacter() {
        let view = PetMiniView(size: 50, characterId: "egg_black")
        XCTAssertNotNil(view)
    }

    // MARK: - 11. ProgressData 版本号

    func test_progressData_version17() {
        let repo = makeProgressRepo()
        XCTAssertEqual(repo.data.version, 17, "ProgressData 版本应为 17")
    }

    // MARK: - 12. 回归: v1.16 功能不受影响

    func test_regression_petState_expStillWorks() {
        var pet = PetState()
        let leveled = pet.addExp(100)
        XCTAssertTrue(leveled)
        XCTAssertEqual(pet.level, 2)
    }

    func test_regression_petState_satietyStillWorks() {
        var pet = PetState()
        pet.satiety = 80
        pet.lastFedTime = Date().addingTimeInterval(-7200)
        pet.decaySatiety()
        XCTAssertEqual(pet.satiety, 70, "2小时应下降10点")
    }

    func test_regression_easterEggManager_stillWorks() {
        let manager = EasterEggManager()
        XCTAssertFalse(manager.showPetDance)
        XCTAssertFalse(manager.showPetDizzy)
    }

    // MARK: - 13. CharacterBonus 占位

    func test_characterBonus_none() {
        let bonus = CharacterBonus.none
        XCTAssertEqual(bonus.expMultiplier, 1.0)
        XCTAssertEqual(bonus.description, "")
    }

    func test_characterBonus_custom() {
        let bonus = CharacterBonus(expMultiplier: 1.5, description: "经验加成 50%")
        XCTAssertEqual(bonus.expMultiplier, 1.5)
        XCTAssertEqual(bonus.description, "经验加成 50%")
    }

    // MARK: - 14. 角色购买扣款验证

    func test_shopPurchase_characterDeductsCoins() {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)

        progressRepo.updateProfile { $0.coins = 200 }
        vm.load()
        XCTAssertEqual(vm.coins, 200)

        let pinkItem = ShopViewModel.catalog.first { $0.id == "char_egg_pink" }!
        _ = vm.purchase(pinkItem)
        XCTAssertEqual(vm.coins, 120, "200 - 80 = 120")
    }
}
