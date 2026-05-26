import Foundation

struct ShopItem: Identifiable, Codable {
    let id: String
    let name: String
    let type: ShopItemType
    let price: Int
    let description: String
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

    static let catalog: [ShopItem] = [
        ShopItem(id: "hat_party", name: "派对帽", type: .accessory, price: 50, description: "彩色派对帽，喜庆又可爱"),
        ShopItem(id: "hat_crown", name: "皇冠", type: .accessory, price: 100, description: "金灿灿的小皇冠"),
        ShopItem(id: "hat_beanie", name: "毛线帽", type: .accessory, price: 30, description: "暖暖的毛线帽"),
        ShopItem(id: "glasses_round", name: "圆眼镜", type: .accessory, price: 40, description: "文艺范儿的圆眼镜"),
        ShopItem(id: "glasses_sunglasses", name: "墨镜", type: .accessory, price: 60, description: "酷酷的蛋仔墨镜"),
        ShopItem(id: "scarf_red", name: "红围巾", type: .accessory, price: 45, description: "温暖的红围巾"),
        ShopItem(id: "bow_pink", name: "粉色蝴蝶结", type: .accessory, price: 35, description: "可爱的粉色蝴蝶结"),
        ShopItem(id: "cape_super", name: "超人披风", type: .accessory, price: 80, description: "超级蛋仔的标志披风"),
    ]

    init(progressRepo: ProgressRepository, petRepo: PetRepository) {
        self.progressRepo = progressRepo
        self.petRepo = petRepo
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
        ownedItemIds.contains(item.id)
    }

    func purchase(_ item: ShopItem) -> Bool {
        guard canAfford(item) && !isOwned(item) else { return false }

        progressRepo.updateProfile { p in
            p.coins -= item.price
        }
        coins = progressRepo.profile.coins

        switch item.type {
        case .accessory:
            petRepo.updatePetState { state in
                if !state.accessories.contains(item.id) {
                    state.accessories.append(item.id)
                }
            }
            ownedItemIds.insert(item.id)
        case .hint, .extraTime:
            // Consumable items — store in profile for now
            progressRepo.updateProfile { p in
                // Future: p.hints += 1 etc.
            }
        }
        return true
    }

    func equip(_ item: ShopItem) {
        petRepo.updatePetState { state in
            state.currentAccessory = item.id
        }
        currentAccessoryId = item.id
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
}
