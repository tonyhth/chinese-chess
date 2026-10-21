import SwiftUI

// MARK: - 学棋中心（v6.4 C3-5 重设计）

/// 学棋中心：P5 重点区B——教程并入引导流 + 主卡"继续上次学习" + 卡片栅格
/// （进度环克制不加——洪涛拍板；进度用细条 bar 呈现）
struct StudyHubView: View {
    /// 开局教练练习数据
    private let practiceStore = OpeningPracticeStore.shared
    private let l10n = L10n.shared

    /// v6.4 C3-5：教程进度（@AppStorage 持久化——P6 并入引导流的数据基础）
    @AppStorage("chinesechess.tutorialLessonProgress") private var tutorialLessonProgress: Int = 0
    @AppStorage("chinesechess.tutorialCompleted") private var tutorialCompleted: Bool = false

    var body: some View {
        ScrollView {
            #if os(iOS)
            iOSLayout
            #else
            macOSLayout
            #endif
        }
        .background(Color.controlBackground)
        .navigationTitle(l10n.t("study.title"))
    }

    // MARK: - 教程进度推导（P6 引导流数据）

    /// 教程总课数（12 课：2 入门 + 7 走法 + 3 战术）
    private let tutorialLessonCount = 12

    /// 已学百分比（0-100）
    private var tutorialPercent: Int {
        tutorialCompleted ? 100 : min(100, tutorialLessonProgress * 100 / tutorialLessonCount)
    }

    /// hero 主卡副标题（继续点）
    private var tutorialHeroSubtitle: String {
        if tutorialCompleted {
            return l10n.t("study.tutorial.done")
        }
        let lesson = tutorialLessonProgress + 1
        return l10n.t("study.tutorial.continueAt", String(lesson))
    }

    // MARK: - macOS: 主卡 + 卡片栅格

    private var macOSLayout: some View {
        VStack(alignment: .leading, spacing: LayoutSpec.space3) {
            tutorialHeroCard
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], spacing: 16) {
                studyCard(
                    title: l10n.t("study.puzzle"),
                    icon: "puzzlepiece",
                    color: .orange,
                    destination: ChapterSelectView(),
                    subtitle: l10n.t("study.puzzle.subtitle")
                )
                studyCard(
                    title: l10n.t("study.masterGame"),
                    icon: "crown",
                    color: .purple,
                    destination: MasterGameBrowserView(),
                    subtitle: l10n.t("study.masterGame.subtitle")
                )
                studyCard(
                    title: l10n.t("study.openingExplorer"),
                    icon: "book",
                    color: .blue,
                    destination: OpeningExplorerView(),
                    subtitle: l10n.t("study.openingExplorer.subtitle")
                )
                studyCard(
                    title: l10n.t("study.dailyChallenge"),
                    icon: "target",
                    color: .red,
                    destination: DailyChallengeView(),
                    subtitle: l10n.t("study.dailyChallenge.subtitle")
                )
                studyCard(
                    title: l10n.t("study.openingCoach"),
                    icon: "location.north.fill",
                    color: .teal,
                    destination: OpeningCoachSelectView(),
                    subtitle: practiceStore.practicedCount > 0
                        ? l10n.t("study.openingCoach.stats", Int(practiceStore.averageAccuracy * 100), practiceStore.practicedCount)
                        : l10n.t("study.openingCoach.noRecord")
                )
            }
        }
        .padding(16)
    }

    // MARK: - iOS: 同构（2 列栅格）

    private var iOSLayout: some View {
        VStack(alignment: .leading, spacing: LayoutSpec.space3) {
            tutorialHeroCard
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                studyCard(
                    title: l10n.t("study.puzzle"),
                    icon: "puzzlepiece",
                    color: .orange,
                    destination: ChapterSelectView(),
                    subtitle: l10n.t("study.puzzle.subtitle")
                )
                studyCard(
                    title: l10n.t("study.masterGame"),
                    icon: "crown",
                    color: .purple,
                    destination: MasterGameBrowserView(),
                    subtitle: l10n.t("study.masterGame.subtitle")
                )
                studyCard(
                    title: l10n.t("study.openingExplorer"),
                    icon: "book",
                    color: .blue,
                    destination: OpeningExplorerView(),
                    subtitle: l10n.t("study.openingExplorer.subtitle")
                )
                studyCard(
                    title: l10n.t("study.dailyChallenge"),
                    icon: "target",
                    color: .red,
                    destination: DailyChallengeView(),
                    subtitle: l10n.t("study.dailyChallenge.subtitle")
                )
                studyCard(
                    title: l10n.t("study.openingCoach"),
                    icon: "location.north.fill",
                    color: .teal,
                    destination: OpeningCoachSelectView(),
                    subtitle: practiceStore.practicedCount > 0
                        ? l10n.t("study.openingCoach.stats", Int(practiceStore.averageAccuracy * 100), practiceStore.practicedCount)
                        : l10n.t("study.openingCoach.noRecord")
                )
            }
        }
        .padding(16)
    }

    // MARK: - hero 主卡：继续上次学习（P6 引导流动线）

    private var tutorialHeroCard: some View {
        NavigationLink {
            TutorialView(onComplete: nil)
        } label: {
            HStack(spacing: LayoutSpec.space3) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: LayoutSpec.fontSizeDisplayLarge))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t(tutorialCompleted ? "study.tutorial.reviewTitle" : "study.tutorial.continueTitle"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tutorialHeroSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    // 进度条（克制：细条，非进度环——洪涛拍板）
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * Double(tutorialPercent) / 100.0)
                        }
                    }
                    .frame(width: 280, height: 4)
                }
                Spacer()
                Text(l10n.t(tutorialCompleted ? "study.tutorial.restart" : "study.tutorial.resume"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func studyCard<D: View>(title: String, icon: String, color: Color, destination: D, subtitle: String? = nil) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: LayoutSpec.fontSizeDisplay))
                    .foregroundStyle(color)
                    .frame(height: 40)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
