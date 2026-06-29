import SwiftUI

struct GameHistoryView: View {
    @State private var records: [GameRecord] = []
    @State private var showClearAlert = false
    // v3.7.0 Phase 2: 多选模式
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []

    var onReplayRequest: ((GameRecord) -> Void)?

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // v3.7.0 Phase 2: 导出门禁
    private var canExport: Bool {
        profile.isFeatureUnlocked(.gameRecordExport)
    }

    var body: some View {
        List(selection: isSelectMode ? $selectedIDs : nil) {
            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(l10n.t("history.empty"))
                        .foregroundColor(.secondary)
                    Text(l10n.t("history.empty.hint"))
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(records) { record in
                    GameHistoryRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelectMode {
                                toggleSelection(record.id)
                            } else {
                                onReplayRequest?(record)
                            }
                        }
                        #if os(macOS)
                        .contextMenu {
                            Button {
                                copyPGNToClipboard(record)
                            } label: {
                                Label(l10n.t("export.copyPGN"), systemImage: "doc.on.doc")
                            }
                            .disabled(!canExport)

                            ShareLink(
                                item: PGNExporter.export(record),
                                preview: SharePreview(
                                    "\(record.title).pgn",
                                    image: Image(systemName: "doc.text")
                                )
                            ) {
                                Label(l10n.t("export.share"), systemImage: "square.and.arrow.up")
                            }
                            .disabled(!canExport)

                            Divider()

                            Button(l10n.t("common.delete"), role: .destructive) {
                                deleteRecord(record)
                            }
                        }
                        #endif
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(record)
                            } label: {
                                Label(l10n.t("common.delete"), systemImage: "trash")
                            }
                        }
                        // v3.7.0 Phase 2: 左滑分享按钮
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                copyPGNToClipboard(record)
                            } label: {
                                Label(l10n.t("export.share"), systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                            .disabled(!canExport)
                        }
                }
            }
        }
        .navigationTitle(l10n.t("history.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            reloadRecords()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .bottomBar) {
                if isSelectMode {
                    // 多选模式工具栏
                    Button(l10n.t("common.cancel")) {
                        exitSelectMode()
                    }

                    Spacer()

                    if canExport && !selectedIDs.isEmpty {
                        ShareLink(
                            item: exportSelectedPGN(),
                            preview: SharePreview(
                                "棋谱.pgn",
                                image: Image(systemName: "doc.text")
                            )
                        ) {
                            Label(l10n.t("export.share"), systemImage: "square.and.arrow.up")
                        }
                    }

                    if !selectedIDs.isEmpty {
                        Button(l10n.t("common.delete"), role: .destructive) {
                            deleteSelectedRecords()
                        }
                    }
                } else {
                    if !records.isEmpty {
                        Button(l10n.t("history.clear"), role: .destructive) {
                            showClearAlert = true
                        }
                    }

                    Spacer()

                    // v3.7.0 Phase 2: 导入入口（按钮先加，逻辑 Phase 3 实现）
                    Button {
                        // Phase 3: 打开导入界面
                    } label: {
                        Image(systemName: "plus")
                    }

                    // v3.7.0 Phase 2: 多选按钮
                    if !records.isEmpty {
                        Button(l10n.t("history.select")) {
                            isSelectMode = true
                        }
                    }
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                if !records.isEmpty {
                    Button(l10n.t("history.clear"), role: .destructive) {
                        showClearAlert = true
                    }
                }
                // v3.7.0 Phase 2: 导入入口
                Button {
                    // Phase 3: 打开导入界面
                } label: {
                    Image(systemName: "plus")
                }

                // v3.7.0 Phase 2: 多选按钮
                if !records.isEmpty {
                    Button(l10n.t("history.select")) {
                        isSelectMode = true
                    }
                }
            }
            #endif
        }
        .alert(l10n.t("history.clear"), isPresented: $showClearAlert) {
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(l10n.t("common.clear"), role: .destructive) {
                GameHistoryStore.shared.clearAll()
                reloadRecords()
            }
        } message: {
            Text(l10n.t("history.clearConfirm"))
        }
    }

    // MARK: - 操作

    private func reloadRecords() {
        records = GameHistoryStore.shared.records
    }

    private func deleteRecord(_ record: GameRecord) {
        GameHistoryStore.shared.deleteRecord(id: record.id)
        reloadRecords()
    }

    // v3.7.0 Phase 2: 复制 PGN 到剪贴板
    private func copyPGNToClipboard(_ record: GameRecord) {
        guard canExport else { return }
        let pgn = PGNExporter.export(record)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
        #else
        UIPasteboard.general.string = pgn
        #endif
    }

    // v3.7.0 Phase 2: 多选操作
    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func exitSelectMode() {
        isSelectMode = false
        selectedIDs.removeAll()
    }

    private func exportSelectedPGN() -> String {
        let selected = records.filter { selectedIDs.contains($0.id) }
        return PGNExporter.exportBatch(selected)
    }

    private func deleteSelectedRecords() {
        for id in selectedIDs {
            GameHistoryStore.shared.deleteRecord(id: id)
        }
        selectedIDs.removeAll()
        reloadRecords()
    }
}

// MARK: - 历史对局行

struct GameHistoryRow: View {
    let record: GameRecord
    private let l10n = L10n.shared

    var body: some View {
        HStack(spacing: 12) {
            // 结果图标
            resultIcon
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(record.title)
                    .font(.headline)

                // 详细信息
                HStack(spacing: 8) {
                    Text(resultText)
                        .foregroundColor(resultColor)
                        .font(.subheadline)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(String(format: l10n.t("history.moveCount"), record.totalMoves))
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(record.difficulty.displayName)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                // 日期
                Text(formatDate(record.date))
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 结果显示

    private var resultIcon: some View {
        switch record.result {
        case .redWon:
            return Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)
        case .blackWon:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .draw:
            return Image(systemName: "equal.circle.fill")
                .foregroundColor(.secondary)
        case .playing:
            return Image(systemName: "questionmark.circle")
                .foregroundColor(.secondary)
        }
    }

    private var resultText: String {
        switch record.result {
        case .redWon: return l10n.t("result.redWon")
        case .blackWon: return l10n.t("result.blackWon")
        case .draw: return l10n.t("result.draw")
        case .playing: return l10n.t("result.playing")
        }
    }

    private var resultColor: Color {
        switch record.result {
        case .redWon: return .green
        case .blackWon: return .red
        case .draw: return .gray
        case .playing: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - AIDifficulty 扩展

extension AIDifficulty {
    var displayName: String {
        switch self {
        case .beginner: return L10n.shared.t("difficulty.beginner")
        case .easy: return L10n.shared.t("difficulty.easy")
        case .medium: return L10n.shared.t("difficulty.medium")
        case .hard: return L10n.shared.t("difficulty.hard")
        case .master: return L10n.shared.t("difficulty.master")
        }
    }
}
