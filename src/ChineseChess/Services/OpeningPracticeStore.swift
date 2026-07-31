import Foundation

// MARK: - Phase B3 Step 1: 开局练习记录与存储

/// 开局练习记录（持久化）
struct OpeningPracticeRecord: Codable {
    var openingId: String
    var totalSessions: Int
    var bestAccuracy: Double
    var lastPracticedAt: Date?
    var totalMoves: Int
    var bookMoves: Int

    init(openingId: String) {
        self.openingId = openingId
        self.totalSessions = 0
        self.bestAccuracy = 0
        self.lastPracticedAt = nil
        self.totalMoves = 0
        self.bookMoves = 0
    }

    // Schema 演进容错：新字段 decodeIfPresent + 默认值
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openingId = try c.decode(String.self, forKey: .openingId)
        totalSessions = try c.decode(Int.self, forKey: .totalSessions)
        bestAccuracy = try c.decode(Double.self, forKey: .bestAccuracy)
        lastPracticedAt = try c.decodeIfPresent(Date.self, forKey: .lastPracticedAt)
        totalMoves = try c.decodeIfPresent(Int.self, forKey: .totalMoves) ?? 0
        bookMoves = try c.decodeIfPresent(Int.self, forKey: .bookMoves) ?? 0
    }
}

/// 练习记录存储
///
/// 采用 JSON 文件 + 串行队列 + 原子写入（与 GameRecordStore 一致），
/// 不用 UserDefaults（避免频繁全量序列化、支持未来复杂查询）。
final class OpeningPracticeStore {
    static let shared = OpeningPracticeStore()

    private let queue = DispatchQueue(label: "chinesechess.openingpractice")
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("chinesechess/opening_practice.json")
    }()

    private(set) var records: [String: OpeningPracticeRecord] = [:]

    private init() { load() }

    /// 根据教练会话更新练习记录
    func update(with session: OpeningCoachSession) {
        queue.sync {
            let id = session.openingId
            var record = records[id] ?? OpeningPracticeRecord(openingId: id)
            record.totalSessions += 1
            record.bestAccuracy = max(record.bestAccuracy, session.accuracy)
            record.lastPracticedAt = Date()
            record.totalMoves += session.moves.count
            record.bookMoves += session.moves.filter { $0.quality == .book }.count
            records[id] = record
            save()
        }
    }

    /// 获取指定开局的练习记录
    func record(for openingId: String) -> OpeningPracticeRecord? {
        queue.sync {
            records[openingId]
        }
    }

    /// 获取所有练习过的开局数量
    var practicedCount: Int {
        queue.sync { records.count }
    }

    /// 获取所有练习的平均准确率
    var averageAccuracy: Double {
        queue.sync {
            guard !records.isEmpty else { return 0 }
            let total = records.values.reduce(0.0) { $0 + $1.bestAccuracy }
            return total / Double(records.count)
        }
    }

    // MARK: - 持久化

    /// Schema 演进容错（与 DemoConfig 一致）
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        records = (try? JSONDecoder().decode([String: OpeningPracticeRecord].self, from: data)) ?? [:]
    }

    /// 原子写入：使用 Foundation 的 .atomic 选项
    /// 自动处理"写临时文件→替换原文件"，不需要手动 moveItem
    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        // 确保目录存在
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
