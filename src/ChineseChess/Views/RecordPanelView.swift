import SwiftUI

struct RecordPanelView: View {
    // ViewModel 引用（对弈模式）：@Observable 对象，sheet 内 SwiftUI 追踪变化
    private let _viewModel: GameViewModel?
    // 静态棋步（残局模式）：不在 sheet 中，无刷新问题
    private let _staticGameMoves: [GameMove]

    @Environment(L10n.self) private var l10n

    /// 对弈模式：传入 viewModel，sheet 内自动追踪 gameMoves 变化
    init(viewModel: GameViewModel) {
        self._viewModel = viewModel
        self._staticGameMoves = []
    }

    /// 残局模式：传入静态 gameMoves（不在 sheet 中，无刷新问题）
    init(gameMoves: [GameMove]) {
        self._viewModel = nil
        self._staticGameMoves = gameMoves
    }

    /// 当前棋步列表：优先从 viewModel 实时读取，否则使用静态快照
    private var gameMoves: [GameMove] {
        _viewModel?.gameMoves ?? _staticGameMoves
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t("record.panelTitle"))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)

            if gameMoves.isEmpty {
                Text(l10n.t("record.empty"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(gameMoves) { gm in
                                moveRow(gm)
                                    .id(gm.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: gameMoves.count) { _, _ in
                        if let last = gameMoves.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func moveRow(_ gm: GameMove) -> some View {
        HStack(spacing: 4) {
            // 回合号
            Text("\(gm.turnNumber).")
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            // 棋谱
            Text(gm.notation)
                .font(.custom(FontRegistry.bestAvailableFontName, size: 13))
                .foregroundColor(gm.piece.side == .red ? .red : .white)

            // 标记
            if gm.isCheckmate {
                Text("#")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.yellow)
            } else if gm.isCheck {
                Text("+")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.yellow)
            }
        }
        .accessibilityLabel(Text(String(format: l10n.t("accessibility.stepN"), gm.turnNumber, gm.notation)))
    }
}
