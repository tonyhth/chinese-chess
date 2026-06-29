import SwiftUI

struct ReplayView: View {
    @State private var viewModel: ReplayViewModel
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // v3.7.0 Phase 2: 导出门禁
    private var canExport: Bool {
        profile.isFeatureUnlocked(.gameRecordExport)
    }

    init(record: GameRecord, onClose: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: ReplayViewModel(record: record))
        self.onClose = onClose
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // v3.7.1 B4: 标题栏改为 HStack 布局，避免 iOS 文字重叠
            HStack(spacing: 8) {
                // 左侧：关闭按钮
                Button(l10n.t("common.close")) { close() }
                    .foregroundColor(.white)

                // 中间：标题 + vs 信息（单行截断）
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.record.title)
                        .font(.callout.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Text(viewModel.record.redPlayer.name)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.red)
                            .lineLimit(1)
                        Text("vs")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(viewModel.record.blackPlayer.name)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)

                // 右侧：分享按钮
                shareMenu
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

    // MARK: - 分享菜单

    private var shareMenu: some View {
        Menu {
            if canExport {
                Button {
                    copyPGNToClipboard()
                } label: {
                    Label(l10n.t("export.copyPGN"), systemImage: "doc.on.doc")
                }

                ShareLink(
                    item: PGNExporter.export(viewModel.record),
                    preview: SharePreview(
                        "\(viewModel.record.title).pgn",
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    Label(l10n.t("export.share"), systemImage: "square.and.arrow.up")
                }
            } else {
                Label(String(format: l10n.t("export.locked"), l10n.t("rank.hanlin")), systemImage: "lock")
            }
        } label: {
            Image(systemName: canExport ? "square.and.arrow.up" : "lock")
                .foregroundColor(.white)
        }
    }

    // MARK: - 导出操作

    private func copyPGNToClipboard() {
        let pgn = PGNExporter.export(viewModel.record)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
        #else
        UIPasteboard.general.string = pgn
        #endif
    }
}
