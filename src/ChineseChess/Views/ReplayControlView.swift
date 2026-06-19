import SwiftUI

struct ReplayControlView: View {
    let viewModel: ReplayViewModel

    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 6) {
            // 控制按钮 + 步数信息（合并为一行）
            HStack(spacing: 16) {
                // 当前步信息
                Text(viewModel.progressText)
                    .font(.footnote.monospaced())
                    .foregroundColor(.gray)
                    .lineLimit(1)

                if let move = viewModel.currentMove {
                    Text(move.notation)
                        .font(.custom(FontRegistry.bestAvailableFontName, size: 14))
                        .foregroundColor(move.piece.side == .red ? .red : .white)
                        .lineLimit(1)
                }

                Spacer()

                // 速度选择（iOS 小屏缩小宽度）
                Picker(l10n.t("replay.speed"), selection: Binding(
                    get: { viewModel.autoPlaySpeed },
                    set: { viewModel.autoPlaySpeed = $0 }
                )) {
                    Text("0.5x").tag(0.5)
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                }
                .pickerStyle(.segmented)
                #if os(iOS)
                .frame(width: UIDevice.current.userInterfaceIdiom == .phone ? 90 : 120)
                #endif
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)

            // 按钮行 + Slider
            HStack(spacing: 20) {
                Button(action: { viewModel.goToStart() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.canGoBack)
                .accessibilityLabel(l10n.t("replay.firstMove"))

                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.canGoBack)
                .accessibilityLabel(l10n.t("replay.previous"))

                Button(action: { viewModel.toggleAutoPlay() }) {
                    Image(systemName: viewModel.isAutoPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .accessibilityLabel(viewModel.isAutoPlaying
                    ? l10n.t("replay.pause")
                    : l10n.t("replay.play"))

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.canGoForward)
                .accessibilityLabel(l10n.t("replay.next"))

                Button(action: { viewModel.goToEnd() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.canGoForward)
                .accessibilityLabel(l10n.t("replay.lastMove"))
            }
            .foregroundColor(.white)

            // 进度条（可拖拽 Slider）
            Slider(
                value: Binding(
                    get: { Double(viewModel.currentIndex) },
                    set: { viewModel.jumpTo(index: Int($0)) }
                ),
                in: 0...Double(max(1, viewModel.record.moves.count)),
                step: 1
            )
            .tint(.brown)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
        .background(Color(red: 50/255, green: 30/255, blue: 20/255))
    }
}
