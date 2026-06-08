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
                Text(viewModel.currentTurn == .red ? "红方走棋" : "黑方走棋")
                    .font(.system(size: 14, weight: .medium))

                if viewModel.isThinking {
                    Text("AI 思考中...")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .pulseAnimation()
                }

                Spacer()

                Text("第 \(max(1, viewModel.moveHistory.count / 2 + 1)) 回合")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .foregroundColor(.white)

            // 被吃棋子
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("红方损失:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    capturedPiecesText(viewModel.capturedPieces.red, color: .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("黑方损失:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
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
            Text("无")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        } else {
            Text(pieces.map { $0.displayName }.joined())
                .font(.custom(FontRegistry.fontName, size: 13))
                .foregroundColor(color)
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
