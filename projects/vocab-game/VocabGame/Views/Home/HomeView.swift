import SwiftUI

struct HomeWrapperView: View {
    @EnvironmentObject var app: AppCoordinator

    var body: some View {
        HomeContent(viewModel: HomeViewModel(progressRepo: app.progressRepo), coordinator: app)
    }
}

struct HomeContent: View {
    @ObservedObject var viewModel: HomeViewModel
    let coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VGSpacing.lg) {
                    // Greeting + Pet Mini
                    HStack {
                        VStack(alignment: .leading, spacing: VGSpacing.xs) {
                            Text(viewModel.greeting)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(VGColors.textPrimary)
                            Text("⭐ \(viewModel.totalStars) · 🔥 \(viewModel.streak)天 · 📚 \(viewModel.totalWordsLearned)词 · 💰 \(coordinator.progressRepo.profile.coins)币")
                                .font(.subheadline)
                                .foregroundColor(VGColors.textSecondary)
                        }
                        Spacer()
                        PetMiniView(size: 60)
                    }
                    .padding(.horizontal, VGSpacing.md)
                    .padding(.top, VGSpacing.lg)

                    // Quick Actions
                    VStack(spacing: VGSpacing.md) {
                        if viewModel.hasActiveSession {
                            QuickActionCard(
                                title: "继续上次",
                                subtitle: "有未完成的游戏",
                                icon: "play.circle.fill",
                                color: VGColors.primary
                            ) {
                                coordinator.resumeSession()
                            }
                        }

                        let mistakeCount = coordinator.progressRepo.mistakeWords().count
                        QuickActionCard(
                            title: "错词复习",
                            subtitle: "\(mistakeCount) 个单词待复习",
                            icon: "book.circle.fill",
                            color: VGColors.error
                        ) {
                            coordinator.startMistakeReview()
                        }

                        QuickActionCard(
                            title: "每日挑战",
                            subtitle: "今日的单词挑战",
                            icon: "flame.circle.fill",
                            color: Color.orange
                        ) {
                            coordinator.currentGameMode = .dailyChallenge
                        }

                        QuickActionCard(
                            title: "拼写挑战",
                            subtitle: "看释义拼单词",
                            icon: "text.cursor",
                            color: Color.purple
                        ) {
                            coordinator.currentGameMode = .spellChallenge
                        }

                        QuickActionCard(
                            title: "配对消消乐",
                            subtitle: "翻牌配对消除",
                            icon: "square.grid.2x2.fill",
                            color: Color.teal
                        ) {
                            coordinator.currentGameMode = .matchPairs
                        }
                    }
                    .padding(.horizontal, VGSpacing.md)
                }
            }
            .background(VGColors.background.ignoresSafeArea())
            .navigationTitle("")
        }
        .onAppear { viewModel.load() }
    }
}
