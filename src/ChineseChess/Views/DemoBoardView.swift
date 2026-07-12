import SwiftUI

// MARK: - 只读演示棋盘视图

/// 用于 PuzzleDemoView 的只读棋盘渲染
/// 不依赖 GameViewModel/PuzzleViewModel，直接从 Board + lastMove 渲染
struct DemoBoardView: View {
    let board: Board
    let lastMove: (from: Position, to: Position)?
    let isFlipped: Bool

    private var theme: ThemeColors { ThemeManager.shared.colors }

    var body: some View {
        GeometryReader { geo in
            let boardSize = min(geo.size.width - 16, geo.size.height - 16)
            ZStack {
                Color.clear
                boardCanvas(boardSize: boardSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 棋盘画布

    @ViewBuilder
    private func boardCanvas(boardSize: CGFloat) -> some View {
        let cellSize = boardSize / 10  // 10 列间距
        let pieceSize = cellSize * 0.82

        ZStack {
            // 棋盘背景
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: theme.boardBackground,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: boardSize, height: boardSize * 10 / 9)

            // 格线
            boardGrid(boardSize: boardSize, cellSize: cellSize)

            // lastMove 高亮
            lastMoveHighlights(boardSize: boardSize, cellSize: cellSize)

            // 棋子
            piecesLayer(boardSize: boardSize, cellSize: cellSize, pieceSize: pieceSize)
        }
    }

    // MARK: - 格线

    @ViewBuilder
    private func boardGrid(boardSize: CGFloat, cellSize: CGFloat) -> some View {
        Canvas { context, size in
            let w = boardSize * 8 / 9  // 9 列交叉点，8 个间距
            let h = boardSize  // 10 行交叉点，9 个间距
            let cw = w / 8
            let ch = h / 9
            let ox = (size.width - w) / 2
            let oy = (size.height - h) / 2

            var path = Path()
            // 横线
            for r in 0..<10 {
                let y = oy + CGFloat(r) * ch
                path.move(to: CGPoint(x: ox, y: y))
                path.addLine(to: CGPoint(x: ox + w, y: y))
            }
            // 竖线（上半场 + 下半场分开，河界中间只有边线连通）
            for c in 0..<9 {
                let x = ox + CGFloat(c) * cw
                if c == 0 || c == 8 {
                    // 边线贯穿
                    path.move(to: CGPoint(x: x, y: oy))
                    path.addLine(to: CGPoint(x: x, y: oy + h))
                } else {
                    // 上半场
                    path.move(to: CGPoint(x: x, y: oy))
                    path.addLine(to: CGPoint(x: x, y: oy + 4 * ch))
                    // 下半场
                    path.move(to: CGPoint(x: x, y: oy + 5 * ch))
                    path.addLine(to: CGPoint(x: x, y: oy + h))
                }
            }
            // 九宫斜线
            for (r1, c1, r2, c2) in [(0,3,2,5), (0,5,2,3), (7,3,9,5), (7,5,9,3)] {
                path.move(to: CGPoint(x: ox + CGFloat(c1)*cw, y: oy + CGFloat(r1)*ch))
                path.addLine(to: CGPoint(x: ox + CGFloat(c2)*cw, y: oy + CGFloat(r2)*ch))
            }

            context.stroke(path, with: .color(theme.lineColor), lineWidth: 1)
        }
        .frame(width: boardSize, height: boardSize * 10 / 9)
    }

    // MARK: - lastMove 高亮

    @ViewBuilder
    private func lastMoveHighlights(boardSize: CGFloat, cellSize: CGFloat) -> some View {
        if let lm = lastMove {
            let w = boardSize * 8 / 9
            let h = boardSize
            let cw = w / 8
            let ch = h / 9
            let ox = boardSize / 2 - w / 2
            let oy = boardSize * 5 / 9 - h / 2

            ForEach([lm.from, lm.to], id: \.self) { pos in
                let row = isFlipped ? (9 - pos.row) : pos.row
                let col = isFlipped ? (8 - pos.col) : pos.col
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                    .position(x: ox + CGFloat(col) * cw, y: oy + CGFloat(row) * ch)
            }
        }
    }

    // MARK: - 棋子层

    @ViewBuilder
    private func piecesLayer(boardSize: CGFloat, cellSize: CGFloat, pieceSize: CGFloat) -> some View {
        let w = boardSize * 8 / 9
        let h = boardSize
        let cw = w / 8
        let ch = h / 9
        let ox = boardSize / 2 - w / 2
        let oy = boardSize * 5 / 9 - h / 2

        ForEach(board.pieces, id: \.id) { piece in
            let row = isFlipped ? (9 - piece.position.row) : piece.position.row
            let col = isFlipped ? (8 - piece.position.col) : piece.position.col

            let isLastFrom = lastMove?.from == piece.position
            let isLastTo = lastMove?.to == piece.position

            Text(piece.displayName)
                .font(.system(size: pieceSize * 0.6, weight: .medium))
                .foregroundStyle(piece.side == .red ? theme.redPieceText : theme.blackPieceText)
                .frame(width: pieceSize, height: pieceSize)
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: theme.pieceFill,
                                center: .center,
                                startRadius: 0,
                                endRadius: pieceSize / 2
                            )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                )
                .overlay(
                    Circle()
                        .stroke(theme.pieceBorder, lineWidth: 1.5)
                )
                .overlay(
                    // lastMove 高亮环
                    Group {
                        if isLastFrom || isLastTo {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2.5)
                        }
                    }
                )
                .position(x: ox + CGFloat(col) * cw, y: oy + CGFloat(row) * ch)
        }
    }
}
