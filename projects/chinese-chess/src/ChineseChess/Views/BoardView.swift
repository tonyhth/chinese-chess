import SwiftUI

struct BoardView: View {
    let viewModel: GameViewModel
    var theme: ThemeColors = ThemeManager.shared.colors

    private let gridCols = 8
    private let gridRows = 9
    private let padding: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = (size - padding * 2) / CGFloat(max(gridCols, gridRows))
            let boardWidth = cellSize * CGFloat(gridCols) + padding * 2
            let boardHeight = cellSize * CGFloat(gridRows) + padding * 2

            ZStack {
                // 棋盘背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: theme.boardBackground,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: boardWidth, height: boardHeight)
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                // 棋盘线条
                Canvas { context, canvasSize in
                    drawBoardLines(context: &context, size: canvasSize, cellSize: cellSize)
                }
                .frame(width: boardWidth, height: boardHeight)

                // 楚河汉界
                riverText(width: boardWidth, cellSize: cellSize)

                // 可走位置标记 + 棋子层
                ZStack {
                    // 可走位置标记
                    ForEach(viewModel.legalMovesForSelected, id: \.self) { pos in
                        let x = padding + CGFloat(pos.col) * cellSize
                        let y = padding + CGFloat(pos.row) * cellSize
                        Circle()
                            .fill(Color.green.opacity(0.4))
                            .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                            .position(x: x, y: y)
                    }

                    // 棋子
                    ForEach(viewModel.board.pieces) { piece in
                        let x = padding + CGFloat(piece.position.col) * cellSize
                        let y = padding + CGFloat(piece.position.row) * cellSize
                        let isSelected = viewModel.selectedPosition == piece.position

                        PieceView(piece: piece, isSelected: isSelected, boardSize: CGSize(width: boardWidth, height: boardHeight), theme: theme)
                            .position(x: x, y: y)
                            .allowsHitTesting(false)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
                    }
                }
                .frame(width: boardWidth, height: boardHeight)
                .allowsHitTesting(false)

                // 交互层
                Color.clear
                    .frame(width: boardWidth, height: boardHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let loc = value.startLocation
                                let col = Int(round((loc.x - padding) / cellSize))
                                let row = Int(round((loc.y - padding) / cellSize))
                                guard row >= 0, row <= 9, col >= 0, col <= 8 else { return }
                                viewModel.selectPiece(at: Position(row: row, col: col))
                            }
                    )
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - 棋盘线条

    private func drawBoardLines(context: inout GraphicsContext, size: CGSize, cellSize: CGFloat) {
        var path = Path()

        for row in 0...gridRows {
            let y = padding + CGFloat(row) * cellSize
            path.move(to: CGPoint(x: padding, y: y))
            path.addLine(to: CGPoint(x: padding + CGFloat(gridCols) * cellSize, y: y))
        }

        for col in 0...gridCols {
            let x = padding + CGFloat(col) * cellSize
            path.move(to: CGPoint(x: x, y: padding))
            path.addLine(to: CGPoint(x: x, y: padding + 4 * cellSize))
        }
        for col in 0...gridCols {
            let x = padding + CGFloat(col) * cellSize
            path.move(to: CGPoint(x: x, y: padding + 5 * cellSize))
            path.addLine(to: CGPoint(x: x, y: padding + 9 * cellSize))
        }
        path.move(to: CGPoint(x: padding, y: padding + 4 * cellSize))
        path.addLine(to: CGPoint(x: padding, y: padding + 5 * cellSize))
        path.move(to: CGPoint(x: padding + 8 * cellSize, y: padding + 4 * cellSize))
        path.addLine(to: CGPoint(x: padding + 8 * cellSize, y: padding + 5 * cellSize))

        drawPalaceDiagonals(path: &path, startRow: 0, startCol: 3, cellSize: cellSize)
        drawPalaceDiagonals(path: &path, startRow: 7, startCol: 3, cellSize: cellSize)

        context.stroke(path, with: .color(theme.lineColor), lineWidth: 1.2)
        drawStarMarks(context: &context, cellSize: cellSize)
    }

    private func drawPalaceDiagonals(path: inout Path, startRow: Int, startCol: Int, cellSize: CGFloat) {
        let x1 = padding + CGFloat(startCol) * cellSize
        let y1 = padding + CGFloat(startRow) * cellSize
        let x2 = padding + CGFloat(startCol + 2) * cellSize
        let y2 = padding + CGFloat(startRow + 2) * cellSize
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        path.move(to: CGPoint(x: x2, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y2))
    }

    private func drawStarMarks(context: inout GraphicsContext, cellSize: CGFloat) {
        let markSize: CGFloat = 5
        let markGap: CGFloat = 3

        let cannonPositions: [(Int, Int)] = [(2, 1), (2, 7), (7, 1), (7, 7)]
        let soldierPositions: [(Int, Int)] = [(3, 0), (3, 2), (3, 4), (3, 6), (3, 8),
                                               (6, 0), (6, 2), (6, 4), (6, 6), (6, 8)]

        for (row, col) in cannonPositions + soldierPositions {
            let cx = padding + CGFloat(col) * cellSize
            let cy = padding + CGFloat(row) * cellSize
            var markPath = Path()

            if col > 0 {
                markPath.move(to: CGPoint(x: cx - markGap, y: cy - markGap - markSize))
                markPath.addLine(to: CGPoint(x: cx - markGap, y: cy - markGap))
                markPath.addLine(to: CGPoint(x: cx - markGap - markSize, y: cy - markGap))
                markPath.move(to: CGPoint(x: cx - markGap, y: cy + markGap + markSize))
                markPath.addLine(to: CGPoint(x: cx - markGap, y: cy + markGap))
                markPath.addLine(to: CGPoint(x: cx - markGap - markSize, y: cy + markGap))
            }
            if col < 8 {
                markPath.move(to: CGPoint(x: cx + markGap, y: cy - markGap - markSize))
                markPath.addLine(to: CGPoint(x: cx + markGap, y: cy - markGap))
                markPath.addLine(to: CGPoint(x: cx + markGap + markSize, y: cy - markGap))
                markPath.move(to: CGPoint(x: cx + markGap, y: cy + markGap + markSize))
                markPath.addLine(to: CGPoint(x: cx + markGap, y: cy + markGap))
                markPath.addLine(to: CGPoint(x: cx + markGap + markSize, y: cy + markGap))
            }

            context.stroke(markPath, with: .color(theme.lineColor), lineWidth: 1)
        }
    }

    // MARK: - 楚河汉界

    @ViewBuilder
    private func riverText(width: CGFloat, cellSize: CGFloat) -> some View {
        let y = padding + 4 * cellSize + cellSize / 2
        HStack(spacing: cellSize * 2) {
            Text("楚  河")
                .font(.custom("STKaiti", size: cellSize * 0.45))
            Text("汉  界")
                .font(.custom("STKaiti", size: cellSize * 0.45))
        }
        .foregroundColor(theme.riverTextColor)
        .position(x: width / 2, y: y)
    }
}
