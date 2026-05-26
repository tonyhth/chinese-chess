import SwiftUI

enum VGColors {
    static let primary = Color(hex: "FF6B9D")      // 糖果粉
    static let secondary = Color(hex: "FFD93D")     // 明黄
    static let success = Color(hex: "6BCB77")       // 清新绿
    static let error = Color(hex: "FF6B6B")         // 柔红
    static let background = Color(hex: "FFF5F9")    // 浅粉白
    static let card = Color.white
    static let textPrimary = Color(hex: "2D2D2D")
    static let textSecondary = Color(hex: "888888")
}

enum VGSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum VGRadius {
    static let button: CGFloat = 16
    static let card: CGFloat = 20
    static let option: CGFloat = 12
    static let avatar: CGFloat = 30
}

enum VGAnimation {
    static let quick: Double = 0.2
    static let standard: Double = 0.35
    static let slow: Double = 0.5
}

// MARK: - Color extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Backgrounds

enum VGGradients {
    static let home = LinearGradient(
        colors: [Color(hex: "FFF5F9"), Color(hex: "FFE8F0")],
        startPoint: .top, endPoint: .bottom
    )
    static let levelMap = LinearGradient(
        colors: [Color(hex: "F0F8FF"), Color(hex: "E0F0FF")],
        startPoint: .top, endPoint: .bottom
    )
    static let petHouse = LinearGradient(
        colors: [Color(hex: "FFF8E1"), Color(hex: "FFF3CD")],
        startPoint: .top, endPoint: .bottom
    )
    static let profile = LinearGradient(
        colors: [Color(hex: "F3E5F5"), Color(hex: "E8DAEF")],
        startPoint: .top, endPoint: .bottom
    )
    static let game = LinearGradient(
        colors: [Color(hex: "FFF5F9"), Color(hex: "FFE0EC")],
        startPoint: .top, endPoint: .bottom
    )
}
