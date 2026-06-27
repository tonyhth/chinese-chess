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
            title: L10n.shared.t("tutorial.0.title"),
            subtitle: L10n.shared.t("tutorial.0.subtitle"),
            description: L10n.shared.t("tutorial.0.description"),
            icon: "figure.walk"
        ),
        TutorialLesson(
            id: 1,
            title: L10n.shared.t("tutorial.1.title"),
            subtitle: L10n.shared.t("tutorial.1.subtitle"),
            description: L10n.shared.t("tutorial.1.description"),
            icon: "exclamationmark.triangle"
        ),
        TutorialLesson(
            id: 2,
            title: L10n.shared.t("tutorial.2.title"),
            subtitle: L10n.shared.t("tutorial.2.subtitle"),
            description: L10n.shared.t("tutorial.2.description"),
            icon: "trophy"
        ),
        TutorialLesson(
            id: 3,
            title: L10n.shared.t("tutorial.3.title"),
            subtitle: L10n.shared.t("tutorial.3.subtitle"),
            description: L10n.shared.t("tutorial.3.description"),
            icon: "book"
        ),
        TutorialLesson(
            id: 4,
            title: L10n.shared.t("tutorial.4.title"),
            subtitle: L10n.shared.t("tutorial.4.subtitle"),
            description: L10n.shared.t("tutorial.4.description"),
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
