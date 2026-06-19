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
            // 标题栏 + 对局信息（ZStack 标题居中，信息左对齐）
            ZStack {
                // 居中标题
                Text(l10n.t("replay.title"))
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)

                // 左侧：关闭按钮 + 对局信息
                HStack {
                    Button(l10n.t("common.close")) { dismiss() }
                        .foregroundColor(.white)
                    Spacer().frame(width: 12)
                    Text(String(format: l10n.t("replay.vsFormat"), viewModel.record.redPlayer.name))
                        .font(.caption.weight(.medium))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(" vs")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(viewModel.record.blackPlayer.name)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))

            // 棋盘（与对弈页面保持一致布局）
            if viewModel.record.moves.isEmpty {
                Spacer()
                Text(l10n.t("replay.empty"))
                    .foregroundColor(.gray)
                    .font(.title3)
                Spacer()
            } else {
                ReplayBoardView(viewModel: viewModel)
                    .layoutPriority(1)
            }

            // 回放控制条
            ReplayControlView(viewModel: viewModel)
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
    }
}
