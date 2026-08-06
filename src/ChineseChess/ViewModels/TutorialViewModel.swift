import Foundation

// MARK: - v3.0 Phase 5: 新手引导教程 (v3.0-final: 12课重设计)

/// 教程课程类型
enum TutorialLessonType: String {
    case info          // 纯文字说明（入门阶段）
    case interactive   // 交互走子练习（练习/进阶阶段）
}

/// 教程课程数据模型
struct TutorialLesson: Identifiable {
    let id: Int
    let titleKey: String          // l10n key
    let subtitleKey: String       // l10n key
    let descriptionKey: String    // l10n key
    let icon: String              // SF Symbol name
    let type: TutorialLessonType

    // interactive 类型专用
    let initialFEN: String?       // 初始局面
    let expectedMoves: [String]?  // 期望走法序列（UCI 格式）
    let hintKeys: [String]?       // 每步提示文字 l10n key（数组长度 = expectedMoves.count）
    let successMessageKey: String? // 成功提示 l10n key

    /// 便捷构造：info 类型
    init(id: Int, titleKey: String, subtitleKey: String, descriptionKey: String, icon: String) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.descriptionKey = descriptionKey
        self.icon = icon
        self.type = .info
        self.initialFEN = nil
        self.expectedMoves = nil
        self.hintKeys = nil
        self.successMessageKey = nil
    }

    /// 便捷构造：interactive 类型
    init(id: Int, titleKey: String, subtitleKey: String, descriptionKey: String, icon: String,
         initialFEN: String, expectedMoves: [String], hintKeys: [String], successMessageKey: String) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.descriptionKey = descriptionKey
        self.icon = icon
        self.type = .interactive
        self.initialFEN = initialFEN
        self.expectedMoves = expectedMoves
        self.hintKeys = hintKeys
        self.successMessageKey = successMessageKey

        // R1 安全约束：hintKeys.count 必须等于 expectedMoves.count
        // C2 fix: 用 precondition 替代 assert，Debug + Release 都生效
        precondition(hintKeys.count == expectedMoves.count,
               "TutorialLesson(\(id)): hintKeys.count (\(hintKeys.count)) must match expectedMoves.count (\(expectedMoves.count))")
    }
}

/// 教程进度管理
@Observable
class TutorialViewModel {

