import SwiftUI

// MARK: - 演示控制栏（公共组件）

/// 残局/大师棋谱播放控制栏
/// PuzzleDemoView 和 MasterGameBrowserView 共用
struct DemoControlBar: View {
    let viewModel: DemoViewModel
    let onBackToList: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(viewModel.currentIndex), total: Double(max(viewModel.totalSteps, 1)))
                .padding(.horizontal, 16)

            HStack(spacing: 16) {
                Button(action: { viewModel.stepBackward() }) {
                    Image(systemName: "backward.frame")
                }
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button(action: { viewModel.stepForward() }) {
                    Image(systemName: "forward.frame")
                }
                .disabled(!viewModel.canGoForward)

                Divider().frame(height: 24)

                Picker(L10n.shared.t("demo.speed"), selection: Binding(
                    get: { viewModel.speed },
                    set: { viewModel.speed = $0 }
                )) {
                    ForEach(DemoSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Divider().frame(height: 24)

                Toggle(isOn: Binding(
                    get: { viewModel.isAutoAdvance },
                    set: { _ in viewModel.toggleAutoAdvance() }
                )) {
                    Image(systemName: "repeat")
                }
                .toggleStyle(.button)

                Spacer()

                Button(action: onBackToList) {
                    Image(systemName: "list.bullet")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}
