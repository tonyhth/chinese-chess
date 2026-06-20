import Foundation

// MARK: - v3.0 Phase 5: 新手引导教程

/// 教程步骤数据模型
struct TutorialLesson: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let description: String
    let icon: String  // SF Symbol name
}

/// 教程进度管理
@Observable
class TutorialViewModel {

    /// 所有课程
    let lessons: [TutorialLesson] = [
        TutorialLesson(
            id: 0,
            title: "棋子走法",
            subtitle: "学习每种棋子的移动规则",
            description: """
            🔴 车走直线，可进可退
            🔴 马走日字，蹩脚不能跳
            🔴 象走田字，塞眼不能过
            🔴 炮翻山吃子，不吃子走直线
            🔴 兵卒过河可横移，不退
            🔴 士走斜线，不出九宫
            🔴 将帅不出宫，横竖一步

            点击棋子查看可走位置！
            """,
            icon: "figure.walk"
        ),
        TutorialLesson(
            id: 1,
            title: "将军与应将",
            subtitle: "学会被将军时如何应对",
            description: """
            ⚡ 将军：对方走子后，你的将/帅被攻击

            应将方式：
            1️⃣ 逃跑：将/帅移到安全位置
            2️⃣ 挡住：用子力挡住攻击路线
            3️⃣ 吃子：吃掉将军的棋子

            ⚠️ 不能不应将！必须解除将军状态。

            AI 将对你将军，尝试应将！
            """,
            icon: "exclamationmark.triangle"
        ),
        TutorialLesson(
            id: 2,
            title: "将死判定",
            subtitle: "3 个一步杀练习",
            description: """
            🏆 将死：将军且对方无法应将 = 获胜

            将死条件：
            • 被将军
            • 且无法逃跑、挡住、吃子

            尝试 3 个一步杀题目，
            找到致胜走法！
            """,
            icon: "trophy"
        ),
        TutorialLesson(
            id: 3,
            title: "特殊规则",
            subtitle: "困毙、长将、长捉",
            description: """
            ⚠️ 困毙 = 输！（不是和棋）
            轮到走棋但无棋可走 = 判负

            🤝 长将和棋：连续将军，对方循环
            🤝 长捉和棋：连续捉子，循环不变

            💡 记住：困毙是输，不是和！
            """,
            icon: "book"
        ),
        TutorialLesson(
            id: 4,
            title: "第一局实战",
            subtitle: "与 AI 对弈（新手难度）",
            description: """
            🎮 实战时间！

            • 新手难度 AI
            • 关键局面会高亮推荐走法
            • 执红先行

            放手去下，享受对弈！
            """,
            icon: "gamecontroller"
        )
    ]

    /// 当前课程索引
    var currentLesson: Int = 0

    /// 是否已完成全部教程
    static var hasCompletedTutorial: Bool {
        UserDefaults.standard.bool(forKey: "chinesechess.tutorialCompleted")
    }

    static func markTutorialCompleted() {
        UserDefaults.standard.set(true, forKey: "chinesechess.tutorialCompleted")
        // v3.0 Phase 6: 联动成就 + 段位
        let store = PlayerProfileStore.shared
        store.update { profile in
            profile.completedTutorials = true
            // 教程完成升至学童段位（如果还是初始状态）
            if profile.rank == .student && profile.totalWins == 0 {
                // 学童是起始段位，不需升级，但解锁成就
            }
        }
        AchievementManager.shared.unlock("tutorial_done")
        AchievementManager.shared.unlock("first_game")
    }

    static func resetTutorial() {
        UserDefaults.standard.set(false, forKey: "chinesechess.tutorialCompleted")
    }

    /// 是否首次启动
    static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "chinesechess.hasLaunched")
    }

    static func markLaunched() {
        UserDefaults.standard.set(true, forKey: "chinesechess.hasLaunched")
    }

    /// 下一课
    func nextLesson() {
        if currentLesson < lessons.count - 1 {
            currentLesson += 1
        }
    }

    /// 上一课
    func previousLesson() {
        if currentLesson > 0 {
            currentLesson -= 1
        }
    }

    /// 是否最后一课
    var isLastLesson: Bool {
        currentLesson == lessons.count - 1
    }
}
