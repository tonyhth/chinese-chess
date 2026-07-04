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
    case gameRecordExport    // 棋谱导出（翰林，v3.7.0 Phase 2）
    case gameRecordImport    // 棋谱导入（无段位限制，v3.7.0 Phase 2）
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
        case .gameRecordExport:    return .hanlin   // v3.7.0: 从棋圣降为翰林
        case .gameRecordImport:    return .student   // v3.7.0: 无段位限制，最低段位即可
        case .customTheme:         return .sage
        }
    }

    /// 该功能是否已在当前版本实现（vs 仅为门禁框架占位）
    var isImplemented: Bool {
        switch self {
        case .chapter2Early, .chapter3Early, .freePlayPuzzles:
            return true
        case .engineAnalysis, .gameRecordExport, .gameRecordImport:
            return true   // v3.7.0 Phase 2: 已实现
        case .aiCoach, .openingTreeBrowse,
             .openingTreeFavorite, .customTheme:
            return true   // v3.7.2: 已实现
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
        case .gameRecordImport:    return "square.and.arrow.down"
        case .customTheme:         return "paintbrush.fill"
        }
    }

    /// 段位升级弹窗功能名称的 L10n key
    var localizedKey: String {
        switch self {
        case .chapter2Early:       return "feature.chapter2Early"
        case .chapter3Early:       return "feature.chapter3Early"
        case .freePlayPuzzles:     return "feature.freePlayPuzzles"
        case .engineAnalysis:      return "feature.engineAnalysis"
        case .aiCoach:             return "feature.aiCoach"
        case .openingTreeBrowse:   return "feature.openingTreeBrowse"
        case .openingTreeFavorite: return "feature.openingTreeFavorite"
        case .gameRecordExport:    return "feature.gameRecordExport"
        case .gameRecordImport:    return "feature.gameRecordImport"
        case .customTheme:         return "feature.customTheme"
        }
    }
}

// MARK: - PlayerProfile 段位解锁扩展

extension PlayerProfile {
    /// 检查功能是否已解锁（基于当前段位）
    func isFeatureUnlocked(_ feature: UnlockedFeature) -> Bool {
        #if DEBUG
        if DeveloperMode.isEnabled { return true }
        #endif
        return rank >= feature.requiredRank
    }
}
