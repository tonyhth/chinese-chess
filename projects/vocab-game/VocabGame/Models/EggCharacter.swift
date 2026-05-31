import Foundation

/// v1.17: Egg character definition
struct EggCharacter: Identifiable, Codable, Hashable {
    let id: String            // e.g. "egg_yellow"
    let name: String          // e.g. "蛋小黄"
    let price: Int            // 0 = free/unlock-only
    let unlockType: CharacterUnlockType
    let bonus: CharacterBonus // Placeholder — not implemented in v1.17.0
}

enum CharacterUnlockType: String, Codable {
    case free           // 默认解锁
    case coins          // 金币购买
    case streak7        // 连续打卡 7 天
    case master50       // 掌握 50 个单词
}

/// Bonus placeholder for v1.17.1
struct CharacterBonus: Codable, Hashable {
    let expMultiplier: Double
    let description: String

    static let none = CharacterBonus(expMultiplier: 1.0, description: "")
}

// MARK: - Character Catalog

extension EggCharacter {
    static let catalog: [EggCharacter] = [
        EggCharacter(
            id: "egg_yellow",
            name: "蛋小黄",
            price: 0,
            unlockType: .free,
            bonus: .none
        ),
        EggCharacter(
            id: "egg_pink",
            name: "蛋小粉",
            price: 80,
            unlockType: .coins,
            bonus: .none
        ),
        EggCharacter(
            id: "egg_blue",
            name: "蛋小蓝",
            price: 80,
            unlockType: .coins,
            bonus: .none
        ),
        EggCharacter(
            id: "egg_green",
            name: "蛋小绿",
            price: 80,
            unlockType: .coins,
            bonus: .none
        ),
        EggCharacter(
            id: "egg_black",
            name: "蛋小黑",
            price: 0,
            unlockType: .streak7,
            bonus: .none
        ),
        EggCharacter(
            id: "egg_red",
            name: "蛋小红",
            price: 0,
            unlockType: .master50,
            bonus: .none
        ),
    ]

    static func byId(_ id: String) -> EggCharacter? {
        catalog.first { $0.id == id }
    }

    /// Asset image name for given mood
    func imageName(mood: PetMood) -> String {
        "\(id)_\(mood.assetSuffix)"
    }

    /// Mini image name
    var miniImageName: String {
        "\(id)_mini"
    }
}

extension PetMood {
    var assetSuffix: String {
        switch self {
        case .happy: return "happy"
        case .normal: return "idle"
        case .sad: return "sad"
        case .excited: return "excited"
        }
    }
}
