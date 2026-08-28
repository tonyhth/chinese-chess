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
                            viewModel.speed = speed  // P2-1: 播放中调速走临时态，不覆写持久默认
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

            // v6.2.1 修复（洪涛实机回归）：速度 Menu(NSMenu 后端)在容器宽不足时
            // label 文字整体零渲染（fixedSize 防不住；Ruby 二轮实测 VTF 死区 364-388pt、392 恢复）。
            // 双态自适应：宽态保持原样；窄态紧凑 spacing + small 控件 + 去 Spacer。
            // ⚠️ 快捷键统一移到 playbackShortcuts/speedShortcuts（ViewThatFits
            // 变体切换不丢快捷键，也避免双变体重复注册）。
            ViewThatFits(in: .horizontal) {
                // wide 变体 minWidth 400（Ruby P1：VTF 布局判定 ~364 起 vs NSMenu 渲染
                // 阈值 ~392 不对齐，364-388 死区 wide 被选中但零渲染；迫使 <~424pt 恒选
                // compact，compact 已实测 280-420 全档安全）
                controlRow(spacing: 10, compact: false)
                    .frame(minWidth: 400)
                controlRow(spacing: 6, compact: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            playbackShortcuts
            speedShortcuts
        }
        .background(.bar)
    }

    /// 播放快捷键（←/空格/→），统一承载不随变体丢夫
    @ViewBuilder
    private var playbackShortcuts: some View {
        Button("") { viewModel.stepBackward() }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .hidden()
        Button("") { viewModel.togglePlay() }
            .keyboardShortcut(.space, modifiers: [])
            .hidden()
        Button("") { viewModel.stepForward() }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .hidden()
    }

    /// 速度快捷键 1-4，统一承载不随变体丢夫
    @ViewBuilder
    private var speedShortcuts: some View {
        ForEach(Array(DemoSpeed.allCases.enumerated()), id: \.offset) { index, speed in
            Button("") {
                viewModel.speed = speed  // P2-1: 快捷键调速同走临时态
            }
            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
            .hidden()
        }
    }

    /// 控制条双态行（宽态 spacing 10 / 窄态 spacing 6 + .small + 去 Spacer）
    private func controlRow(spacing: CGFloat, compact: Bool) -> some View {
        HStack(spacing: spacing) {
                Button(action: { viewModel.stepBackward() }) {
                    Image(systemName: "backward.frame")
                }
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }

                Button(action: { viewModel.stepForward() }) {
                    Image(systemName: "forward.frame")
                }
                .disabled(!viewModel.canGoForward)

                Divider().frame(height: 20)

                // 速度选择器：Menu 替代 segmented Picker（和 iOS 统一，节省空间）
                Menu {
                    ForEach(DemoSpeed.allCases) { speed in
                        Button {
                            viewModel.speed = speed  // P2-1: 播放中调速走临时态，不覆写持久默认
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
                    .padding(.horizontal, compact ? 4 : 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .accessibilityLabel(L10n.shared.t("demo.speed"))

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

                if !compact {
                    Spacer()
                }

                // 设置按钮
                Button(action: { showConfig = true }) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(L10n.shared.t("demo.settings"))

                Button(action: onBackToList) {
                    Image(systemName: "list.bullet")
                }
            }
            .controlSize(compact ? .small : .regular)
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
            .onChange(of: config.smartCommentaryEnabled) { _, newValue in
                viewModel.smartCommentaryEnabled = newValue
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

            Toggle(isOn: $config.smartCommentaryEnabled) {
                Text(L10n.shared.t("demo.smartCommentary"))
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

                Toggle(isOn: $config.smartCommentaryEnabled) {
                    Text(L10n.shared.t("demo.smartCommentary"))
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
