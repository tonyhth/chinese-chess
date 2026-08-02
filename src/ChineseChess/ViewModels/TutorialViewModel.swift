import Foundation

// MARK: - v3.0 Phase 5: 新手引导教程

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
    let hintKey: String?          // 提示文字 l10n key
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
        self.hintKey = nil
        self.successMessageKey = nil
    }

    /// 便捷构造：interactive 类型
    init(id: Int, titleKey: String, subtitleKey: String, descriptionKey: String, icon: String,
         initialFEN: String, expectedMoves: [String], hintKey: String, successMessageKey: String) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.descriptionKey = descriptionKey
        self.icon = icon
        self.type = .interactive
        self.initialFEN = initialFEN
        self.expectedMoves = expectedMoves
        self.hintKey = hintKey
        self.successMessageKey = successMessageKey
    }
}

/// 教程进度管理
@Observable
class TutorialViewModel {

    /// 所有课程（9 课：3 入门 + 4 练习 + 2 进阶）
    let lessons: [TutorialLesson] = [
        // MARK: - 入门阶段（info 类型）

        // 课 0: 棋盘认识
        TutorialLesson(
            id: 0,
            titleKey: "tutorial.lesson0.title",
            subtitleKey: "tutorial.lesson0.subtitle",
            descriptionKey: "tutorial.lesson0.description",
            icon: "rectangle.grid"
        ),

        // 课 1: 棋子走法
        TutorialLesson(
            id: 1,
            titleKey: "tutorial.lesson1.title",
            subtitleKey: "tutorial.lesson1.subtitle",
            descriptionKey: "tutorial.lesson1.description",
            icon: "figure.walk"
        ),

        // 课 2: 基本规则
        TutorialLesson(
            id: 2,
            titleKey: "tutorial.lesson2.title",
            subtitleKey: "tutorial.lesson2.subtitle",
            descriptionKey: "tutorial.lesson2.description",
            icon: "book"
        ),

        // MARK: - 练习阶段（interactive 类型）

        // 课 3: 走子练习
        // 红车在 (9,4)，横向移到 (9,3)。UCI: e0d0
        TutorialLesson(
            id: 3,
            titleKey: "tutorial.lesson3.title",
            subtitleKey: "tutorial.lesson3.subtitle",
            descriptionKey: "tutorial.lesson3.description",
            icon: "arrow.up.arrow.down",
            initialFEN: "3aka3/9/9/9/9/9/9/9/4K4/4R4 w - - 0 1",
            expectedMoves: ["e0d0"],
            hintKey: "tutorial.practice1.hint",
            successMessageKey: "tutorial.practice1.success"
        ),

        // 课 4: 吃子练习
        // 红车在 (9,3)，黑炮在 (3,3) 同列。车直线吃炮。UCI: d0d6
        TutorialLesson(
            id: 4,
            titleKey: "tutorial.lesson4.title",
            subtitleKey: "tutorial.lesson4.subtitle",
            descriptionKey: "tutorial.lesson4.description",
            icon: "scissors",
            initialFEN: "3aka3/9/9/3c5/9/9/9/9/4K4/3R5 w - - 0 1",
            expectedMoves: ["d0d6"],
            hintKey: "tutorial.practice2.hint",
            successMessageKey: "tutorial.practice2.success"
        ),

        // 课 5: 将军练习
        // 红炮在 (9,2)，红兵在 (4,4) 为炮架。炮横移到 (9,4) 形成炮架将军。UCI: c0e0
        TutorialLesson(
            id: 5,
            titleKey: "tutorial.lesson5.title",
            subtitleKey: "tutorial.lesson5.subtitle",
            descriptionKey: "tutorial.lesson5.description",
            icon: "exclamationmark.triangle",
            initialFEN: "3aka3/9/9/9/4P4/9/9/9/4K4/2C6 w - - 0 1",
            expectedMoves: ["c0e0"],
            hintKey: "tutorial.practice3.hint",
            successMessageKey: "tutorial.practice3.success"
        ),

        // 课 6: 应将练习
        // 红炮在 (6,4)，红兵在 (3,4) 为炮架，将军黑将。黑将横向逃离。UCI: e9d9
        TutorialLesson(
            id: 6,
            titleKey: "tutorial.lesson6.title",
            subtitleKey: "tutorial.lesson6.subtitle",
            descriptionKey: "tutorial.lesson6.description",
            icon: "shield",
            initialFEN: "4k4/9/9/4P4/9/9/4C4/9/9/4K4 b - - 0 1",
            expectedMoves: ["e9d9"],
            hintKey: "tutorial.practice4.hint",
            successMessageKey: "tutorial.practice4.success"
        ),

        // MARK: - 进阶阶段（interactive 类型）

        // 课 7: 闷宫杀（一步将死）
        // 炮在 (3,2) 横移到 (3,4)，以黑卒 (1,4) 为炮架将军。
        // 黑将无法逃跑（双士堵塞），卒无法移除（未过河不能横移，前进仍为炮架）。UCI: c6e6
        TutorialLesson(
            id: 7,
            titleKey: "tutorial.lesson7.title",
            subtitleKey: "tutorial.lesson7.subtitle",
            descriptionKey: "tutorial.lesson7.description",
            icon: "trophy",
            initialFEN: "3aka3/4p4/9/2C6/9/9/9/9/4K4/9 w - - 0 1",
            expectedMoves: ["c6e6"],
            hintKey: "tutorial.advanced1.hint",
            successMessageKey: "tutorial.advanced1.success"
        ),

        // 课 8: 避免送子
        // 黑炮 (3,4) 是诱饵，黑车 (1,4) 在后方伏击。红车吃炮会被反吃。
        // 正确走法：车横移到安全位置 (5,3)。UCI: e4d4
        TutorialLesson(
            id: 8,
            titleKey: "tutorial.lesson8.title",
            subtitleKey: "tutorial.lesson8.subtitle",
            descriptionKey: "tutorial.lesson8.description",
            icon: "eye.slash",
            initialFEN: "4k4/4r4/9/4c4/9/4R4/9/9/4K4/9 w - - 0 1",
            expectedMoves: ["e4d4"],
            hintKey: "tutorial.advanced2.hint",
            successMessageKey: "tutorial.advanced2.success"
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
