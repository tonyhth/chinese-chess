import SwiftUI

struct PuzzleSelectView: View {
    @State private var selectedCategory: String?
    @State private var selectedPuzzle: Puzzle?
    @State private var showPuzzle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("残局闯关")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // 分类选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryButton(title: "全部", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(PuzzleStore.shared.categories, id: \.self) { cat in
                        CategoryButton(title: cat, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
            }

            // 残局列表
            let list = filteredPuzzles
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(list) { puzzle in
                        PuzzleRow(puzzle: puzzle, progress: PuzzleStore.shared.progress(for: puzzle.id)) {
                            selectedPuzzle = puzzle
                            showPuzzle = true
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(8)
        .sheet(isPresented: $showPuzzle) {
            if let puzzle = selectedPuzzle {
                PuzzlePlayView(puzzle: puzzle)
            }
        }
    }

    private var filteredPuzzles: [Puzzle] {
        guard let cat = selectedCategory else {
            return PuzzleStore.shared.puzzles
        }
        return PuzzleStore.shared.puzzles.filter { $0.category == cat }
    }
}

// MARK: - 分类按钮

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.brown : Color.clear)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 残局行

struct PuzzleRow: View {
    let puzzle: Puzzle
    let progress: PuzzleProgress?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text(puzzle.description)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // 星级
                HStack(spacing: 2) {
                    ForEach(1...puzzle.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }

                // 完成标记
                if progress?.isCompleted == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
            }
            .padding(10)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 残局闯关视图

struct PuzzlePlayView: View {
    let puzzle: Puzzle
    @State private var viewModel: PuzzleViewModel
    @State private var selectedPosition: Position?
    @State private var legalMovesForSelected: [Position] = []
    @Environment(\.dismiss) private var dismiss

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self._viewModel = State(initialValue: PuzzleViewModel(puzzle: puzzle))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button("返回") { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Text(puzzle.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(viewModel.gameState == .success ? "通关 ✅" : "\(viewModel.gameMoves.count)/\(puzzle.maxMoves)")
                    .font(.system(size: 13))
                    .foregroundColor(viewModel.gameState == .success ? .green : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))

            // 棋盘（复用渲染，交互独立）
            puzzleBoardView
                .padding()

            // 操作栏
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.undoMove()
                    selectedPosition = nil
                    legalMovesForSelected = []
                }) {
                    Label("悔棋", systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.isThinking)
                .buttonStyle(.bordered)
                .tint(.brown)

                Button(action: { viewModel.showHint() }) {
                    Label("提示", systemImage: "lightbulb")
                }
                .buttonStyle(.bordered)
                .tint(.brown)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 提示显示
            if let hint = viewModel.currentHint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .padding(.horizontal, 16)
                    .onTapGesture { viewModel.dismissHint() }
            }

            // 棋谱
            if !viewModel.gameMoves.isEmpty {
                RecordPanelView(gameMoves: viewModel.gameMoves)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
    }

    // MARK: - 棋盘视图（残局独立交互）

    @ViewBuilder
    private var puzzleBoardView: some View {
        GeometryReader { geo in
            let boardSize = min(geo.size.width, geo.size.height) - 16
            let cellSize = boardSize / 9

            ZStack {
                // 棋盘背景
                boardBackground

                // 棋子
                ForEach(viewModel.board.pieces) { piece in
                    PieceView(piece: piece, isSelected: selectedPosition == piece.position, boardSize: CGSize(width: boardSize, height: boardSize * 10 / 9))
                        .position(
                            x: CGFloat(piece.position.col) * cellSize + cellSize / 2 + 8,
                            y: CGFloat(piece.position.row) * cellSize + cellSize / 2 + 8
                        )
                        .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                }

                // 合法走法提示
                ForEach(legalMovesForSelected, id: \.self) { pos in
                    Circle()
                        .fill(viewModel.board.piece(at: pos) != nil ? Color.red.opacity(0.4) : Color.green.opacity(0.4))
                        .frame(width: cellSize * 0.4, height: cellSize * 0.4)
                        .position(
                            x: CGFloat(pos.col) * cellSize + cellSize / 2 + 8,
                            y: CGFloat(pos.row) * cellSize + cellSize / 2 + 8
                        )
                }

                // 点击手势
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleTap(at: value.location, cellSize: cellSize)
                            }
                    )
            }
            .frame(width: boardSize + 16, height: boardSize * 10 / 9 + 16)
        }
        .frame(maxWidth: 400, maxHeight: 480)
        .aspectRatio(9/10, contentMode: .fit)
    }

    @ViewBuilder
    private var boardBackground: some View {
        Rectangle()
            .fill(Color(red: 222/255, green: 184/255, blue: 135/255))
            .overlay(
                Canvas { context, size in
                    let w = size.width - 16
                    let h = size.height - 16
                    let cellW = w / 8
                    let cellH = h / 9

                    var path = Path()
                    // 横线
                    for row in 0...9 {
                        let y = CGFloat(row) * cellH + 8
                        path.move(to: CGPoint(x: 8, y: y))
                        path.addLine(to: CGPoint(x: w + 8, y: y))
                    }
                    // 竖线
                    for col in 0...8 {
                        let x = CGFloat(col) * cellW + 8
                        path.move(to: CGPoint(x: x, y: 8))
                        if col == 0 || col == 8 {
                            path.addLine(to: CGPoint(x: x, y: h + 8))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: 4 * cellH + 8))
                            path.move(to: CGPoint(x: x, y: 5 * cellH + 8))
                            path.addLine(to: CGPoint(x: x, y: h + 8))
                        }
                    }
                    // 九宫对角线
                    let palaceLines: [(Int, Int, Int, Int)] = [
                        (3, 0, 5, 2), (5, 0, 3, 2),
                        (3, 7, 5, 9), (5, 7, 3, 9)
                    ]
                    for (c1, r1, c2, r2) in palaceLines {
                        path.move(to: CGPoint(x: CGFloat(c1) * cellW + 8, y: CGFloat(r1) * cellH + 8))
                        path.addLine(to: CGPoint(x: CGFloat(c2) * cellW + 8, y: CGFloat(r2) * cellH + 8))
                    }

                    context.stroke(path, with: .color(.black), lineWidth: 1)
                }
            )
    }

    private func handleTap(at point: CGPoint, cellSize: CGFloat) {
        let col = Int((point.x - 8) / cellSize + 0.5)
        let row = Int((point.y - 8) / cellSize + 0.5)
        guard row >= 0, row <= 9, col >= 0, col <= 8 else { return }
        let pos = Position(row: row, col: col)

        // 如果已选中棋子且点击合法目标
        if let selected = selectedPosition, legalMovesForSelected.contains(pos) {
            viewModel.movePiece(from: selected, to: pos)
            selectedPosition = nil
            legalMovesForSelected = []
            return
        }

        // 选择棋子
        let legalMoves = viewModel.selectPiece(at: pos)
        if !legalMoves.isEmpty {
            selectedPosition = pos
            legalMovesForSelected = legalMoves
        } else {
            selectedPosition = nil
            legalMovesForSelected = []
        }
    }
}
