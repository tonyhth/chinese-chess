import SwiftUI

// MARK: - v3.0 Phase 7: 每日挑战视图

struct DailyChallengeView: View {
    @State private var manager = DailyChallengeManager.shared
    @State private var todayMode: DailyChallengeMode = .endgamePuzzle
    @State private var todayDiff: AIDifficulty = .beginner
    @State private var isCompleted = false
    @State private var streak = 0
    @State private var streakReward: DailyStreakReward? = nil
    @State private var showPuzzle = false
    @State private var showBlitzGame = false
    @State private var showMasterGame = false
    @State private var showEndgameStart = false
    @State private var showSolveMate = false
    @State private var showCannonOnly = false
    @State private var dailyPuzzleId: String? = nil

    /// Q4: 可玩模式 + v4.0 Phase 5 新增
    private let playableModes: [DailyChallengeMode] = [
        .endgamePuzzle, .timeBlitz, .masterChallenge,
        .endgameStart, .solveMate, .cannonOnly
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

                // v4.0: 敬请期待 — 单行文案
                Text(L10n.shared.t("daily.view.moreModesComingSoon"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)

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
                            Text("🏅 \(L10n.shared.t(reward.localizedRewardKey))")
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
                                        Text(L10n.shared.t(reward.localizedDescKey))
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
                    Text(L10n.shared.t("daily.view.recent"))
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
                                Text(L10n.shared.t(challenge.mode.localizedTitleKey))
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
            isCompleted = manager.isTodayCompleted(puzzles: PuzzleStore.shared.puzzles)
            streak = manager.checkDailyLogin()
            streakReward = manager.checkStreakReward()
            dailyPuzzleId = manager.dailyPuzzleId(puzzles: PuzzleStore.shared.puzzles)
            // v3.0 gap fix: 自动领取待领取的连续登录奖励
            _ = manager.claimPendingRewards()
        }
        .sheet(isPresented: $showPuzzle) {
            if let puzzle = manager.dailyPuzzle(puzzles: PuzzleStore.shared.puzzles) {
                NavigationStack {
                    PuzzlePlayView(puzzle: puzzle, isDailyChallenge: true)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showPuzzle = false }
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
                    vm.challengeMode = .timeBlitz
                    let profile = PlayerProfileStore.shared.profile
                    vm.blitzTimeLimitSeconds = 300 + profile.bonusBlitzTimeBonus
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.shared.t("common.done")) { showBlitzGame = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showMasterGame) {
            NavigationStack {
                BoardView(viewModel: {
                    let vm = GameViewModel()
                    vm.difficulty = .amateurHigh
                    vm.isMasterChallenge = true
                    vm.challengeMode = .masterChallenge
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.shared.t("common.done")) { showMasterGame = false }
                    }
                }
            }
        }
        // v4.0 Phase 5: endgameStart
        .sheet(isPresented: $showEndgameStart) {
            NavigationStack {
                BoardView(viewModel: {
                    let vm = GameViewModel()
                    let puzzle = manager.endgameStartPuzzle(puzzles: PuzzleStore.shared.puzzles)
                    vm.loadChallenge(mode: .endgameStart, puzzle: puzzle, difficulty: todayDiff)
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.shared.t("common.done")) { showEndgameStart = false }
                    }
                }
            }
        }
        // v4.0 Phase 5: solveMate
        .sheet(isPresented: $showSolveMate) {
            NavigationStack {
                BoardView(viewModel: {
                    let vm = GameViewModel()
                    let puzzle = manager.solveMatePuzzle(puzzles: PuzzleStore.shared.puzzles)
                    vm.loadChallenge(mode: .solveMate, puzzle: puzzle, difficulty: todayDiff)
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.shared.t("common.done")) { showSolveMate = false }
                    }
                }
            }
        }
        // v4.0 Phase 5: cannonOnly
        .sheet(isPresented: $showCannonOnly) {
            NavigationStack {
                BoardView(viewModel: {
                    let vm = GameViewModel()
                    vm.loadChallenge(mode: .cannonOnly, puzzle: nil, difficulty: todayDiff)
                    return vm
                }())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.shared.t("common.done")) { showCannonOnly = false }
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
                Text(L10n.shared.t(mode.localizedTitleKey))
                    .font(.headline)
                Text(L10n.shared.t(mode.localizedDescKey))
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
            case .endgameStart:
                showEndgameStart = true
            case .solveMate:
                showSolveMate = true
            case .cannonOnly:
                showCannonOnly = true
            default:
                break
            }
        }
    }
}
