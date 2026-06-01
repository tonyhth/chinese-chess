import Foundation

struct Food: Identifiable, Codable {
    let id: String        // "cookie", "cake", "icecream", "starcandy"
    let name: String
    let price: Int
    let satiety: Int      // 饱腹度恢复量
    let effect: FoodEffect

    static let allFoods: [Food] = [
        Food(id: "cookie", name: "小饼干", price: 5, satiety: 15, effect: .none),
        Food(id: "cake", name: "蛋糕", price: 15, satiety: 30, effect: .happyMood),
        Food(id: "icecream", name: "彩虹冰淇淋", price: 30, satiety: 50, effect: .expBoost20),
        Food(id: "starcandy", name: "星星糖果", price: 50, satiety: 80, effect: .doubleExp),
    ]

    static func food(by id: String) -> Food? {
        allFoods.first { $0.id == id }
    }
}

enum FoodEffect: String, Codable {
    case none             // 无额外效果
    case happyMood        // 心情变 happy
    case expBoost20       // 经验 +20
    case doubleExp        // 下局双倍经验
}
