import SwiftUI

struct RecordPanelView: View {
    // ViewModel 引用（对弈模式）：@Observable 对象，sheet 内 SwiftUI 追踪变化
    private let _viewModel: GameViewModel?
    // 静态棋步（残局模式）：不在 sheet 中，无刷新问题
    private let _staticGameMoves: [GameMove]
    // v3.7.0 Phase 2: 可选的导出回调
    var onExportRequest: (() -> Void)? = nil

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // v3.7.0 Phase 2: 导出门禁
    private var canExport: Bool {
        profile.isFeatureUnlocked(.gameRecordExport)
    }

    /// 对弈模式：传入 viewModel，sheet 内自动追踪 gameMoves 变化
    init(viewModel: GameViewModel, onExportRequest: (() -> Void)? = nil) {
        self._viewModel = viewModel
        self._staticGameMoves = []
        self.onExportRequest = onExportRequest
    }

    /// 残局模式：传入静态 gameMoves（不在 sheet 中，无刷新问题）
    init(gameMoves: [GameMove], onExportRequest: (() -> Void)? = nil) {
        self._viewModel = nil
        self._staticGameMoves = gameMoves
        self.onExportRequest = onExportRequest
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
                        VStack(alignment: .leading, spacing: 3) {
                            let pairs = pairMoves(gameMoves)
                            ForEach(pairs) { pair in
                                roundRow(pair)
                                    .id(pair.id)
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

                // 底部统一导出栏（从 moveText 移出）
                if let onExport = onExportRequest {
                    Divider()
                        .background(Color.white.opacity(0.2))

                    HStack {
                        Spacer()
                        if canExport {
                            Button {
                                onExport()
                            } label: {
                                Label(l10n.t("export.quick"), systemImage: "square.and.arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else {
                            Label(String(format: l10n.t("export.locked"), l10n.t("rank.hanlin")), systemImage: "lock")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(8)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(8)
    }

    // MARK: - 回合配对

    struct MovePair: Identifiable {
        let id: UUID
        let roundNumber: Int
        let first: GameMove
        let second: GameMove?
        let firstSide: Side
    }

    private func pairMoves(_ moves: [GameMove]) -> [MovePair] {
        guard !moves.isEmpty else { return [] }
        let firstSide = moves[0].piece.side
        var pairs: [MovePair] = []
        var i = 0
        var roundNum = 1
        while i < moves.count {
            let first = moves[i]
            let second = (i + 1 < moves.count) ? moves[i + 1] : nil
            pairs.append(MovePair(
                id: first.id,
                roundNumber: roundNum,
                first: first,
                second: second,
                firstSide: firstSide
            ))
            i += 2
            roundNum += 1
        }
        return pairs
    }

    @ViewBuilder
    private func roundRow(_ pair: MovePair) -> some View {
        HStack(spacing: 8) {
            // 回合号
            Text("\(pair.roundNumber).")
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)

            // 黑方先手前缀
            if pair.firstSide == .black {
                Text("……")
                    .font(.footnote.monospaced())
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }

            moveText(pair.first)

            Spacer().frame(width: 12)

            // 后手方走法（如有）
            if let second = pair.second {
                moveText(second)
            }
        }
        .accessibilityLabel(Text(String(format: l10n.t("accessibility.stepN"), pair.roundNumber, pair.first.notation + (pair.second != nil ? " " + pair.second!.notation : ""))))
    }

    @ViewBuilder
    private func moveText(_ gm: GameMove) -> some View {
        HStack(spacing: 1) {
            Text(gm.notation)
                .font(.custom(FontRegistry.bestAvailableFontName, size: 14))
                .foregroundColor(gm.piece.side == .red ? .red : .white)
            if gm.isCheckmate || gm.isCheck {
                Text(gm.isCheckmate ? "#" : "+")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.yellow)
            }
        }
    }
}
