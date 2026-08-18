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
                Text(L10n.shared.t(rank.localizedTitleKey))
                    .font(.headline)
                    .foregroundColor(rankColor)
                if let next = rank.next {
                    Text("→ \(L10n.shared.t(next.localizedTitleKey))")
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
                        Text(L10n.shared.t("achievement.view.nextRank", L10n.shared.t(next.localizedTitleKey)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(L10n.shared.t("achievement.view.rankProgress",
                                      String(next.requiredWins),
                                      next.requiredPuzzles > 0 ? L10n.shared.t("achievement.view.rankProgress.puzzles", String(next.requiredPuzzles)) : ""))
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

                // Phase 2.2: 空状态引导（v6.2 P1-2: 空态统一 ContentUnavailableView，Eric）
                if profile.unlockedAchievements.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.shared.t("achievement.empty.title"), systemImage: "trophy")
                    } description: {
                        Text(L10n.shared.t("achievement.empty.hint"))
                    }
                }

                // 按稀有度分组
                ForEach(AchievementRarity.allCases, id: \.self) { rarity in
                    let achievements = AchievementLibrary.achievements(for: rarity)
                    let unlocked = achievements.filter { profile.unlockedAchievements.contains($0.id) }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(L10n.shared.t(rarity.localizedKey)) (\(unlocked.count)/\(achievements.count))")
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
                Text(achievement.rarity == .hidden ? "?????" : L10n.shared.t(achievement.nameL10nKey))
                    .font(.caption)
                    .fontWeight(isUnlocked ? .bold : .regular)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                if !achievement.available {
                    Text(L10n.shared.t("achievement.comingSoon"))
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(achievement.rarity == .hidden ? "?????" : L10n.shared.t(achievement.descriptionL10nKey))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(isUnlocked ? Color.accentColor.opacity(0.08) : Color.controlBackground)
        .cornerRadius(6)
        .opacity(isUnlocked ? 1.0 : (achievement.available ? 0.6 : 0.45))
    }
}
