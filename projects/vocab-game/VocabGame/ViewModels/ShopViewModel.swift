import Foundation

struct ShopItem: Identifiable, Codable {
    let id: String
    let name: String
    let type: ShopItemType
    let category: ShopCategory
    let price: Int
    let description: String
}

enum ShopCategory: String, Codable, CaseIterable {
    case character = "角色"
    case food = "食物"
    case hat = "帽子"
    case accessory = "服装"
    case scene = "场景"
    case effect = "特效"
}

enum ShopItemType: String, Codable {
    case accessory  // Pet decoration
    case hint       // Spell hint
    case extraTime  // Extra time for daily challenge
}

@MainActor
class ShopViewModel: ObservableObject {
    @Published var items: [ShopItem] = []
    @Published var coins: Int = 0
    @Published var ownedItemIds: Set<String> = []
    @Published var currentAccessoryId: String? = nil

    private let progressRepo: ProgressRepository
    private let petRepo: PetRepository
    private weak var achievementRepo: AchievementRepository?

    static let catalog: [ShopItem] = [
        // v1.17: 角色 (金币购买)
        ShopItem(id: "char_egg_pink", name: "蛋小粉", type: .accessory, category: .character, price: 80, description: "粉色蛋仔，甜美可爱"),
        ShopItem(id: "char_egg_blue", name: "蛋小蓝", type: .accessory, category: .character, price: 80, description: "蓝色蛋仔，活泼好动"),
        ShopItem(id: "char_egg_green", name: "蛋小绿", type: .accessory, category: .character, price: 80, description: "绿色蛋仔，清新自然"),
        // 装饰品 (hat)
        ShopItem(id: "hat_party", name: "派对帽", type: .accessory, category: .hat, price: 50, description: "彩色派对帽，喜庆又可爱"),
        ShopItem(id: "hat_crown", name: "皇冠", type: .accessory, category: .hat, price: 100, description: "金灿灿的小皇冠"),
        ShopItem(id: "hat_beanie", name: "毛线帽", type: .accessory, category: .hat, price: 30, description: "暖暖的毛线帽"),
        // 装饰品 (clothing/accessory)
        ShopItem(id: "glasses_round", name: "圆眼镜", type: .accessory, category: .accessory, price: 40, description: "文艺范儿的圆眼镜"),
        ShopItem(id: "glasses_sunglasses", name: "墨镜", type: .accessory, category: .accessory, price: 60, description: "酷酷的蛋仔墨镜"),
        ShopItem(id: "scarf_red", name: "红围巾", type: .accessory, category: .accessory, price: 45, description: "温暖的红围巾"),
        ShopItem(id: "bow_pink", name: "粉色蝴蝶结", type: .accessory, category: .accessory, price: 35, description: "可爱的粉色蝴蝶结"),
        ShopItem(id: "cape_super", name: "超人披风", type: .accessory, category: .accessory, price: 80, description: "超级蛋仔的标志披风"),
        // 食物
        ShopItem(id: "food_cookie", name: "小饼干", type: .accessory, category: .food, price: 5, description: "简单美味，饱腹度+15"),
        ShopItem(id: "food_cake", name: "蛋糕", type: .accessory, category: .food, price: 15, description: "香甜蛋糕，饱腹度+30，心情变开心"),
        ShopItem(id: "food_icecream", name: "彩虹冰淇淋", type: .accessory, category: .food, price: 30, description: "七彩冰淇淋，饱腹度+50，经验+20"),
        ShopItem(id: "food_starcandy", name: "星星糖果", type: .accessory, category: .food, price: 50, description: "神奇糖果，饱腹度+80，下局双倍经验"),
        // 场景
        ShopItem(id: "scene_garden", name: "花园", type: .accessory, category: .scene, price: 100, description: "鲜花盛开的花园"),
        ShopItem(id: "scene_beach", name: "海滩", type: .accessory, category: .scene, price: 120, description: "阳光沙滩海浪"),
        ShopItem(id: "scene_starry", name: "星空", type: .accessory, category: .scene, price: 150, description: "繁星闪烁的夜空"),
        ShopItem(id: "scene_castle", name: "城堡", type: .accessory, category: .scene, price: 200, description: "梦幻水晶城堡"),
        // 特效
        ShopItem(id: "effect_rainbow", name: "彩虹尾迹", type: .accessory, category: .effect, price: 80, description: "移动时留下彩虹痕迹"),
        ShopItem(id: "effect_hearts", name: "爱心泡泡", type: .accessory, category: .effect, price: 100, description: "身边飘浮爱心泡泡"),
        ShopItem(id: "effect_stars", name: "星星光环", type: .accessory, category: .effect, price: 120, description: "头顶闪烁星星光环"),
    ]

    init(progressRepo: ProgressRepository, petRepo: PetRepository, achievementRepo: AchievementRepository? = nil) {
        self.progressRepo = progressRepo
        self.petRepo = petRepo
        self.achievementRepo = achievementRepo
    }

