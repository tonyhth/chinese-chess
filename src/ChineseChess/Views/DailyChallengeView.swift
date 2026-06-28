import SwiftUI

// MARK: - v3.0 Phase 7: 每日挑战视图

struct DailyChallengeView: View {
    @State private var manager = DailyChallengeManager.shared
    @State private var todayMode: DailyChallengeMode = .endgamePuzzle
    @State private var todayDiff: AIDifficulty = .easy
    @State private var isCompleted = false
    @State private var streak = 0
    @State private var streakReward: DailyStreakReward? = nil
    @State private var showPuzzle = false
    @State private var showBlitzGame = false
    @State private var showMasterGame = false
    @State private var dailyPuzzleId: String? = nil

    /// Q4: 可玩模式
    private let playableModes: [DailyChallengeMode] = [.endgamePuzzle, .timeBlitz, .masterChallenge]
    /// Q4: 敬请期待模式
    private let comingSoonModes: [DailyChallengeMode] = [
        .materialAdvantage, .endgameStart, .solveMate,
        .defendChallenge, .comboKill, .cannonOnly, .horseOnly
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Q4: 三种可玩模式
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.shared.t("daily.view.todayChallenge"))
                        .font(.headline)

                    ForEach(playableModes, id: \.self) { mode in
                        challengeCard(for: mode)
                    }
                }
                .padding()
                .background(Color.controlBackground)
                .cornerRadius(12)

                // Q4: 敬请期待模式
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.shared.t("daily.view.comingSoon"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(comingSoonModes, id: \.self) { mode in
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(mode.localizedTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding()
                .background(Color.controlBackground)
                .cornerRadius(12)

                // 连续登录
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.shared.t("daily.view.loginStreak"))
                        .font(.headline)

                    HStack {
                        Text("\(streak) \(L10n.shared.t("daily.view.days"))")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)

                        Spacer()

                        if let reward = streakReward {
                            Text("🏅 \(reward.localizedReward)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }

                    // 奖励阶梯
                    HStack(spacing: 4) {
                        ForEach(DailyStreakReward.allCases, id: \.self) { reward in
                            VStack(spacing: 2) {
                                Image(systemName: streak >= reward.rawValue ? "flame.fill" : "flame")
                                    .foregroundColor(streak >= reward.rawValue ? .orange : .secondary)
                                    .font(.caption)
                                Text("\(reward.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    // v3.0 gap fix: 显示解锁内容简述
                                    if streak >= reward.rawValue {
                                        Text(reward.localizedDesc)
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                    }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                .background(Color.controlBackground)
                .cornerRadius(12)

                // 最近挑战
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近挑战")
                        .font(.headline)

                    let recent = manager.recentChallenges(days: 7)
                    if recent.isEmpty {
                        Text(L10n.shared.t("daily.view.noRecord"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recent, id: \.date) { challenge in
                            HStack {
                                Image(systemName: challenge.mode.icon)
                                    .foregroundColor(.secondary)
                                Text(challenge.mode.localizedTitle)
                                    .font(.caption)
                                Spacer()
                                if challenge.completed {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                                Text(challenge.date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.controlBackground)
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            todayMode = manager.todayChallengeMode()
            todayDiff = manager.todayDifficulty()
            isCompleted = manager.isTodayCompleted
            streak = manager.checkDailyLogin()
            streakReward = manager.checkStreakReward()
            dailyPuzzleId = manager.dailyPuzzleId()
            // v3.0 gap fix: 自动领取待领取的连续登录奖励
            _ = manager.claimPendingRewards()
        }
        .sheet(isPresented: $showPuzzle) {
            if let puzzle = manager.dailyPuzzle() {
                NavigationStack {
                    PuzzlePlayView(puzzle: puzzle)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showPuzzle = false }
                            }
                        }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(L10n.shared.t("daily.puzzleLoadError"))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showBlitzGame) {
            NavigationStack {
                BoardView(viewModel: {
                    let vm = GameViewModel()
                    vm.difficulty = todayDiff
                    vm.isBlitzMode = true
                    let profile = PlayerProfileStore.shared.profile
                    vm.blitzTimeLimitSeconds = 300 + profile.bonusBlitzTimeBonus
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showBlitzGame = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showMasterGame) {
            NavigationStack {
                BoardView(viewModel: {
                    let vm = GameViewModel()
                    vm.difficulty = .master
                    vm.isMasterChallenge = true
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showMasterGame = false }
                    }
                }
            }
        }
    }

    // MARK: - Q4: 挑战卡片

    @ViewBuilder
    private func challengeCard(for mode: DailyChallengeMode) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.localizedTitle)
                    .font(.headline)
                Text(mode.localizedDesc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            switch mode {
            case .endgamePuzzle:
                showPuzzle = true
            case .timeBlitz:
                showBlitzGame = true
            case .masterChallenge:
                showMasterGame = true
            default:
                break
            }
        }
    }
}
