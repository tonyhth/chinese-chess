import SwiftUI

// MARK: - v3.0 Phase 6: 段位徽章视图

struct RankBadgeView: View {
    let rank: Rank
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: rank.icon)
                .font(.headline)
                .foregroundColor(rankColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(rank.localizedTitle)
                    .font(.headline)
                    .foregroundColor(rankColor)
                if let next = rank.next {
                    Text("→ \(next.localizedTitle)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(rankColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var rankColor: Color {
        switch rank {
        case .student: return .gray
        case .scholar: return .blue
        case .juren: return .green
        case .jinshi: return .orange
        case .hanlin: return .purple
        case .master: return .red
        case .sage: return .yellow
        }
    }
}

// MARK: - 段位进度条

struct RankProgressView: View {
    let profile: PlayerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RankBadgeView(rank: profile.rank)
                Spacer()
                if let next = profile.rank.next {
                    VStack(alignment: .trailing) {
                        Text(L10n.shared.t("achievement.view.nextRank", next.localizedTitle))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("需 \(next.requiredWins) 胜\(next.requiredPuzzles > 0 ? " + \(next.requiredPuzzles) 残局" : "")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            ProgressView(value: profile.rankProgress)
                .tint(profile.rank >= .hanlin ? .yellow : .accentColor)

            HStack {
                Text("\(L10n.shared.t("achievement.view.wins"))：\(profile.effectiveWins)/\(profile.rank.next?.requiredWins ?? profile.effectiveWins)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if profile.rank.next?.requiredPuzzles ?? 0 > 0 {
                    Text("\(L10n.shared.t("achievement.view.puzzles"))：\(profile.effectivePuzzles)/\(profile.rank.next?.requiredPuzzles ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.controlBackground)
        .cornerRadius(8)
    }
}

// MARK: - 成就视图

struct AchievementView: View {
    let profile: PlayerProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 总进度
                HStack {
                    Text(L10n.shared.t("achievement.view.title"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(profile.unlockedAchievements.count)/\(AchievementLibrary.all.count)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                ProgressView(
                    value: Double(profile.unlockedAchievements.count),
                    total: Double(max(AchievementLibrary.all.count, 1))
                )
                .tint(.accentColor)

                // Phase 2.2: 空状态引导
                if profile.unlockedAchievements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(L10n.shared.t("achievement.empty.title"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(L10n.shared.t("achievement.empty.hint"))
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                // 按稀有度分组
                ForEach(AchievementRarity.allCases, id: \.self) { rarity in
                    let achievements = AchievementLibrary.achievements(for: rarity)
                    let unlocked = achievements.filter { profile.unlockedAchievements.contains($0.id) }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(rarity.localizedName) (\(unlocked.count)/\(achievements.count))")
                                .font(.headline)
                            Spacer()
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(achievements) { achievement in
                                achievementCard(achievement, isUnlocked: profile.unlockedAchievements.contains(achievement.id))
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func achievementCard(_ achievement: Achievement, isUnlocked: Bool) -> some View {
        HStack(spacing: 8) {
            Text(isUnlocked ? AchievementLibrary.find(id: achievement.id)?.rarity.icon ?? "🔒" : "🔒")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.displayName)
                    .font(.caption)
                    .fontWeight(isUnlocked ? .bold : .regular)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                Text(achievement.displayDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(isUnlocked ? Color.accentColor.opacity(0.08) : Color.controlBackground)
        .cornerRadius(6)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
