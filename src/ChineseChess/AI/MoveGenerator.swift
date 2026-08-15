// MoveGenerator.swift — AI 专用伪合法走法生成器（m1-hotpath-redesign v1.2 §2.6）
//
// 面向 SearchBoardV2 信箱：生成不经 Board.execute、直接邮箱操作（A-1 核心路径）。
// 只生成伪合法走法（pseudo-legal）：不做送将过滤——送将在搜索循环 make 之后由
// inCheck 过滤（A-1，§三）。
//
// 语义对齐要求（§2.6）：与 MoveValidator.allLegalMoves 减去送将走法后的集合
// 严格全等（from/to/pieceId/captured 逐字段），由 §8.2 交叉对比逐局面断言。
// 生成顺序与 Legacy 不同（slot 序 vs Legacy pieces 数组序）——集合序不比对，
// 排序属 MoveOrderer 职责。

enum MoveGenerator {

    // MARK: - 预计算目标表（初始化一次；边界/宫殿/半场约束在表内，运行时零分支）

    /// (dr, dc, legDr, legDc)：8 个马位 + 对应蹩腿位（对齐 MoveValidator.isValidHorseMove）
    private static let horseDeltas: [(dr: Int, dc: Int, legDr: Int, legDc: Int)] = [
        (2, 1, 1, 0), (2, -1, 1, 0), (-2, 1, -1, 0), (-2, -1, -1, 0),
        (1, 2, 0, 1), (1, -2, 0, -1), (-1, 2, 0, 1), (-1, -2, 0, -1),
    ]
    /// (dr, dc)：4 个象位（眼 = from + (dr/2, dc/2)，运行时查）
    private static let elephantDeltas: [(dr: Int, dc: Int)] = [(2, 2), (2, -2), (-2, 2), (-2, -2)]
    private static let diagonalDeltas: [(dr: Int, dc: Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    private static let orthogonalDeltas: [(dr: Int, dc: Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    /// 车/炮滑动方向（同上四正方向，mailbox 步进用）
    private static let slideDirections: [(dr: Int, dc: Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    // 表布局：[sideIndex][sq] → 元素数组。sideIndex: 0=红 1=黑（SearchBoardV2.sideIndex 同约定）
    private static let horseTable: [[[Int8]]] = buildHorseTable()
    private static let elephantTable: [[[Int8]]] = buildElephantTable()
    private static let advisorTable: [[[Int8]]] = buildPalaceTable(diagonal: true)
    private static let generalTable: [[[Int8]]] = buildPalaceTable(diagonal: false)
    private static let soldierTable: [[[Int8]]] = buildSoldierTable()

    // MARK: - 生成入口

    /// 当前行棋方的全部伪合法走法。
    /// capturesOnly = true 服务 QS（语义对齐 MoveValidator.captureMoves：模式合法 + 吃对方子，无送将过滤）。
    static func pseudoLegalMoves(on board: SearchBoardV2, capturesOnly: Bool = false) -> [Move] {
        let side = board.currentTurn
        let sideIdx = side == .red ? 0 : 1
        var moves: [Move] = []
        moves.reserveCapacity(48)

        for slot in 0..<32 {
            let fromSq = board.squareOfSlot(slot)
            guard fromSq >= 0 else { continue }                    // 死亡槽跳过
            let code = board.codeOfSlot(slot)
            guard PieceCode.side(of: code) == side else { continue }
            let kind = PieceCode.kind(of: code)
            let from = PieceCode.position(fromSq)
            let piece = Piece(kind: kind, side: side, position: from, id: slot)

            switch kind {
            case .horse:
                let table = horseTable[sideIdx][Int(fromSq)]
                var i = 0
                while i < table.count {
                    if board.codeAt(table[i + 1]) == PieceCode.empty {   // 蹩腿检查
                        appendTarget(table[i], piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                    }
                    i += 2
                }
            case .elephant:
                let table = elephantTable[sideIdx][Int(fromSq)]
                var i = 0
                while i < table.count {
                    if board.codeAt(table[i + 1]) == PieceCode.empty {   // 塞象眼检查
                        appendTarget(table[i], piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                    }
                    i += 2
                }
            case .advisor:
                for t in advisorTable[sideIdx][Int(fromSq)] {
                    appendTarget(t, piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                }
            case .general:
                for t in generalTable[sideIdx][Int(fromSq)] {
                    appendTarget(t, piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                }
            case .soldier:
                for t in soldierTable[sideIdx][Int(fromSq)] {
                    appendTarget(t, piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                }
            case .chariot:
                let row = Int(fromSq) / 9, col = Int(fromSq) % 9
                for (dr, dc) in slideDirections {
                    var r = row + dr, c = col + dc
                    while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
                        let t = Int8(r * 9 + c)
                        appendTarget(t, piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                        if board.codeAt(t) != PieceCode.empty { break } // 遇子停止（吃或挡）
                        r += dr; c += dc
                    }
                }
            case .cannon:
                let row = Int(fromSq) / 9, col = Int(fromSq) % 9
                for (dr, dc) in slideDirections {
                    var r = row + dr, c = col + dc
                    var mounted = false
                    while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
                        let t = Int8(r * 9 + c)
                        let codeAt = board.codeAt(t)
                        if !mounted {
                            if codeAt == PieceCode.empty {
                                if !capturesOnly {                   // 空移：QS 不生成
                                    moves.append(Move(piece: piece, from: from, to: PieceCode.position(t), captured: nil))
                                }
                            } else {
                                mounted = true                      // 找到炮架
                            }
                        } else {
                            if codeAt != PieceCode.empty {          // 炮架后第一个子
                                appendTarget(t, piece: piece, moves: &moves, board: board, capturesOnly: capturesOnly)
                                break
                            }
                        }
                        r += dr; c += dc
                    }
                }
            }
        }
        return moves
    }

    /// 目标格分类：空格（依 capturesOnly）/ 己方（跳过）/ 对方（吃子）。
    /// captured 经 SearchBoardV2.piece(at:) O(1) 构造（id/position 与 Legacy board.piece(at:) 全等）
    @inline(__always)
    private static func appendTarget(_ t: Int8, piece: Piece, moves: inout [Move],
                                     board: SearchBoardV2, capturesOnly: Bool) {
        let targetCode = board.codeAt(t)
        if targetCode == PieceCode.empty {
            if !capturesOnly {
                moves.append(Move(piece: piece, from: piece.position, to: PieceCode.position(t), captured: nil))
            }
        } else if PieceCode.side(of: targetCode) != piece.side {
            let to = PieceCode.position(t)
            if let captured = board.piece(at: to) {
                moves.append(Move(piece: piece, from: piece.position, to: to, captured: captured))
            }
        }
    }

    // MARK: - 表构建（纯函数，进程生命周期一次）

    private static func buildHorseTable() -> [[[Int8]]] {
        var tables: [[[Int8]]] = [[], []]
        for sideIdx in 0..<2 {
            var perSquare: [[Int8]] = []
            perSquare.reserveCapacity(90)
            for row in 0...9 {
                for col in 0...8 {
                    var entry: [Int8] = []
                    entry.reserveCapacity(16)
                    for d in horseDeltas {
                        let tr = row + d.dr, tc = col + d.dc
                        guard (0...9).contains(tr), (0...8).contains(tc) else { continue }
                        entry.append(Int8(tr * 9 + tc))                 // target
                        entry.append(Int8((row + d.legDr) * 9 + col + d.legDc))  // leg
                    }
                    perSquare.append(entry)
                }
            }
            tables[sideIdx] = perSquare
        }
        return tables
    }

    private static func buildElephantTable() -> [[[Int8]]] {
        var tables: [[[Int8]]] = [[], []]
        for sideIdx in 0..<2 {
            var perSquare: [[Int8]] = []
            perSquare.reserveCapacity(90)
            for row in 0...9 {
                for col in 0...8 {
                    var entry: [Int8] = []
                    entry.reserveCapacity(8)
                    for d in elephantDeltas {
                        let tr = row + d.dr, tc = col + d.dc
                        guard (0...9).contains(tr), (0...8).contains(tc) else { continue }
                        // 象不过河：目标限己方半场（对齐 isValidElephantMove）
                        let inOwnHalf = sideIdx == 0 ? tr >= 5 : tr <= 4
                        guard inOwnHalf else { continue }
                        entry.append(Int8(tr * 9 + tc))                 // target
                        entry.append(Int8((row + d.dr / 2) * 9 + col + d.dc / 2))  // eye
                    }
                    perSquare.append(entry)
                }
            }
            tables[sideIdx] = perSquare
        }
        return tables
    }

    /// 士（斜向）/ 将（直向）：目标限己方宫殿
    private static func buildPalaceTable(diagonal: Bool) -> [[[Int8]]] {
        let deltas = diagonal ? diagonalDeltas : orthogonalDeltas
        var tables: [[[Int8]]] = [[], []]
        for sideIdx in 0..<2 {
            var perSquare: [[Int8]] = []
            perSquare.reserveCapacity(90)
            for row in 0...9 {
                for col in 0...8 {
                    var entry: [Int8] = []
                    entry.reserveCapacity(4)
                    for d in deltas {
                        let tr = row + d.dr, tc = col + d.dc
                        guard (0...9).contains(tr), (0...8).contains(tc) else { continue }
                        let inPalace = sideIdx == 0
                            ? (tr >= 7 && tr <= 9 && tc >= 3 && tc <= 5)   // 红宫
                            : (tr <= 2 && tc >= 3 && tc <= 5)              // 黑宫
                        guard inPalace else { continue }
                        entry.append(Int8(tr * 9 + tc))
                    }
                    perSquare.append(entry)
                }
            }
            tables[sideIdx] = perSquare
        }
        return tables
    }

    /// 兵/卒：未过河仅前进；过河后前进 + 左右（对齐 isValidSoldierMove）
    private static func buildSoldierTable() -> [[[Int8]]] {
        var tables: [[[Int8]]] = [[], []]
        for sideIdx in 0..<2 {
            var perSquare: [[Int8]] = []
            perSquare.reserveCapacity(90)
            for row in 0...9 {
                for col in 0...8 {
                    var entry: [Int8] = []
                    entry.reserveCapacity(3)
                    let forward = sideIdx == 0 ? -1 : 1                  // 红向北(row-) 黑向南(row+)
                    let hasCrossed = sideIdx == 0 ? row <= 4 : row >= 5
                    let fr = row + forward
                    if (0...9).contains(fr) { entry.append(Int8(fr * 9 + col)) }
                    if hasCrossed {
                        if col - 1 >= 0 { entry.append(Int8(row * 9 + col - 1)) }
                        if col + 1 <= 8 { entry.append(Int8(row * 9 + col + 1)) }
                    }
                    perSquare.append(entry)
                }
            }
            tables[sideIdx] = perSquare
        }
        return tables
    }
}
