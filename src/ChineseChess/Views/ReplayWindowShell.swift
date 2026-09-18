import Foundation

// MARK: - v6.4 C4a：P9 复盘独立窗口壳层（ReplayView 窗口壳/布局层）
// 壳芯契约（c-line-schedule §2 v1.1 写死）：壳以 AnalysisPresentationProvider protocol 为注入边界，
// C4a 先行期用本文件 stub 实现（空数据），C4b 芯合入时替换实现类，壳代码零改动。
// 芯层（评估曲线/走法回跳/变招三要素/top3/持久化加载）= Cody A 线域，本文件不实现。
//
// 文件域归属：设计单 §3 P9 拆分表——壳=Eric（C 线，ReplayView 窗口壳/布局层），
// 芯=Cody（A 线，AnalysisView/PositionAnalyzer 消费层）。

// MARK: - stub 实现（C4a 先行期；C4b 替换为 AnalysisViewModel 注入）

/// 空数据 stub：所有查询返回空/nil，满足 protocol 契约但不产生任何分析内容。
/// k 域边界断言与正式实现同款（domain 契约在 protocol 注释，v1.1 钉死）。
@MainActor
final class StubAnalysisPresentationProvider: AnalysisPresentationProvider {

    func variations(atPosition k: Int) -> [Variation] {
        assert(k >= 0, "k 域外（k∈[0, N]，v1.1）")
        return []
    }

    func moveReview(atMove i: Int) -> MoveReview? {
        assert(i >= 0, "i 域外（i=k-1）")
        return nil
    }

    func coachingPayload(atPosition k: Int) -> CoachingPayload {
        CoachingPayload(positionIndex: k, variations: [], moveReview: nil)
    }
}
