import Foundation

enum PetDialogueScene: String, CaseIterable {
    case greeting
    case preGame
    case postGameGood
    case postGameBad
    case idle
    case hungry
    case levelUp
    case streak
}

enum PetDialogue {
    static let dialogues: [PetDialogueScene: [String]] = [
        .greeting: [
            "今天也要加油哦~",
            "蛋仔等你好久啦！",
            "准备好了吗？",
            "新的一天，新的冒险！",
            "一起来学单词吧~",
        ],
        .preGame: [
            "加油！蛋仔相信你！",
            "这局一定能拿满分！",
            "冲冲冲！",
            "集中注意力~",
        ],
        .postGameGood: [
            "太厉害了！蛋仔好崇拜你！",
            "满分！蛋仔要向你学习！",
            "你是最棒的！",
            "哇，好厉害！再来一局？",
        ],
        .postGameBad: [
            "没关系，下次一定行！",
            "蛋仔陪你一起努力~",
            "别灰心，你已经很棒了！",
            "休息一下再来吧~",
        ],
        .idle: [
            "怎么不动了？蛋仔在等你~",
            "发什么呆呢？",
            "要不要来一局？",
        ],
        .hungry: [
            "咕噜咕噜...蛋仔饿了",
            "想吃饼干...",
            "好饿啊...有吃的吗？",
            "肚子在叫了...",
        ],
        .levelUp: [
            "哇！蛋仔进化了！",
            "太棒了！蛋仔变强了！",
            "新的力量觉醒了！",
        ],
        .streak: [
            "连续打卡！蛋仔好骄傲！",
            "坚持就是胜利！",
            "你的毅力让蛋仔佩服！",
        ],
    ]

    static func randomDialogue(for scene: PetDialogueScene) -> String {
        let options = dialogues[scene] ?? ["..."]
        return options.randomElement() ?? "..."
    }
}
