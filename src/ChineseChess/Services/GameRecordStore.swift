import Foundation

// MARK: - 记录摘要（列表展示用，避免全量加载）

struct RecordSummary: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let result: GameState
    let totalMoves: Int
    let difficulty: AIDifficulty
    let source: RecordSource

    init(from record: GameRecord) {
        self.id = record.id
        self.title = record.title
        self.date = record.date
        self.result = record.result
        self.totalMoves = record.totalMoves
        self.difficulty = record.difficulty
        self.source = record.source
    }
}

// MARK: - 新存储引擎（替代 GameHistoryStore）

/// 基于 JSON 文件存储，替代 UserDefaults 方案
/// - 路径：Documents/GameRecords/index.json + {uuid}.json
/// - 线程安全：串行写入队列
/// - 原子写入：先写 .tmp 临时文件再 rename
/// - id 去重：addRecord 中检查 summaries
final class GameRecordStore {
    static let shared = GameRecordStore()

    private let fileManager = FileManager.default
    let baseURL: URL           // Documents/GameRecords/
    private let indexURL: URL  // Documents/GameRecords/index.json

    /// 内存缓存：列表展示用摘要
    private(set) var summaries: [RecordSummary] = []

    /// 串行写入队列，防止并发写坏文件
    private let writeQueue = DispatchQueue(label: "com.chinesechess.recordstore", qos: .userInitiated)

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseURL = docs.appendingPathComponent("GameRecords", isDirectory: true)
        indexURL = baseURL.appendingPathComponent("index.json")

        // 确保目录存在
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)

        // 启动时加载摘要
        loadSummariesFromDisk()
    }

    // MARK: - 读取

    /// 全部记录摘要（列表展示用，从内存缓存读取）
    func loadSummaries() -> [RecordSummary] {
        return summaries
    }

    /// 从磁盘重新加载摘要到内存
    func reloadSummaries() {
        loadSummariesFromDisk()
    }

    /// 加载完整记录（按需加载，避免内存占用）
    func loadRecord(id: UUID) -> GameRecord? {
        let fileURL = baseURL.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GameRecord.self, from: data)
    }

    /// 记录数量
    var count: Int { summaries.count }

    // MARK: - 写入（线程安全 + 去重 + 原子写入）

    /// 添加记录（自动去重，新记录插入最前面）
    func addRecord(_ record: GameRecord) {
        writeQueue.sync {
            // id 去重：同 id 不重复写入
            guard !summaries.contains(where: { $0.id == record.id }) else { return }

            // 1. 写入单条文件（原子写入：先写临时文件再 rename）
            let fileURL = baseURL.appendingPathComponent("\(record.id.uuidString).json")
            let tmpURL = baseURL.appendingPathComponent("\(record.id.uuidString).tmp")
            do {
                let data = try JSONEncoder().encode(record)
                try data.write(to: tmpURL, options: .atomic)
                // 如果目标文件已存在，先删除
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            } catch {
                #if DEBUG
                AppLog.history.error("failed to write record \(record.id): \(error)")
                #endif
                return
            }

            // 2. 更新内存摘要（新记录插入最前面，按日期倒序）
            summaries.insert(RecordSummary(from: record), at: 0)

            // 3. 更新 index.json
            persistIndex()
        }
    }

    /// 更新记录（改标题/标签等）
    func updateRecord(_ record: GameRecord) {
        writeQueue.sync {
            // 1. 覆写单条文件（原子写入）
            let fileURL = baseURL.appendingPathComponent("\(record.id.uuidString).json")
            let tmpURL = baseURL.appendingPathComponent("\(record.id.uuidString).tmp")
            do {
                let data = try JSONEncoder().encode(record)
                try data.write(to: tmpURL, options: .atomic)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            } catch {
                #if DEBUG
                AppLog.history.error("failed to update record \(record.id): \(error)")
                #endif
                return
            }

            // 2. 更新内存摘要
            if let idx = summaries.firstIndex(where: { $0.id == record.id }) {
                summaries[idx] = RecordSummary(from: record)
            }

            // 3. 更新 index.json
            persistIndex()
        }
    }

    /// 删除记录
    func deleteRecord(id: UUID) {
        writeQueue.sync {
            // 1. 删除单条文件
            let fileURL = baseURL.appendingPathComponent("\(id.uuidString).json")
            try? fileManager.removeItem(at: fileURL)

            // 2. 更新内存摘要
            summaries.removeAll { $0.id == id }

            // 3. 更新 index.json
            persistIndex()
        }
    }

    /// 清空全部
    func clearAll() {
        writeQueue.sync {
            // 1. 删除所有 .json 文件（不删除 .tmp 等）
            for summary in summaries {
                let fileURL = baseURL.appendingPathComponent("\(summary.id.uuidString).json")
                try? fileManager.removeItem(at: fileURL)
            }
            summaries = []
            persistIndex()
        }
    }

    // MARK: - 内部

    /// 从磁盘加载摘要到内存
    private func loadSummariesFromDisk() {
        guard let data = try? Data(contentsOf: indexURL),
              let loaded = try? JSONDecoder().decode([RecordSummary].self, from: data) else {
            summaries = []
            return
        }
        summaries = loaded
    }

    /// 持久化 index.json（原子写入：先写临时文件再 rename）
    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        let tmpURL = baseURL.appendingPathComponent("index.tmp")
        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: indexURL.path) {
                try fileManager.removeItem(at: indexURL)
            }
            try fileManager.moveItem(at: tmpURL, to: indexURL)
        } catch {
            #if DEBUG
            AppLog.history.error("failed to persist index: \(error)")
            #endif
        }
    }
}
