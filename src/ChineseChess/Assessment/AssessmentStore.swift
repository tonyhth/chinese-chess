import Foundation

// MARK: - v6.0 Phase 4: 评估报告持久化

/// 评估报告存储管理器
final class AssessmentStore {
    static let shared = AssessmentStore()

    private let defaults: UserDefaults
    private let storageKey = "chinesechess.assessment.report"

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

    // MARK: - 写入

    /// 保存评估报告
    func save(_ report: StrengthReport) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - 清除

    /// 删除评估报告
    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
