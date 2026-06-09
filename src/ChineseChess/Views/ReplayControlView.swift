import SwiftUI

struct ReplayControlView: View {
    let viewModel: ReplayViewModel

    var body: some View {
        VStack(spacing: 8) {
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

            // 控制按钮
            HStack(spacing: 20) {
                Button(action: { viewModel.goToStart() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 18))
                }
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                }
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.toggleAutoPlay() }) {
                    Image(systemName: viewModel.isAutoPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                }

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                }
                .disabled(!viewModel.canGoForward)

                Button(action: { viewModel.goToEnd() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 18))
                }
                .disabled(!viewModel.canGoForward)

                Spacer()

                // 速度选择
                Picker("速度", selection: Binding(
                    get: { viewModel.autoPlaySpeed },
                    set: { viewModel.autoPlaySpeed = $0 }
                )) {
                    Text("0.5x").tag(0.5)
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .foregroundColor(.white)

            // 当前步信息
            HStack {
                Text(viewModel.progressText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                if let move = viewModel.currentMove {
                    Text(move.notation)
                        .font(.custom(FontRegistry.bestAvailableFontName, size: 14))
                        .foregroundColor(move.piece.side == .red ? .red : .white)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(red: 50/255, green: 30/255, blue: 20/255))
    }
}
