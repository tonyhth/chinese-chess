import Foundation

// MARK: - Phase B3 Step 1: 开局教练走法质量等级

/// 开局教练走法质量等级
///
/// 基于 PositionAnalyzer.MoveQuality 扩展，新增 book 级别。
/// 映射关系：
///   book       = 书谱走法（新增，OpeningBook 命中）
///   brilliant  = 精妙（≤10cp，与复盘一致）
///   good       = 好棋（≤50cp，与复盘一致）
///   normal     = 普通（≤100cp，与复盘一致）
///   doubtful   = 疑问（≤300cp，与复盘一致）
///   blunder    = 失误（≤700cp，与复盘一致）
///   losing     = 败着（>700cp，与复盘一致）
enum OpeningMoveQuality: Int, CaseIterable, Codable {
    case book      = 7  // 书谱走法（新增）
    case brilliant = 5  // 复用 PositionAnalyzer 阈值
    case good      = 4
    case normal    = 3
    case doubtful  = 2
    case blunder   = 1
    case losing    = 0

    /// 从 PositionAnalyzer.MoveQuality 转换
    /// 如果 rawValue 映射不存在（未来某一方调整），fallback 到 .normal
    init(from analysis: MoveQuality) {
        self = OpeningMoveQuality(rawValue: analysis.rawValue) ?? .normal
    }

    /// 显示标签
    var label: String {
        switch self {
        case .book:      return L10n.shared.t("coach.quality.book")
        case .brilliant: return L10n.shared.t("move.quality.brilliant")
        case .good:      return L10n.shared.t("move.quality.good")
        case .normal:    return L10n.shared.t("move.quality.normal")
        case .doubtful:  return L10n.shared.t("move.quality.doubtful")
        case .blunder:   return L10n.shared.t("move.quality.blunder")
        case .losing:    return L10n.shared.t("move.quality.losing")
        }
    }

    /// 颜色名称（用于 UI 标注）
    var colorName: String {
        switch self {
        case .book:      return "green"
        case .brilliant: return "green"
        case .good:      return "blue"
        case .normal:    return "gray"
        case .doubtful:  return "yellow"
        case .blunder:   return "orange"
        case .losing:    return "red"
        }
    }
}
