import SwiftUI

// MARK: - v6.4 C1：对局页信息带（状态栏 + 棋钟合并为棋盘上方单行）
//
// 依据：v6.4-layout-redesign.md §3.1-2 + prototypes/v6.4-p1-final.html .infoband
// 布局常量全引 LayoutSpec（C0 单源）。macOS 专用（iOS 本期不动，仍走 StatusBarView+ChessClockView）。

struct GameInfoBandView: View {
    let viewModel: GameViewModel

    private let l10n = L10n.shared

    @State private var displayRedSeconds: Int = 0
    @State private var displayBlackSeconds: Int = 0
    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: LayoutSpec.space4) {
            // 轮次 + 将军 + AI 思考
            HStack(spacing: LayoutSpec.space2) {
                Circle()
                    .fill(viewModel.currentTurn == .red ? Color.red : Color.black)
                    .frame(width: 10, height: 10)
                Text(viewModel.currentTurn == .red ? l10n.t("status.redTurn") : l10n.t("status.blackTurn"))
                    .font(.system(size: LayoutSpec.fontSizeBody))

                if viewModel.isInCheck {
                    Text(l10n.t("status.check"))
                        .font(.system(size: LayoutSpec.fontSizeBody, weight: .bold))
                        .foregroundColor(.red)
                        .pulseAnimation()
                }

                if viewModel.isThinking {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text(l10n.t("status.aiThinking"))
                            .font(.system(size: LayoutSpec.fontSizeCaption))
                            .foregroundColor(.yellow)
                    }
                    .pulseAnimation()
                }
            }
            .lineLimit(1)

            Spacer(minLength: LayoutSpec.space2)

            // 回合
            Text(String(format: l10n.t("status.roundN"), max(1, viewModel.moveHistory.count / 2 + 1)))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundColor(.secondary)

            // 双方棋钟（合并单行）
            clockLabel(side: .red, seconds: displayRedSeconds)
            clockLabel(side: .black, seconds: displayBlackSeconds)

            // 难度标签
            Text(viewModel.difficulty.displayName)
                .font(.system(size: LayoutSpec.fontSizeCaption, weight: .semibold))
                .foregroundColor(.yellow)
                .lineLimit(1)
                .padding(.horizontal, LayoutSpec.space2)
                .padding(.vertical, 2)
                .background(Color.brown.opacity(0.6))
                .cornerRadius(6)
        }
        .foregroundColor(.white)
        .padding(.horizontal, LayoutSpec.space3)
        .frame(height: 40)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.06), Color.clear],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
        .onReceive(timerPublisher) { _ in updateClocks() }
        .onChange(of: viewModel.redClockSeconds) { _, _ in updateClocks() }
        .onChange(of: viewModel.blackClockSeconds) { _, _ in updateClocks() }
        .onAppear { updateClocks() }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 棋钟（低时红脉冲）

    private func clockLabel(side: Side, seconds: Int) -> some View {
        let isRunning = viewModel.gameState == .playing
            && viewModel.clockRunningSide == side
            && !viewModel.isThinking
        return HStack(spacing: 4) {
            Circle()
                .fill(side == .red ? Color.red : Color.black)
                .frame(width: 8, height: 8)
            Text(formatTime(seconds))
                .font(.system(size: LayoutSpec.fontSizeTitle, design: .monospaced)
                    .weight(isRunning ? .bold : .regular))
                .foregroundColor(isRunning && seconds < 60 ? .red : .primary)
        }
        .opacity(isRunning ? 1 : 0.6)
        .modifier(LowTimePulse(active: isRunning && seconds < 60))
        .accessibilityLabel(l10n.t(side == .red ? "clock.red" : "clock.black"))
    }

    private func updateClocks() {
        var red = viewModel.redClockSeconds
        var black = viewModel.blackClockSeconds
        if viewModel.gameState == .playing, let start = viewModel.clockStartTime {
            let elapsed = Int(Date().timeIntervalSince(start))
            if viewModel.clockRunningSide == .red { red += elapsed } else { black += elapsed }
        }
        displayRedSeconds = red
        displayBlackSeconds = black
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

/// 低时红脉冲（信息带唯一动效，克制原则 refine #7）
private struct LowTimePulse: ViewModifier {
    let active: Bool
    @State private var pulsing = false
    func body(content: Content) -> some View {
        if active {
            content
                .foregroundColor(.red)
                .opacity(pulsing ? 0.55 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulsing)
                .onAppear { pulsing = true }
        } else {
            content
        }
    }
}
