import Foundation

// MARK: - v6.0 Phase 4: 评估报告持久化

/// 评估报告存储管理器
final class AssessmentStore {
    static let shared = AssessmentStore()

    private let defaults: UserDefaults
    private let storageKey = "chinesechess.assessment.report"
    // v6.4 A1（Elo 诚信降级）：趋势箭头所需的历史序列（最近 10 条，仅供相对比较，不展示绝对值）
    private let historyKey = "chinesechess.assessment.history"
    private let historyLimit = 10

    private init() {
        self.defaults = .standard
    }

    /// 测试用初始化器
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - 读取

    /// 最近的评估报告
    var lastReport: StrengthReport? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(StrengthReport.self, from: data)
    }

    /// 历史报告序列（旧→新）
    var reportHistory: [StrengthReport] {
        guard let arr = defaults.array(forKey: historyKey) as? [Data] else { return [] }
        return arr.compactMap { try? JSONDecoder().decode(StrengthReport.self, from: $0) }
    }

    /// 上一份报告（趋势对比用；无历史时 nil）
    var previousReport: StrengthReport? {
        let h = reportHistory
        return h.count >= 2 ? h[h.count - 2] : nil
    }

    // MARK: - 写入

    /// 保存评估报告
    func save(_ report: StrengthReport) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        defaults.set(data, forKey: storageKey)
        // v6.4 A1：追加历史（去重同局集重复保存，保留最近 historyLimit 条）
        // P2-4：按局集去重（Set 比较，顺序不敏感——同局集不同顺序不产生重复条目，Ruby 08-30）
        var h = reportHistory.filter { Set($0.sourceGames) != Set(report.sourceGames) }
        h.append(report)
        if h.count > historyLimit { h.removeFirst(h.count - historyLimit) }
        let encoded: [Data] = h.compactMap { try? JSONEncoder().encode($0) }
        defaults.set(encoded, forKey: historyKey)
    }

    // MARK: - 清除

    /// 删除评估报告
    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
