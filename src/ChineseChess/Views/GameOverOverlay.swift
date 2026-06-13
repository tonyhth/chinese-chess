import SwiftUI

struct GameOverOverlay: View {
    let gameState: GameState
    let onNewGame: () -> Void
    var onViewRecord: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Text(gameState == .redWon ? String(localized: "gameover.redWon") :
                     gameState == .blackWon ? String(localized: "gameover.blackWon") : String(localized: "gameover.draw"))
                    .font(.custom(FontRegistry.bestAvailableFontName, size: 36))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    Button(String(localized: "gameover.newGame")) {
                        onNewGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .controlSize(.large)

                    if let onViewRecord {
                        Button(String(localized: "gameover.viewRecord")) {
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
