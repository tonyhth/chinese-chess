import SwiftUI

// MARK: - 对局信息栏

/// 演示模式对局信息展示
/// 支持 DemoItemWrapper（残局 + 大师棋谱）
struct DemoInfoBar: View {
    let item: DemoItemWrapper
    let viewModel: DemoViewModel

    var body: some View {
        VStack(spacing: 4) {
            // 标题 + 分类
            HStack {
                Text(item.demoTitle)
                    .font(.headline)
                    .lineLimit(1)

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
}
