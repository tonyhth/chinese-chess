import SwiftUI

struct ReplayView: View {
    @State private var viewModel: ReplayViewModel
    @Environment(\.dismiss) private var dismiss

    init(record: GameRecord) {
        self._viewModel = State(initialValue: ReplayViewModel(record: record))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏：仅保留返回按钮和标题
            HStack {
                Button(String(localized: "common.close")) { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Text(String(localized: "replay.title"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                // 占位保持居中
                Color.clear.frame(width: 44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))

            // 对局信息：独立区域
            HStack(spacing: 4) {
                Text(String(localized: "replay.vsFormat", defaultValue: "红 \(viewModel.record.redPlayer.name)"))
                    .foregroundColor(.red)
                Text("vs")
                    .foregroundColor(.gray)
                Text(viewModel.record.blackPlayer.name)
                    .foregroundColor(.white)
            }
            .font(.system(size: 13))
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255).opacity(0.6))

            // 棋盘（优先占据空间）
            ZStack {
                ChessBoardView(mode: .replay(viewModel))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 280)
                    .layoutPriority(1)
                    .padding()

                // 空步数提示
                if viewModel.record.moves.isEmpty {
                    Text(String(localized: "replay.empty"))
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }

            // 回放控制条
            ReplayControlView(viewModel: viewModel)
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
    }
}
