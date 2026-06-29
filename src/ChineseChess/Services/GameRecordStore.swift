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
/// - 原子写入：Data.write(to:options:.atomic) 本身即原子操作
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

        // P1-5: 启动时一致性校验（发现孤立文件时 reconcil）
        reconcileOrphanFiles()
    }

    /// 测试用初始化器（指定 baseURL，避免污染真实数据）
    init(baseURL: URL) {
        self.baseURL = baseURL
        indexURL = baseURL.appendingPathComponent("index.json")

        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        loadSummariesFromDisk()
        reconcileOrphanFiles()
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

            // 1. 写入单条文件（P1-4: .atomic 本身即原子操作，无需双重间接）
            let fileURL = baseURL.appendingPathComponent("\(record.id.uuidString).json")
            do {
                let data = try JSONEncoder().encode(record)
                try data.write(to: fileURL, options: .atomic)
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
            // 1. 覆写单条文件（P1-4: .atomic 本身即原子操作）
            let fileURL = baseURL.appendingPathComponent("\(record.id.uuidString).json")
            do {
                let data = try JSONEncoder().encode(record)
                try data.write(to: fileURL, options: .atomic)
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

    /// 持久化 index.json（P1-4: .atomic 本身即原子操作）
    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        do {
            try data.write(to: indexURL, options: .atomic)
        } catch {
            #if DEBUG
            AppLog.history.error("failed to persist index: \(error)")
            #endif
        }
    }

    /// P1-5: 启动时一致性校验 — 扫描目录发现孤立文件，补充到 index
    private func reconcileOrphanFiles() {
        let indexedIDs = Set(summaries.map { $0.id })

        guard let files = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else {
            return
        }

        var orphans: [RecordSummary] = []

        for fileURL in files {
            let filename = fileURL.lastPathComponent
            // 只处理 {uuid}.json 文件
            guard filename.hasSuffix(".json"), filename != "index.json" else { continue }

            let uuidStr = filename.replacingOccurrences(of: ".json", with: "")
            guard let uuid = UUID(uuidString: uuidStr) else { continue }

            // 已在索引中 → 跳过
            if indexedIDs.contains(uuid) { continue }

            // 孤立文件：尝试加载并补充摘要
            guard let data = try? Data(contentsOf: fileURL),
                  let record = try? JSONDecoder().decode(GameRecord.self, from: data) else {
                #if DEBUG
                AppLog.history.warning("orphan file \(filename) is corrupt, removing")
                #endif
                try? fileManager.removeItem(at: fileURL)
                continue
            }

            #if DEBUG
            AppLog.history.warning("orphan file \(filename) recovered, adding to index")
            #endif
            orphans.append(RecordSummary(from: record))
        }

        // 将孤立记录补充到摘要（按日期排序后插入）
        if !orphans.isEmpty {
            summaries.append(contentsOf: orphans)
            summaries.sort { $0.date > $1.date }
            persistIndex()
        }
    }
}
