import SwiftUI

struct StatusBarView: View {
    let viewModel: GameViewModel

    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 8) {
            // 当前轮次 + AI 思考状态
            HStack {
                Circle()
                    .fill(viewModel.currentTurn == .red ? Color.red : Color.black)
                    .frame(width: 12, height: 12)
                Text(viewModel.currentTurn == .red ? l10n.t("status.redTurn") : l10n.t("status.blackTurn"))
                    .font(.subheadline.weight(.medium))

                // TODO: guided 走错回退文案 — 待 PuzzlePlayView 集成 StatusBarView 后启用

                if viewModel.isThinking {
                    Text(l10n.t("status.aiThinking"))
                        .font(.footnote)
                        .foregroundColor(.yellow)
                        .pulseAnimation()
                }

                if viewModel.isInCheck {
                    Text(l10n.t("status.check"))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.red)
                        .pulseAnimation()
                }

                Spacer()

                // 当前难度标签
                HStack(spacing: 3) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.caption2)
                    Text(viewModel.difficulty.displayName)
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.brown.opacity(0.6))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 0.5)
                )

                #if os(macOS)
                // P2 #12: 引擎类型提示
                HStack(spacing: 3) {
                    Image(systemName: EngineConfigStore.shared.useEmbeddedEngine ? "externaldrive" : "cpu")
                        .font(.caption2)
                    Text(EngineConfigStore.shared.useEmbeddedEngine ? "外部" : "内置")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.cyan)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(6)
                #endif

                Text(String(format: l10n.t("status.roundN"), max(1, viewModel.moveHistory.count / 2 + 1)))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)

            // 被吃棋子
            #if os(iOS)
            iOSCapturedPiecesSection()
            #else
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("status.redLostFull"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    capturedPiecesText(viewModel.capturedPieces.red, color: .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(l10n.t("status.blackLostFull"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    capturedPiecesText(viewModel.capturedPieces.black, color: .white)
                }
            }
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 60/255, green: 36/255, blue: 21/255))
        .accessibilityElement(children: .combine)
    }

    // MARK: - iOS 被吃棋子精简布局

    #if os(iOS)
    private let capturedRowHeight: CGFloat = 24

    @ViewBuilder
    private func iOSCapturedPiecesSection() -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 2) {
                Text(l10n.t("status.redLost"))
                    .font(.caption2)
                    .foregroundColor(.red)
                capturedPiecesText(viewModel.capturedPieces.red, color: .red)
                    .frame(height: capturedRowHeight, alignment: .leading)
                    .clipped()
            }

            Spacer()

            HStack(spacing: 2) {
                Text(l10n.t("status.blackLost"))
                    .font(.caption2)
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
            Text(l10n.t("common.none"))
                .font(.footnote)
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
