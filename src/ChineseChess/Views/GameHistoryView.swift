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
                        .foregroundColor(.gray)
                    Text("暂无历史对局")
                        .foregroundColor(.gray)
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
                            Button("删除", role: .destructive) {
                                deleteRecord(record)
                            }
                        }
                        #endif
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("历史对局")
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
                    Button("清空历史", role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                if !records.isEmpty {
                    Button("清空历史", role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
            #endif
        }
        .alert("清空历史", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                GameHistoryStore.shared.clearAll()
                reloadRecords()
            }
        } message: {
            Text("确定要清空所有历史对局吗？此操作不可恢复。")
        }
        .sheet(isPresented: $showReplay) {
            if let record = replayRecord {
                #if os(iOS)
                NavigationStack {
                    ReplayView(record: record)
                        .navigationTitle("对局回放")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showReplay = false }
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
                        .foregroundColor(.gray)

                    Text("\(record.totalMoves) 步")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    Text("·")
                        .foregroundColor(.gray)

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
                .foregroundColor(.gray)
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
                .foregroundColor(.gray)
        case .playing:
            return Image(systemName: "questionmark.circle")
                .foregroundColor(.gray)
        }
    }

    private var resultText: String {
        switch record.result {
        case .redWon: return "红方胜"
        case .blackWon: return "黑方胜"
        case .draw: return "和棋"
        case .playing: return "进行中"
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
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - AIDifficulty 扩展

extension AIDifficulty {
    var displayName: String {
        switch self {
        case .beginner: return "新手"
        case .easy: return "初级"
        case .medium: return "中级"
        case .hard: return "高级"
        case .master: return "大师"
        }
    }
}
