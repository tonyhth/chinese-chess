import SwiftUI

// MARK: - 学棋中心入口

/// 学棋中心：统一入口卡片页，NavigationLink 推入主 NavigationStack
struct StudyHubView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                studyCard(
                    title: L10n.shared.t("study.puzzle"),
                    icon: "puzzlepiece",
                    color: .orange,
                    destination: ChapterSelectView()
                )
                studyCard(
                    title: L10n.shared.t("study.masterGame"),
                    icon: "crown",
                    color: .purple,
                    destination: MasterGameBrowserView()
                )
                studyCard(
                    title: L10n.shared.t("study.openingExplorer"),
                    icon: "book",
                    color: .blue,
                    destination: OpeningExplorerView()
                )
                studyCard(
                    title: L10n.shared.t("study.dailyChallenge"),
                    icon: "target",
                    color: .red,
                    destination: DailyChallengeView()
                )
            }
            .padding(16)
        }
        .background(Color.controlBackground)
        .navigationTitle(L10n.shared.t("study.title"))
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

