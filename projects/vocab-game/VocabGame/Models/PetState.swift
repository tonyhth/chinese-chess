import Foundation

struct PetState: Codable {
    var level: Int = 1
    var exp: Int = 0
    var mood: PetMood = .normal
    var accessories: [String] = []
    var currentAccessory: String? = nil

    // V2: 饱腹度 & 互动
    var satiety: Int = 100
    var lastFedTime: Date = Date()
    var lastPetTime: Date = Date.distantPast
    var lastPlayTime: Date = Date.distantPast
    var interactionCount: Int = 0
    var ownedFoods: [String] = []          // 拥有的食物 ID 列表
    var ownedScenes: [String] = []         // 拥有的场景 ID
    var currentScene: String? = nil        // 当前场景
    var ownedEffects: [String] = []        // 拥有的特效 ID
    var currentEffect: String? = nil       // 当前特效

    // v1.17: 角色系统
    var currentCharacterId: String = "egg_yellow"
    var ownedCharacterIds: [String] = ["egg_yellow"]

    /// Exp thresholds for each level (1→2, 2→3, 3→4, 4→5)
    static let levelThresholds = [100, 250, 500, 1000]

    var expForNextLevel: Int? {
        guard level <= 4 else { return nil } // max level
        return PetState.levelThresholds[level - 1]
    }

    var expProgress: Double {
        guard level <= 4 else { return 1.0 }
        let threshold = PetState.levelThresholds[level - 1]
        return Double(exp) / Double(threshold)
    }

    /// 饱腹度每小时下降 5 点
    mutating func decaySatiety(now: Date = Date()) {
        let hours = now.timeIntervalSince(lastFedTime) / 3600.0
        if hours > 0 {
            satiety = max(0, satiety - Int(round(hours * 5)))
        }
    }

    /// 饱腹度 > 50 时经验加成 20%
    var expMultiplier: Double {
        return satiety > 50 ? 1.2 : 1.0
    }

    /// 是否处于双倍经验效果中
    var hasDoubleExp: Bool {
        return currentEffect == "double_exp"
    }

    @discardableResult
    mutating func addExp(_ amount: Int) -> Bool {
        let effective = Int(Double(amount) * expMultiplier * (hasDoubleExp ? 2.0 : 1.0))
        let oldLevel = level
        exp += effective
        while level <= 4 {
            let threshold = PetState.levelThresholds[level - 1]
            if exp >= threshold {
                exp -= threshold
                level += 1
            } else {
                break
            }
        }
        return level > oldLevel
    }

    // MARK: - Cooldowns

    var canPet: Bool {
        Date().timeIntervalSince(lastPetTime) >= 30
    }

    var canPlay: Bool {
        Date().timeIntervalSince(lastPlayTime) >= 4 * 3600
    }
}

enum PetMood: String, Codable {
    case happy
    case normal
    case sad
    case excited
}
