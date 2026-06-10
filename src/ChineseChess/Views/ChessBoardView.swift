import SwiftUI

// MARK: - 棋盘模式

enum BoardMode {
    case playGame(GameViewModel)
    case playPuzzle(PuzzleViewModel)
    case replay(ReplayViewModel)
}

// MARK: - 统一棋盘视图

/// 合并 BoardView + ChessBoardCanvas 的统一棋盘组件
/// 三种模式共享渲染逻辑，交互根据 mode 分发
struct ChessBoardView: View {
    let mode: BoardMode
    var theme: ThemeColors = ThemeManager.shared.colors

    // 网格常量
    private let gridCols = 8  // 8个间距，9条竖线
    private let gridRows = 9  // 9个间距，10条横线

    // 最大 cellSize，防止窗口过大时棋盘无限放大
    private let maxCellSize: CGFloat = 80

    // iOS 大屏棋盘最大尺寸约束
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
            let padding = max(10, min(availableWidth, availableHeight) * 0.04)
            let cellSizeW = (availableWidth - padding * 2) / CGFloat(gridCols)
            let cellSizeH = (availableHeight - padding * 2) / CGFloat(gridRows)
            let cellSize = min(cellSizeW, cellSizeH, maxCellSize)
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

                // 高亮 + 棋子 + 提示
                renderOverlays(cellSize: cellSize, padding: padding)

                // 交互层（仅 playGame 和 playPuzzle）
                if !isReadOnly {
                    Color.clear
                        .frame(width: boardWidth, height: boardHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, cellSize: cellSize, padding: padding)
                        }
                }
            }
            .frame(width: boardWidth, height: boardHeight)
        }
        .aspectRatio(CGFloat(gridCols) / CGFloat(gridRows), contentMode: .fit)
    }

    // MARK: - Mode helpers

    private var isReadOnly: Bool {
        if case .replay = mode { return true }
        return false
    }

    private var board: Board {
        switch mode {
        case .playGame(let vm): return vm.board
        case .playPuzzle(let vm): return vm.board
        case .replay(let vm): return vm.board
        }
    }

    private var selectedPosition: Position? {
        switch mode {
        case .playGame(let vm): return vm.selectedPosition
        case .playPuzzle(let vm): return vm.selectedPosition
        case .replay: return nil
        }
    }

    private var legalMoves: [Position] {
        switch mode {
        case .playGame(let vm): return vm.legalMovesForSelected
        case .playPuzzle(let vm): return vm.legalMovesForSelected
        case .replay: return []
        }
    }

    private var hintMove: (from: Position, to: Position)? {
        switch mode {
        case .playGame(let vm): return vm.hintMove
        case .playPuzzle(let vm): return vm.hintMove
        case .replay: return nil
        }
    }

    private var isInCheck: Bool {
        switch mode {
        case .playGame(let vm): return vm.isInCheck
        case .playPuzzle(let vm): return vm.isInCheck
        case .replay: return false
        }
    }

    private var lastMove: (from: Position, to: Position)? {
        if case .replay(let vm) = mode { return vm.lastMove }
        return nil
    }

    // MARK: - Overlays

    @ViewBuilder
    private func renderOverlays(cellSize: CGFloat, padding: CGFloat) -> some View {
        // 上一步高亮
        if let last = lastMove {
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: cellSize * 0.5, height: cellSize * 0.5)
                .position(posToCGPoint(last.from, cellSize: cellSize, padding: padding))
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: cellSize * 0.5, height: cellSize * 0.5)
                .position(posToCGPoint(last.to, cellSize: cellSize, padding: padding))
        }

        // 被将军高亮：被将方的帅/将格子加红色闪烁圈
        if !isReadOnly {
            if isInCheck, let kingPos = board.generalPosition(of: board.currentTurn) {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                    .position(posToCGPoint(kingPos, cellSize: cellSize, padding: padding))
                    .modifier(CheckPulseModifier())
            }
        }

        // 提示高亮（蓝色）
        if let hint = hintMove {
            Circle()
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                .position(posToCGPoint(hint.from, cellSize: cellSize, padding: padding))
            Circle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: cellSize * 0.35, height: cellSize * 0.35)
                .position(posToCGPoint(hint.to, cellSize: cellSize, padding: padding))
        }

        // 合法走法提示
        ForEach(legalMoves, id: \.self) { pos in
            Circle()
                .fill(board.piece(at: pos) != nil ? Color.red.opacity(0.4) : Color.green.opacity(0.4))
                .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                .position(posToCGPoint(pos, cellSize: cellSize, padding: padding))
        }

        // 棋子
        ForEach(board.pieces) { piece in
            let isSelected = selectedPosition == piece.position
            PieceView(piece: piece, isSelected: isSelected, cellSize: cellSize, theme: theme)
                .position(posToCGPoint(piece.position, cellSize: cellSize, padding: padding))
                .allowsHitTesting(false)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
        }
    }

    // MARK: - 坐标映射

    /// Position → CGPoint，用于 ZStack 内 .position() 定位
    /// ZStack 内 .position() 坐标原点在 ZStack 左上角
    private func posToCGPoint(_ pos: Position, cellSize: CGFloat, padding: CGFloat) -> CGPoint {
        CGPoint(
            x: padding + CGFloat(pos.col) * cellSize,
            y: padding + CGFloat(pos.row) * cellSize
        )
    }

    /// CGPoint → Position，用于交互层点击坐标转换
    /// onTapGesture 坐标相对于视图本地坐标系（左上角为原点）
    private func cgPointToPos(_ point: CGPoint, cellSize: CGFloat, padding: CGFloat) -> Position? {
        let col = Int(round((point.x - padding) / cellSize))
        let row = Int(round((point.y - padding) / cellSize))
        guard row >= 0, row <= 9, col >= 0, col <= 8 else { return nil }
        return Position(row: row, col: col)
    }

    // MARK: - 交互分发

    private func handleTap(at point: CGPoint, cellSize: CGFloat, padding: CGFloat) {
        guard let pos = cgPointToPos(point, cellSize: cellSize, padding: padding) else { return }
        switch mode {
        case .playGame(let vm):
            vm.selectPiece(at: pos)
        case .playPuzzle(let vm):
            vm.handleSquareTap(at: pos)
        case .replay:
            break
        }
    }

    // MARK: - 棋盘线条

    private func drawBoardLines(context: inout GraphicsContext, size: CGSize, cellSize: CGFloat, padding: CGFloat) {
        var path = Path()

        // 横线
        for row in 0...gridRows {
            let y = padding + CGFloat(row) * cellSize
            path.move(to: CGPoint(x: padding, y: y))
            path.addLine(to: CGPoint(x: padding + CGFloat(gridCols) * cellSize, y: y))
        }

        // 竖线（上半）
        for col in 0...gridCols {
            let x = padding + CGFloat(col) * cellSize
            path.move(to: CGPoint(x: x, y: padding))
            path.addLine(to: CGPoint(x: x, y: padding + 4 * cellSize))
        }
        // 竖线（下半）
        for col in 0...gridCols {
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

// MARK: - 将军闪烁动画

struct CheckPulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
