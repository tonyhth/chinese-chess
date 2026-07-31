import Foundation

// MARK: - Phase B3 Step 2: 开局教练配置与结束原因

/// 开局教练配置
struct CoachConfig {
    /// 目标开局子分类
    let targetSubcategory: OpeningSubcategory
    /// 开局结束后的 AI 难度
    let aiDifficulty: AIDifficulty
    /// 用户执哪方
    let playerSide: Side
}

/// 开局阶段结束原因
enum OpeningEndReason {
    /// OpeningBook 无数据（自然走出开局区域）
    case naturalEnd
    /// 超过 20 步
    case maxStepsReached
    /// 用户主动退出
    case userAbandoned
    // 注意：用户脱谱（走了非书谱走法）不判定为开局结束
}
