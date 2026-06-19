import SwiftUI

struct GameHistoryView: View {
    @State private var records: [GameRecord] = []
    @State private var showClearAlert = false

    var onReplayRequest: ((GameRecord) -> Void)?

    private let l10n = L10n.shared

    var body: some View {
        List {
            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(l10n.t("history.empty"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(records) { record in
                    GameHistoryRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onReplayRequest?(record)
                        }
                        #if os(macOS)
                        .contextMenu {
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
            ToolbarItem(placement: .bottomBar) {
                if !records.isEmpty {
                    Button(l10n.t("history.clear"), role: .destructive) {
                        showClearAlert = true
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

    private func reloadRecords() {
        records = GameHistoryStore.shared.records
    }

    private func deleteRecord(_ record: GameRecord) {
        GameHistoryStore.shared.deleteRecord(id: record.id)
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
