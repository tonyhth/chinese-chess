import Foundation

// MARK: - 走法排序

/// 对候选走法排序，提升 Alpha-Beta 剪枝效率。
/// 优先级：置换表最佳走法 > 将军 > 吃子(MVV-LVA) > 历史启发 > 其他
struct MoveOrderer {

    /// 历史启发表：记录每种走法产生 cutoff 的次数（A-3 整数化，v1.2 §4）
    /// 旧 String 键不含走子方（双方互染统计缺陷）；整数键含 side 分域
    /// 16200 定长数组（63KB）替代字典：查询零分配、clear memset 级
    private var historyTable: [Int32]

    // Killer Move 表：Key=depth, Value=最多 2 个 killer move
    private var killerMoves: [Int: [Move?]] = [:]

    // Countermove 表（v3.0 Phase 2a）：对手走法键 → 最佳回应完整键
    // 值存完整键（Int16 含 side，v1.2 P2-1），-1 = 无记录
    private var countermoveTable: [Int16]

    /// 键空间：红 0..<8100，黑 8100..<16200（(sideBase + fromSq) * 90 + toSq）
    static let keySpace = 16200

    init() {
        historyTable = [Int32](repeating: 0, count: Self.keySpace)
        countermoveTable = [Int16](repeating: -1, count: Self.keySpace)
    }

    /// A-3 整数键（含走子方）：(sideBase + fromSq) * 90 + toSq
    static func historyKey(_ move: Move) -> Int {
        let fromSq = move.from.row * 9 + move.from.col
        let toSq = move.to.row * 9 + move.to.col
        return (move.piece.side == .red ? 0 : 8100) + fromSq * 90 + toSq
    }

    /// 走法压缩编码（不含 side）：M2 预留——countermove 存值改完整键后生产零调用（仅 M1Phase1Tests 往返验证）。保留供 M2 TT 紧凑条目（路线图 G）复用，届时重新评审
    static func packedMove(_ move: Move) -> Int16 {
        let fromSq = move.from.row * 9 + move.from.col
        let toSq = move.to.row * 9 + move.to.col
        return Int16(fromSq * 90 + toSq)
    }

    /// 逆变换：完整键 → (side, fromSq, toSq)。M2 预留（同 packedMove 注释）
    static func unpackKey(_ key: Int) -> (side: Side, fromSq: Int, toSq: Int) {
        let side: Side = key >= 8100 ? .black : .red
        let base = key - (side == .red ? 0 : 8100)
        return (side, base / 90, base % 90)
    }

    /// 统一判等逻辑：piece.id + from + to
    static func isSameMove(_ a: Move, _ b: Move) -> Bool {
        return a.piece.id == b.piece.id && a.from == b.from && a.to == b.to
    }

    /// 记录一个产生 beta cutoff 的走法
    mutating func recordCutoff(move: Move, depth: Int) {
        // 深度加权；&+= 环回而非陷阱（极长对局理论可环回，排序分数噪声可接受，无正确性影响）
        historyTable[Self.historyKey(move)] &+= Int32(depth * depth)
    }

    /// v3.0 Phase 2a: 记录 countermove（A-3 整数化：存回应方完整键，含 side）
    mutating func recordCountermove(move: Move, opponentMove: Move?) {
        guard let opp = opponentMove else { return }
        countermoveTable[Self.historyKey(opp)] = Int16(Self.historyKey(move))
    }

    /// v3.0 Phase 2a: 查询 countermove 键（A-3：返回完整键，order 侧键比对，P2-1）
    func getCountermoveKey(for opponentMove: Move?) -> Int? {
        guard let opp = opponentMove else { return nil }
        let stored = countermoveTable[Self.historyKey(opp)]
        return stored >= 0 ? Int(stored) : nil
    }

    /// 记录一个产生 beta cutoff 的非吃子走法为 killer move
    mutating func recordKiller(move: Move, depth: Int) {
        guard move.captured == nil else { return }

        if var killers = killerMoves[depth] {
            if let k0 = killers[0], Self.isSameMove(k0, move) { return }
            killers[1] = killers[0]
            killers[0] = move
            killerMoves[depth] = killers
        } else {
            killerMoves[depth] = [move, nil]
        }
    }

    /// 检查走法是否为当前深度的 killer move
    func isKillerMove(_ move: Move, depth: Int) -> Bool {
        guard let killers = killerMoves[depth] else { return false }
        for killer in killers {
            if let k = killer, Self.isSameMove(k, move) {
                return true
            }
        }
        return false
    }

