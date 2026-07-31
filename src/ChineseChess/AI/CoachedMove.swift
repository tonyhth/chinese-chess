import Foundation

// MARK: - Phase B3 Step 1: 带评估的走法记录

/// 带质量评估的走法记录
struct CoachedMove: Codable {
    /// 走法（ICCS 格式，与 OpeningBook 一致）
    let move: String
    /// 走法质量等级
    let quality: OpeningMoveQuality
    /// 书谱推荐走法（如有，ICCS 格式）
    let bookMove: String?
    /// 与最佳走法的评估差距（cp）
    let evalDelta: Int?
    /// 简短说明
    let explanation: String?
}
