import Foundation

// MARK: - 历史对局存储

/// UserDefaults 双层存储：index（id 列表） + record-{id}（单条记录）
/// 最多 20 局，按时间倒序
final class GameHistoryStore {
    static let shared = GameHistoryStore()

    private let defaults: UserDefaults
    private let indexKey = "chinesechess.history.index"
    private let recordPrefix = "chinesechess.history.record."
    private let maxRecords = 20

    private init() {
        self.defaults = .standard
    }

    /// 测试用初始化器
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - 读取

    /// 所有历史记录，按时间倒序
    var records: [GameRecord] {
        let ids = index
        var result: [GameRecord] = []
        for id in ids {
            if let record = loadRecord(id: id) {
                result.append(record)
            }
        }
        // 按时间倒序
        return result.sorted { $0.date > $1.date }
    }

    /// 记录数量
    var count: Int {
        index.count
    }

    // MARK: - 写入

    /// 添加记录（自动去重，超出上限删除最旧的）
    func addRecord(_ record: GameRecord) {
        var ids = index

        // 去重
        if ids.contains(record.id) {
            #if DEBUG
            print("[History] duplicate record \(record.id), skipping")
            #endif
            return
        }

        // 保存记录数据
        saveRecordData(record)

        // 更新索引
        ids.append(record.id)

        // 超出上限：删除最旧的
        if ids.count > maxRecords {
            let toRemove = ids.prefix(ids.count - maxRecords)
            for oldId in toRemove {
                removeRecordData(id: oldId)
            }
            ids = Array(ids.suffix(maxRecords))
        }

        saveIndex(ids)
    }

    /// 删除指定记录
    func deleteRecord(id: UUID) {
        var ids = index
        ids.removeAll { $0 == id }
        removeRecordData(id: id)
        saveIndex(ids)
    }

    /// 清空所有记录
    func clearAll() {
        let ids = index
        for id in ids {
            removeRecordData(id: id)
        }
        saveIndex([])
    }

    // MARK: - 内部

    private var index: [UUID] {
        guard let data = defaults.data(forKey: indexKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return ids
    }

    private func saveIndex(_ ids: [UUID]) {
        guard let data = try? JSONEncoder().encode(ids) else {
            #if DEBUG
            print("[History] failed to encode index")
            #endif
            return
        }
        defaults.set(data, forKey: indexKey)
    }

    private func loadRecord(id: UUID) -> GameRecord? {
        let key = recordPrefix + id.uuidString
        guard let data = defaults.data(forKey: key),
              let record = try? JSONDecoder().decode(GameRecord.self, from: data) else {
            #if DEBUG
            print("[History] failed to load record \(id)")
            #endif
            return nil
        }
        return record
    }

    private func saveRecordData(_ record: GameRecord) {
        let key = recordPrefix + record.id.uuidString
        guard let data = try? JSONEncoder().encode(record) else {
            #if DEBUG
            print("[History] failed to encode record \(record.id)")
            #endif
            return
        }
        defaults.set(data, forKey: key)
    }

    private func removeRecordData(id: UUID) {
        let key = recordPrefix + id.uuidString
        defaults.removeObject(forKey: key)
    }
}
