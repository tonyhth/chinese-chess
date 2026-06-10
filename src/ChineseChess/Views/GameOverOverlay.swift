import SwiftUI

struct GameOverOverlay: View {
    let gameState: GameState
    let onNewGame: () -> Void
    var onViewRecord: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(gameState == .redWon ? "🎉 红方获胜！" :
                     gameState == .blackWon ? "🖤 黑方获胜！" : "🤝 和棋！")
                    .font(.custom(FontRegistry.bestAvailableFontName, size: 36))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    Button("再来一局") {
                        onNewGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .controlSize(.large)

                    if let onViewRecord {
                        Button("查看棋谱") {
                            onViewRecord()
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .controlSize(.large)
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 44/255, green: 24/255, blue: 16/255))
                    .shadow(radius: 20)
            )
        }
    }
}
