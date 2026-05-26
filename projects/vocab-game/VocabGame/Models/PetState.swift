import Foundation

struct PetState: Codable {
    var level: Int = 1
    var exp: Int = 0
    var mood: PetMood = .normal
    var accessories: [String] = []
    var currentAccessory: String? = nil

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

    @discardableResult
    mutating func addExp(_ amount: Int) -> Bool {
        let oldLevel = level
        exp += amount
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
}

enum PetMood: String, Codable {
    case happy
    case normal
    case sad
    case excited
}
