import Foundation
import SwiftUI

/// Theme skin for PetHouseView and HomeView backgrounds
enum ThemeSkin: String, Codable, CaseIterable {
    case garden = "garden"       // Default
    case beach = "beach"         // 海滩夏日
    case starry = "starry"       // 星空幻想
    case candy = "candy"         // 糖果王国
    case party = "party"         // 蛋仔派对

    var displayName: String {
        switch self {
        case .garden: return "粉色花园"
        case .beach: return "海滩夏日"
        case .starry: return "星空幻想"
        case .candy: return "糖果王国"
        case .party: return "蛋仔派对"
        }
    }

    var unlockCondition: String {
        switch self {
        case .garden: return "初始解锁"
        case .beach: return "购买解锁（120金币）"
        case .starry: return "通过第 15 关"
        case .candy: return "通过第 25 关"
        case .party: return "成就「收藏家」解锁"
        }
    }

    func isUnlocked(profile: PlayerProfile, petState: PetState) -> Bool {
        switch self {
        case .garden: return true
        case .beach: return petState.ownedScenes.contains("scene_beach")
        case .starry: return profile.totalStars >= 15 // ~15 levels with 1+ stars
        case .candy: return profile.totalStars >= 25
        case .party: return (petState.accessories.count + petState.ownedFoods.count + petState.ownedScenes.count + petState.ownedEffects.count) >= 10
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .garden: return [Color(hex: "FFE0EC"), Color(hex: "FFB6C1")]
        case .beach: return [Color(hex: "87CEEB"), Color(hex: "4682B4")]
        case .starry: return [Color(hex: "0D1B2A"), Color(hex: "1B2838")]
        case .candy: return [Color(hex: "FFB3D9"), Color(hex: "B3E5FC"), Color(hex: "FFF9C4")]
        case .party: return [Color(hex: "FF6B9D"), Color(hex: "FFE66D")]
        }
    }

    var emoji: String {
        switch self {
        case .garden: return "🌸"
        case .beach: return "🏖️"
        case .starry: return "🌙"
        case .candy: return "🍬"
        case .party: return "🎉"
        }
    }
}