    /// 清空历史表、killer 表和 countermove 表（新对局时调用）
    mutating func clearHistory() {
        historyTable = [Int32](repeating: 0, count: Self.keySpace)
        killerMoves.removeAll()
        countermoveTable = [Int16](repeating: -1, count: Self.keySpace)
    }

    /// 排序走法列表
    /// - Parameters:
    ///   - moves: 候选走法
    ///   - board: 当前棋盘
    ///   - ttBestMove: 置换表中的最佳走法（如有）
    ///   - checkLegal: 是否启用将军排序（depth >= 3 时启用，低深度开销大）
    ///   - countermoveKey: 对手上一走法的 countermove 完整键（A-3，如有）
    /// P2c-①：约束放宽 SearchBoardConvertible → BoardReadable（V2 无拷贝路径不可实现前者，
    /// v1.2 §3.3 MoveOrderer 行）。checkLegal 分支 as? 下派发：Legacy 走拷贝路径；
    /// **P3-①（phase3.md 裁定 A）：V2 分支已建**（orderV2 双快路径）——givesCheckV2
    /// work 副本 make O(1)+inCheck O(32)+unmake O(1)，threatBonusV2 预提取零分配。
    func order<T: BoardReadable>(_ moves: [Move], on board: T, ttBestMove: Move? = nil, checkLegal: Bool = false, depth: Int? = nil, countermoveKey: Int? = nil) -> [Move] {
        // P3-①：V2 双快路径入口（order 层一次 as?；work 副本/预提取都在分支内）
        if let v2 = board as? SearchBoardV2 {
            return orderV2(moves, on: v2, ttMove: ttBestMove, cmKey: countermoveKey,
                           checkLegal: checkLegal, depth: depth)
        }
        let ttMove = ttBestMove
        let cmKey = countermoveKey

        return moves.map { move in
            var score = 0

            // 0. 置换表最佳走法（最高优先级）
            if let ttMove = ttMove, Self.isSameMove(move, ttMove) {
                score += 100000
            }

            // 1. 将军走法（仅 depth >= 3 时启用，避免低深度的 execute 开销）
            if checkLegal && givesCheck(move, on: board) {
                score += 50000
            }

            // 2. 吃子 MVV-LVA (Most Valuable Victim - Least Valuable Attacker)
            if let captured = move.captured {
                score += 10000 + captured.baseValue * 10 - move.piece.baseValue
            }

            // 3. Killer Move（吃子之后、历史启发之前）
            if let d = depth, isKillerMove(move, depth: d) {
                score += 8000
            }

            // 3.5 v3.0 Phase 2a: Countermove（A-3 键比对，含 side 避免跨方碰撞假阳性）
            if let cm = cmKey, Self.historyKey(move) == cm {
                score += 6000
            }

            // 4. 威胁子力（走到目标位置后能威胁对方高价值棋子）
            score += threatBonus(for: move, on: board)

            // 5. 历史启发加分（A-3：整数键直索引，零分配）
            score += Int(historyTable[Self.historyKey(move)])

            return (move, score)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    // MARK: - P3-① V2 双快路径（phase3.md 裁定 A + Vera 硬化注 3 条）

    /// V2 分支排序：work 副本提升到 order 层（每调用一次，~246B = 5 个 [Int8] 缓冲 COW 之和
    /// + 重绑空 undoStack/moveHistory 防深度 COW，硬化注2/3）；givesCheckV2 每候选断言复位（硬1）。
    /// 评分公式与 Legacy 分支逐项全等（tt/将军/吃子/killer/countermove/threat/history）。
    private func orderV2(_ moves: [Move], on v2Board: SearchBoardV2,
                          ttMove: Move?, cmKey: Int?, checkLegal: Bool, depth: Int?) -> [Move] {
        var work = v2Board
        work.prepareOrderWork()
        // 预提取：行棋方全部同 side，对方目标集 order 层一次（裁定 A 零分配锚）
        let moverSide: Side = moves.first?.piece.side ?? v2Board.currentTurn
        let opponent: Side = (moverSide == .red) ? .black : .red
        let targets = v2Board.threatTargets(of: opponent)

        return moves.map { move -> (Move, Int) in
            var score = 0
            // 0. 置换表最佳
            if let tt = ttMove, Self.isSameMove(move, tt) { score += 100000 }
            // 1. 将军走法（V2 快路径：make O(1) + inCheck O(32) + unmake O(1)）
            if checkLegal && givesCheckV2(move, &work) { score += 50000 }
            // 2. 吃子 MVV-LVA
            if let captured = move.captured { score += 10000 + captured.baseValue * 10 - move.piece.baseValue }
            // 3. Killer
            if let d = depth, isKillerMove(move, depth: d) { score += 8000 }
            // 3.5 Countermove（A-3 完整键含 side）
            if let cm = cmKey, Self.historyKey(move) == cm { score += 6000 }
            // 4. 威胁子力（V2 预提取版，公式/baseValue 与 Legacy 全等——等价锚 §4 #6）
            score += threatBonusV2(move, targets: targets)
            // 5. 历史启发（A-3 整数键直索引）
            score += Int(historyTable[Self.historyKey(move)])
            return (move, score)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    /// V2 将军检测：work 副本上 make → inCheck(对方) → unmake，严格配对。
    /// 硬化注1：每候选断言复位（O(1)），不在 order 出口集中查——中途失衡立即定位。
    private func givesCheckV2(_ move: Move, _ work: inout SearchBoardV2) -> Bool {
        let undo = work.make(move)
        let opponent: Side = (move.piece.side == .red) ? .black : .red
        let inCheck = work.inCheck(opponent)
        work.unmake(undo)
        assert(work.moveHistory.count == 0,
               "givesCheckV2 work 副本失衡（P3-① 硬化注1）")
        return inCheck
    }

    /// V2 威胁加分：预提取元组零分配查询。
    /// 语义与 Legacy threatBonus 逐分支全等（车同行列/5、炮同行列/10、马日字/5、上限 5000）。
    private func threatBonusV2(_ move: Move, targets: [(row: Int, col: Int, baseValue: Int)]) -> Int {
        var bonus = 0
        switch move.piece.kind {
        case .chariot:
            for t in targets where t.baseValue >= 300 {
                if t.row == move.to.row || t.col == move.to.col { bonus += t.baseValue / 5 }
            }
        case .cannon:
            for t in targets where t.baseValue >= 300 {
                if t.col == move.to.col || t.row == move.to.row { bonus += t.baseValue / 10 }
            }
        case .horse:
            let horseMoves = [(2, 1), (2, -1), (-2, 1), (-2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2)]
            for (dr, dc) in horseMoves {
                let tr = move.to.row + dr, tc = move.to.col + dc
                if let t = targets.first(where: { $0.row == tr && $0.col == tc }) {
                    bonus += t.baseValue / 5
                }
            }
        default:
            break
        }
        return min(bonus, 5000)
    }

    // MARK: - 将军检测

    /// 判断走法是否会导致将军。
    /// P2c-①：as? 下派发（v1.2 §3.3）——Legacy 走 makeSearchBoard 拷贝路径（原语义）；
    /// V2 快路径 P3 落地（givesCheck make O(1) + inCheck + unmake），
    /// 在此之前 V2 路径 order 必传 checkLegal: false，本分支不可达。
    private func givesCheck<T: BoardReadable>(_ move: Move, on board: T) -> Bool {
        guard let legacy = board as? LegacySearchBoard else { return false }
        var workBoard = legacy.makeSearchBoard()
        workBoard.execute(move)
        let opponentSide: Side = (move.piece.side == .red) ? .black : .red
        let inCheck = MoveValidator.isInCheck(opponentSide, on: workBoard)
        return inCheck
    }

    // MARK: - 威胁子力加分

    /// 走到目标位置后能威胁对方高价值棋子的加分
    private func threatBonus<T: BoardReadable>(for move: Move, on board: T) -> Int {
        let opponentSide: Side = (move.piece.side == .red) ? .black : .red
        let opponentPieces = board.pieces.filter { $0.side == opponentSide && $0.kind != .general }

        // 简化版：只看车、炮、马的潜在威胁，不做完整走法生成
        var bonus = 0
        switch move.piece.kind {
        case .chariot:
            // 车威胁同行/同列的高价值子
            for target in opponentPieces where target.baseValue >= 300 {
                if target.position.row == move.to.row || target.position.col == move.to.col {
                    bonus += target.baseValue / 5
                }
            }
        case .cannon:
            // 炮威胁同列高价值子（简化：不计算翻山）
            for target in opponentPieces where target.baseValue >= 300 {
                if target.position.col == move.to.col || target.position.row == move.to.row {
                    bonus += target.baseValue / 10
                }
            }
        case .horse:
            // 马威胁日字形位置的高价值子
            let horseMoves = [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)]
            for (dr, dc) in horseMoves {
                let tr = move.to.row + dr, tc = move.to.col + dc
                if let target = opponentPieces.first(where: { $0.position.row == tr && $0.position.col == tc }) {
                    bonus += target.baseValue / 5
                }
            }
        default:
            break
        }
        return min(bonus, 5000)  // 上限
    }

    // MARK: - 历史启发辅助（A-3：键函数已上移为静态，供测试与 order 复用）
}
