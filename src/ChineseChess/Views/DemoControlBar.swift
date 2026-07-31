import SwiftUI

// MARK: - 演示控制栏（公共组件）

/// 残局/大师棋谱播放控制栏
/// PuzzleDemoView 和 MasterGameBrowserView 共用
struct DemoControlBar: View {
    let viewModel: DemoViewModel
    let onBackToList: () -> Void

    var body: some View {
        #if os(iOS)
        iosControlBar
        #else
        macosControlBar
        #endif
    }

    // MARK: - iOS 紧凑布局

    #if os(iOS)
    private var iosControlBar: some View {
        VStack(spacing: 4) {
            // 第一行：播放控制 + 速度菜单 + 连播 + 返回列表
            HStack(spacing: 8) {
                Button(action: { viewModel.stepBackward() }) {
                    Image(systemName: "backward.frame")
                        .font(.callout)
                }
                .disabled(!viewModel.canGoBack)
                .accessibilityLabel(L10n.shared.t("demo.stepBack"))

                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.callout)
                }
                .accessibilityLabel(viewModel.isPlaying
                    ? L10n.shared.t("demo.pause")
                    : L10n.shared.t("demo.play"))

                Button(action: { viewModel.stepForward() }) {
                    Image(systemName: "forward.frame")
                        .font(.callout)
                }
                .disabled(!viewModel.canGoForward)
                .accessibilityLabel(L10n.shared.t("demo.stepForward"))

                Spacer(minLength: 0)

                // 速度选择器：Menu 替代 Segmented（节省 ~140pt）
                Menu {
                    ForEach(DemoSpeed.allCases) { speed in
                        Button {
                            viewModel.speed = speed
                        } label: {
                            if viewModel.speed == speed {
                                Label(speed.label, systemImage: "checkmark")
                            } else {
                                Text(speed.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(viewModel.speed.label)
                            .font(.subheadline.monospacedDigit())
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .accessibilityLabel(L10n.shared.t("demo.speed"))

                // 连播 Toggle：set 忽略传入值，依赖 toggleAutoAdvance() 翻转，
                // 因为 isAutoAdvance 仅通过 toggleAutoAdvance() 修改，不会不同步
                Toggle(isOn: Binding(
                    get: { viewModel.isAutoAdvance },
                    set: { _ in viewModel.toggleAutoAdvance() }
                )) {
                    Image(systemName: "repeat")
                        .font(.callout)
                }
                .toggleStyle(.button)
                .accessibilityLabel(L10n.shared.t("demo.autoAdvance"))

                // 返回列表按钮（冗余入口，DemoInfoBar 左侧也有返回）
                Button(action: onBackToList) {
                    Image(systemName: "list.bullet")
                        .font(.callout)
                }
                .accessibilityLabel(L10n.shared.t("demo.backToList"))
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // 第二行：进度条
            ProgressView(value: Double(viewModel.currentIndex), total: Double(max(viewModel.totalSteps, 1)))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .background(.bar)
    }
    #endif

    // MARK: - macOS 布局（不变）

    #if os(macOS)
    private var macosControlBar: some View {
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
    #endif
}
