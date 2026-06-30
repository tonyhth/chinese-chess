import SwiftUI

// MARK: - 棋盘主题

enum BoardTheme: String, CaseIterable, Codable {
    case classicWood = "classicWood"    // 经典木纹（默认）
    case inkStone = "inkStone"          // 石材水墨（默认）
    // v3.0 Phase 8: 段位解锁主题
    case jadeGreen = "jadeGreen"        // 翡翠绿（秀才解锁）
    case imperialGold = "imperialGold"  // 帝王金（举人解锁）
    case crimson = "crimson"            // 朱砂红（进士解锁）

    var displayName: String {
        switch self {
        case .classicWood: return L10n.shared.t("theme.classicWood")
        case .inkStone: return L10n.shared.t("theme.inkStone")
        case .jadeGreen: return "翡翠绿"
        case .imperialGold: return "帝王金"
        case .crimson: return "朱砂红"
        }
    }

    var icon: String {
        switch self {
        case .classicWood: return "tree.fill"
        case .inkStone: return "drop.fill"
        case .jadeGreen: return "leaf.fill"
        case .imperialGold: return "crown.fill"
        case .crimson: return "flame.fill"
        }
    }

    // v3.0 Phase 8: 解锁条件
    var unlockDescription: String {
        switch self {
        case .classicWood, .inkStone: return "默认解锁"
        case .jadeGreen: return "升至秀才段位解锁"
        case .imperialGold: return "升至举人段位解锁"
        case .crimson: return "升至进士段位解锁"
        }
    }

    var requiredRank: Rank? {
        switch self {
        case .classicWood, .inkStone: return nil
        case .jadeGreen: return .scholar
        case .imperialGold: return .juren
        case .crimson: return .jinshi
        }
    }

    var isUnlockedByDefault: Bool {
        requiredRank == nil
    }

    /// 段位升级弹窗预览色
    var previewColor: Color {
        switch self {
        case .classicWood: return .brown
        case .inkStone: return .gray
        case .jadeGreen: return .green
        case .imperialGold: return .yellow
        case .crimson: return .red
        }
    }
}

// MARK: - 主题颜色配置

struct ThemeColors: Equatable {
    let boardBackground: [Color]      // 渐变色
    let lineColor: Color
    let textColor: Color
    let redPieceText: Color
    let blackPieceText: Color
    let pieceFill: [Color]           // 棋子底色渐变（径向）
    let pieceBorder: Color
    let riverTextColor: Color
    let appBackground: Color

    static func forTheme(_ theme: BoardTheme) -> ThemeColors {
        switch theme {
        case .classicWood:
            return ThemeColors(
                boardBackground: [
                    Color(red: 222/255, green: 184/255, blue: 135/255),
                    Color(red: 210/255, green: 170/255, blue: 120/255),
                    Color(red: 222/255, green: 184/255, blue: 135/255)
                ],
                lineColor: Color(red: 74/255, green: 55/255, blue: 40/255),
                textColor: .white,
                redPieceText: Color(red: 204/255, green: 0, blue: 0),
                blackPieceText: Color(red: 26/255, green: 26/255, blue: 26/255),
                pieceFill: [
                    Color(red: 255/255, green: 253/255, blue: 230/255),
                    Color(red: 240/255, green: 230/255, blue: 200/255),
                    Color(red: 220/255, green: 200/255, blue: 170/255)
                ],
                pieceBorder: Color(red: 150/255, green: 120/255, blue: 80/255),
                riverTextColor: Color(red: 74/255, green: 55/255, blue: 40/255),
                appBackground: Color(red: 44/255, green: 24/255, blue: 16/255)
            )

        case .inkStone:
            return ThemeColors(
                boardBackground: [
                    Color(red: 230/255, green: 225/255, blue: 218/255),
                    Color(red: 215/255, green: 208/255, blue: 198/255),
                    Color(red: 225/255, green: 220/255, blue: 210/255)
                ],
                lineColor: Color(red: 60/255, green: 55/255, blue: 50/255),
                textColor: .white,
                redPieceText: Color(red: 180/255, green: 30/255, blue: 30/255),
                blackPieceText: Color(red: 20/255, green: 20/255, blue: 25/255),
                pieceFill: [
                    Color(red: 245/255, green: 240/255, blue: 232/255),
                    Color(red: 235/255, green: 228/255, blue: 218/255),
                    Color(red: 225/255, green: 218/255, blue: 208/255)
                ],
                pieceBorder: Color(red: 120/255, green: 115/255, blue: 105/255),
                riverTextColor: Color(red: 80/255, green: 70/255, blue: 60/255),
                appBackground: Color(red: 55/255, green: 50/255, blue: 45/255)
            )

        case .jadeGreen:
            return ThemeColors(
                boardBackground: [
                    Color(red: 180/255, green: 210/255, blue: 170/255),
                    Color(red: 160/255, green: 195/255, blue: 155/255),
                    Color(red: 175/255, green: 205/255, blue: 168/255)
                ],
                lineColor: Color(red: 35/255, green: 65/255, blue: 40/255),
                textColor: .white,
                redPieceText: Color(red: 180/255, green: 20/255, blue: 20/255),
                blackPieceText: Color(red: 20/255, green: 35/255, blue: 25/255),
                pieceFill: [
                    Color(red: 240/255, green: 250/255, blue: 235/255),
                    Color(red: 225/255, green: 240/255, blue: 220/255),
                    Color(red: 210/255, green: 228/255, blue: 205/255)
                ],
                pieceBorder: Color(red: 80/255, green: 120/255, blue: 75/255),
                riverTextColor: Color(red: 35/255, green: 65/255, blue: 40/255),
                appBackground: Color(red: 25/255, green: 50/255, blue: 30/255)
            )

        case .imperialGold:
            return ThemeColors(
                boardBackground: [
                    Color(red: 240/255, green: 215/255, blue: 140/255),
                    Color(red: 225/255, green: 200/255, blue: 120/255),
                    Color(red: 238/255, green: 212/255, blue: 135/255)
                ],
                lineColor: Color(red: 90/255, green: 65/255, blue: 20/255),
                textColor: .white,
                redPieceText: Color(red: 170/255, green: 20/255, blue: 20/255),
                blackPieceText: Color(red: 40/255, green: 30/255, blue: 15/255),
                pieceFill: [
                    Color(red: 255/255, green: 248/255, blue: 220/255),
                    Color(red: 245/255, green: 235/255, blue: 200/255),
                    Color(red: 230/255, green: 218/255, blue: 180/255)
                ],
                pieceBorder: Color(red: 160/255, green: 130/255, blue: 50/255),
                riverTextColor: Color(red: 90/255, green: 65/255, blue: 20/255),
                appBackground: Color(red: 60/255, green: 45/255, blue: 15/255)
            )

        case .crimson:
            return ThemeColors(
                boardBackground: [
                    Color(red: 200/255, green: 130/255, blue: 120/255),
                    Color(red: 185/255, green: 115/255, blue: 105/255),
                    Color(red: 195/255, green: 125/255, blue: 115/255)
                ],
                lineColor: Color(red: 80/255, green: 25/255, blue: 20/255),
                textColor: .white,
                redPieceText: Color(red: 90/255, green: 10/255, blue: 10/255),
                blackPieceText: Color(red: 30/255, green: 15/255, blue: 15/255),
                pieceFill: [
                    Color(red: 250/255, green: 235/255, blue: 230/255),
                    Color(red: 240/255, green: 222/255, blue: 215/255),
                    Color(red: 228/255, green: 208/255, blue: 200/255)
                ],
                pieceBorder: Color(red: 140/255, green: 60/255, blue: 50/255),
                riverTextColor: Color(red: 80/255, green: 25/255, blue: 20/255),
                appBackground: Color(red: 50/255, green: 20/255, blue: 18/255)
            )
        }
    }
}

