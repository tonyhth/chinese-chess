import SwiftUI

struct GameHeaderView: View {
    let progress: Double
    let current: Int
    let total: Int
    let score: Int
    let combo: Int

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressView(value: progress)
                .tint(VGColors.primary)
                .padding(.horizontal, VGSpacing.md)

            HStack {
                Text("\(current)/\(total)")
                    .font(.caption)
                    .foregroundColor(VGColors.textSecondary)

                Spacer()

                if combo > 0 {
                    Text("🔥 \(combo)x")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(VGColors.error)
                        .scaleEffect(combo >= 3 ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: combo)
                }

                Text("⭐ \(score)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.secondary)
            }
            .padding(.horizontal, VGSpacing.md)
        }
    }
}
