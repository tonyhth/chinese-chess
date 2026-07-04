import SwiftUI

// MARK: - 棋盘模式

enum BoardMode {
    case playGame(GameViewModel)
    case playPuzzle(PuzzleViewModel)
}

// MARK: - 统一棋盘视图

/// 合并 BoardView + ChessBoardCanvas 的统一棋盘组件
/// 三种模式共享渲染逻辑，交互根据 mode 分发
struct ChessBoardView: View {
    let mode: BoardMode
    var theme: ThemeColors = ThemeManager.shared.colors
    var isFlipped: Bool = false

    // MARK: - 拖拽状态

    /// 正在拖拽的棋子
    @State private var dragPiece: Piece? = nil
    /// 拖拽偏移量
    @State private var dragOffset: CGSize = .zero
    /// 拖拽起始位置
    @State private var dragStartPosition: Position? = nil
    /// 是否已进入拖拽模式（移动距离 > 5pt）
    @State private var isDragging: Bool = false

    // MARK: - 非法走法提示状态

    /// 非法目标位置
    @State private var illegalTarget: Position? = nil
    /// 非法提示自动消失任务
    @State private var illegalFlashTask: Task<Void, Never>? = nil

    private let l10n = L10n.shared

    var body: some View {
        GeometryReader { geo in
            let sizing = BoardSizing.calculate(width: geo.size.width, height: geo.size.height)
            let cellSize = sizing.cellSize
            let padding = sizing.padding
            let boardWidth = sizing.boardWidth
            let boardHeight = sizing.boardHeight

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

                // 交互层
                Color.clear
                    .frame(width: boardWidth, height: boardHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDragChanged(
                                    startLocation: value.startLocation,
                                    translation: value.translation,
                                    cellSize: cellSize,
                                    padding: padding
                                )
                            }
                            .onEnded { value in
                                handleDragEnded(
                                    startLocation: value.startLocation,
                                    translation: value.translation,
                                    cellSize: cellSize,
                                    padding: padding
                                )
                            }
                    )
            }
            .frame(width: boardWidth, height: boardHeight)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(l10n.t("accessibility.board"))
        }
        .aspectRatio(CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows), contentMode: .fit)
    }

    // MARK: - Mode helpers

    private var board: Board {
        switch mode {
        case .playGame(let vm): return vm.board
        case .playPuzzle(let vm): return vm.board
        }
    }

    private var selectedPosition: Position? {
        switch mode {
        case .playGame(let vm): return vm.selectedPosition
        case .playPuzzle(let vm): return vm.selectedPosition
        }
    }

    private var legalMoves: [Position] {
        switch mode {
        case .playGame(let vm): return vm.legalMovesForSelected
        case .playPuzzle(let vm): return vm.legalMovesForSelected
        }
    }

    private var hintMove: (from: Position, to: Position)? {
        switch mode {
        case .playGame(let vm): return vm.hintMove
        case .playPuzzle(let vm): return vm.hintMove
        }
    }

    private var isInCheck: Bool {
        switch mode {
        case .playGame(let vm): return vm.isInCheck
        case .playPuzzle(let vm): return vm.isInCheck
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func renderOverlays(cellSize: CGFloat, padding: CGFloat) -> some View {
        // 被将军高亮：被将方的帅/将格子加红色闪烁圈
        if isInCheck, let kingPos = board.generalPosition(of: board.currentTurn) {
            Circle()
                .stroke(Color.red, lineWidth: 3)
                .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                .position(posToCGPoint(kingPos, cellSize: cellSize, padding: padding))
                .modifier(CheckPulseModifier())
        }

        // 提示高亮（蓝色）
        // 提示高亮移至棋子之后渲染（避免被棋子遮挡）

        // 合法走法提示
        ForEach(legalMoves, id: \.self) { pos in
            Circle()
                .fill(board.piece(at: pos) != nil ? Color.red.opacity(0.4) : Color.green.opacity(0.4))
                .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                .position(posToCGPoint(pos, cellSize: cellSize, padding: padding))
                .accessibilityLabel(l10n.t("board.legalMove"))
                .accessibilityHint(String(format: l10n.t("board.legalMoveHint"), pos.col, pos.row))
        }

        // 拖拽时显示当前拖拽棋子的合法走法
        if let startPos = dragStartPosition, isDragging {
            let dragLegalMoves = legalMovesForPiece(at: startPos)
            ForEach(dragLegalMoves, id: \.self) { pos in
                Circle()
                    .fill(board.piece(at: pos) != nil ? Color.red.opacity(0.4) : Color.green.opacity(0.4))
                    .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                    .position(posToCGPoint(pos, cellSize: cellSize, padding: padding))
            }
        }

        // 棋子
        ForEach(board.pieces) { piece in
            let isSelected = selectedPosition == piece.position
            let isPieceDragging = dragPiece?.id == piece.id

            if isPieceDragging {
                // 原位置显示半透明幽灵
                PieceView(piece: piece, isSelected: false, cellSize: cellSize, theme: theme)
                    .opacity(0.3)
                    .position(posToCGPoint(piece.position, cellSize: cellSize, padding: padding))
                    .allowsHitTesting(false)
            } else {
                PieceView(piece: piece, isSelected: isSelected, cellSize: cellSize, theme: theme)
                    .position(posToCGPoint(piece.position, cellSize: cellSize, padding: padding))
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFlipped)
            }
        }

        // 拖拽中的棋子（跟随手指/鼠标）
        if let dragPiece = dragPiece, let startPos = dragStartPosition, isDragging {
            PieceView(piece: dragPiece, isSelected: true, cellSize: cellSize, theme: theme)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 2, y: 4)
                .scaleEffect(1.15)
                .position(
                    CGPoint(
                        x: posToCGPoint(startPos, cellSize: cellSize, padding: padding).x + dragOffset.width,
                        y: posToCGPoint(startPos, cellSize: cellSize, padding: padding).y + dragOffset.height
                    )
                )
                .allowsHitTesting(false)
        }

        // 提示高亮（蓝色）— 渲染在棋子之上，避免被吃子位置棋子遮挡
        if let hint = hintMove {
            // from: 蓝色空心圆圈（标记起始棋子）
            Circle()
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                .position(posToCGPoint(hint.from, cellSize: cellSize, padding: padding))
            // to: 区分空位/吃子
            if board.piece(at: hint.to) != nil {
                // 吃子：蓝色空心圆圈（与 from 同样式，叠在棋子上方）
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                    .position(posToCGPoint(hint.to, cellSize: cellSize, padding: padding))
            } else {
                // 空位：蓝色实心圆点
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: cellSize * 0.35, height: cellSize * 0.35)
                    .position(posToCGPoint(hint.to, cellSize: cellSize, padding: padding))
            }
        }

        // 非法走法提示：红色圆圈 + 叉号
        if let illegal = illegalTarget {
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                Image(systemName: "xmark")
                    .font(.system(size: cellSize * 0.3, weight: .bold))
                    .foregroundColor(.red)
            }
            .position(posToCGPoint(illegal, cellSize: cellSize, padding: padding))
            .opacity(0.8)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: illegalTarget)
        }
    }

    // MARK: - 坐标映射

    /// Position → CGPoint，用于 ZStack 内 .position() 定位
    /// ZStack 内 .position() 坐标原点在 ZStack 左上角
    private func posToCGPoint(_ pos: Position, cellSize: CGFloat, padding: CGFloat) -> CGPoint {
        BoardSizing.posToCGPoint(pos, cellSize: cellSize, padding: padding, flipped: isFlipped)
    }

    /// CGPoint → Position，用于交互层点击坐标转换
    /// onTapGesture 坐标相对于视图本地坐标系（左上角为原点）
    private func cgPointToPos(_ point: CGPoint, cellSize: CGFloat, padding: CGFloat) -> Position? {
        BoardSizing.cgPointToPos(point, cellSize: cellSize, padding: padding, flipped: isFlipped)
    }

    // MARK: - 拖拽手势处理

    /// 判断位置上是否为玩家可操作的棋子
    private func isPlayerPiece(at pos: Position) -> Bool {
        guard let piece = board.piece(at: pos) else { return false }
        switch mode {
        case .playGame(let vm): return piece.side == vm.humanSide
        case .playPuzzle(let vm): return piece.side == vm.playerSide
        }
    }

    /// 获取某个位置棋子的合法目标
    private func legalMovesForPiece(at pos: Position) -> [Position] {
        guard let piece = board.piece(at: pos) else { return [] }
        return MoveValidator.legalMoves(for: piece, on: board).map { $0.to }
    }

    /// 判断当前是否可以交互（非思考中、对局进行中）
    private var canInteract: Bool {
        switch mode {
        case .playGame(let vm): return !vm.isThinking && vm.gameState == .playing
        case .playPuzzle(let vm): return !vm.isThinking && vm.gameState == .playing
        }
    }

    private func handleDragChanged(startLocation: CGPoint, translation: CGSize,
                                     cellSize: CGFloat, padding: CGFloat) {
        guard canInteract else { return }

        let dx = abs(translation.width)
        let dy = abs(translation.height)

        // 首次进入拖拽：检测起始位置是否是己方棋子
        if dragPiece == nil {
            guard let pos = cgPointToPos(startLocation, cellSize: cellSize, padding: padding),
                  isPlayerPiece(at: pos) else { return }
            dragPiece = board.piece(at: pos)
            dragStartPosition = pos
            dragOffset = .zero
            isDragging = false
        }

        // 移动距离超过阈值才进入拖拽模式
        if !isDragging && (dx > 5 || dy > 5) {
            isDragging = true
        }

        if isDragging {
            dragOffset = translation
        }
    }

    private func handleDragEnded(startLocation: CGPoint, translation: CGSize,
                                  cellSize: CGFloat, padding: CGFloat) {
        guard canInteract else {
            resetDragState()
            return
        }

        let dx = abs(translation.width)
        let dy = abs(translation.height)

        // 移动距离 ≤ 5pt → 视为点击
        if dx <= 5 && dy <= 5 {
            resetDragState()
            handleTap(at: startLocation, cellSize: cellSize, padding: padding)
            return
        }

        // 拖拽结束
        guard let from = dragStartPosition, dragPiece != nil else {
            resetDragState()
            return
        }

        let finalLocation = CGPoint(
            x: startLocation.x + translation.width,
            y: startLocation.y + translation.height
        )

        guard let to = cgPointToPos(finalLocation, cellSize: cellSize, padding: padding) else {
            // 松手在棋盘外
            resetDragState()
            return
        }

        let legalTargets = legalMovesForPiece(at: from)
        if legalTargets.contains(to) {
            // 合法走子
            switch mode {
            case .playGame(let vm): vm.movePiece(from: from, to: to)
            case .playPuzzle(let vm): vm.movePiece(from: from, to: to)
            }
        } else {
            // 非法目标
            showIllegalHint(at: to)
        }

        resetDragState()
    }

    private func resetDragState() {
        dragPiece = nil
        dragOffset = .zero
        dragStartPosition = nil
        isDragging = false
    }

    // MARK: - 非法走法提示

    private func showIllegalHint(at pos: Position) {
        illegalFlashTask?.cancel()
        illegalTarget = pos
        triggerHapticFeedback()
        illegalFlashTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
            guard !Task.isCancelled else { return }
            await MainActor.run {
                illegalTarget = nil
            }
        }
    }

    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    // MARK: - 交互分发

    private func handleTap(at point: CGPoint, cellSize: CGFloat, padding: CGFloat) {
        guard let pos = cgPointToPos(point, cellSize: cellSize, padding: padding) else { return }
        switch mode {
        case .playGame(let vm):
            // 已有选中棋子，且点击的不是合法目标 → 非法提示
            if let _ = vm.selectedPosition, !vm.legalMovesForSelected.contains(pos) {
                // 点击空位或对方不可吃棋子（不是己方棋子切换）
                if !isPlayerPiece(at: pos) {
                    showIllegalHint(at: pos)
                    return  // 非法提示后保留选中，不执行 selectPiece
                }
            }
            vm.selectPiece(at: pos)
        case .playPuzzle(let vm):
            if let _ = vm.selectedPosition, !vm.legalMovesForSelected.contains(pos) {
                if !isPlayerPiece(at: pos) {
                    showIllegalHint(at: pos)
                    return  // 非法提示后保留选中，不执行 handleSquareTap
                }
            }
            vm.handleSquareTap(at: pos)
        }
    }

    // MARK: - 棋盘线条

    private func drawBoardLines(context: inout GraphicsContext, size: CGSize, cellSize: CGFloat, padding: CGFloat) {
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

    // MARK: - 楚河汉界

    @ViewBuilder
    private func riverText(width: CGFloat, cellSize: CGFloat, padding: CGFloat) -> some View {
        let y = padding + 4 * cellSize + cellSize / 2
        HStack(spacing: cellSize * 2) {
            // 翻转时顺序对调："汉 界"在左，"楚 河"在右
            if isFlipped {
                Text("汉  界")
                    .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.45))
                Text("楚  河")
                    .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.45))
            } else {
                Text("楚  河")
                    .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.45))
                Text("汉  界")
                    .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.45))
            }
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