    func load() {
        coins = progressRepo.profile.coins
        ownedItemIds = Set(petRepo.petState.accessories)
        currentAccessoryId = petRepo.petState.currentAccessory
        items = Self.catalog
    }

    func canAfford(_ item: ShopItem) -> Bool {
        coins >= item.price
    }

    func isOwned(_ item: ShopItem) -> Bool {
        switch item.category {
        case .character:
            let charId = Self.characterIdFromItemId(item.id)
            return petRepo.petState.ownedCharacterIds.contains(charId)
        case .food:
            let foodId = Self.foodIdFromItemId(item.id)
            return petRepo.petState.ownedFoods.contains(foodId)
        case .hat, .accessory:
            return ownedItemIds.contains(item.id)
        case .scene:
            return petRepo.petState.ownedScenes.contains(item.id)
        case .effect:
            return petRepo.petState.ownedEffects.contains(item.id)
        }
    }

    func ownedCount(for item: ShopItem) -> Int {
        switch item.category {
        case .food:
            let foodId = Self.foodIdFromItemId(item.id)
            return petRepo.petState.ownedFoods.filter { $0 == foodId }.count
        case .hat, .accessory:
            return ownedItemIds.contains(item.id) ? 1 : 0
        case .scene:
            return petRepo.petState.ownedScenes.contains(item.id) ? 1 : 0
        case .effect:
            return petRepo.petState.ownedEffects.contains(item.id) ? 1 : 0
        case .character:
            let charId = Self.characterIdFromItemId(item.id)
            return petRepo.petState.ownedCharacterIds.contains(charId) ? 1 : 0
        }
    }

    /// Extract food ID from shop item ID (e.g. "food_cookie" → "cookie")
    private static func foodIdFromItemId(_ itemId: String) -> String {
        if let range = itemId.range(of: "_") {
            return String(itemId[range.upperBound...])
        }
        return itemId
    }

    /// Extract character ID from shop item ID (e.g. "char_egg_pink" → "egg_pink")
    private static func characterIdFromItemId(_ itemId: String) -> String {
        if itemId.hasPrefix("char_") {
            return String(itemId.dropFirst("char_".count))
        }
        return itemId
    }

    func purchase(_ item: ShopItem) -> Bool {
        guard canAfford(item) else { return false }
        // Food is repeatable purchase; Character can't be re-purchased
        if item.category != .food && isOwned(item) { return false }

        progressRepo.updateProfile { p in
            p.coins -= item.price
        }
        coins = progressRepo.profile.coins

        switch item.category {
        case .character:
            let charId = Self.characterIdFromItemId(item.id)
            petRepo.updatePetState { state in
                if !state.ownedCharacterIds.contains(charId) {
                    state.ownedCharacterIds.append(charId)
                }
            }
        case .food:
            let foodId = Self.foodIdFromItemId(item.id)
            petRepo.updatePetState { state in
                state.ownedFoods.append(foodId)
            }
        case .hat, .accessory:
            petRepo.updatePetState { state in
                if !state.accessories.contains(item.id) {
                    state.accessories.append(item.id)
                }
            }
            ownedItemIds.insert(item.id)
        case .scene:
            petRepo.updatePetState { state in
                if !state.ownedScenes.contains(item.id) {
                    state.ownedScenes.append(item.id)
                }
            }
        case .effect:
            petRepo.updatePetState { state in
                if !state.ownedEffects.contains(item.id) {
                    state.ownedEffects.append(item.id)
                }
            }
        }
        // Phase 4: achievement
        let totalCount = petRepo.petState.accessories.count + petRepo.petState.ownedFoods.count + petRepo.petState.ownedScenes.count + petRepo.petState.ownedEffects.count
        achievementRepo?.record(.itemCollected(totalCount: totalCount))
        return true
    }

    func equip(_ item: ShopItem) {
        switch item.category {
        case .character:
            let charId = Self.characterIdFromItemId(item.id)
            petRepo.updatePetState { state in
                state.currentCharacterId = charId
            }
        case .hat, .accessory:
            petRepo.updatePetState { state in
                state.currentAccessory = item.id
            }
            currentAccessoryId = item.id
        case .scene:
            petRepo.updatePetState { state in
                state.currentScene = item.id
            }
        case .effect:
            petRepo.updatePetState { state in
                state.currentEffect = item.id
            }
        case .food:
            break // Food can't be equipped
        }
    }

    func unequip() {
        petRepo.updatePetState { state in
            state.currentAccessory = nil
        }
        currentAccessoryId = nil
    }

    func isEquipped(_ item: ShopItem) -> Bool {
        currentAccessoryId == item.id
    }

    /// v1.16: Expose current pet state for shop preview
    var currentPetState: PetState {
        return petRepo.petState
    }
}
