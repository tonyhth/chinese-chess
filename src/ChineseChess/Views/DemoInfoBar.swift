import SwiftUI

// MARK: - 对局信息栏

/// 演示模式对局信息展示
/// 支持 DemoItemWrapper（残局 + 大师棋谱）
struct DemoInfoBar: View {
    let item: DemoItemWrapper
    let viewModel: DemoViewModel
    var onBackToList: (() -> Void)? = nil

    var body: some View {
        #if os(iOS)
        iosInfoBar
        #else
        macosInfoBar
        #endif
    }

    // MARK: - iOS 布局（左侧返回按钮 + 标题）

    #if os(iOS)
    private var iosInfoBar: some View {
        VStack(spacing: 4) {
            // 标题 + 返回 + 分类
            HStack(spacing: 8) {
                // 返回按钮（主入口，返回列表）
                if let onBack = onBackToList {
                    Button(action: onBack) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                            Text(item.demoTitle)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel(L10n.shared.t("demo.backToList"))
                } else {
                    Text(item.demoTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                Text(item.demoCategory)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            // 副标题 + 步数进度
            HStack {
                Text(item.demoSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(viewModel.progressText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    #endif

    // MARK: - macOS 布局（不变）

    #if os(macOS)
    private var macosInfoBar: some View {
        HStack(spacing: 8) {
            Text(item.demoTitle)
                .font(.headline)
                .lineLimit(1)

            Text(item.demoCategory)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            Text(item.demoSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(viewModel.progressText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    #endif
}
