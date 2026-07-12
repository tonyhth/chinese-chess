import SwiftUI

// MARK: - 对局信息栏

/// 漋示模式对局信息展示
/// 含步数进度 "第 3/7 步"
struct DemoInfoBar: View {
    let puzzle: Puzzle
    let viewModel: DemoViewModel

    var body: some View {
        VStack(spacing: 4) {
            // 残局名称 + 分类
            HStack {
                Text(puzzle.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(puzzle.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            // 步数进度
            HStack {
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // 难度星级
                HStack(spacing: 2) {
                    ForEach(0..<puzzle.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
