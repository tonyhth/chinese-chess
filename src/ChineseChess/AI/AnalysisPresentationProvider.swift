import Foundation

// MARK: - v6.4 A-Phase2 §2：变招 API（C4 消费接口，P9 芯层）

/// 三要素走法回顾（P1 速览 / P9 走法列表徽章点开直出）
struct MoveReview {
    let played: String        // 实际着法（中文）
    let recommended: String   // 引擎推荐（中文）
    let lossCp: Int           // 亏损 cp（= evalDelta，阈值常量同源）
}

/// CoachExplainer 数据包（数据供给式，不改其场景逻辑）
struct CoachingPayload {
    let positionIndex: Int          // 局面 k
    let variations: [Variation]     // top3（可为空=降级）
    let moveReview: MoveReview?     // 第 k 着回顾（k≥1 时）
}

/// 评估域对展示层的唯一供给口（P9 芯 / P1 速览 / CoachExplainer 共用）
/// off-by-one 只允许定义一次（v1.1）：k = 第 k 着后的局面（k∈[0, N]，N=总着数）；
/// 变招数据属第 k 着的分析结果（i = k-1）。
protocol AnalysisPresentationProvider {
    /// 局面 k 的 top3 变招。
    /// k 域边界（v1.1 钉死）：有效域 k∈[1, N]（N=已分析着数）；k=0（首着前）/
    /// k>N（终局后/未分析段）一律返回 []，debug 构建加 assert 防遇外不叫。
    func variations(atPosition k: Int) -> [Variation]
    /// 三要素：实际着法 / 引擎推荐 / 亏损 cp（第 i 着，i=k-1；i 域外返回 nil）
    func moveReview(atMove i: Int) -> MoveReview?
    /// 供 CoachExplainer：局面+变招打包
    func coachingPayload(atPosition k: Int) -> CoachingPayload
}
