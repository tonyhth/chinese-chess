import SwiftUI

struct AchievementWallView: View {
    @ObservedObject var achievementRepo: AchievementRepository

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(achievementRepo.achievements) { achievement in
                    achievementCard(achievement)
                }
            }
            .padding()
        }
        .background(VGColors.background.ignoresSafeArea())
        .navigationTitle("成就墙")
        .overlay(alignment: .center) {
            if let unlocked = achievementRepo.newlyUnlocked {
                unlockPopup(unlocked)
            }
        }
    }

    private func achievementCard(_ a: Achievement) -> some View {
        VStack(spacing: 8) {
            Text(a.icon)
                .font(.system(size: 36))
                .grayscale(a.isUnlocked ? 0 : 1)
                .opacity(a.isUnlocked ? 1 : 0.4)

            Text(a.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(a.isUnlocked ? VGColors.textPrimary : VGColors.textSecondary)

            Text(a.description)
                .font(.caption2)
                .foregroundColor(VGColors.textSecondary)
                .multilineTextAlignment(.center)

            if !a.isUnlocked {
                ProgressView(value: min(Double(a.progress) / Double(a.requirement), 1.0))
                    .tint(VGColors.accent)
            } else if let date = a.unlockedAt {
                Text(dateFormatter.string(from: date))
                    .font(.caption2)
                    .foregroundColor(VGColors.success)
            }

            HStack(spacing: 2) {
                Image(systemName: "coins")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text("\(a.reward)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(a.isUnlocked ? Color.white : Color.white.opacity(0.5))
        .cornerRadius(VGRadius.card)
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    private func unlockPopup(_ a: Achievement) -> some View {
        VStack(spacing: 12) {
            Text(a.icon)
                .font(.system(size: 64))

            Text("🎉 成就解锁！")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)

            Text(a.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(VGColors.accent)

            HStack(spacing: 2) {
                Image(systemName: "coins")
                    .foregroundColor(.orange)
                Text("+\(a.reward) 金币")
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 16, y: 8)
        )
        .transition(.scale.combined(with: .opacity))
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }
}
