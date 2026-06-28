import SwiftUI

// MARK: - Phase 2.3: 棋钟视图（对局双方用时）

struct ChessClockView: View {
    let viewModel: GameViewModel
    @State private var displayRedSeconds: Int = 0
    @State private var displayBlackSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let l10n = L10n.shared

    var body: some View {
        HStack(spacing: 0) {
            // 红方计时器
            clockCell(
                side: .red,
                seconds: displayRedSeconds,
                isRunning: viewModel.isThinking == false && viewModel.clockRunningSide == .red && viewModel.gameState == .playing,
                label: l10n.t("clock.red")
            )

            Spacer(minLength: 8)

            // 黑方计时器
            clockCell(
                side: .black,
                seconds: displayBlackSeconds,
                isRunning: viewModel.isThinking == false && viewModel.clockRunningSide == .black && viewModel.gameState == .playing,
                label: l10n.t("clock.black")
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            updateDisplay()
        }
        .onChange(of: viewModel.redClockSeconds) { _, _ in updateDisplay() }
        .onChange(of: viewModel.blackClockSeconds) { _, _ in updateDisplay() }
        .onAppear { updateDisplay() }
    }

    private func clockCell(side: Side, seconds: Int, isRunning: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(side == .red ? Color.red : Color.black)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(formatTime(seconds))
                .font(.system(.caption, design: .monospaced).weight(isRunning ? .bold : .regular))
                .foregroundColor(clockColor(for: side, seconds: seconds, isRunning: isRunning))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isRunning ? (side == .red ? Color.red.opacity(0.15) : Color.white.opacity(0.1)) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isRunning ? (side == .red ? Color.red.opacity(0.4) : Color.white.opacity(0.3)) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func updateDisplay() {
        // 累加当前方正在走的实时秒数
        var red = viewModel.redClockSeconds
        var black = viewModel.blackClockSeconds
        if viewModel.gameState == .playing, let start = viewModel.clockStartTime {
            let elapsed = Int(Date().timeIntervalSince(start))
            if viewModel.clockRunningSide == .red {
                red += elapsed
            } else {
                black += elapsed
            }
        }
        displayRedSeconds = red
        displayBlackSeconds = black
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func clockColor(for side: Side, seconds: Int, isRunning: Bool) -> Color {
        // 时间不足 10 秒且正在计时 → 红色警示
        if isRunning && seconds < 10 {
            return .red
        }
        return isRunning ? .primary : .secondary
    }
}
