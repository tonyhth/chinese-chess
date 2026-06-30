import SwiftUI
import UniformTypeIdentifiers

struct GameHistoryView: View {
    @State private var summaries: [RecordSummary] = []
    @State private var showClearAlert = false
    @State private var showCorruptAlert = false
    @State private var showExportResultAlert = false
    @State private var exportResultText = ""
    // v3.7.0 Phase 3: 重命名
    @State private var showRenameAlert = false
    @State private var renameTargetID: UUID?
    @State private var renameText = ""
    // v3.7.0 Phase 3: 导入（改造为 ImportViewModel）
    @State private var importViewModel = ImportViewModel()
    @State private var showFileImporter = false
    // v3.7.0 Phase 2: 多选模式
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    // v3.7.1 A2: 搜索
    @State private var searchText = ""

    var onReplayRequest: ((GameRecord) -> Void)?

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile
    private let store = GameRecordStore.shared

    // v3.7.0 Phase 2: 导出门禁
    private var canExport: Bool {
        profile.isFeatureUnlocked(.gameRecordExport)
    }

    // v3.7.1 A2: 搜索过滤
    private var filteredSummaries: [RecordSummary] {
        if searchText.isEmpty {
            return summaries
        }
        return summaries.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(selection: isSelectMode ? $selectedIDs : nil) {
            if filteredSummaries.isEmpty {
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
                ForEach(filteredSummaries) { summary in
                    GameHistorySummaryRow(summary: summary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelectMode {
                                toggleSelection(summary.id)
                            } else {
                                // P1-1: 从 GameRecordStore 按需加载完整记录
                                if let record = store.loadRecord(id: summary.id) {
                                    onReplayRequest?(record)
                                } else {
                                    showCorruptAlert = true
                                }
                            }
                        }
                        #if os(macOS)
                        .contextMenu {
                            Button {
                                startRename(summary)
                            } label: {
                                Label(l10n.t("history.rename"), systemImage: "pencil")
                            }

                            Button {
                                copyPGNToClipboard(summary.id)
                            } label: {
                                Label(l10n.t("export.copyPGN"), systemImage: "doc.on.doc")
                            }
                            .disabled(!canExport)

                            if let record = store.loadRecord(id: summary.id) {
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
                            }

                            Divider()

                            Button(l10n.t("common.delete"), role: .destructive) {
                                deleteRecord(summary.id)
                            }
                        }
                        #else
                        .contextMenu {
                            Button {
                                startRename(summary)
                            } label: {
                                Label(l10n.t("history.rename"), systemImage: "pencil")
                            }

                            Button {
                                copyPGNToClipboard(summary.id)
                            } label: {
                                Label(l10n.t("export.copyPGN"), systemImage: "doc.on.doc")
                            }
                            .disabled(!canExport)

                            // C1: iOS 分享（复制到剪贴板 + 提示，避免 ShareLink 不稳定）
                            Button {
                                shareRecordOnIOS(summary.id)
                            } label: {
                                Label(l10n.t("export.share"), systemImage: "square.and.arrow.up")
                            }
                            .disabled(!canExport)

                            Divider()

                            Button(l10n.t("common.delete"), role: .destructive) {
                                deleteRecord(summary.id)
                            }
                        }
                        #endif
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(summary.id)
                            } label: {
                                Label(l10n.t("common.delete"), systemImage: "trash")
                            }
                        }
                        // v3.7.0 Phase 2: 左滑分享按钮
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                copyPGNToClipboard(summary.id)
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
        .searchable(text: $searchText, prompt: l10n.t("history.searchPlaceholder"))
        .onAppear {
            reloadSummaries()
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
                        Button {
                            exportSelectedAndReport()
                        } label: {
                            Label(l10n.t("export.copyPGN"), systemImage: "doc.on.doc")
                        }
                    }

                    if !selectedIDs.isEmpty {
                        Button(l10n.t("common.delete"), role: .destructive) {
                            deleteSelectedRecords()
                        }
                    }
                } else {
                    if !summaries.isEmpty {
                        Button(l10n.t("history.clear"), role: .destructive) {
                            showClearAlert = true
                        }
                    }

                    Spacer()

                    // v3.7.0 Phase 3: 导入入口（粘贴 PGN）
                    Button {
                        importFromClipboard()
                    } label: {
                        Image(systemName: "plus")
                    }

                    // v3.7.0 Phase 2: 多选按钮
                    if !summaries.isEmpty {
                        Button(l10n.t("history.select")) {
                            isSelectMode = true
                        }
                    }
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                if !summaries.isEmpty {
                    Button(l10n.t("history.clear"), role: .destructive) {
                        showClearAlert = true
                    }
                }
                // v3.7.1 Phase 3A: 导入入口（Menu：粘贴 + 文件导入）
                Menu {
                    Button {
                        importFromClipboard()
                    } label: {
                        Label(l10n.t("import.pastePGN"), systemImage: "doc.on.clipboard")
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(l10n.t("import.fromFile"), systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "plus")
                }

                // v3.7.0 Phase 2: 多选按钮
                if !summaries.isEmpty {
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
                store.clearAll()
                reloadSummaries()
            }
        } message: {
            Text(l10n.t("history.clearConfirm"))
        }
        // P1-1: 记录损坏提示
        .alert(l10n.t("history.corruptTitle"), isPresented: $showCorruptAlert) {
            Button(l10n.t("common.ok"), role: .cancel) {}
        } message: {
            Text(l10n.t("history.corruptMessage"))
        }
        // P1-2: 导出部分失败提示
        .alert(l10n.t("export.resultTitle"), isPresented: $showExportResultAlert) {
            Button(l10n.t("common.ok"), role: .cancel) {}
        } message: {
            Text(exportResultText)
        }
        // v3.7.0 Phase 3: 重命名弹窗
        .alert(l10n.t("history.rename"), isPresented: $showRenameAlert) {
            TextField(l10n.t("history.title"), text: $renameText)
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(l10n.t("common.done")) {
                guard let id = renameTargetID, var record = store.loadRecord(id: id) else { return }
                record.title = renameText
                store.updateRecord(record)
                reloadSummaries()
            }
        }
        // v3.7.1 Phase 3A: 导入结果 sheet（用 .sheet(item:) 避免空白 sheet）
        .sheet(item: Binding<ImportResult?>(
            get: {
                if case .success(let result) = importViewModel.state {
                    return result
                }
                return nil
            },
            set: { _ in }
        )) { result in
            ImportResultSheet(
                result: result,
                onConfirm: { importViewModel.confirmImport() },
                onCancel: { importViewModel.reset() }
            )
        }
        // v3.7.1 Phase 3A: 导入失败 alert
        .alert(l10n.t("import.resultTitle"), isPresented: Binding(
            get: { if case .failure = importViewModel.state { return true } else { return false } },
            set: { if !$0 { importViewModel.reset() } }
        )) {
            Button(l10n.t("common.ok"), role: .cancel) { importViewModel.reset() }
        } message: {
            if case .failure(let msg) = importViewModel.state {
                Text(msg)
            }
        }
        // v3.7.1 Phase 3A: 文件导入
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: {
                if let pgnType = UTType(filenameExtension: "pgn") {
                    return [pgnType]
                } else {
                    return [UTType.plainText]
                }
            }(),
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let text = try? String(contentsOf: url, encoding: .utf8) {
                        importViewModel.parse(pgnText: text)
                    }
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - 操作

    private func reloadSummaries() {
        store.reloadSummaries()
        summaries = store.loadSummaries()
    }

    private func deleteRecord(_ id: UUID) {
        store.deleteRecord(id: id)
        reloadSummaries()
    }

    // v3.7.0 Phase 2: 复制 PGN 到剪贴板
    private func copyPGNToClipboard(_ id: UUID) {
        guard canExport, let record = store.loadRecord(id: id) else { return }
        let pgn = PGNExporter.export(record)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
        #else
        UIPasteboard.general.string = pgn
        #endif
    }

    // C1: iOS 分享（复制 + 提示）
    private func shareRecordOnIOS(_ id: UUID) {
        guard canExport, let record = store.loadRecord(id: id) else { return }
        let pgn = PGNExporter.export(record)
        #if os(iOS)
        UIPasteboard.general.string = pgn
        exportResultText = String(format: l10n.t("export.copiedN"), 1)
        showExportResultAlert = true
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
        let selectedRecords = selectedIDs.compactMap { store.loadRecord(id: $0) }
        return PGNExporter.exportBatch(selectedRecords)
    }

    // P1-2: 导出后统计成功/失败数，不一致时提示
    // v3.7.1 A3: iOS 降级为剪贴板复制 + 提示
    private func exportSelectedAndReport() {
        let total = selectedIDs.count
        let selectedRecords = selectedIDs.compactMap { store.loadRecord(id: $0) }
        let successCount = selectedRecords.count
        let failCount = total - successCount

        let pgn = PGNExporter.exportBatch(selectedRecords)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
        #else
        UIPasteboard.general.string = pgn
        #endif

        if failCount > 0 {
            exportResultText = String(format: l10n.t("export.partialFail"), successCount, failCount)
            showExportResultAlert = true
        } else {
            exportResultText = String(format: l10n.t("export.copiedN"), successCount)
            showExportResultAlert = true
        }
    }

    private func deleteSelectedRecords() {
        for id in selectedIDs {
            store.deleteRecord(id: id)
        }
        selectedIDs.removeAll()
        reloadSummaries()
    }

    // MARK: - v3.7.0 Phase 3: 导入

    private func importFromClipboard() {
        #if os(macOS)
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            importViewModel.fail(l10n.t("import.emptyClipboard"))
            return
        }
        #else
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            importViewModel.fail(l10n.t("import.emptyClipboard"))
            return
        }
        #endif
        importViewModel.parse(pgnText: text)
    }

