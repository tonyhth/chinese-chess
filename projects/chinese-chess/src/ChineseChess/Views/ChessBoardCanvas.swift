import SwiftUI

/// 共享棋盘渲染组件——画线 + 棋子 + 选中/合法走法高亮
/// BoardView、PuzzlePlayView、ReplayView 共用
struct ChessBoardCanvas: View {
    let board: Board
    let boardSize: CGFloat
    let selectedPosition: Position?
    let legalMoves: [Position]
    let lastMove: (from: Position, to: Position)?
    var theme: ThemeColors = ThemeManager.shared.colors

    private var cellSize: CGFloat { boardSize / 9 }

    var body: some View {
        ZStack {
            // 棋盘底色 + 线条
            boardGrid

            // 上一步高亮
            if let last = lastMove {
                moveHighlight(from: last.from, to: last.to)
            }

            // 合法走法提示
            ForEach(legalMoves, id: \.self) { pos in
                Circle()
                    .fill(board.piece(at: pos) != nil ? Color.red.opacity(0.4) : Color.green.opacity(0.4))
                    .frame(width: cellSize * 0.4, height: cellSize * 0.4)
                    .position(posToCGPoint(pos))
            }

            // 棋子
            ForEach(board.pieces) { piece in
                PieceView(
                    piece: piece,
                    isSelected: selectedPosition == piece.position,
                    boardSize: CGSize(width: boardSize, height: boardSize * 10 / 9),
                    theme: theme
                )
                .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                .position(posToCGPoint(piece.position))
            }
        }
        .frame(width: boardSize, height: boardSize * 10 / 9)
    }

    // MARK: - 棋盘网格

    @ViewBuilder
    private var boardGrid: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: theme.boardBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let cellW = w / 8
                    let cellH = h / 9

                    var path = Path()
                    // 横线
                    for row in 0...9 {
                        let y = CGFloat(row) * cellH
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    // 竖线
                    for col in 0...8 {
                        let x = CGFloat(col) * cellW
                        path.move(to: CGPoint(x: x, y: 0))
                        if col == 0 || col == 8 {
                            path.addLine(to: CGPoint(x: x, y: h))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: 4 * cellH))
                            path.move(to: CGPoint(x: x, y: 5 * cellH))
                            path.addLine(to: CGPoint(x: x, y: h))
                        }
                    }
                    // 九宫对角线
                    let palaceLines: [(Int, Int, Int, Int)] = [
                        (3, 0, 5, 2), (5, 0, 3, 2),
                        (3, 7, 5, 9), (5, 7, 3, 9)
                    ]
                    for (c1, r1, c2, r2) in palaceLines {
                        path.move(to: CGPoint(x: CGFloat(c1) * cellW, y: CGFloat(r1) * cellH))
                        path.addLine(to: CGPoint(x: CGFloat(c2) * cellW, y: CGFloat(r2) * cellH))
                    }

                    context.stroke(path, with: .color(theme.lineColor), lineWidth: 1)
                }
            )
    }

    // MARK: - 走法高亮

    @ViewBuilder
    private func moveHighlight(from: Position, to: Position) -> some View {
        Circle()
            .fill(Color.yellow.opacity(0.3))
            .frame(width: cellSize * 0.5, height: cellSize * 0.5)
            .position(posToCGPoint(from))
        Circle()
            .fill(Color.green.opacity(0.3))
            .frame(width: cellSize * 0.5, height: cellSize * 0.5)
            .position(posToCGPoint(to))
    }

    // MARK: - 坐标转换

    private func posToCGPoint(_ pos: Position) -> CGPoint {
        CGPoint(
            x: CGFloat(pos.col) * cellSize + cellSize / 2,
            y: CGFloat(pos.row) * cellSize + cellSize / 2
        )
    }
}
