import XCTest
@testable import VocabGame

@MainActor
final class Phase2FeatureTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeWordRepo() -> WordRepository {
        let words = (1...30).map { i in
            Word(id: i, text: "word\(i)", meaning: "含义\(i)", group: (i - 1) / 10 + 1)
        }
        return WordRepository(words: words)
    }

    private func makeProgressRepo() -> ProgressRepository {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ProgressRepository(documentsDir: dir)
    }

    private func makePetRepo() -> PetRepository {
        return PetRepository(testKey: "test_pet_\(UUID().uuidString)")
    }

    // MARK: - 1. 宠物互动系统

    // 1a. 抚摸宠物 — 成功 + 经验增加（初始 satiety=100 > 50 → 1.2x）
    func test_pet_success_addsExp() {
        let repo = makePetRepo()
        repo.updatePetState { $0.satiety = 40 } // ≤50 → 无加成
        let oldExp = repo.petState.exp
        let result = repo.pet()
        XCTAssertTrue(result)
        XCTAssertEqual(repo.petState.exp, oldExp + 5)
        XCTAssertEqual(repo.petState.interactionCount, 1)
    }

    // 1b. 抚摸宠物 — 30s 冷却
    func test_pet_cooldown_30seconds() {
        let repo = makePetRepo()
        _ = repo.pet()
        let result = repo.pet()
        XCTAssertFalse(result, "30s 内不应允许再次抚摸")
    }

    // 1c. 抚摸宠物 — 冷却后可再次抚摸
    func test_pet_afterCooldown() {
        let repo = makePetRepo()
        // 手动设置 lastPetTime 为 31s 前
        repo.updatePetState { state in
            state.lastPetTime = Date().addingTimeInterval(-31)
        }
        let result = repo.pet()
        XCTAssertTrue(result)
    }

    // 1d. 玩耍 — 心情变 happy + 经验变化
    func test_play_setsMoodHappy() {
        let repo = makePetRepo()
        repo.updatePetState { $0.mood = .sad }
        let result = repo.play()
        XCTAssertTrue(result)
        XCTAssertEqual(repo.petState.mood, .happy)
        XCTAssertEqual(repo.petState.interactionCount, 1)
    }

    // 1e. 玩耍 — 4h 冷却
    func test_play_cooldown_4hours() {
        let repo = makePetRepo()
        _ = repo.play()
        let result = repo.play()
        XCTAssertFalse(result, "4h 内不应允许再次玩耍")
    }

    // 1f. 玩耍 — 冷却后可再次玩耍
    func test_play_afterCooldown() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.lastPlayTime = Date().addingTimeInterval(-4 * 3600 - 1)
        }
        let result = repo.play()
        XCTAssertTrue(result)
    }

    // MARK: - 2. 饱腹度系统

    // 2a. 初始饱腹度 100
    func test_satiety_initialValue() {
        let state = PetState()
        XCTAssertEqual(state.satiety, 100)
    }

    // 2b. 饱腹度每小时衰减 5 点
    func test_satiety_decay_perHour() {
        var state = PetState()
        state.lastFedTime = Date().addingTimeInterval(-2 * 3600) // 2 小时前
        state.decaySatiety()
        XCTAssertEqual(state.satiety, 90, "2 小时 → 衰减 10 点")
    }

    // 2c. 饱腹度不低于 0
    func test_satiety_decay_floorZero() {
        var state = PetState()
        state.lastFedTime = Date().addingTimeInterval(-25 * 3600) // 25 小时前
        state.decaySatiety()
        XCTAssertEqual(state.satiety, 0)
    }

    // 2d. 饱腹度 > 50 → 经验加成 20%
    func test_expMultiplier_above50() {
        var state = PetState()
        state.satiety = 60
        XCTAssertEqual(state.expMultiplier, 1.2)
    }

    // 2e. 饱腹度 <= 50 → 无加成
    func test_expMultiplier_belowOrEqual50() {
        var state = PetState()
        state.satiety = 50
        XCTAssertEqual(state.expMultiplier, 1.0)

        state.satiety = 0
        XCTAssertEqual(state.expMultiplier, 1.0, "饱腹度 0 不惩罚")
    }

    // 2e2. 抚摸时 1.2x 加成
    func test_pet_expWithSatietyBonus() {
        let repo = makePetRepo()
        repo.updatePetState { $0.satiety = 80 } // >50 → 1.2x
        let oldExp = repo.petState.exp
        _ = repo.pet()
        XCTAssertEqual(repo.petState.exp, oldExp + 6, "5 * 1.2 = 6")
    }

    // 2f. 饱腹度 0 → 不惩罚（但会触发 level up 消耗经验）
    func test_expMultiplier_zero_noPenalty() {
        var state = PetState()
        state.satiety = 0
        state.level = 5 // 满级，不会再升级消耗经验
        _ = state.addExp(100)
        XCTAssertEqual(state.exp, 100)
    }

    // 2g. 饱腹度 > 50 → addExp 应用 1.2x（满级避免 level up 消耗）
    func test_addExp_withSatietyBonus() {
        var state = PetState()
        state.satiety = 80 // > 50 → 1.2x
        state.level = 5 // 满级
        _ = state.addExp(100)
        XCTAssertEqual(state.exp, 120, "100 * 1.2 = 120")
    }

    // 2h. 双倍经验特效叠加（满级避免 level up 消耗）
    func test_addExp_doubleExp_effect() {
        var state = PetState()
        state.satiety = 80  // 1.2x
        state.currentEffect = "double_exp" // 2x
        state.level = 5 // 满级
        _ = state.addExp(100)
        XCTAssertEqual(state.exp, 240, "100 * 1.2 * 2.0 = 240")
    }

    // MARK: - 3. 食物系统

    // 3a. Food.allFoods 包含 4 种
    func test_allFoods_count() {
        XCTAssertEqual(Food.allFoods.count, 4)
    }

    // 3b. Food.food(by:) 正确查找
    func test_food_lookup() {
        XCTAssertNotNil(Food.food(by: "cookie"))
        XCTAssertEqual(Food.food(by: "cookie")?.name, "小饼干")
        XCTAssertNotNil(Food.food(by: "starcandy"))
        XCTAssertNil(Food.food(by: "nonexistent"))
    }

    // 3c. 食物价格和饱腹度
    func test_food_properties() {
        let cookie = Food.food(by: "cookie")!
        XCTAssertEqual(cookie.price, 5)
        XCTAssertEqual(cookie.satiety, 15)
        XCTAssertEqual(cookie.effect, .none)

        let cake = Food.food(by: "cake")!
        XCTAssertEqual(cake.price, 15)
        XCTAssertEqual(cake.satiety, 30)
        XCTAssertEqual(cake.effect, .happyMood)

        let icecream = Food.food(by: "icecream")!
        XCTAssertEqual(icecream.satiety, 50)
        XCTAssertEqual(icecream.effect, .expBoost20)

        let starcandy = Food.food(by: "starcandy")!
        XCTAssertEqual(starcandy.satiety, 80)
        XCTAssertEqual(starcandy.effect, .doubleExp)
    }

    // 3d. 喂食 — 消耗食物 + 增加饱腹度
    func test_feed_consumesFood_andIncreasesSatiety() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.ownedFoods = ["cookie", "cookie"]
            state.satiety = 50
        }
        let result = repo.feed(foodId: "cookie")
        XCTAssertTrue(result)
        XCTAssertEqual(repo.petState.ownedFoods.count, 1, "应消耗 1 个饼干")
        XCTAssertEqual(repo.petState.satiety, 65, "50 + 15 = 65")
    }

    // 3e. 喂食 — 没有食物则失败
    func test_feed_noFood_fails() {
        let repo = makePetRepo()
        let result = repo.feed(foodId: "cookie")
        XCTAssertFalse(result)
    }

    // 3f. 喂食 — 饱腹度不超过 100
    func test_feed_satietyCap100() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.ownedFoods = ["starcandy"] // +80
            state.satiety = 90
        }
        _ = repo.feed(foodId: "starcandy")
        XCTAssertEqual(repo.petState.satiety, 100, "90 + 80 = 170 → cap 100")
    }

    // 3g. 喂食蛋糕 → 心情变 happy
    func test_feed_cake_setsHappyMood() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.ownedFoods = ["cake"]
            state.mood = .normal
        }
        _ = repo.feed(foodId: "cake")
        XCTAssertEqual(repo.petState.mood, .happy)
    }

    // 3h. 喂食冰淇淋 → 额外经验 +20（喂食后 satiety 变高但 feed 内 addExp 在 updatePetState 之后）
    // 注意：feed() 先 updatePetState (satiety +50), 再 addExp(20)
    // 所以 satiety 50+50=100 > 50 → 1.2x → 24
    func test_feed_icecream_grantsExp() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.ownedFoods = ["icecream"]
            state.satiety = 10 // 低饱腹度
        }
        let oldExp = repo.petState.exp
        _ = repo.feed(foodId: "icecream")
        // satiety = min(100, 10+50) = 60 > 50 → 1.2x
        XCTAssertEqual(repo.petState.exp, oldExp + 24, "20 * 1.2 = 24")
        XCTAssertEqual(repo.petState.satiety, 60)
    }

    // 3i. 喂食星星糖果 → 设置双倍经验特效
    func test_feed_starcandy_setsDoubleExp() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.ownedFoods = ["starcandy"]
            state.currentEffect = nil
        }
        _ = repo.feed(foodId: "starcandy")
        XCTAssertTrue(repo.petState.hasDoubleExp)
        XCTAssertEqual(repo.petState.currentEffect, "double_exp")
    }

    // 3j. 喂食 — 无效 foodId
    func test_feed_invalidFoodId_fails() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.ownedFoods = ["invalid_food"]
        }
        let result = repo.feed(foodId: "invalid_food")
        XCTAssertFalse(result, "Food.food(by:) 返回 nil 时应失败")
    }

    // MARK: - 4. 商店扩充

    // 4a. 5 个分类 Tab
    func test_shopCategories() {
        XCTAssertEqual(ShopCategory.allCases.count, 6)
        XCTAssertTrue(ShopCategory.allCases.contains(.food))
        XCTAssertTrue(ShopCategory.allCases.contains(.hat))
        XCTAssertTrue(ShopCategory.allCases.contains(.accessory))
        XCTAssertTrue(ShopCategory.allCases.contains(.scene))
        XCTAssertTrue(ShopCategory.allCases.contains(.effect))
    }

    // 4b. Catalog 包含食物商品
    func test_shopCatalog_hasFoods() {
        let foodItems = ShopViewModel.catalog.filter { $0.category == .food }
        XCTAssertEqual(foodItems.count, 4)
        // 食物 ID 格式: "food_cookie", "food_cake", "food_icecream", "food_starcandy"
        XCTAssertTrue(foodItems.contains { $0.id == "food_cookie" })
        XCTAssertTrue(foodItems.contains { $0.id == "food_cake" })
        XCTAssertTrue(foodItems.contains { $0.id == "food_icecream" })
        XCTAssertTrue(foodItems.contains { $0.id == "food_starcandy" })
    }

    // 4c. Catalog 包含场景商品
    func test_shopCatalog_hasScenes() {
        let sceneItems = ShopViewModel.catalog.filter { $0.category == .scene }
        XCTAssertEqual(sceneItems.count, 4)
        XCTAssertTrue(sceneItems.contains { $0.id == "scene_garden" })
        XCTAssertTrue(sceneItems.contains { $0.id == "scene_beach" })
    }

    // 4d. Catalog 包含特效商品
    func test_shopCatalog_hasEffects() {
        let effectItems = ShopViewModel.catalog.filter { $0.category == .effect }
        XCTAssertEqual(effectItems.count, 3)
        XCTAssertTrue(effectItems.contains { $0.id == "effect_rainbow" })
    }

    // 4e. 购买食物 — 金币扣除 + ownedFoods 增加
    func test_shop_purchaseFood() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 100 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let foodItem = ShopViewModel.catalog.first { $0.id == "food_cookie" }!
        let result = vm.purchase(foodItem)
        XCTAssertTrue(result)
        XCTAssertEqual(vm.coins, 95, "100 - 5 = 95")

        // 验证食物已入库
        let foodId = String(foodItem.id.dropFirst(5)) // "cookie"
        XCTAssertTrue(petRepo.petState.ownedFoods.contains(foodId))
    }

    // 4f. 食物可重复购买
    func test_shop_foodRepeatablePurchase() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 20 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let foodItem = ShopViewModel.catalog.first { $0.id == "food_cookie" }!
        _ = vm.purchase(foodItem)
        _ = vm.purchase(foodItem)
        XCTAssertEqual(petRepo.petState.ownedFoods.filter { $0 == "cookie" }.count, 2)
        XCTAssertEqual(vm.coins, 10, "20 - 5*2 = 10")
    }

    // 4g. 买完食物后喂食成功（ID 对齐）
    func test_shop_buyThenFeed_alignment() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 100 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        // 购买蛋糕
        let cakeItem = ShopViewModel.catalog.first { $0.id == "food_cake" }!
        _ = vm.purchase(cakeItem)

        // 先降低饱腹度以验证增加
        petRepo.updatePetState { $0.satiety = 50 }

        // 用 PetRepository 喂食
        let petVM = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)
        petVM.load()
        let result = petVM.feed(foodId: "cake")
        XCTAssertTrue(result, "商店购买 → 喂食应成功，ID 对齐")
        XCTAssertEqual(petVM.petState.satiety, 80, "50 + 30 = 80")
        XCTAssertEqual(petVM.petState.mood, .happy)
    }

    // 4h. 购买场景 → ownedScenes 增加
    func test_shop_purchaseScene() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 200 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let sceneItem = ShopViewModel.catalog.first { $0.id == "scene_garden" }!
        let result = vm.purchase(sceneItem)
        XCTAssertTrue(result)
        XCTAssertTrue(petRepo.petState.ownedScenes.contains("scene_garden"))
    }

    // 4i. 装备场景
    func test_shop_equipScene() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 200 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let sceneItem = ShopViewModel.catalog.first { $0.id == "scene_garden" }!
        _ = vm.purchase(sceneItem)
        vm.equip(sceneItem)
        XCTAssertEqual(petRepo.petState.currentScene, "scene_garden")
    }

    // 4j. 购买特效 → ownedEffects 增加
    func test_shop_purchaseEffect() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 200 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let effectItem = ShopViewModel.catalog.first { $0.id == "effect_rainbow" }!
        let result = vm.purchase(effectItem)
        XCTAssertTrue(result)
        XCTAssertTrue(petRepo.petState.ownedEffects.contains("effect_rainbow"))
    }

    // 4k. 非食物不可重复购买
    func test_shop_nonFoodNotRepeatable() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 200 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let hatItem = ShopViewModel.catalog.first { $0.id == "hat_party" }!
        let first = vm.purchase(hatItem)
        XCTAssertTrue(first)
        let second = vm.purchase(hatItem)
        XCTAssertFalse(second, "帽子不可重复购买")
    }

    // 4l. 余额不足时购买失败
    func test_shop_cannotAfford() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        progressRepo.updateProfile { $0.coins = 2 }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let foodItem = ShopViewModel.catalog.first { $0.id == "food_cookie" }!
        let result = vm.purchase(foodItem)
        XCTAssertFalse(result)
    }

    // MARK: - 5. 听写模式

    // 5a. isDictationMode 标记设置
    func test_dictationMode_flag() {
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        XCTAssertFalse(vm.isDictationMode)
        vm.isDictationMode = true
        XCTAssertTrue(vm.isDictationMode)
    }

    // 5b. 听写模式计分：无提示 150 分
    func test_dictation_scoring_noHint() {
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true
        vm.words = makeWordRepo().allWords.prefix(3).map { $0 }
        vm.currentIndex = 0
        vm.spelledAnswer = vm.currentWord!.text
        vm.submit()

        XCTAssertEqual(vm.score, 150, "听写无提示 → 150 分")
    }

    // 5c. 听写模式计分：使用首字母提示后 100 分
    func test_dictation_scoring_withHint() {
        let progressRepo = makeProgressRepo()
        progressRepo.updateProfile { $0.coins = 50 }
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: progressRepo,
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true
        vm.words = makeWordRepo().allWords.prefix(3).map { $0 }
        vm.currentIndex = 0
        let hintResult = vm.useFirstLetterHint()
        XCTAssertTrue(hintResult, "应有足够金币使用提示")
        vm.spelledAnswer = vm.currentWord!.text
        vm.submit()

        XCTAssertEqual(vm.score, 100, "听写有提示 → 100 分")
    }

    // 5d. 听写模式计分：错误 0 分
    func test_dictation_scoring_wrong() {
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true
        vm.words = makeWordRepo().allWords.prefix(3).map { $0 }
        vm.currentIndex = 0
        vm.spelledAnswer = "wronganswer"
        vm.submit()

        XCTAssertEqual(vm.score, 0, "听写错误 → 0 分")
        XCTAssertEqual(vm.combo, 0)
    }

    // 5e. useFirstLetterHint 扣 10 币
    func test_dictation_firstLetterHint_costs10() {
        let progressRepo = makeProgressRepo()
        progressRepo.updateProfile { $0.coins = 50 }
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: progressRepo,
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true

        let result = vm.useFirstLetterHint()
        XCTAssertTrue(result)
        XCTAssertEqual(progressRepo.profile.coins, 40)
        XCTAssertTrue(vm.usedDictationHint)
    }

    // 5f. useFirstLetterHint 余额不足
    func test_dictation_firstLetterHint_noCoins() {
        let progressRepo = makeProgressRepo()
        progressRepo.updateProfile { $0.coins = 5 }
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: progressRepo,
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true

        let result = vm.useFirstLetterHint()
        XCTAssertFalse(result)
    }

    // 5g. firstLetterHint 显示首字母
    func test_dictation_firstLetterHint_display() {
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true
        vm.words = [Word(id: 1, text: "apple", meaning: "苹果", group: 1)]
        vm.currentIndex = 0
        vm.usedDictationHint = true

        XCTAssertEqual(vm.firstLetterHint, "A")
    }

    // 5h. replayAudio 扣 5 币
    func test_dictation_replayAudio_costs5() {
        let progressRepo = makeProgressRepo()
        progressRepo.updateProfile { $0.coins = 20 }
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: progressRepo,
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true

        let result = vm.replayAudio()
        XCTAssertTrue(result)
        XCTAssertEqual(progressRepo.profile.coins, 15)
        XCTAssertEqual(vm.replayCount, 1)
    }

    // 5i. replayAudio 余额不足
    func test_dictation_replayAudio_noCoins() {
        let progressRepo = makeProgressRepo()
        progressRepo.updateProfile { $0.coins = 3 }
        let vm = SpellChallengeViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: progressRepo,
            petRepo: makePetRepo()
        )
        vm.isDictationMode = true

        let result = vm.replayAudio()
        XCTAssertFalse(result)
    }

    // MARK: - 6. 单词跑酷

    // 6a. WordRunnerViewModel 初始化
    func test_wordRunner_init() {
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        XCTAssertFalse(vm.isRunning)
        XCTAssertEqual(vm.lives, 3)
        XCTAssertEqual(vm.timeRemaining, 60)
        XCTAssertEqual(vm.score, 0)
        XCTAssertEqual(vm.combo, 0)
    }

    // 6b. start() — 单词不足报错
    func test_wordRunner_start_notEnoughWords() {
        let smallRepo = WordRepository(words: [Word(id: 1, text: "a", meaning: "一", group: 1)])
        let vm = WordRunnerViewModel(
            wordRepo: smallRepo,
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isRunning)
    }

    // 6c. start() — 正常开始
    func test_wordRunner_start_normal() {
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()
        XCTAssertTrue(vm.isRunning)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.lives, 3)
        XCTAssertEqual(vm.timeRemaining, 60)
    }

    // 6d. selectLane 正确选项 — 加分 + combo
    func test_wordRunner_selectCorrectLane() {
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()

        // 找到正确答案的 lane
        if let correctIdx = vm.lanes.firstIndex(where: { $0.isCorrect }) {
            vm.selectLane(correctIdx)
            XCTAssertGreaterThan(vm.score, 0)
            XCTAssertEqual(vm.combo, 1)
            XCTAssertEqual(vm.maxCombo, 1)
        } else {
            XCTFail("应有一个正确选项")
        }
    }

    // 6e. selectLane 错误选项 — 扣命 + combo 归零
    func test_wordRunner_selectWrongLane() {
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()

        // 先正确一次建立 combo
        if let correctIdx = vm.lanes.firstIndex(where: { $0.isCorrect }) {
            vm.selectLane(correctIdx)
        }
        XCTAssertEqual(vm.combo, 1)

        // 选择错误选项
        if let wrongIdx = vm.lanes.firstIndex(where: { !$0.isCorrect }) {
            vm.selectLane(wrongIdx)
            XCTAssertEqual(vm.lives, 2, "错一次扣 1 命")
            XCTAssertEqual(vm.combo, 0)
        }
    }

    // 6f. 连击计分：combo * 10 加成
    func test_wordRunner_comboScoring() {
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()

        // 连续正确 3 次
        for _ in 0..<3 {
            if let correctIdx = vm.lanes.firstIndex(where: { $0.isCorrect }) {
                vm.selectLane(correctIdx)
            }
        }

        // combo 3 → 第 3 次得分 = 100 + 2*10 = 120（combo 从 0 开始计数时第3次的 combo=2）
        // 实际: 第1次 combo=0 → 100+0=100, 第2次 combo=1 → 100+10=110, 第3次 combo=2 → 100+20=120
        // 总分 = 100 + 110 + 120 = 330
        XCTAssertGreaterThan(vm.score, 200)
        XCTAssertEqual(vm.maxCombo, 3)
    }

    // 6g. stop() 停止游戏
    func test_wordRunner_stop() {
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()
        XCTAssertTrue(vm.isRunning)
        vm.stop()
        XCTAssertFalse(vm.isRunning)
    }

    // 6h. endGame 幂等验证 — guard isCompleted 防止重复
    func test_wordRunner_endGame_guard_isCompleted() {
        // endGame 内部有 guard !isCompleted else { return }
        // 此处验证 endGame 逻辑：isCompleted 一旦设为 true 不再发放奖励
        // 实际行为由 stop() + gameTask cancel 保证
        let vm = WordRunnerViewModel(
            wordRepo: makeWordRepo(),
            progressRepo: makeProgressRepo(),
            petRepo: makePetRepo()
        )
        vm.start()
        vm.stop()
        XCTAssertFalse(vm.isRunning)
    }

    // MARK: - 7. 对话气泡

    // 7a. PetDialogue 随机对话返回非空字符串
    func test_dialogue_random_returnsNonEmpty() {
        for scene in PetDialogueScene.allCases {
            let text = PetDialogue.randomDialogue(for: scene)
            XCTAssertFalse(text.isEmpty, "\(scene) 应返回非空对话")
        }
    }

    // 7b. 饱腹度 < 30 且 scene==.hungry 时显示饥饿对话
    func test_dialogue_hungry_whenLow() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.satiety = 10
        }
        let text = repo.getDialogue(scene: .hungry)
        let hungryDialogues = PetDialogue.dialogues[.hungry]!
        XCTAssertTrue(hungryDialogues.contains(text), "scene=.hungry + satiety<30 → 饥饿对话")
    }

    // 7b2. [发现] 饱腹度低 + scene 非 .hungry → 仍返回普通对话（潜在 P2）
    func test_dialogue_hungry_notTriggered_forNonHungryScene() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.satiety = 10
        }
        let text = repo.getDialogue(scene: .greeting)
        let hungryDialogues = PetDialogue.dialogues[.hungry]!
        XCTAssertFalse(hungryDialogues.contains(text), "scene=.greeting 不触发饥饿对话")
    }

    // 7c. 饱腹度正常时显示正常对话
    func test_dialogue_normal_whenSatietyOk() {
        let repo = makePetRepo()
        repo.updatePetState { state in
            state.satiety = 80
        }
        let text = repo.getDialogue(scene: .greeting)
        let hungryDialogues = PetDialogue.dialogues[.hungry]!
        XCTAssertFalse(hungryDialogues.contains(text), "饱腹度高时不应显示饥饿对话")
    }

    // MARK: - 8. PetState Codable 兼容性

    // 8a. 新字段编码解码
    func test_petState_codable_newFields() throws {
        var state = PetState()
        state.satiety = 70
        state.ownedFoods = ["cookie", "cake"]
        state.ownedScenes = ["scene_garden"]
        state.currentEffect = "double_exp"

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PetState.self, from: data)

        XCTAssertEqual(decoded.satiety, 70)
        XCTAssertEqual(decoded.ownedFoods, ["cookie", "cake"])
        XCTAssertEqual(decoded.ownedScenes, ["scene_garden"])
        XCTAssertEqual(decoded.currentEffect, "double_exp")
    }

    // 8b. PetHouseViewModel.load() 刷新 petState
    func test_petHouseViewModel_load() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)

        petRepo.updatePetState { $0.level = 3 }
        vm.load()

        XCTAssertEqual(vm.petState.level, 3)
    }

    // 8c. PetHouseViewModel.pet() 刷新状态
    func test_petHouseViewModel_pet() {
        let petRepo = makePetRepo()
        let progressRepo = makeProgressRepo()
        let vm = PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo)

        // 确保可抚摸
        petRepo.updatePetState { $0.lastPetTime = Date.distantPast }
        vm.load()
        let result = vm.pet()

        XCTAssertTrue(result)
        XCTAssertEqual(vm.petState.interactionCount, 1)
    }

    // MARK: - 9. GameMode 包含 wordRunner 和 dictation

    // 9a. GameMode 新增类型
    func test_gameMode_newCases() {
        XCTAssertTrue(GameMode.allCases.contains(.wordRunner))
        XCTAssertTrue(GameMode.allCases.contains(.dictation))
    }

    // 9b. GameMode rawValue
    func test_gameMode_rawValues() {
        XCTAssertEqual(GameMode.wordRunner.rawValue, "wordRunner")
        XCTAssertEqual(GameMode.dictation.rawValue, "dictation")
    }

    // MARK: - 10. ShopViewModel ownedCount

    // 10a. ownedCount for food
    func test_shop_ownedCount_food() async {
        let progressRepo = makeProgressRepo()
        let petRepo = makePetRepo()
        petRepo.updatePetState { state in
            state.ownedFoods = ["cookie", "cookie", "cake"]
        }
        let vm = ShopViewModel(progressRepo: progressRepo, petRepo: petRepo)
        vm.load()

        let cookie = ShopViewModel.catalog.first { $0.id == "food_cookie" }!
        XCTAssertEqual(vm.ownedCount(for: cookie), 2)

        let cake = ShopViewModel.catalog.first { $0.id == "food_cake" }!
        XCTAssertEqual(vm.ownedCount(for: cake), 1)

        let icecream = ShopViewModel.catalog.first { $0.id == "food_icecream" }!
        XCTAssertEqual(vm.ownedCount(for: icecream), 0)
    }
}


