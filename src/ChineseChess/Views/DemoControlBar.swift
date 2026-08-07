import SwiftUI

// MARK: - 演示控制栏（公共组件）

/// 残局/大师棋谱播放控制栏
/// PuzzleDemoView 和 MasterGameBrowserView 共用
struct DemoControlBar: View {
    let viewModel: DemoViewModel
    let onBackToList: () -> Void

    /// DemoConfig 编辑状态
    @State private var showConfig = false
    @State private var config = DemoConfig.load()

    var body: some View {
        #if os(iOS)
        iosControlBar
            .sheet(isPresented: $showConfig) {
                DemoConfigSheet(config: $config)
            }
            .syncConfigToViewModel(config: config, viewModel: viewModel)
        #else
        macosControlBar
            .popover(isPresented: $showConfig) {
                DemoConfigPopover(config: $config)
            }
            .syncConfigToViewModel(config: config, viewModel: viewModel)
        #endif
    }

    // MARK: - iOS 紧凑布局

    #if os(iOS)
    private var iosControlBar: some View {
        VStack(spacing: 4) {
            // 第一行：播放控制 + 速度菜单 + 连播 + 设置 + 返回列表
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
                            config.demoSpeed = speed  // 通过 onChange 同步到 viewModel
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
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .accessibilityLabel(L10n.shared.t("demo.speed"))

                // 连播 Toggle
                Toggle(isOn: Binding(
                    get: { viewModel.isAutoAdvance },
                    set: { newValue in
                        if newValue != viewModel.isAutoAdvance {
                            viewModel.toggleAutoAdvance()
                        }
                        config.autoNextPuzzle = viewModel.isAutoAdvance
                        config.save()
                    }
                )) {
                    Image(systemName: "repeat")
                        .font(.callout)
                }
                .toggleStyle(.button)
                .accessibilityLabel(L10n.shared.t("demo.autoAdvance"))

                // 设置按钮
                Button(action: { showConfig = true }) {
                    Image(systemName: "gearshape")
                        .font(.callout)
                }
                .accessibilityLabel(L10n.shared.t("demo.settings"))

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

    // MARK: - macOS 布局

    #if os(macOS)
    private var macosControlBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: Double(viewModel.currentIndex), total: Double(max(viewModel.totalSteps, 1)))
                .padding(.horizontal, 16)

            HStack(spacing: 10) {
                Button(action: { viewModel.stepBackward() }) {
                    Image(systemName: "backward.frame")
                }
                .disabled(!viewModel.canGoBack)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .keyboardShortcut(.space, modifiers: [])

                Button(action: { viewModel.stepForward() }) {
                    Image(systemName: "forward.frame")
                }
                .disabled(!viewModel.canGoForward)
                .keyboardShortcut(.rightArrow, modifiers: [])

                Divider().frame(height: 20)

                // 速度选择器：Menu 替代 segmented Picker（和 iOS 统一，节省空间）
                Menu {
                    ForEach(DemoSpeed.allCases) { speed in
                        Button {
                            config.demoSpeed = speed
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
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .accessibilityLabel(L10n.shared.t("demo.speed"))

                // 速度快捷键 1-4
                ForEach(Array(DemoSpeed.allCases.enumerated()), id: \.offset) { index, speed in
                    Button("") {
                        config.demoSpeed = speed
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                    .hidden()
                }

                Divider().frame(height: 20)

                Toggle(isOn: Binding(
                    get: { viewModel.isAutoAdvance },
                    set: { newValue in
                        if newValue != viewModel.isAutoAdvance {
                            viewModel.toggleAutoAdvance()
                        }
                        config.autoNextPuzzle = viewModel.isAutoAdvance
                        config.save()
                    }
                )) {
                    Image(systemName: "repeat")
                }
                .toggleStyle(.button)

                Spacer()

                // 设置按钮
                Button(action: { showConfig = true }) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(L10n.shared.t("demo.settings"))

                Button(action: onBackToList) {
                    Image(systemName: "list.bullet")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
    #endif
}

// MARK: - Config → ViewModel 同步修饰符

/// P1 fix: DemoConfig 变更即时同步到 ViewModel
/// Popover/Sheet 修改 config → onChange 写回 viewModel + save
private struct SyncConfigToViewModel: ViewModifier {
    let config: DemoConfig
    let viewModel: DemoViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: config.pauseOnCommentary) { _, newValue in
                viewModel.pauseOnCommentary = newValue
                config.save()
            }
            .onChange(of: config.showCommentary) { _, newValue in
                viewModel.showCommentary = newValue
                config.save()
            }
            .onChange(of: config.autoNextPuzzle) { _, newValue in
                viewModel.isAutoAdvance = newValue
                config.save()
            }
            .onChange(of: config.demoSpeed) { _, newValue in
                viewModel.speed = newValue
                config.save()
            }
    }
}

private extension View {
    func syncConfigToViewModel(config: DemoConfig, viewModel: DemoViewModel) -> some View {
        modifier(SyncConfigToViewModel(config: config, viewModel: viewModel))
    }
}

// MARK: - DemoConfig Popover (macOS)

#if os(macOS)
struct DemoConfigPopover: View {
    @Binding var config: DemoConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.shared.t("demo.settings"))
                .font(.headline)

            Toggle(isOn: $config.pauseOnCommentary) {
                Text(L10n.shared.t("demo.pauseOnCommentary"))
            }

            Toggle(isOn: $config.showCommentary) {
                Text(L10n.shared.t("demo.showCommentary"))
            }

            Toggle(isOn: $config.autoNextPuzzle) {
                Text(L10n.shared.t("demo.autoNextPuzzle"))
            }

            HStack {
                Text(L10n.shared.t("demo.defaultSpeed"))
                Spacer()
                Picker("", selection: $config.demoSpeed) {
                    ForEach(DemoSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
#endif

// MARK: - DemoConfig Sheet (iOS)

#if os(iOS)
struct DemoConfigSheet: View {
    @Binding var config: DemoConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Toggle(isOn: $config.pauseOnCommentary) {
                    Text(L10n.shared.t("demo.pauseOnCommentary"))
                }

                Toggle(isOn: $config.showCommentary) {
                    Text(L10n.shared.t("demo.showCommentary"))
                }

                Toggle(isOn: $config.autoNextPuzzle) {
                    Text(L10n.shared.t("demo.autoNextPuzzle"))
                }

                Picker(L10n.shared.t("demo.defaultSpeed"), selection: $config.demoSpeed) {
                    ForEach(DemoSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
            }
            .navigationTitle(L10n.shared.t("demo.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.shared.t("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
#endif
