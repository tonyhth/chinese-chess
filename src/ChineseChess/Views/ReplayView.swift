import SwiftUI

struct ReplayView: View {
    @State private var viewModel: ReplayViewModel
    @Environment(\.dismiss) private var dismiss

    init(record: GameRecord) {
        self._viewModel = State(initialValue: ReplayViewModel(record: record))
    }

    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏：仅保留返回按钮和标题
            HStack {
                Button(l10n.t("common.close")) { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Text(l10n.t("replay.title"))
                    .font(.callout.weight(.bold))
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
                Text(String(format: l10n.t("replay.vsFormat"), viewModel.record.redPlayer.name))
                    .foregroundColor(.red)
                Text("vs")
                    .foregroundColor(.gray)
                Text(viewModel.record.blackPlayer.name)
                    .foregroundColor(.white)
            }
            .font(.subheadline)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255).opacity(0.6))

            // 棋盘（与对弈页面保持一致布局）
            ReplayBoardView(viewModel: viewModel)
                .layoutPriority(1)

            // 回放控制条
            ReplayControlView(viewModel: viewModel)
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
    }
}
