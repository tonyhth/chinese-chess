import SwiftUI

struct ReplayView: View {
    @State private var viewModel: ReplayViewModel
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil

    // v3.7.1 C3: FEN 显示开关
    @State private var showFEN = false
    private let l10n = L10n.shared
    // v3.7.1 C4: 重命名状态
    @State private var showRenameAlert = false
    @State private var renameText = ""
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
                    Text(viewModel.displayTitle)
                        .font(.callout.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        // C4: 长按重命名
                        .onLongPressGesture {
                            renameText = viewModel.record.title
                            showRenameAlert = true
                        }
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

            // v3.7.1 C3: 可折叠 FEN 显示
            VStack(spacing: 4) {
                Button {
                    withAnimation { showFEN.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showFEN ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text("FEN")
                            .font(.caption2.weight(.medium))
                        Spacer()
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                }
                if showFEN {
                    Text(FENParser.generate(board: viewModel.board))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .textSelection(.enabled)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 2)
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
        // C4: 重命名弹窗
        .alert(l10n.t("history.rename"), isPresented: $showRenameAlert) {
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(l10n.t("common.ok")) {
                guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                viewModel.rename(renameText.trimmingCharacters(in: .whitespaces))
            }
            TextField(l10n.t("history.rename"), text: $renameText)
        }
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
