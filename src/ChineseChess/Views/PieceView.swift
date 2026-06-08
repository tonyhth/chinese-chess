import SwiftUI

struct PieceView: View {
    let piece: Piece
    let isSelected: Bool
    let boardSize: CGSize
    var theme: ThemeColors = ThemeManager.shared.colors

    private var pieceDiameter: CGFloat {
        boardSize.width / 10 * 0.85
    }

    private var fontSize: CGFloat {
        pieceDiameter * 0.45
    }

    private var textColor: Color {
        piece.side == .red ? theme.redPieceText : theme.blackPieceText
    }

    private var borderColor: Color { theme.pieceBorder }

    var body: some View {
        ZStack {
            // 棋子底色 + 立体感
            Circle()
                .fill(
                    RadialGradient(
                        colors: theme.pieceFill,
                        center: .center,
                        startRadius: 0,
                        endRadius: pieceDiameter / 2
                    )
                )
                .frame(width: pieceDiameter, height: pieceDiameter)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1.5)
                        .frame(width: pieceDiameter - 4, height: pieceDiameter - 4)
                )

            // 棋子文字
            Text(piece.displayName)
                .font(.custom(FontRegistry.fontName, size: fontSize))
                .foregroundColor(textColor)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .overlay {
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: pieceDiameter + 4, height: pieceDiameter + 4)
            }
        }
        .shadow(color: isSelected ? .yellow : .clear, radius: isSelected ? 6 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
    }
}

// Font fallback is handled automatically by the system when LXGW WenKai is not available
