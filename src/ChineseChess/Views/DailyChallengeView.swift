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
    @State private var dailyPuzzleId: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 今日挑战卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: todayMode.icon)
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text("今日挑战")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(todayMode.rawValue)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title)
                        }
                    }

                    Text(todayMode.description)
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("推荐难度：\(todayDiff.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        // v3.0 gap fix: 残局模式可点击进入
                        if todayMode == .endgamePuzzle || todayMode == .endgameStart || todayMode == .solveMate {
                            if dailyPuzzleId != nil {
                                Button("开始残局挑战") {
                                    showPuzzle = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.brown)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // 连续登录
                VStack(alignment: .leading, spacing: 8) {
                    Text("连续登录")
                        .font(.headline)

                    HStack {
                        Text("\(streak) 天")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)

                        Spacer()

                        if let reward = streakReward {
                            Text("🏅 \(reward.reward)")
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
                                        Text(reward.unlockDescription)
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
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // 最近挑战
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近挑战")
                        .font(.headline)

                    let recent = manager.recentChallenges(days: 7)
                    if recent.isEmpty {
                        Text("暂无记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recent, id: \.date) { challenge in
                            HStack {
                                Image(systemName: challenge.mode.icon)
                                    .foregroundColor(.secondary)
                                Text(challenge.mode.rawValue)
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
                .background(Color(nsColor: .controlBackgroundColor))
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
            }
        }
    }
}
