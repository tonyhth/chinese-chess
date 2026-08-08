import Foundation

// MARK: - 点评类型

/// 棋谱自动演示点评（Phase 1 仅三种）
enum CommentaryType {
    case check(side: Side)       // 将军
    case checkmate(side: Side)   // 将死
    case sacrifice(side: Side, delta: Int)  // 弃子（Phase 2：materialDelta 检测）
    case keyMove                 // 最后一步关键走法
    case mistake                 // 失误（智能点评）
    case capture                 // 吃子（轻量级点评）
    case threat                  // 捉子/攻击（轻量级点评）
    case crossing                // 过河（轻量级点评）
}

// MARK: - 点评条目

struct CommentaryItem: Identifiable {
    let id = UUID()
    let type: CommentaryType
    let timestamp = Date()
    /// 评估差距（cp），由分析师填充，UI/趋势分析可使用
    var evalDelta: Int = 0

    /// 点评文本（可自定义，默认从 type 派生）
    private let customText: String?

    var text: String {
        if let customText { return customText }
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
        case .mistake:
            return String(localized: "失误")
        case .capture:
            return customText ?? String(localized: "吃子")
        case .threat:
            return customText ?? String(localized: "捉子")
        case .crossing:
            return customText ?? String(localized: "过河")
        }
    }

    /// 图标
    var icon: String {
        switch type {
        case .check: return "bolt.fill"
        case .checkmate: return "crown.fill"
        case .sacrifice: return "flame.fill"
        case .keyMove: return "star.fill"
        case .mistake: return "exclamationmark.triangle.fill"
        case .capture: return "hand.point.right.fill"
        case .threat: return "eye.fill"
        case .crossing: return "arrow.forward.circle.fill"
        }
    }

    init(type: CommentaryType, text: String? = nil) {
        self.type = type
        self.customText = text
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

    /// 轻量级同步点评（Phase 3）
    /// 不依赖引擎，基于规则检测吃子/捉子/过河等事件
    /// 覆盖率目标 40-60% 走法，避免每步都点评
    static func evaluateLightweight(move: Move, on board: Board, moveIndex: Int, totalMoves: Int) -> CommentaryItem? {
        let movingSide = move.piece.side

        // 1. 吃子点评
        if let captured = move.captured {
            let capturedValue = captured.baseValue
            let moverValue = move.piece.baseValue

            if capturedValue >= 900 && moverValue < capturedValue {
                // 大子吃小子（车吃马/炮等）
                let pieceName = pieceDisplayName(move.piece.kind)
                let targetName = pieceDisplayName(captured.kind)
                return CommentaryItem(type: .capture, text: "\(pieceName)扫荡\(targetName)！")
            } else if abs(capturedValue - moverValue) <= 50 && capturedValue >= 350 {
                // 等价交换（马换炮、炮换马等）
                return CommentaryItem(type: .capture, text: "兑换")
            } else if capturedValue <= 200 {
                // 吃兵卒/士象
                if capturedValue <= 100 {
                    return CommentaryItem(type: .capture, text: "掠兵")
                }
            } else {
                // 其他吃子
                let targetName = pieceDisplayName(captured.kind)
                return CommentaryItem(type: .capture, text: "吃\(targetName)")
            }
        }

        // 2. 过河检测（仅兵/卒）
        if move.piece.kind == .soldier {
            let fromRow = move.from.row
            let toRow = move.to.row
            let crossedRiver: Bool
            if movingSide == .red {
                crossedRiver = fromRow > 4 && toRow <= 4
            } else {
                crossedRiver = fromRow < 5 && toRow >= 5
            }
            if crossedRiver {
                return CommentaryItem(type: .crossing, text: movingSide == .red ? "小卒过河当车用" : "卒过河，攻势渐起")
            }
        }

        // 3. 捉子检测：走完后检查己方棋子是否可攻击对方大子
        let opponentSide: Side = movingSide == .red ? .black : .red
        let bigPieces: Set<PieceKind> = [.chariot, .cannon, .horse]
        for piece in board.pieces(for: movingSide) {
            // 只检查刚移动的棋子（减少计算量）
            guard piece.position == move.to else { continue }
            let legalTargets = MoveValidator.legalMoves(for: piece, on: board)
            for target in legalTargets {
                if let targetPiece = board.piece(at: target.to),
                   targetPiece.side == opponentSide,
                   bigPieces.contains(targetPiece.kind) {
                    let targetName = pieceDisplayName(targetPiece.kind)
                    return CommentaryItem(type: .threat, text: "捉\(targetName)！")
                }
            }
        }

        return nil
    }

    /// 棋子类型中文名
    private static func pieceDisplayName(_ kind: PieceKind) -> String {
        switch kind {
        case .general:  return "将"
        case .chariot:  return "车"
        case .cannon:   return "炮"
        case .horse:    return "马"
        case .advisor:  return "士"
        case .elephant: return "象"
        case .soldier:  return "兵"
        }
    }

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
    /// 使用单次前向遍历，维护当前棋盘状态，每步只做增量 execute，O(moves)
    /// - Parameters:
    ///   - moves: 完整走法序列
    ///   - initialFEN: 初始 FEN
    /// - Returns: 每步的弃子点评（索引 → 点评条目）
    static func generateSacrificeCommentaries(moves: [Move], initialFEN: String) -> [Int: CommentaryItem] {
        var result: [Int: CommentaryItem] = [:]
        guard !moves.isEmpty else { return result }

        // 单次前向遍历，维护棋盘状态
        var boardStates: [Board] = []  // 保存每步执行后的棋盘，用于前瞻
        var currentBoard = Board(fen: initialFEN)
        boardStates.append(currentBoard.snapshot())  // index 0 = 初始局面

        for move in moves {
            currentBoard.execute(move)
            boardStates.append(currentBoard.snapshot())
        }
        // boardStates[i] = 执行完第 i 步后的棋盘（boardStates[0] = 初始局面）

        for i in 0..<moves.count {
            let move = moves[i]
            let movingSide = move.piece.side

            // 执行前子力
            let materialBefore = materialValue(for: movingSide, on: boardStates[i])
            // 执行后子力
            let materialAfter = materialValue(for: movingSide, on: boardStates[i + 1])

            let delta = materialAfter - materialBefore
            guard delta <= -sacrificeMinDelta else { continue }

            // 前瞻确认：看未来 N 步内己方子力是否恢复
            let lookaheadEnd = min(i + sacrificeLookahead, moves.count - 1)
            for j in (i + 1)...lookaheadEnd {
                let futureMaterial = materialValue(for: movingSide, on: boardStates[j + 1])
                if futureMaterial >= materialBefore {
                    result[i] = CommentaryItem(type: .sacrifice(side: movingSide, delta: -delta))
                    break
                }
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
