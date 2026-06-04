import SwiftUI

struct ReplayView: View {
    @State private var viewModel: ReplayViewModel
    @Environment(\.dismiss) private var dismiss

    init(record: GameRecord) {
        self._viewModel = State(initialValue: ReplayViewModel(record: record))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button("关闭") { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Text(viewModel.record.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                // 对局信息
                HStack(spacing: 4) {
                    Text("红 \(viewModel.record.redPlayer.name)")
                        .foregroundColor(.red)
                    Text("vs")
                        .foregroundColor(.gray)
                    Text(viewModel.record.blackPlayer.name)
                        .foregroundColor(.white)
                }
                .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))

            // 棋盘
            ChessBoardView(mode: .replay(viewModel))
                .padding()

            // 回放控制条
            ReplayControlView(viewModel: viewModel)
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
    }
}
