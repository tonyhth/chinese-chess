import SwiftUI

// MARK: - 学棋中心入口

/// 学棋中心：统一入口卡片页，NavigationLink 推入主 NavigationStack
struct StudyHubView: View {
    /// 开局教练练习数据
    private let practiceStore = OpeningPracticeStore.shared
    private let l10n = L10n.shared

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

    // MARK: - macOS: 3 列自适应网格

    private var macOSLayout: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], spacing: 16) {
            studyCard(
                title: l10n.t("study.puzzle"),
                icon: "puzzlepiece",
                color: .orange,
                destination: ChapterSelectView()
            )
            studyCard(
                title: l10n.t("study.masterGame"),
                icon: "crown",
                color: .purple,
                destination: MasterGameBrowserView()
            )
            studyCard(
                title: l10n.t("study.openingExplorer"),
                icon: "book",
                color: .blue,
                destination: OpeningExplorerView()
            )
            studyCard(
                title: l10n.t("study.dailyChallenge"),
                icon: "target",
                color: .red,
                destination: DailyChallengeView()
            )
            // Phase B3 Step 3: 开局教练卡片
            openingCoachCard
        }
        .padding(16)
    }

    // MARK: - iOS: 纵向列表

    private var iOSLayout: some View {
        VStack(spacing: 16) {
            studyCard(
                title: l10n.t("study.puzzle"),
                icon: "puzzlepiece",
                color: .orange,
                destination: ChapterSelectView()
            )
            studyCard(
                title: l10n.t("study.masterGame"),
                icon: "crown",
                color: .purple,
                destination: MasterGameBrowserView()
            )
            studyCard(
                title: l10n.t("study.openingExplorer"),
                icon: "book",
                color: .blue,
                destination: OpeningExplorerView()
            )
            studyCard(
                title: l10n.t("study.dailyChallenge"),
                icon: "target",
                color: .red,
                destination: DailyChallengeView()
            )
            // Phase B3 Step 3: 开局教练卡片
            openingCoachCard
        }
        .padding(16)
    }

    // MARK: - 开局教练卡片

    private var openingCoachCard: some View {
        NavigationLink(destination: OpeningCoachSelectView()) {
            VStack(spacing: 12) {
                Image(systemName: "compass.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.teal)
                    .frame(height: 40)

                Text(l10n.t("study.openingCoach"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // 副标题
                if practiceStore.practicedCount > 0 {
                    Text(l10n.t("study.openingCoach.stats",
                                Int(practiceStore.averageAccuracy * 100),
                                practiceStore.practicedCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(l10n.t("study.openingCoach.noRecord"))
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

    @ViewBuilder
    private func studyCard<D: View>(title: String, icon: String, color: Color, destination: D) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .frame(height: 40)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
