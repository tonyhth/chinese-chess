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
                Text(viewModel.currentTurn == .red ? String(localized: "status.redTurn") : String(localized: "status.blackTurn"))
                    .font(.system(size: 14, weight: .medium))

                if viewModel.isThinking {
                    Text(String(localized: "status.aiThinking"))
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .pulseAnimation()
                }

                if viewModel.isInCheck {
                    Text(String(localized: "status.check"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                        .pulseAnimation()
                }

                Spacer()

                Text(String(localized: "status.roundN", defaultValue: "第 \(max(1, viewModel.moveHistory.count / 2 + 1)) 回合"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)

            // 被吃棋子
            #if os(iOS)
            iOSCapturedPiecesSection()
            #else
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "status.redLostFull"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    capturedPiecesText(viewModel.capturedPieces.red, color: .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "status.blackLostFull"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    capturedPiecesText(viewModel.capturedPieces.black, color: .white)
                }
            }
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 60/255, green: 36/255, blue: 21/255))
    }

    // MARK: - iOS 被吃棋子精简布局

    #if os(iOS)
    private let capturedRowHeight: CGFloat = 24

    @ViewBuilder
    private func iOSCapturedPiecesSection() -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 2) {
                Text(String(localized: "status.redLost"))
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                capturedPiecesText(viewModel.capturedPieces.red, color: .red)
                    .frame(height: capturedRowHeight, alignment: .leading)
                    .clipped()
            }

            Spacer()

            HStack(spacing: 2) {
                Text(String(localized: "status.blackLost"))
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                capturedPiecesText(viewModel.capturedPieces.black, color: .white)
                    .frame(height: capturedRowHeight, alignment: .leading)
                    .clipped()
            }
        }
    }
    #endif

    @ViewBuilder
    private func capturedPiecesText(_ pieces: [Piece], color: Color) -> some View {
        if pieces.isEmpty {
            Text("无")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(pieces) { piece in
                    Text(piece.displayName)
                        .font(.custom(FontRegistry.bestAvailableFontName, size: 13))
                        .foregroundColor(color)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
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
