import SwiftUI

/// 回放专用棋盘视图
///
/// 独立于 ChessBoardView / BoardMode enum，避免 enum 持有 @Observable associated value
/// 导致 AG LayoutDescriptor 在 sheet 中递归崩溃。
///
/// 只读模式：渲染棋盘 + 棋子 + 上一步高亮，无交互层。
struct ReplayBoardView: View {
    let viewModel: ReplayViewModel
    var theme: ThemeColors = ThemeManager.shared.colors

    private let gridCols = 8
    private let gridRows = 9
    private let maxCellSize: CGFloat = 80

    #if os(iOS)
    private let maxBoardWidth: CGFloat = 600
    private let maxBoardHeight: CGFloat = 675
    #endif

    var body: some View {
        GeometryReader { geo in
            #if os(iOS)
            let availableWidth = min(geo.size.width, maxBoardWidth)
            let availableHeight = min(geo.size.height, maxBoardHeight)
            #else
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            #endif
            // padding 和 cellSize 循环依赖：一步迭代收敛
            let basePadding = min(availableWidth, availableHeight) * 0.04
            let cellSizeEst = min((availableWidth - basePadding * 2) / CGFloat(gridCols),
                                  (availableHeight - basePadding * 2) / CGFloat(gridRows),
                                  maxCellSize)
            // padding 至少等于棋子半径，防止边缘棋子被裁
            let padding = max(basePadding, cellSizeEst * 0.45)
            // 用最终 padding 重算 cellSize，补偿 padding 增加占用的空间
            let cellSize = min((availableWidth - padding * 2) / CGFloat(gridCols),
                               (availableHeight - padding * 2) / CGFloat(gridRows),
                               maxCellSize)
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
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                // 棋盘线条
                Canvas { context, canvasSize in
                    drawBoardLines(context: &context, size: canvasSize, cellSize: cellSize, padding: padding)
                }

                // 楚河汉界
                riverText(width: boardWidth, cellSize: cellSize, padding: padding)

                // 上一步高亮 + 棋子
                renderOverlays(cellSize: cellSize, padding: padding)
            }
            .frame(width: boardWidth, height: boardHeight)
            .aspectRatio(CGFloat(gridCols) / CGFloat(gridRows), contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func renderOverlays(cellSize: CGFloat, padding: CGFloat) -> some View {
        let board = viewModel.board

        // 上一步高亮
        if let last = viewModel.lastMove {
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: cellSize * 0.5, height: cellSize * 0.5)
                .position(posToCGPoint(last.from, cellSize: cellSize, padding: padding))
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: cellSize * 0.5, height: cellSize * 0.5)
                .position(posToCGPoint(last.to, cellSize: cellSize, padding: padding))
        }

        // 棋子
        ForEach(board.pieces) { piece in
            PieceView(piece: piece, isSelected: false, cellSize: cellSize, theme: theme)
                .position(posToCGPoint(piece.position, cellSize: cellSize, padding: padding))
                .allowsHitTesting(false)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
        }
    }

    // MARK: - 坐标映射

    private func posToCGPoint(_ pos: Position, cellSize: CGFloat, padding: CGFloat) -> CGPoint {
        CGPoint(
            x: padding + CGFloat(pos.col) * cellSize,
            y: padding + CGFloat(pos.row) * cellSize
        )
    }

    // MARK: - 棋盘线条

    private func drawBoardLines(context: inout GraphicsContext, size: CGSize, cellSize: CGFloat, padding: CGFloat) {
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

        drawPalaceDiagonals(path: &path, startRow: 0, startCol: 3, cellSize: cellSize, padding: padding)
        drawPalaceDiagonals(path: &path, startRow: 7, startCol: 3, cellSize: cellSize, padding: padding)

        context.stroke(path, with: .color(theme.lineColor), lineWidth: 1.2)
        drawStarMarks(context: &context, cellSize: cellSize, padding: padding)
    }

    private func drawPalaceDiagonals(path: inout Path, startRow: Int, startCol: Int, cellSize: CGFloat, padding: CGFloat) {
        let x1 = padding + CGFloat(startCol) * cellSize
        let y1 = padding + CGFloat(startRow) * cellSize
        let x2 = padding + CGFloat(startCol + 2) * cellSize
        let y2 = padding + CGFloat(startRow + 2) * cellSize
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        path.move(to: CGPoint(x: x2, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y2))
    }

    private func drawStarMarks(context: inout GraphicsContext, cellSize: CGFloat, padding: CGFloat) {
        let markSize: CGFloat = cellSize * 0.15
        let markGap: CGFloat = cellSize * 0.09

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
    private func riverText(width: CGFloat, cellSize: CGFloat, padding: CGFloat) -> some View {
        let y = padding + 4 * cellSize + cellSize / 2
        HStack(spacing: cellSize * 2) {
            Text("楚  河")
                .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.45))
            Text("汉  界")
                .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.45))
        }
        .foregroundColor(theme.riverTextColor)
        .position(x: width / 2, y: y)
    }
}
