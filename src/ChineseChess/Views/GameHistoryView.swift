import SwiftUI

struct GameHistoryView: View {
    @State private var records: [GameRecord] = []
    @State private var showReplay = false
    @State private var replayRecord: GameRecord?
    @State private var showClearAlert = false

    var body: some View {
        List {
            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(String(localized: "history.empty"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(records) { record in
                    GameHistoryRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            replayRecord = record
                            showReplay = true
                        }
                        #if os(macOS)
                        .contextMenu {
                            Button(String(localized: "common.delete"), role: .destructive) {
                                deleteRecord(record)
                            }
                        }
                        #endif
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(record)
                            } label: {
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(String(localized: "history.title"))
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
                    Button(String(localized: "history.clear"), role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                if !records.isEmpty {
                    Button(String(localized: "history.clear"), role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
            #endif
        }
        .alert(String(localized: "history.clear"), isPresented: $showClearAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.clear"), role: .destructive) {
                GameHistoryStore.shared.clearAll()
                reloadRecords()
            }
        } message: {
            Text(String(localized: "history.clearConfirm"))
        }
        .sheet(isPresented: $showReplay) {
            if let record = replayRecord {
                #if os(iOS)
                NavigationStack {
                    ReplayView(record: record)
                        .navigationTitle(String(localized: "replay.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { showReplay = false }
                            }
                        }
                }
                #else
                ReplayView(record: record)
                    .frame(minWidth: 600, minHeight: 720)
                #endif
            }
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

                    Text(String(localized: "history.moveCount", defaultValue: "\(record.totalMoves) 步"))
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
        case .redWon: return String(localized: "result.redWon")
        case .blackWon: return String(localized: "result.blackWon")
        case .draw: return String(localized: "result.draw")
        case .playing: return String(localized: "result.playing")
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
        case .beginner: return String(localized: "difficulty.beginner")
        case .easy: return String(localized: "difficulty.easy")
        case .medium: return String(localized: "difficulty.medium")
        case .hard: return String(localized: "difficulty.hard")
        case .master: return String(localized: "difficulty.master")
        }
    }
}
