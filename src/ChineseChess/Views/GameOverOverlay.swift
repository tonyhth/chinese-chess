import SwiftUI

struct GameOverOverlay: View {
    let gameState: GameState
    let onNewGame: () -> Void
    var onViewRecord: (() -> Void)? = nil

    @Environment(L10n.self) private var l10n

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Text(gameState == .redWon ? l10n.t("gameover.redWon") :
                     gameState == .blackWon ? l10n.t("gameover.blackWon") : l10n.t("gameover.draw"))
                    .font(.custom(FontRegistry.bestAvailableFontName, size: 36))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    Button(l10n.t("gameover.newGame")) {
                        onNewGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                    .controlSize(.large)

                    if let onViewRecord {
                        Button(l10n.t("gameover.viewRecord")) {
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
            .accessibilityElement(children: .combine)
        }
    }
}
