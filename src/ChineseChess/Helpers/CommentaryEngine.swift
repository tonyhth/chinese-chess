import Foundation

// MARK: - 点评类型

/// 棋谱自动演示点评（Phase 1 仅三种）
enum CommentaryType {
    case check(side: Side)       // 将军
    case checkmate(side: Side)   // 将死
    case sacrifice(side: Side, delta: Int)  // 弃子（Phase 2：materialDelta 检测）
    case keyMove                 // 最后一步关键走法
}

// MARK: - 点评条目

struct CommentaryItem: Identifiable {
    let id = UUID()
    let type: CommentaryType
    let timestamp = Date()

    /// 点评文本
    var text: String {
        switch type {
        case .check(let side):
            let sideName = side == .red
                ? String(localized: "红方")
                : String(localized: "黑方")
            return String(localized: "\(sideName)将军！")
        case .checkmate(let side):
            let sideName = side == .red
                ? String(localized: "红方")
                : String(localized: "黑方")
            return String(localized: "\(sideName)将死！绝杀！")
        case .sacrifice(let side, let delta):
            let sideName = side == .red
                ? String(localized: "红方")
                : String(localized: "黑方")
            return String(localized: "\(sideName)弃子！子力差 \(delta)")
        case .keyMove:
            return String(localized: "关键一步！")
        }
    }

    /// 图标
    var icon: String {
        switch type {
        case .check: return "bolt.fill"
        case .checkmate: return "crown.fill"
        case .sacrifice: return "flame.fill"
        case .keyMove: return "star.fill"
        }
    }
}

// MARK: - CommentaryEngine

/// 规则推断点评引擎
/// Phase 1：将军(check)、将死(checkmate)、最后一步(keyMove)
/// Phase 2：弃子(sacrifice) — materialDelta 检测 + 前瞻确认
struct CommentaryEngine {

    /// 弃子前瞻步数：执行弃子后，看未来 N 步内子力是否恢复
    static let sacrificeLookahead = 6

    /// 弃子最小子力差阈值（绝对值）：差值小于此值不算弃子（避免小交换误报）
    static let sacrificeMinDelta = 200  // 相当于一士/一象的价值

    /// 对指定走法生成点评
    /// - Parameters:
    ///   - move: 当前走法
    ///   - board: 执行后的棋盘
    ///   - moveIndex: 走法索引
    ///   - totalMoves: 总步数
    /// - Returns: 点评条目，或 nil
    static func evaluate(move: Move, on board: Board, moveIndex: Int, totalMoves: Int) -> CommentaryItem? {
        // 检查将军/将死
        let currentSide = board.currentTurn  // 下一步走棋方
        if MoveValidator.isInCheck(currentSide, on: board) {
            // currentSide 被将军
            if MoveValidator.isCheckmate(currentSide, on: board) {
                return CommentaryItem(type: .checkmate(side: currentSide))
            }
            return CommentaryItem(type: .check(side: currentSide))
        }

        // 最后一步（非将死）
        if moveIndex == totalMoves - 1 {
            return CommentaryItem(type: .keyMove)
        }

        return nil
    }

    /// 弃子检测（Phase 2）
    /// 在完整走法序列中检测弃子战术：走法导致己方子力下降，但前瞻 N 步后恢复或超过。
    ///
    /// - Parameters:
    ///   - moves: 完整走法序列
    ///   - initialFEN: 初始 FEN
    ///   - moveIndex: 当前检测的走法索引
    /// - Returns: 弃子点评条目，或 nil
    static func detectSacrifice(moves: [Move], initialFEN: String, moveIndex: Int) -> CommentaryItem? {
        guard moveIndex < moves.count else { return nil }

        let move = moves[moveIndex]
        let movingSide = move.piece.side

        // 1. 计算走法执行前的子力
        let boardBefore = rebuildBoard(moves: moves, initialFEN: initialFEN, upTo: moveIndex)
        let materialBefore = materialValue(for: movingSide, on: boardBefore)

        // 2. 计算走法执行后的子力
        let boardAfter = boardBefore.snapshot()
        boardAfter.execute(move)
        let materialAfter = materialValue(for: movingSide, on: boardAfter)

        // 3. materialDelta = materialAfter - materialBefore
        //    负值 = 己方子力减少 = 可能弃子
        let delta = materialAfter - materialBefore
        guard delta <= -sacrificeMinDelta else {
            // 子力未显著下降，不是弃子
            return nil
        }

        // 4. 前瞻确认：看未来 N 步内己方子力是否恢复
        let lookaheadEnd = min(moveIndex + sacrificeLookahead, moves.count - 1)
        for i in (moveIndex + 1)...lookaheadEnd {
            let futureBoard = rebuildBoard(moves: moves, initialFEN: initialFEN, upTo: i + 1)
            let futureMaterial = materialValue(for: movingSide, on: futureBoard)
            // 如果子力恢复到弃子前的水平或更高，确认弃子
            if futureMaterial >= materialBefore {
                return CommentaryItem(type: .sacrifice(side: movingSide, delta: -delta))
            }
        }

        // 前瞻步数内未恢复，不判定为弃子（可能只是单纯失子）
        return nil
    }

    /// 对完整走法序列批量生成弃子点评
    /// - Parameters:
    ///   - moves: 完整走法序列
    ///   - initialFEN: 初始 FEN
    /// - Returns: 每步的弃子点评（索引 → 点评条目）
    static func generateSacrificeCommentaries(moves: [Move], initialFEN: String) -> [Int: CommentaryItem] {
        var result: [Int: CommentaryItem] = [:]
        guard !moves.isEmpty else { return result }

        for i in 0..<moves.count {
            if let item = detectSacrifice(moves: moves, initialFEN: initialFEN, moveIndex: i) {
                result[i] = item
            }
        }

        return result
    }

    // MARK: - 内部方法

    /// 计算某方子力总值
    static func materialValue(for side: Side, on board: Board) -> Int {
        board.pieces(for: side).reduce(0) { $0 + $1.baseValue }
    }

    /// 从初始 FEN 重建棋盘到指定步
    static func rebuildBoard(moves: [Move], initialFEN: String, upTo index: Int) -> Board {
        let board = Board(fen: initialFEN)
        for i in 0..<min(index, moves.count) {
            board.execute(moves[i])
        }
        return board
    }
}
