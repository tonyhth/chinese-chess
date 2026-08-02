import SwiftUI

// MARK: - TutorialInteractiveView — interactive 类型课程视图（Step 3 完整实现）

struct TutorialInteractiveView: View {
    let lesson: TutorialLesson

    // 走法验证状态
    enum StepStatus {
        case waiting      // 等待用户走子
        case correct      // 走对了（短暂显示）
        case wrong        // 走法合法但非期望
        case illegal      // 走法不合法
        case complete     // 全部步骤完成
    }

    // Board 是 class，用 @State 持有引用，手动触发刷新
    @State private var board: Board = Board(fen: FENParser.standardInitial)
    @State private var stepIndex = 0
    @State private var status: StepStatus = .waiting
    @State private var boardRevision = 0  // 强制 SwiftUI 刷新

    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 12) {
            // 标题
            Text(l10n.t(lesson.titleKey))
                .font(.title2)
                .fontWeight(.bold)

            Text(l10n.t(lesson.subtitleKey))
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 步骤进度（多步走法时显示）
            if let moves = lesson.expectedMoves, moves.count > 1 {
                Text(l10n.t("tutorial.stepProgress", stepIndex + 1, moves.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 迷你棋盘
            MiniChessBoard(
                board: board,
                enabledSide: enabledSide,
                onMove: { from, to in validateMove(from, to) }
            )
            .id(boardRevision) // 强制刷新

            // 状态反馈
            statusView

            // 重试按钮（走错时显示）
            if status == .wrong || status == .illegal {
                Button(l10n.t("tutorial.retry")) {
                    resetCurrentStep()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { setupBoard() }
        .onChange(of: lesson.id) { _, _ in setupBoard() }
    }

    // MARK: - 棋盘初始化

    private func setupBoard() {
        resetBoardOnly()
        stepIndex = 0
        status = .waiting
        boardRevision += 1
    }

    /// 只重置棋盘到初始局面，不碰 stepIndex
    private func resetBoardOnly() {
        if let fen = lesson.initialFEN,
           let parsed = FENParser.parse(fen: fen) {
            board = parsed
        } else {
            board = Board(fen: FENParser.standardInitial)
        }
    }

    // MARK: - 可操作方

    private var enabledSide: Side? {
        guard let fen = lesson.initialFEN else { return nil }
        // 从 FEN 解析当前走方
        let parts = fen.split(separator: " ")
        if parts.count >= 2 {
            return parts[1] == "w" ? .red : .black
        }
        return .red
    }

    // MARK: - 走法验证

    private func validateMove(_ from: Position, _ to: Position) {
        guard status != .complete else { return }
        guard let piece = board.piece(at: from) else {
            #if DEBUG
            print("[Tutorial] validateMove: no piece at \(from)")
            #endif
            return
        }

        #if DEBUG
        print("[Tutorial] validateMove: from=\(from), to=\(to), piece=\(piece.kind), side=\(piece.side), enabledSide=\(String(describing: enabledSide))")
        #endif

        // 层 1：检查走法是否合法
        let legalMoves = MoveValidator.legalMoves(for: piece, on: board)
        #if DEBUG
        print("[Tutorial] legalMoves: \(legalMoves.map { $0.to })")
        #endif
        guard legalMoves.contains(where: { $0.to == to }) else {
            status = .illegal
            return
        }

        // 构造 Move 对象
        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        // 层 2：检查是否匹配期望走法
        guard let expected = lesson.expectedMoves,
              stepIndex < expected.count else {
            status = .wrong
            return
        }

        // UCI 转换比较
        let uciString = UCIMoveConverter.uciString(from: move)
        let expectedUCI = expected[stepIndex]

        if uciString == expectedUCI {
            // 正确！执行走法
            board.execute(move)
            boardRevision += 1
            stepIndex += 1

            if stepIndex >= (lesson.expectedMoves?.count ?? 0) {
                status = .complete
            } else {
                status = .correct
            }
        } else {
            // 合法但非期望走法
            status = .wrong
        }
    }

    // MARK: - 重置当前步骤

    private func resetCurrentStep() {
        // P1-7 fix: 保存 stepIndex，先重置棋盘，再重放之前的正确步骤
        // 注意：wrong/illegal 时棋盘未被修改（board.execute 不会被调用），
        // 理论上只需 status = .waiting。保留重放逻辑是防御性写法。
        let savedStepIndex = stepIndex
        resetBoardOnly()
        if let expected = lesson.expectedMoves {
            for i in 0..<savedStepIndex {
                if let move = UCIMoveConverter.move(from: expected[i], on: board) {
                    board.execute(move)
                }
            }
            boardRevision += 1
        }
        status = .waiting
    }

    // MARK: - 位置标签

    /// 将 Position 转为可读坐标标签（如 "七路"、"3列"）
    private func positionLabel(_ pos: Position) -> String {
        // 用列号中文表示
        let colNames = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let rowNum = 10 - pos.row  // 转为传统象棋表示（从下往上数）
        return "\(colNames[pos.col])路\(rowNum)"
    }

    // MARK: - 状态视图

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .waiting:
            if let hintKey = lesson.hintKey {
                Text(l10n.t(hintKey))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

        case .correct:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(l10n.t("tutorial.stepProgress", min(stepIndex, lesson.expectedMoves?.count ?? 0),
                            lesson.expectedMoves?.count ?? 0))
                    .font(.subheadline)
                    .foregroundColor(.green)
            }

        case .wrong:
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(l10n.t("tutorial.wrongMove"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                // P1-7 Fix 3: 显示期望走法提示
                if let expected = lesson.expectedMoves,
                   stepIndex < expected.count,
                   let (fromPos, toPos) = UCIMoveConverter.positions(from: expected[stepIndex]) {
                    Text(String(format: l10n.t("tutorial.hintMove"),
                                positionLabel(fromPos), positionLabel(toPos)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .illegal:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(l10n.t("tutorial.illegalMove"))
                    .font(.subheadline)
                    .foregroundColor(.red)
            }

        case .complete:
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    if let successKey = lesson.successMessageKey {
                        Text(l10n.t(successKey))
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
                Text(l10n.t("tutorial.interactiveComplete"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
