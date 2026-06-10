import SwiftUI

struct StatusBarView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            // 当前轮次 + AI 思考状态
            HStack {
                Circle()
                    .fill(viewModel.currentTurn == .red ? Color.red : Color.black)
                    .frame(width: 12, height: 12)
                Text(viewModel.currentTurn == .red ? String(localized: "red.move") : String(localized: "black.move"))
                    .font(.system(.subheadline, weight: .medium))

                if viewModel.isThinking {
                    Text(String(localized: "ai.thinking"))
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .pulseAnimation()
                }

                if viewModel.isInCheck {
                    Text(String(localized: "check"))
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundColor(.red)
                        .pulseAnimation()
                }

                Spacer()

                Text(String(localized: "round", defaultValue: "第 \(max(1, viewModel.moveHistory.count / 2 + 1)) 回合"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)

            // 被吃棋子
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "red.loss"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    capturedPiecesText(viewModel.capturedPieces.red, color: .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "black.loss"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    capturedPiecesText(viewModel.capturedPieces.black, color: .white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 60/255, green: 36/255, blue: 21/255))
    }

    @ViewBuilder
    private func capturedPiecesText(_ pieces: [Piece], color: Color) -> some View {
        if pieces.isEmpty {
            Text(String(localized: "none"))
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(pieces) { piece in
                    Text(piece.displayName)
                        .font(.custom(FontRegistry.bestAvailableFontName, size: 13))
                        .foregroundColor(color)
                }
            }
        }
    }
}

// MARK: - 脉冲动画 modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulseAnimation() -> some View {
        modifier(PulseModifier())
    }
}
