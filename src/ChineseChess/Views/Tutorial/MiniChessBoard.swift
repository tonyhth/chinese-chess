import SwiftUI

// MARK: - MiniChessBoard — 教程专用精简棋盘视图
// 独立实现，不依赖 ChessBoardView，支持 tap-to-select-and-move 交互

struct MiniChessBoard: View {
    let board: Board
    var theme: ThemeColors = ThemeManager.shared.colors
    var enabledSide: Side? = nil  // 限制可操作的方
    var onMove: ((Position, Position) -> Void)? = nil

    @State private var selectedPosition: Position? = nil
    @State private var legalTargets: [Position] = []
    @State private var illegalTarget: Position? = nil
    @State private var illegalTask: Task<Void, Never>? = nil

    var body: some View {
        GeometryReader { geo in
            let sizing = BoardSizing.calculate(width: geo.size.width, height: geo.size.height)
            let cellSize = sizing.cellSize
            let padding = sizing.padding

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
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)

                // 棋盘线条
                Canvas { context, _ in
                    drawBoardLines(context: &context, cellSize: cellSize, padding: padding)
                }

                // 楚河汉界
                let yRiver = padding + 4 * cellSize + cellSize / 2
                HStack(spacing: cellSize * 2) {
                    Text("楚  河")
                        .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.4))
                    Text("汉  界")
                        .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.4))
                }
                .foregroundColor(theme.riverTextColor)
                .position(x: sizing.boardWidth / 2, y: yRiver)

                // 合法走法提示
                ForEach(legalTargets, id: \.self) { pos in
                    Circle()
                        .fill(board.piece(at: pos) != nil ? Color.red.opacity(0.4) : Color.green.opacity(0.4))
                        .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                        .position(BoardSizing.posToCGPoint(pos, cellSize: cellSize, padding: padding))
                }

                // 选中高亮
                if let selected = selectedPosition {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                        .position(BoardSizing.posToCGPoint(selected, cellSize: cellSize, padding: padding))
                }

                // 棋子
                ForEach(board.pieces) { piece in
                    PieceView(piece: piece, isSelected: selectedPosition == piece.position,
                              cellSize: cellSize, theme: theme)
                        .position(BoardSizing.posToCGPoint(piece.position, cellSize: cellSize, padding: padding))
                        .allowsHitTesting(false)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
                }

                // 非法走法提示
                if let illegal = illegalTarget {
                    ZStack {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                        Image(systemName: "xmark")
                            .font(.system(size: cellSize * 0.3, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .position(BoardSizing.posToCGPoint(illegal, cellSize: cellSize, padding: padding))
                    .opacity(0.8)
                    .transition(.opacity)
                }

                // 交互层
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, cellSize: cellSize, padding: padding)
                    }
            }
            .frame(width: sizing.boardWidth, height: sizing.boardHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows), contentMode: .fit)
    }

    // MARK: - 交互

    private func handleTap(at point: CGPoint, cellSize: CGFloat, padding: CGFloat) {
        guard let pos = BoardSizing.cgPointToPos(point, cellSize: cellSize, padding: padding) else { return }

        // 已有选中棋子
        if let selected = selectedPosition {
            if legalTargets.contains(pos) {
                // 合法目标 → 执行走子
                onMove?(selected, pos)
                selectedPosition = nil
                legalTargets = []
            } else if canSelect(at: pos) {
                // 切换选中
                selectPiece(at: pos)
            } else {
                // 非法目标
                showIllegal(at: pos)
            }
        } else {
            // 无选中 → 尝试选中
            if canSelect(at: pos) {
                selectPiece(at: pos)
            }
        }
    }

    private func canSelect(at pos: Position) -> Bool {
        guard let piece = board.piece(at: pos) else { return false }
        if let side = enabledSide, piece.side != side { return false }
        return true
    }

    private func selectPiece(at pos: Position) {
        guard let piece = board.piece(at: pos) else { return }
        selectedPosition = pos
        legalTargets = MoveValidator.legalMoves(for: piece, on: board).map { $0.to }
    }

    private func showIllegal(at pos: Position) {
        illegalTask?.cancel()
        illegalTarget = pos
        illegalTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { illegalTarget = nil }
        }
    }

    // MARK: - 棋盘线条

    private func drawBoardLines(context: inout GraphicsContext, cellSize: CGFloat, padding: CGFloat) {
        var path = Path()

        // 横线
        for row in 0...BoardSizing.gridRows {
            let y = padding + CGFloat(row) * cellSize
            path.move(to: CGPoint(x: padding, y: y))
            path.addLine(to: CGPoint(x: padding + CGFloat(BoardSizing.gridCols) * cellSize, y: y))
        }

        // 竖线（上半）
        for col in 0...BoardSizing.gridCols {
            let x = padding + CGFloat(col) * cellSize
            path.move(to: CGPoint(x: x, y: padding))
            path.addLine(to: CGPoint(x: x, y: padding + 4 * cellSize))
        }
        // 竖线（下半）
        for col in 0...BoardSizing.gridCols {
            let x = padding + CGFloat(col) * cellSize
            path.move(to: CGPoint(x: x, y: padding + 5 * cellSize))
            path.addLine(to: CGPoint(x: x, y: padding + 9 * cellSize))
        }

        // 左右边框连河
        path.move(to: CGPoint(x: padding, y: padding + 4 * cellSize))
        path.addLine(to: CGPoint(x: padding, y: padding + 5 * cellSize))
        path.move(to: CGPoint(x: padding + 8 * cellSize, y: padding + 4 * cellSize))
        path.addLine(to: CGPoint(x: padding + 8 * cellSize, y: padding + 5 * cellSize))

        // 九宫对角线
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

    // MARK: - 公开方法（供父视图重置）

    func resetSelection() {
        selectedPosition = nil
        legalTargets = []
    }
}
