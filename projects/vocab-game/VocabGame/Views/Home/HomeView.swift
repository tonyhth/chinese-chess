import SwiftUI

struct HomeWrapperView: View {
    @StateObject private var viewModel: HomeViewModel
    @EnvironmentObject var app: AppCoordinator

    init(progressRepo: ProgressRepository) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(progressRepo: progressRepo))
    }

    var body: some View {
        HomeContent(viewModel: viewModel, coordinator: app)
            .sheet(isPresented: $app.showingAchievements) {
                NavigationStack {
                    AchievementWallView(achievementRepo: app.achievementRepo)
                }
            }
    }
}

struct HomeContent: View {
    @ObservedObject var viewModel: HomeViewModel
    let coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VGSpacing.lg) {
                    // 顶部问候 + 数据条
                    headerSection

                    // 蛋仔 + 每日挑战 双卡片
                    petAndDailySection

                    // 主 CTA 按钮
                    mainCTASection

                    // 快捷入口
                    quickActionsSection

                    // 今日目标
                    dailyGoalSection
                }
                .padding(.horizontal, VGSpacing.md)
                .padding(.top, VGSpacing.lg)
                .padding(.bottom, VGSpacing.xl)
            }
            .background(VGColors.background.ignoresSafeArea())
            .navigationTitle("")
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: VGSpacing.xs) {
            Text(viewModel.greeting)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(VGColors.textPrimary)

            HStack(spacing: VGSpacing.md) {
                statBadge(icon: "star.fill", value: "\(viewModel.totalStars)", color: VGColors.secondary)
                statBadge(icon: "flame.fill", value: "\(viewModel.streak)天", color: VGColors.error)
                statBadge(icon: "book.fill", value: "\(viewModel.totalWordsLearned)词", color: VGColors.accent)
                statBadge(icon: "coins", value: "\(coordinator.progressRepo.profile.coins)", color: .orange)
            }
        }
    }

    private func statBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(VGColors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Pet + Daily Challenge

    private var petAndDailySection: some View {
        HStack(spacing: VGSpacing.md) {
            // 蛋仔大卡片
            VStack {
                PetDisplayView(petState: coordinator.petRepo.petState, size: 120)
                Text("Lv.\(coordinator.petRepo.petState.level)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(VGRadius.card)
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)

            // 每日挑战卡片
            Button {
                coordinator.currentGameMode = .dailyChallenge
            } label: {
                VStack(spacing: VGSpacing.sm) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)

                    Text("每日挑战")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(VGColors.textPrimary)

                    Text(coordinator.progressRepo.isDailyCompleted ? "已完成 ✓" : "等你来战")
                        .font(.caption)
                        .foregroundColor(coordinator.progressRepo.isDailyCompleted ? VGColors.success : VGColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FFF8E1"), Color(hex: "FFECB3")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(VGRadius.card)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Main CTA

    @ViewBuilder
    private var mainCTASection: some View {
        if viewModel.hasActiveSession {
            largeCTAButton(
                title: "继续上次",
                subtitle: "有未完成的游戏",
                icon: "play.circle.fill",
                gradient: [VGColors.accent, Color(hex: "3DBCB5")]
            ) {
                coordinator.resumeSession()
            }
        } else {
            largeCTAButton(
                title: "开始闯关",
                subtitle: "选择关卡开始冒险",
                icon: "gamecontroller.fill",
                gradient: [VGColors.primary, Color(hex: "FF8CAE")]
            ) {
                coordinator.currentGameMode = .adventure
                coordinator.currentGameLevel = nil
            }
        }
    }

    private func largeCTAButton(title: String, subtitle: String, icon: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(VGRadius.card)
            .shadow(color: gradient.first?.opacity(0.3) ?? Color.clear, radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: VGSpacing.sm) {
            Text("快捷入口")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VGSpacing.sm) {
                    quickActionCard(
                        title: "拼写挑战",
                        icon: "text.cursor",
                        color: VGColors.purple
                    ) {
                        coordinator.currentGameMode = .spellChallenge
                    }

                    quickActionCard(
                        title: "听写挑战",
                        icon: "ear",
                        color: VGColors.peach
                    ) {
                        coordinator.currentGameMode = .dictation
                    }

                    let mistakeCount = coordinator.progressRepo.mistakeWords().count
                    quickActionCard(
                        title: "错词复习",
                        icon: "book.circle.fill",
                        color: VGColors.error,
                        badge: mistakeCount > 0 ? "\(mistakeCount)" : nil
                    ) {
                        coordinator.startMistakeReview()
                    }

                    quickActionCard(
                        title: "单词跑酷",
                        icon: "figure.run",
                        color: VGColors.accent
                    ) {
                        coordinator.currentGameMode = .wordRunner
                    }

                    quickActionCard(
                        title: "成就墙",
                        icon: "trophy.fill",
                        color: VGColors.secondary
                    ) {
                        coordinator.showingAchievements = true
                    }
                }
            }
        }
    }

    private func quickActionCard(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    if let badge = badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VGColors.error)
                            .cornerRadius(8)
                            .offset(x: 8, y: -4)
                    }
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(VGColors.textSecondary)
            }
            .frame(width: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Daily Goal

    private var dailyGoalSection: some View {
        let goal = coordinator.progressRepo.dailyGoalProgress
        return VStack(alignment: .leading, spacing: VGSpacing.sm) {
            HStack {
                Text("今日目标")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.textPrimary)
                Spacer()
                if goal.isDone {
                    Text("✅ 已完成！连续\(goal.consecutiveDays)天")
                        .font(.caption)
                        .foregroundColor(VGColors.success)
                } else {
                    Text("\(goal.completed) / \(goal.target) 词")
                        .font(.caption)
                        .foregroundColor(VGColors.textSecondary)
                }
            }

            ProgressView(value: min(Double(goal.completed) / Double(max(goal.target, 1)), 1.0))
                .tint(goal.isDone ? VGColors.success : VGColors.accent)
                .scaleEffect(y: 1.5)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(VGRadius.card)
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
    }
}
