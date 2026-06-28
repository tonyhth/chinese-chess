import Foundation

// MARK: - v3.6.0 Phase Q2: 段位门禁系统

/// 可解锁的功能（段位门禁）
enum UnlockedFeature: String, Codable, CaseIterable {
    // 已实现功能（Q2 生效）
    case chapter2Early       // 第二章提前解锁（秀才）
    case chapter3Early       // 第三章提前解锁（举人）
    case freePlayPuzzles     // freePlay 残局全解锁（翰林）

    // 学棋线功能（Phase 2/3 完成后生效，Q2 先做门禁框架）
    case engineAnalysis      // 引擎分析（翰林，Phase 2）
    case aiCoach             // AI 教练（国手，Phase 3）
    case openingTreeBrowse   // 开局树浏览（秀才）
    case openingTreeFavorite // 开局树收藏（棋圣）
    case gameRecordExport    // 棋谱导出（棋圣）
    case customTheme         // 自定义主题（棋圣）

    /// 解锁该功能所需的最低段位
    var requiredRank: Rank {
        switch self {
        case .chapter2Early:       return .scholar
        case .chapter3Early:       return .juren
        case .freePlayPuzzles:     return .hanlin
        case .engineAnalysis:      return .hanlin
        case .aiCoach:             return .master
        case .openingTreeBrowse:   return .scholar
        case .openingTreeFavorite: return .sage
        case .gameRecordExport:    return .sage
        case .customTheme:         return .sage
        }
    }

    /// 该功能是否已在当前版本实现（vs 仅为门禁框架占位）
    var isImplemented: Bool {
        switch self {
        case .chapter2Early, .chapter3Early, .freePlayPuzzles:
            return true
        case .engineAnalysis, .aiCoach, .openingTreeBrowse,
             .openingTreeFavorite, .gameRecordExport, .customTheme:
            return false  // 待 Phase 2/3 实现
        }
    }

    /// 段位升级弹窗图标
    var iconName: String {
        switch self {
        case .chapter2Early:       return "book.fill"
        case .chapter3Early:       return "book.closed.fill"
        case .freePlayPuzzles:     return "puzzlepiece.fill"
        case .engineAnalysis:      return "chart.line.uptrend.xyaxis"
        case .aiCoach:             return "graduationcap.fill"
        case .openingTreeBrowse:   return "tree"
        case .openingTreeFavorite: return "star.fill"
        case .gameRecordExport:    return "square.and.arrow.up"
        case .customTheme:         return "paintbrush.fill"
        }
    }

    /// 段位升级弹窗功能名称
    var localizedName: String {
        switch self {
        case .chapter2Early:       return L10n.shared.t("feature.chapter2Early")
        case .chapter3Early:       return L10n.shared.t("feature.chapter3Early")
        case .freePlayPuzzles:     return L10n.shared.t("feature.freePlayPuzzles")
        case .engineAnalysis:      return L10n.shared.t("feature.engineAnalysis")
        case .aiCoach:             return L10n.shared.t("feature.aiCoach")
        case .openingTreeBrowse:   return L10n.shared.t("feature.openingTreeBrowse")
        case .openingTreeFavorite: return L10n.shared.t("feature.openingTreeFavorite")
        case .gameRecordExport:    return L10n.shared.t("feature.gameRecordExport")
        case .customTheme:         return L10n.shared.t("feature.customTheme")
        }
    }
}

// MARK: - PlayerProfile 段位解锁扩展

extension PlayerProfile {
    /// 检查功能是否已解锁（基于当前段位）
    func isFeatureUnlocked(_ feature: UnlockedFeature) -> Bool {
        rank >= feature.requiredRank
    }
}