    /// 所有课程（12 课：2 入门 + 7 走法 + 3 战术）
    let lessons: [TutorialLesson] = [
        // MARK: - Phase 1: 入门阶段（info 类型）

        // 课 0: 认识棋盘
        TutorialLesson(
            id: 0,
            titleKey: "tutorial.lesson0.title",
            subtitleKey: "tutorial.lesson0.subtitle",
            descriptionKey: "tutorial.lesson0.description",
            icon: "rectangle.grid"
        ),

        // 课 1: 认识棋子
        TutorialLesson(
            id: 1,
            titleKey: "tutorial.lesson1.title",
            subtitleKey: "tutorial.lesson1.subtitle",
            descriptionKey: "tutorial.lesson1.description",
            icon: "rectangle.grid.2x2"
        ),

        // MARK: - Phase 2: 走法教学（interactive 类型，每种棋子1课）

        // 课 2: 车的走法 — 直线前进 + 横移吃子（2步）
        TutorialLesson(
            id: 2,
            titleKey: "tutorial.lesson2.title",
            subtitleKey: "tutorial.lesson2.subtitle",
            descriptionKey: "tutorial.lesson2.description",
            icon: "arrow.up.arrow.down",
            initialFEN: "3aka3/9/9/9/9/4p4/9/9/3K5/R8 w - - 0 1",
            expectedMoves: ["a0a4", "a4e4"],
            hintKeys: ["tutorial.lesson2.hint1", "tutorial.lesson2.hint2"],
            successMessageKey: "tutorial.lesson2.success"
        ),

        // 课 3: 马的走法 — 日字跳跃 + 吃子（2步）
        TutorialLesson(
            id: 3,
            titleKey: "tutorial.lesson3.title",
            subtitleKey: "tutorial.lesson3.subtitle",
            descriptionKey: "tutorial.lesson3.description",
            icon: "figure.walk",
            initialFEN: "3aka3/9/9/3p5/9/9/4N4/9/3K5/9 w - - 0 1",
            expectedMoves: ["e3f5", "f5d6"],
            hintKeys: ["tutorial.lesson3.hint1", "tutorial.lesson3.hint2"],
            successMessageKey: "tutorial.lesson3.success"
        ),

        // 课 4: 炮的走法 — 直线移动 + 翻山吃子（2步）
        TutorialLesson(
            id: 4,
            titleKey: "tutorial.lesson4.title",
            subtitleKey: "tutorial.lesson4.subtitle",
            descriptionKey: "tutorial.lesson4.description",
            icon: "scope",
            initialFEN: "3aka3/9/4c4/9/9/4P4/9/9/3K5/C8 w - - 0 1",
            expectedMoves: ["a0e0", "e0e7"],
            hintKeys: ["tutorial.lesson4.hint1", "tutorial.lesson4.hint2"],
            successMessageKey: "tutorial.lesson4.success"
        ),

        // 课 5: 象的走法 — 田字走法 + 吃子（2步）
        TutorialLesson(
            id: 5,
            titleKey: "tutorial.lesson5.title",
            subtitleKey: "tutorial.lesson5.subtitle",
            descriptionKey: "tutorial.lesson5.description",
            icon: "arc",
            initialFEN: "3aka3/9/9/9/9/6p2/9/9/3K5/6B3 w - - 0 1",
            expectedMoves: ["g0e2", "e2g4"],
            hintKeys: ["tutorial.lesson5.hint1", "tutorial.lesson5.hint2"],
            successMessageKey: "tutorial.lesson5.success"
        ),

        // 课 6: 士的走法 — 斜线吃子 + 回防（2步）
        TutorialLesson(
            id: 6,
            titleKey: "tutorial.lesson6.title",
            subtitleKey: "tutorial.lesson6.subtitle",
            descriptionKey: "tutorial.lesson6.description",
            icon: "shield",
            initialFEN: "3k5/9/9/9/9/9/9/4p4/3AK4/9 w - - 0 1",
            expectedMoves: ["d1e2", "e2f1"],
            hintKeys: ["tutorial.lesson6.hint1", "tutorial.lesson6.hint2"],
            successMessageKey: "tutorial.lesson6.success"
        ),

        // 课 7: 兵的走法 — 前进过河 + 横移吃子（2步）
        TutorialLesson(
            id: 7,
            titleKey: "tutorial.lesson7.title",
            subtitleKey: "tutorial.lesson7.subtitle",
            descriptionKey: "tutorial.lesson7.description",
            icon: "arrow.up",
            initialFEN: "4ka3/9/9/9/3p5/4P4/9/9/3K5/9 w - - 0 1",
            expectedMoves: ["e4e5", "e5d5"],
            hintKeys: ["tutorial.lesson7.hint1", "tutorial.lesson7.hint2"],
            successMessageKey: "tutorial.lesson7.success"
        ),

        // 课 8: 将帅走法 — 九宫内移动（2步）
        TutorialLesson(
            id: 8,
            titleKey: "tutorial.lesson8.title",
            subtitleKey: "tutorial.lesson8.subtitle",
            descriptionKey: "tutorial.lesson8.description",
            icon: "crown",
            initialFEN: "3aka3/9/9/9/9/4R4/9/9/3K5/9 w - - 0 1",
            expectedMoves: ["d1e1", "e1e2"],
            hintKeys: ["tutorial.lesson8.hint1", "tutorial.lesson8.hint2"],
            successMessageKey: "tutorial.lesson8.success"
        ),

        // MARK: - Phase 3: 基础战术（interactive 类型）

        // 课 9: 将军练习 — 炮翻山将军（1步）
        TutorialLesson(
            id: 9,
            titleKey: "tutorial.lesson9.title",
            subtitleKey: "tutorial.lesson9.subtitle",
            descriptionKey: "tutorial.lesson9.description",
            icon: "exclamationmark.triangle",
            initialFEN: "3aka3/9/9/9/4P4/9/9/9/3K5/2C6 w - - 0 1",
            expectedMoves: ["c0e0"],
            hintKeys: ["tutorial.lesson9.hint1"],
            successMessageKey: "tutorial.lesson9.success"
        ),

        // 课 10: 应将练习 — 黑将逃离（1步）
        TutorialLesson(
            id: 10,
            titleKey: "tutorial.lesson10.title",
            subtitleKey: "tutorial.lesson10.subtitle",
            descriptionKey: "tutorial.lesson10.description",
            icon: "shield.lefthalf.filled",
            initialFEN: "4ka3/9/9/4P4/9/9/4C4/9/5K3/9 b - - 0 1",
            expectedMoves: ["e9d9"],
            hintKeys: ["tutorial.lesson10.hint1"],
            successMessageKey: "tutorial.lesson10.success"
        ),

        // 课 11: 闷宫杀 — 一步将死（1步）
        TutorialLesson(
            id: 11,
            titleKey: "tutorial.lesson11.title",
            subtitleKey: "tutorial.lesson11.subtitle",
            descriptionKey: "tutorial.lesson11.description",
            icon: "trophy",
            initialFEN: "3aka3/4p4/9/2C6/9/9/9/9/3K5/9 w - - 0 1",
            expectedMoves: ["c6e6"],
            hintKeys: ["tutorial.lesson11.hint1"],
            successMessageKey: "tutorial.lesson11.success"
        ),
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
