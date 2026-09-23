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
    /// v6.4 C4b（T-0918 接线，8dd48a7 注释锚点落地）：跨版本 estimate 不可比
    /// （校准参数升级=绝对值坐标系已换，混比=伪趋势）——趋势对比只认**同校准版本**
    /// 的前一份报告；旧版本/legacy（nil）报告不参与趋势（消费侧拿 nil=不显示趋势箭头）。
    var previousReport: StrengthReport? {
        let current = lastReport
        let h = reportHistory
        // 跨版本趋势隔离（8dd48a7 锚注释处方·贴锚逐字）：过滤基准=全局常量
        // currentCalibrationVersion，非报告自身版本——校准升级后旧系报告全部出局，
        // W1（新版首报告前）/W2（存量 legacy）两窗口旧系趋势不再照显。
        guard let cur = current else { return nil }
        let sameSeries = h.filter { $0.calibrationVersion == StrengthReport.currentCalibrationVersion }
        guard let curIdx = sameSeries.firstIndex(where: { $0.id == cur.id }),
              curIdx > 0 else { return nil }
        return sameSeries[curIdx - 1]
    }

    // v6.4 A3（T-0917-7 1c）：跨版本语义钩子——判定接口（C4b 起为消费侧供给面）。
    // 校准参数升级递增 currentCalibrationVersion 后，isCurrentCalibration 即翻 false
    // （旧档），previousReport 过滤同版本序列（上方），趋势不可比口径闭环。
    /// 报告是否与当前校准版本同系（nil=legacy 恒 false）
    func isCurrentCalibration(_ report: StrengthReport) -> Bool {
        report.calibrationVersion == StrengthReport.currentCalibrationVersion
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
