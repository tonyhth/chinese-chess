import SwiftUI

// MARK: - 棋盘主题

enum BoardTheme: String, CaseIterable, Codable {
    case classicWood = "classicWood"    // 经典木纹
    case inkStone = "inkStone"          // 石材水墨

    var displayName: String {
        switch self {
        case .classicWood: return L10n.shared.t("theme.classicWood")
        case .inkStone: return L10n.shared.t("theme.inkStone")
        }
    }

    var icon: String {
        switch self {
        case .classicWood: return "tree.fill"
        case .inkStone: return "drop.fill"
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
    }

    private func save() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: userDefaultsKey)
    }
}
