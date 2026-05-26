import SwiftUI

struct PieceView: View {
    let piece: Piece
    let isSelected: Bool
    let boardSize: CGSize

    private var pieceDiameter: CGFloat {
        boardSize.width / 10 * 0.85
    }

    private var fontSize: CGFloat {
        pieceDiameter * 0.45
    }

    private var textColor: Color {
        piece.side == .red ? Color(red: 204/255, green: 0, blue: 0) : Color(red: 26/255, green: 26/255, blue: 26/255)
    }

    private var borderColor: Color { textColor }

    var body: some View {
        ZStack {
            // 棋子底色 + 立体感
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 255/255, green: 253/255, blue: 230/255),
                            Color(red: 240/255, green: 230/255, blue: 200/255),
                            Color(red: 220/255, green: 200/255, blue: 170/255)
                        ],
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
                .font(.custom("STKaiti", size: fontSize))
                .foregroundColor(textColor)
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .shadow(color: isSelected ? .yellow : .clear, radius: isSelected ? 6 : 0)
    }
}

// Font fallback is handled automatically by the system when STKaiti is not available
