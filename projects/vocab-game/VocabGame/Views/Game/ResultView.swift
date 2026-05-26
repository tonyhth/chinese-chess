import SwiftUI

struct ResultView: View {
    let session: GameSession
    let onDismiss: () -> Void

    @State private var showScore = false
    @State private var showStars = false
    @State private var showConfetti = false

    private var stars: Int {
        StarRating.stars(forScore: session.score)
    }

    private var coinsEarned: Int {
        max(session.score / 100, 1) + (session.maxCombo >= 5 ? 5 : 0)
    }

    var body: some View {
        ZStack {
            VGGradients.game.ignoresSafeArea()

            // Confetti for good results
            if showConfetti && stars >= 2 {
                ConfettiView()
            }

            VStack(spacing: VGSpacing.xl) {
                Spacer()

                Text(session.isCompleted ? "关卡完成!" : "时间到!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.textPrimary)
                    .modifier(GlowEffect(color: VGColors.primary, radius: 10))

                // Score with bounce
                Text("\(session.score)")
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundColor(VGColors.primary)
                    .scaleEffect(showScore ? 1.0 : 0.3)
                    .opacity(showScore ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showScore)

                // Stars with pop
                HStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { i in
                        StarPopView(
                            filled: i < stars,
                            delay: Double(i) * 0.2 + 0.3
                        )
                    }
                }
                .opacity(showStars ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: showStars)

                // Stats cards
                HStack(spacing: VGSpacing.lg) {
                    VStack(spacing: 4) {
                        Text("🔥 \(session.maxCombo)x")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(VGColors.error)
                        Text("最高连击")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(16)

                    VStack(spacing: 4) {
                        let correct = session.questions.filter { $0.isCorrect == true }.count
                        Text("\(session.questions.isEmpty ? 0 : correct * 100 / session.questions.count)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(VGColors.success)
                        Text("正确率")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(16)
                }
                .padding(.horizontal, VGSpacing.xl)

                // Coins earned
                HStack(spacing: 6) {
                    Image(systemName: "coins")
                        .foregroundColor(VGColors.secondary)
                    Text("+\(coinsEarned)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(VGColors.secondary)
                }
                .padding(.horizontal, VGSpacing.lg)
                .padding(.vertical, VGSpacing.sm)
                .background(VGColors.secondary.opacity(0.15))
                .cornerRadius(20)

                // Buttons
                Button("继续") {
                    onDismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, VGSpacing.xl)

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showScore = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showStars = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if stars >= 2 { showConfetti = true }
            }
            AudioService.shared.play(.levelComplete)
        }
    }
}
