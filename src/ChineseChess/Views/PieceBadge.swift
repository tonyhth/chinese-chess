import SwiftUI

// MARK: - PieceBadge — 轻量棋子展示组件（教程课1专用）

/// 从 PieceView 提取的轻量棋子展示组件，用于教程和卡片展示场景。
/// 容忍与 PieceView 的少量代码重复，后续重构时 PieceView 可内部调用 PieceBadge。
struct PieceBadge: View {
    let kind: PieceKind
    let side: Side
    var size: CGFloat = 44

    private var theme: ThemeColors { ThemeManager.shared.colors }

    private var displayChar: String {
        switch kind {
        case .general:  return side == .red ? "帅" : "将"
        case .advisor:  return side == .red ? "仕" : "士"
        case .elephant: return side == .red ? "相" : "象"
        case .horse:    return side == .red ? "馬" : "馬"
        case .chariot:  return side == .red ? "車" : "車"
        case .cannon:   return side == .red ? "炮" : "砲"
        case .soldier:  return side == .red ? "兵" : "卒"
        }
    }

    private var textColor: Color {
        side == .red ? theme.redPieceText : theme.blackPieceText
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: theme.pieceFill,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .stroke(theme.pieceBorder, lineWidth: max(1, size * 0.04))
                .frame(width: size, height: size)

            Text(displayChar)
                .font(.custom(FontRegistry.bestAvailableFontName, size: size * 0.5))
                .foregroundColor(textColor)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        PieceBadge(kind: .chariot, side: .red)
        PieceBadge(kind: .horse, side: .red)
        PieceBadge(kind: .general, side: .black)
    }
    .padding()
}