// MARK: - 主题管理

@Observable
class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: BoardTheme {
        didSet {
            save()
        }
    }

    var colors: ThemeColors {
        ThemeColors.forTheme(currentTheme)
    }

    private let userDefaultsKey = "chinesechess.theme"

    private init() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
           let theme = BoardTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .classicWood
        }
        // 启动时校验：如果当前主题未解锁（段位降级/数据迁移），回退到默认
        ensureValidTheme()
    }

    private func save() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: userDefaultsKey)
    }

    // v3.0 Phase 8: 检查主题是否解锁（段位 OR 连续登录奖励 OR 成就）
    func isThemeUnlocked(_ theme: BoardTheme, profile: PlayerProfile) -> Bool {
        guard let required = theme.requiredRank else { return true }
        // 段位达标 OR 连续登录奖励解锁
        if profile.rank >= required || profile.bonusUnlockedThemes.contains(theme.rawValue) {
            return true
        }
        // v3.0 gap fix P1-2: 棋圣专属主题通过 day100 奖励解锁
        // P1 修复：bonusSpecialTheme 只对 requiredRank == .sage 的主题生效，不是无条件全部解锁
        if profile.bonusSpecialTheme && theme.requiredRank == .sage {
            return true
        }
        // v3.0 gap fix: 钻石成就关联解锁
        // 拥有 3+ 钻石成就 → 解锁全部主题
        let diamondIds = Set(AchievementLibrary.diamond.map { $0.id })
        let diamondCount = profile.unlockedAchievements.filter { diamondIds.contains($0) }.count
        return diamondCount >= 3
    }

    // v3.0 Phase 8: 可用主题列表
    func availableThemes(profile: PlayerProfile) -> [BoardTheme] {
        BoardTheme.allCases.filter { isThemeUnlocked($0, profile: profile) }
    }

    // v3.0 Phase 8: 尝试切换主题（如果未解锁返回 false）
    @discardableResult
    func switchTheme(_ theme: BoardTheme, profile: PlayerProfile) -> Bool {
        guard isThemeUnlocked(theme, profile: profile) else { return false }
        currentTheme = theme
        return true
    }

    /// 校验当前主题是否已解锁，未解锁则回退到 .classicWood
    /// App 启动时和段位变化时调用
    func ensureValidTheme() {
        let profile = PlayerProfileStore.shared.profile
        if !isThemeUnlocked(currentTheme, profile: profile) && !currentTheme.isUnlockedByDefault {
            currentTheme = .classicWood
        }
    }
}