    // MARK: - v3.7.0 Phase 3: 重命名

    private func startRename(_ summary: RecordSummary) {
        renameTargetID = summary.id
        renameText = summary.title
        showRenameAlert = true
    }
}

// MARK: - 历史对局摘要行（基于 RecordSummary，无需全量加载）

struct GameHistorySummaryRow: View {
    let summary: RecordSummary
    private let l10n = L10n.shared

    var body: some View {
        HStack(spacing: 12) {
            // 来源图标
            sourceIcon
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(summary.title)
                    .font(.headline)

                // 详细信息
                HStack(spacing: 8) {
                    Text(resultText)
                        .foregroundColor(resultColor)
                        .font(.subheadline)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(String(format: l10n.t("history.moveCount"), summary.totalMoves))
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(summary.difficulty?.displayName ?? "–")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    // v3.7.0 Phase 2: 来源标签
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(sourceText)
                        .foregroundColor(.secondary.opacity(0.8))
                        .font(.caption2)
                }

                // 日期
                Text(formatDate(summary.date))
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

    // MARK: - 来源图标

    private var sourceIcon: some View {
        switch summary.source {
        case .versusAI:
            return Image(systemName: "sword.fill")
                .foregroundColor(.orange)
        case .puzzle:
            return Image(systemName: "puzzlepiece.fill")
                .foregroundColor(.purple)
        case .imported:
            return Image(systemName: "arrow.down.doc.fill")
                .foregroundColor(.blue)
        case .freePlay:
            return Image(systemName: "person.2.fill")
                .foregroundColor(.green)
        }
    }

    // MARK: - 来源文本

    private var sourceText: String {
        switch summary.source {
        case .versusAI: return l10n.t("source.versusAI")
        case .puzzle:   return l10n.t("source.puzzle")
        case .imported: return l10n.t("source.imported")
        case .freePlay: return l10n.t("source.freePlay")
        }
    }

    // MARK: - 结果显示

    private var resultIcon: some View {
        switch summary.result {
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
        switch summary.result {
        case .redWon: return l10n.t("result.redWon")
        case .blackWon: return l10n.t("result.blackWon")
        case .draw: return l10n.t("result.draw")
        case .playing: return l10n.t("result.playing")
        }
    }

    private var resultColor: Color {
        switch summary.result {
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
