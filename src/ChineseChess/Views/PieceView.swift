import SwiftUI

struct PieceView: View {
    let piece: Piece
    let isSelected: Bool
    let cellSize: CGFloat
    var theme: ThemeColors = ThemeManager.shared.colors

    private var pieceDiameter: CGFloat {
        cellSize * 0.85
    }

    private var fontSize: CGFloat {
        pieceDiameter * 0.45
    }

    private var textColor: Color {
        piece.side == .red ? theme.redPieceText : theme.blackPieceText
    }

    private var borderColor: Color { theme.pieceBorder }

    /// 小棋盘模式（compact），需增强选中效果
    private var isCompact: Bool { cellSize < 40 }

    /// 选中边框线宽
    private var selectedBorderWidth: CGFloat { isCompact ? 3 : 2 }

    /// 选中边框额外尺寸
    private var selectedBorderExpansion: CGFloat { isCompact ? 8 : 4 }

    /// 选中发光半径
    private var selectedGlowRadius: CGFloat { isCompact ? 8 : 6 }

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
                .font(.custom(FontRegistry.bestAvailableFontName, size: fontSize))
                .foregroundColor(textColor)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .overlay {
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: selectedBorderWidth)
                    .frame(width: pieceDiameter + selectedBorderExpansion,
                           height: pieceDiameter + selectedBorderExpansion)
            }
        }
        .shadow(color: isSelected ? .yellow : .clear, radius: isSelected ? selectedGlowRadius : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
        .accessibilityLabel(pieceAccessibilityLabel)
    }

    private var pieceAccessibilityLabel: String {
        let sideName = piece.side == .red ? "红方" : "黑方"
        let colLabel = "abcdefghi"
        let colChar = String(colLabel[colLabel.index(colLabel.startIndex, offsetBy: piece.position.col)])
        return "\(sideName)\(piece.displayName) \(colChar)\(piece.position.row)"
    }
}
