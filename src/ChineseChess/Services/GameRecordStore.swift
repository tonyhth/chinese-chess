import Foundation

// MARK: - 记录摘要（列表展示用，避免全量加载）

struct RecordSummary: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let result: GameState
    let totalMoves: Int
    let difficulty: AIDifficulty?
    let source: RecordSource
    let puzzleId: String?   // v3.7.1: 用于 puzzleId 去重
    /// T-1013-OC-03 P1-2：S2 迁移标记（同 GameRecord 边界单次应用协议；var=解码内应用后置位）
    var s2Migrated: Bool

    // P1-2：显式 Codable——difficulty 解码走 S2 边界迁移（标记缺席=旧档迁移，在位=零腐蚀直读）
    private enum CodingKeys: String, CodingKey {
        case id, title, date, result, totalMoves, difficulty, source, puzzleId, s2Migrated
    }

    init(from record: GameRecord) {
        self.id = record.id
        self.title = record.title
        self.date = record.date
        self.result = record.result
        self.totalMoves = record.totalMoves
        self.difficulty = record.difficulty
        self.source = record.source
        self.puzzleId = record.puzzleId
        self.s2Migrated = record.s2Migrated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        result = try c.decode(GameState.self, forKey: .result)
        totalMoves = try c.decode(Int.self, forKey: .totalMoves)
        source = try c.decodeIfPresent(RecordSource.self, forKey: .source) ?? .versusAI
        puzzleId = try c.decodeIfPresent(String.self, forKey: .puzzleId)
        s2Migrated = try c.decodeIfPresent(Bool.self, forKey: .s2Migrated) ?? false
        let difficultyRaw = try c.decodeIfPresent(String.self, forKey: .difficulty)
        if let raw = difficultyRaw {
            let migrated = s2Migrated ? raw : AIDifficulty.s2MigratedRaw(raw)
            difficulty = AIDifficulty(rawValue: migrated) ?? .amateurMid
        } else {
            difficulty = nil
        }
        // P1-2 应用后标记：迁移已应用 → 内存态置 true（persistIndex 写回=单次应用持久化）
        s2Migrated = true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(date, forKey: .date)
        try c.encode(result, forKey: .result)
        try c.encode(totalMoves, forKey: .totalMoves)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(source, forKey: .source)
        try c.encode(puzzleId, forKey: .puzzleId)
        try c.encode(s2Migrated, forKey: .s2Migrated)
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

    let fileManager = FileManager.default
    let baseURL: URL           // Documents/GameRecords/
    private let indexURL: URL  // Documents/GameRecords/index.json

    /// 内存缓存：列表展示用摘要
    private(set) var summaries: [RecordSummary] = []

    /// 串行写入队列，防止并发写坏文件
    let writeQueue = DispatchQueue(label: "com.chinesechess.recordstore", qos: .userInitiated)

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
        writeQueue.sync { summaries }
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
    var count: Int { writeQueue.sync { summaries.count } }

    /// v3.7.1 A4: 按 puzzleId 查找记录
    func findRecordByPuzzleId(_ puzzleId: String) -> GameRecord? {
        writeQueue.sync {
            for summary in summaries {
                if summary.source == .puzzle,
                   let record = loadRecord(id: summary.id),
                   record.puzzleId == puzzleId {
                    return record
                }
            }
            return nil
        }
    }

    // MARK: - 写入（线程安全 + 去重 + 原子写入）

    /// 添加记录（自动去重，新记录插入最前面）
    func addRecord(_ record: GameRecord) {
        writeQueue.sync {
            // id 去重：同 id 不重复写入
            guard !summaries.contains(where: { $0.id == record.id }) else { return }

            // 1. 写入单条文件
            persistSingleRecord(record)

            // 2. 更新内存摘要（新记录插入最前面，按日期倒序）
            summaries.insert(RecordSummary(from: record), at: 0)

            // 3. 更新 index.json
            persistIndex()
        }
    }

    /// 更新记录（改标题/标签等）
    func updateRecord(_ record: GameRecord) {
        writeQueue.sync {
            // 1. 覆写单条文件
            persistSingleRecord(record)

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
            // v6.4 A2①：连带删 sidecar analysis（生命周期归本 store）
            let analysisURL = baseURL.appendingPathComponent("\(id.uuidString).analysis.json")
            try? fileManager.removeItem(at: analysisURL)

            // 2. 更新内存摘要
            summaries.removeAll { $0.id == id }

            // 3. 更新 index.json
            persistIndex()
        }
    }

    /// 清空全部
    func clearAll() {
        writeQueue.sync {
            // 1. 删除所有 .json 文件与 sidecar analysis（不删除 .tmp 等）
            for summary in summaries {
                let fileURL = baseURL.appendingPathComponent("\(summary.id.uuidString).json")
                try? fileManager.removeItem(at: fileURL)
                let analysisURL = baseURL.appendingPathComponent("\(summary.id.uuidString).analysis.json")
                try? fileManager.removeItem(at: analysisURL)
            }
            summaries = []
            persistIndex()
        }
    }

    // MARK: - 批量导入

    /// 批量添加记录，返回实际新增数量
    /// 单次 writeQueue.sync 内完成所有写入，只调用一次 persistIndex()
    @discardableResult
    func batchAdd(_ records: [GameRecord]) -> Int {
        writeQueue.sync {
            var added = 0
            var newSummaries: [RecordSummary] = []
            for record in records {
                // id 去重（与 addRecord 一致）
                guard !summaries.contains(where: { $0.id == record.id }) else { continue }
                // puzzleId 去重
                if let pid = record.puzzleId,
                   summaries.contains(where: { $0.puzzleId == pid }) {
                    continue
                }
                // 直接操作内存，不逐条调 addRecord
                newSummaries.append(RecordSummary(from: record))
                persistSingleRecord(record)
                added += 1
            }
            if added > 0 {
                // 批量插入到最前面（与 addRecord 的 insert(at: 0) 一致，保持新记录在前）
                summaries.insert(contentsOf: newSummaries.reversed(), at: 0)
                persistIndex()
            }
            return added
        }
    }

    // MARK: - 内部

    /// 写入单条记录文件（调用方需在 writeQueue 内）
    private func persistSingleRecord(_ record: GameRecord) {
        let fileURL = baseURL.appendingPathComponent("\(record.id.uuidString).json")
        do {
            let data = try JSONEncoder().encode(record)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            AppLog.history.error("failed to write record \(record.id): \(error)")
            #endif
        }
    }

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

        // v6.4 A2①：孤立 analysis sidecar 回收——棋谱已不存在的 analysis 文件删除
        // （可再生态数据，不回收只占磁盘；目录 stat 判定零加载成本）
        let indexedIDsAfterRecovery = indexedIDs.union(orphans.map { $0.id })
        for fileURL in files {
            let filename = fileURL.lastPathComponent
            guard filename.hasSuffix(".analysis.json") else { continue }
            let uuidStr = filename.replacingOccurrences(of: ".analysis.json", with: "")
            guard let uuid = UUID(uuidString: uuidStr) else {
                try? fileManager.removeItem(at: fileURL)
                continue
            }
            if !indexedIDsAfterRecovery.contains(uuid) {
                #if DEBUG
                AppLog.history.warning("orphan analysis sidecar \(filename) removed")
                #endif
                try? fileManager.removeItem(at: fileURL)
            }
        }

        // 将孤立记录补充到摘要（按日期排序后插入）
        if !orphans.isEmpty {
            summaries.append(contentsOf: orphans)
            summaries.sort { $0.date > $1.date }
            persistIndex()
        }
    }
}
