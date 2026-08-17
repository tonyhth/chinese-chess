import Foundation
// SearchBoardV2.swift — 90 格信箱 + piece list 搜索棋盘（m1-hotpath-redesign v1.2 §2）
//
// A-2 数据结构：mailbox O(1) 直查替代 Legacy 的 [Piece] 线扫。
// 双实现并存窗口 P2c→P2d：与 LegacySearchBoard 并存，交叉对比（§8.2）为合入门槛。
//
// 范围注记（P2b）：materialSum/pstSum 增量字段按 v1.2 §2.1 属 B 阶段（P4 cheapEval
// 分流）配套，本 Phase 不落——避免无消费者的派生状态（ pstSum 依赖 P4 的 PST 表
// 选型）。P4 接入时增量维护 + 对账断言一起加。

struct SearchBoardV2 {
    // MARK: - 主存储（v1.2 §2.1）

    private var mailbox: [Int8]      // 90 格：sq = row * 9 + col；0 = 空；±1..±7 = 红黑 7 种棋子
    private var pieceSquares: [Int8] // 32 槽：槽 i 的棋子所在格；-1 = 已被吃
    private var pieceCodes: [Int8]   // 32 槽：槽 i 的棋子编码（死亡后保留，供 unmake 恢复）
    private var sqToSlot: [Int8]     // 90 格：格 → 槽位；-1 = 空格
    private var kingSq: [Int8]       // [红, 黑]：将帅所在格（将帅走子时更新，inCheck/照面免找将扫描）
    // ── P4-① 增量字段族（phase4.md §1.1，v1.2 §2.1 留白兑现）──
    /// [红, 黑] 子力和（AIEvaluator.dynamicValue 口径含相位三调整；
    /// 增量全等专项守护与 AIEvaluator 实调全等，复刻漂移会被抓）
    private var materialSum: [Int]
    /// [红, 黑] 位置分（PositionTables.positionWeight 同源直调，零复刻）
    private var pstSum: [Int]
    /// 活子数（含将帅，同 board.pieces.count 口径；相位界碑 16 + standPat 守卫 6）
    private(set) var pieceCount: Int
    private(set) var moveHistory: [Move]
    private var undoStack: [UndoInfo]
    private(set) var currentTurn: Side

    // Debug 断言抽样计数（v1.1/P2-3：每 4096 次 make/unmake 抽一次 structureIsValid，
    // 复用 timeCheckInterval 位掩码模式；V2_FULL_ASSERT=1 全量）
    // 值语义下随 board 传递；搜索路径 board 为 inout 原位 make/unmake，计数器单调有效
    private var assertTick: Int = 0
    private static let fullAssert: Bool = {
        ProcessInfo.processInfo.environment["V2_FULL_ASSERT"] == "1"
    }()

    // MARK: - UndoInfo（v1.2 §2.1）

    struct UndoInfo {
        let move: Move
        let movedSlot: Int8     // 走子槽位（= Piece.id，见 §2.3）
        let capturedSlot: Int8  // 被吃槽位；-1 = 无吃子
        // P4-①：增量字段快照（回滚 = 快照恢复而非逆运算——相位切换下逆推导
        // 易对称漂移，快照方案天然免疫；5×Int ≈ 40B）
        let savedMaterialSum: [Int]
        let savedPstSum: [Int]
        let savedPieceCount: Int
    }

    // MARK: - 初始化

    /// 标准开局
    init() {
        self.init(pieces: Board.initialPieces(), currentTurn: .red, moveHistory: [])
    }

    /// 从 Board 创建（AI 入口唯一转换点）
    init(from board: Board) {
        self.init(pieces: board.pieces, currentTurn: board.currentTurn, moveHistory: board.moveHistory)
    }

    /// 直接构造（测试 / 交叉对比局面源）
    ///
    /// 槽位规则（v1.2 §2.3）：槽 i ↔ id == i 的棋子。⚠️ Board.initialPieces() 的
    /// pieces 数组下标 ≠ id（左右对称位 id 相邻，如黑方下标 0 = id 16），故按 id
    /// 分配槽位、不按数组序——pieces 重建 id 保真与 UndoInfo 调试可读性均依赖此约定。
    /// 不在场的 id 视为死亡槽（象棋棋子只减不增，语义等价）。
    init(pieces: [Piece], currentTurn: Side, moveHistory: [Move] = []) {
        self.mailbox = [Int8](repeating: PieceCode.empty, count: 90)
        self.pieceSquares = [Int8](repeating: -1, count: 32)
        self.pieceCodes = [Int8](repeating: PieceCode.empty, count: 32)
        self.sqToSlot = [Int8](repeating: -1, count: 90)
        self.kingSq = [-1, -1]
        self.moveHistory = moveHistory
        self.undoStack = []
        self.currentTurn = currentTurn

        var seenIds = Set<Int>()
        var kingFound = [false, false]
        materialSum = [0, 0]
        pstSum = [0, 0]
        pieceCount = 0
        for piece in pieces {
            // Debug 防御：构造源局面必须 id 唯一、位置唯一（A3 精神：输入侧拦截）
            assert((0..<32).contains(piece.id), "SearchBoardV2 构造：id \(piece.id) 越界（0..31）")
            assert(seenIds.insert(piece.id).inserted, "SearchBoardV2 构造：id \(piece.id) 重复")
            let sq = PieceCode.square(piece.position)
            assert(sqToSlot[Int(sq)] == -1, "SearchBoardV2 构造：格 \(sq) 双占（id \(piece.id)）")

            let slot = Int8(piece.id)
            mailbox[Int(sq)] = PieceCode.code(kind: piece.kind, side: piece.side)
            pieceSquares[piece.id] = sq
            pieceCodes[piece.id] = PieceCode.code(kind: piece.kind, side: piece.side)
            sqToSlot[Int(sq)] = slot
            if piece.kind == .general {
                kingSq[Self.sideIndex(of: piece.side)] = sq
                kingFound[Self.sideIndex(of: piece.side)] = true
            }
        }
        assert(kingFound[0] && kingFound[1], "SearchBoardV2 构造：将/帅缺失（交叉对比局面源应保证双方有将）")
        recomputeIncrementalSums()
    }

    // MARK: - P4-① 增量维护（phase4.md §1.1 + P4-0 双相位发现）

    /// 从零重算三字段（init / 相位跨界（16 线）/ 全等专项对照共享）。
    /// 口径：materialSum = Σ incrementalValue（dynamicValue 逐值复刻，全等专项守护）；
    /// pstSum = Σ PositionTables.positionWeight（同源直调零复刻）。
    private mutating func recomputeIncrementalSums() {
        var mat = [0, 0], pst = [0, 0], count = 0
        let phaseCount = pieceCountForPhase
        for slot in 0..<32 {
            let sq = pieceSquares[slot]
            guard sq >= 0 else { continue }
            let code = pieceCodes[slot]
            let side = PieceCode.side(of: code), kind = PieceCode.kind(of: code)
            let row = Int(sq) / 9, col = Int(sq) % 9
            let si = Self.sideIndex(of: side)
            mat[si] += incrementalValue(code: code, at: sq, isEndgame: phaseCount <= 16)
            pst[si] += PositionTables.positionWeight(
                for: Piece(kind: kind, side: side, position: Position(row: row, col: col), id: 0),
                totalPieces: phaseCount)
            count += 1
        }
        materialSum = mat
        pstSum = pst
        pieceCount = count
    }

    /// 相位判定用活子数（本次重算前的 pieceCount 或临时计数）
    private var pieceCountForPhase: Int {
        (0..<32).lazy.filter { pieceSquares[$0] >= 0 }.count
    }

    /// dynamicValue 复刻（AIEvaluator.swift :82-99 逐值，含残局三调整；
    /// base 链 = baseValueLookup（含 soldier 位置翻倍）与 Piece.baseValue 逐值一致
    /// ——Ruby P2 实核。⚠️ 与 AIEvaluator 同步义务：增量全等专项逐局面对照实调，
    /// 复刻漂移必被抓。
    private func incrementalValue(code: Int8, at sq: Int8, isEndgame: Bool) -> Int {
        let base = baseValueLookup(code, at: sq)
        guard isEndgame else { return base }
        let kind = PieceCode.kind(of: code)
        switch kind {
        case .soldier:
            let side = PieceCode.side(of: code)
            let row = Int(sq) / 9
            let crossed = (side == .black) ? row >= 5 : row <= 4
            return crossed ? base * 2 : base
        case .elephant: return base / 2
        case .advisor:  return base * 3 / 4
        default:        return base
        }
    }

    // MARK: - 走法执行（v1.2 §2.5，O(1)）

    @discardableResult
    mutating func make(_ move: Move) -> UndoInfo {
        let fromSq = PieceCode.square(move.from), toSq = PieceCode.square(move.to)
        let slot = sqToSlot[Int(fromSq)]
        var capturedSlot: Int8 = -1
        let capturedCode = mailbox[Int(toSq)]
        if capturedCode != PieceCode.empty {
            capturedSlot = sqToSlot[Int(toSq)]
            pieceSquares[Int(capturedSlot)] = -1          // 槽标记死亡（sqToSlot[toSq] 随即被移动方覆盖，勿写 dead store）
            // 被吃将的 kingSq 清零（防御：正常搜索不走吃将走法，但伪合法生成器会生成吃将走法——
            // 断言层/测试需要正确语义；照面检查依赖 kingSq 有效性）
            if PieceCode.kind(of: capturedCode) == .general {
                kingSq[Self.sideIndex(of: PieceCode.side(of: capturedCode))] = -1
            }
        }
        mailbox[Int(toSq)] = mailbox[Int(fromSq)]
        mailbox[Int(fromSq)] = PieceCode.empty
        pieceSquares[Int(slot)] = toSq
        sqToSlot[Int(toSq)] = slot
        sqToSlot[Int(fromSq)] = -1                        // ← fromSq 腾空必须显式清（v1.1/P1-2）
        if move.piece.kind == .general {
            kingSq[Self.sideIndex(of: move.piece.side)] = toSq
        }
        // ── P4-① 增量维护（快照 + 增量 + 相位跨界重算）──
        let savedMaterial = materialSum, savedPst = pstSum, savedCount = pieceCount
        let oldPhase = pieceCount <= 16
        let moverCode = pieceCodes[Int(slot)]
        let moverSide = Self.sideIndex(of: move.piece.side)
        // mover：新位值 − 旧位值（soldier 过河/相位调整随位置与相位变化）
        materialSum[moverSide] += incrementalValue(code: moverCode, at: toSq, isEndgame: oldPhase)
                                          - incrementalValue(code: moverCode, at: fromSq, isEndgame: oldPhase)
        pstSum[moverSide] += Self.pstWeight(code: moverCode, at: toSq, totalPieces: savedCount)
                             - Self.pstWeight(code: moverCode, at: fromSq, totalPieces: savedCount)
        // captured：整值减除
        if capturedSlot >= 0 {
            let capSide = Self.sideIndex(of: PieceCode.side(of: capturedCode))
            materialSum[capSide] -= incrementalValue(code: capturedCode, at: toSq, isEndgame: oldPhase)
            pstSum[capSide] -= Self.pstWeight(code: capturedCode, at: toSq, totalPieces: savedCount)
            pieceCount -= 1
            // 相位跨界（16 线）：全子重算（P4-0 双相位发现——表切换/系数变化影响全部子）
            // （Ruby 4️⃣：取反条件直挂 recompute，免空真分支）
            if (savedCount > 16) != (pieceCount > 16) {
                recomputeIncrementalSums()
            }
        }
        moveHistory.append(move)
        currentTurn = (currentTurn == .red) ? .black : .red
        let undo = UndoInfo(move: move, movedSlot: slot, capturedSlot: capturedSlot,
                            savedMaterialSum: savedMaterial, savedPstSum: savedPst, savedPieceCount: savedCount)
        undoStack.append(undo)
        assertStructure()
        return undo
    }

    mutating func unmake(_ undo: UndoInfo) {
        let fromSq = PieceCode.square(undo.move.from), toSq = PieceCode.square(undo.move.to)
        mailbox[Int(fromSq)] = mailbox[Int(toSq)]
        mailbox[Int(toSq)] = PieceCode.empty
        pieceSquares[Int(undo.movedSlot)] = fromSq
        sqToSlot[Int(fromSq)] = undo.movedSlot
        sqToSlot[Int(toSq)] = undo.capturedSlot >= 0 ? undo.capturedSlot : -1   // ← 无吃子也必须清（v1.1/P1-2）
        if undo.capturedSlot >= 0 {
            let code = pieceCodes[Int(undo.capturedSlot)]   // 死亡时编码保留，直接恢复
            mailbox[Int(toSq)] = code
            pieceSquares[Int(undo.capturedSlot)] = toSq
            // 恢复被吃将的 kingSq（与 make 对称）
            if PieceCode.kind(of: code) == .general {
                kingSq[Self.sideIndex(of: PieceCode.side(of: code))] = toSq
            }
        }
        if undo.move.piece.kind == .general {
            kingSq[Self.sideIndex(of: undo.move.piece.side)] = fromSq
        }
        // ── P4-① 增量回滚 = 快照恢复（相位跨界下逆推导易对称漂移，快照天然免疫）──
        materialSum = undo.savedMaterialSum
        pstSum = undo.savedPstSum
        pieceCount = undo.savedPieceCount
        moveHistory.removeLast()
        undoStack.removeLast()
        currentTurn = (currentTurn == .red) ? .black : .red
        assertStructure()
    }

    /// NMP 空着表示（v1.1/P1-4）：仅翻行棋方；哈希翻转（hash ^ sideHash）留在 AIEngine 调用点。
    /// undoStack 不入栈——空着的撤销由 AIEngine 显式再次 toggleTurn 完成（与 Legacy 同约定）。
    mutating func toggleTurn() {
        currentTurn = (currentTurn == .red) ? .black : .red
    }

    // MARK: - 内部辅助

    private static func sideIndex(of side: Side) -> Int {
        side == .red ? 0 : 1
    }

    /// 测试用：读取 undoStack 末尾（往返一致性测试的 unmake 配对需要）
    internal func undoStackLast() -> UndoInfo {
        undoStack.last!
    }

    /// P4-①：PST 单子取值（PositionTables 同源直调；make 增量用，零复刻）
    private static func pstWeight(code: Int8, at sq: Int8, totalPieces: Int) -> Int {
        PositionTables.positionWeight(
            for: Piece(kind: PieceCode.kind(of: code), side: PieceCode.side(of: code),
                        position: Position(row: Int(sq) / 9, col: Int(sq) % 9), id: 0),
            totalPieces: totalPieces)
    }

    // MARK: - P4-① cheapEval（phase4.md §1.2，O(1)）

    /// 廉价评估 = material + PST 增量直读（v1.2 §5.1 原文口径：纯差值，
    /// 无 weights 加权无 contempt——margin 容差吸收；黑视角差 × side 符号）。
    /// ⚠️ ≤6 子 Endgame 域 full eval 走 endgameScore 早返，分值体系不同——
    /// 消费方 standPat 带守卫（phase4 §1 + P4-0），razor/futility 靠 margin 容差。
    func cheapEval(for side: Side) -> Int {
        let red = materialSum[0] + pstSum[0], black = materialSum[1] + pstSum[1]
        return side == .red ? red - black : black - red
    }

    // MARK: - 结构不变式断言（v1.2 §2.5，Debug-only）

    /// 不变式清单（v1.1/P1-2）：
    /// - 空格 sq ⇔ mailbox[sq] == 0 ∧ sqToSlot[sq] == -1
    /// - 占用格 sq（占用槽 s）⇔ mailbox[sq] == pieceCodes[s] ∧ sqToSlot[sq] == s ∧ pieceSquares[s] == sq（三向闭合）
    /// - 死亡槽 s ⇔ pieceSquares[s] == -1（pieceCodes 保留供 unmake 恢复）
    /// - kingSq[side] == 该方将帅实际占用格
    /// O(122)。mailbox 单值存储下"同格两子"是不可能状态——A3 根因在 AI 路径表示级消灭。
    static func structureIsValid(_ board: SearchBoardV2) -> Bool {
        // 双向闭合：槽 → 格 与 格 → 槽
        for slot in 0..<32 {
            let sq = board.pieceSquares[slot]
            if sq >= 0 {
                let code = board.pieceCodes[slot]
                guard code != PieceCode.empty,
                      board.mailbox[Int(sq)] == code,
                      board.sqToSlot[Int(sq)] == Int8(slot)
                else { return false }
            }
            // 死亡槽无额外约束（pieceCodes 保留）
        }
        for sq in 0..<90 {
            let code = board.mailbox[sq]
            if code == PieceCode.empty {
                guard board.sqToSlot[sq] == -1 else { return false }
            } else {
                let slot = board.sqToSlot[sq]
                guard slot >= 0,
                      board.pieceSquares[Int(slot)] == Int8(sq),
                      board.pieceCodes[Int(slot)] == code
                else { return false }
            }
        }
        // kingSq 与实际占用格一致
        for (idx, side) in [(0, Side.red), (1, Side.black)] {
            let ks = board.kingSq[idx]
            guard ks >= 0 else { continue }  // 构造期断言已保证双方有将；防御极端构造
            guard board.mailbox[Int(ks)] == PieceCode.code(kind: .general, side: side),
                  PieceCode.kind(of: board.pieceCodes[Int(board.sqToSlot[Int(ks)])]) == .general
            else { return false }
        }
        return true
    }

    /// 抽样断言入口（v1.1/P2-3：每 4096 次 make/unmake 一次；V2_FULL_ASSERT=1 全量）
    private mutating func assertStructure() {
        #if DEBUG
        assertTick &+= 1
        if Self.fullAssert || (assertTick & 4095) == 0 {
            assert(Self.structureIsValid(self), "SearchBoardV2 结构腐败（make/unmake 第 \(assertTick) 次）")
        }
        #endif
    }
}

// MARK: - BoardReadable 纯读协议（v1.2 §2.4）
// ⚠️ V2 明确不实现 SearchBoardConvertible——拷贝式合法化路径（makeSearchBoard →
// execute → isInCheck）在类型层面进不了 V2，A-1 伪合法化是唯一走法来源。

extension SearchBoardV2: BoardReadable {
    /// O(32) 遍历重建；仅非热路径调用（UI 调试/测试/交叉对比）
    var pieces: [Piece] {
        (0..<32).compactMap { slot in
            let sq = pieceSquares[slot]
            guard sq >= 0 else { return nil }
            let code = pieceCodes[slot]
            return Piece(kind: PieceCode.kind(of: code),
                         side: PieceCode.side(of: code),
                         position: PieceCode.position(sq),
                         id: slot)
        }
    }

    /// O(1)：mailbox 查 + 槽位反查 + 栈上构造
    func piece(at pos: Position) -> Piece? {
        let sq = Int(PieceCode.square(pos))
        let code = mailbox[sq]
        guard code != PieceCode.empty else { return nil }
        return Piece(kind: PieceCode.kind(of: code),
                     side: PieceCode.side(of: code),
                     position: pos,
                     id: Int(sqToSlot[sq]))
    }

    /// O(1)
    func hasPiece(at pos: Position) -> Bool {
        mailbox[Int(PieceCode.square(pos))] != PieceCode.empty
    }

    /// 槽位遍历直过滤，不经 pieces()+filter 两级数组分配（v1.1/P1-3①）
    func pieces(for side: Side) -> [Piece] {
        var result: [Piece] = []
        result.reserveCapacity(16)
        for slot in 0..<32 {
            let sq = pieceSquares[slot]
            guard sq >= 0 else { continue }
            let code = pieceCodes[slot]
            guard PieceCode.side(of: code) == side else { continue }
            result.append(Piece(kind: PieceCode.kind(of: code),
                                side: side,
                                position: PieceCode.position(sq),
                                id: slot))
        }
        return result
    }

    /// kingSq 直查（v1.1/P2-4，免扫 32 槽找将）
    func generalPosition(of side: Side) -> Position? {
        let ks = kingSq[Self.sideIndex(of: side)]
        return ks >= 0 ? PieceCode.position(ks) : nil
    }
}

extension SearchBoardV2 {
    // MARK: - MoveGenerator 专用快速访问面（热路径直读，零 Piece 构造）
    // 封装边界：仅暴露只读标量查询，内部表示（数组布局）不外漏

    @inline(__always) func aliveSlot(_ slot: Int) -> Bool { pieceSquares[slot] >= 0 }
    @inline(__always) func squareOfSlot(_ slot: Int) -> Int8 { pieceSquares[slot] }
    @inline(__always) func codeOfSlot(_ slot: Int) -> Int8 { pieceCodes[slot] }
    @inline(__always) func codeAt(_ sq: Int8) -> Int8 { mailbox[Int(sq)] }
    @inline(__always) func slotAt(_ sq: Int8) -> Int8 { sqToSlot[Int(sq)] }

    /// NMP 守门专用（v1.1/P1-3②）：非将/士/象子力合计，槽位扫描 O(32)。
    /// 替代 shouldDisableNullMove 内的 pieces(for:) 调用（AIEngine.swift:904-917 语义）。
    /// 每节点至多一次（depth≥3 入口），不值得为此加增量状态。
    func nonGuardMaterial(_ side: Side) -> Int {
        var total = 0
        for slot in 0..<32 {
            let sq = pieceSquares[slot]
            guard sq >= 0 else { continue }
            let code = pieceCodes[slot]
            guard PieceCode.side(of: code) == side else { continue }
            switch PieceCode.kind(of: code) {
            case .general, .advisor, .elephant:
                continue
            case .chariot, .cannon, .horse, .soldier:
                total += baseValueLookup(code, at: sq)
            }
        }
        return total
    }

    // MARK: - P3-① order 快路径支撑（phase3.md 裁定 A + Vera 硬化注）

    /// order work 副本准备（硬化注2）：undoStack/moveHistory 重绑空数组——
    /// 深度比例 COW（UndoInfo ~40B × 深度 8-10）共享 + 首 make 触发整栈拷贝的规避；
    /// 断言简化为归零判（make/unmake 平衡后两数组应回到空）。
    mutating func prepareOrderWork() {
        undoStack = []
        moveHistory = []
    }

    /// 预提取对方活跃威胁目标（裁定 A：order 层一次，循环内零分配）。
    /// 语义锚 = Legacy threatBonus 的 opponentPieces（对方非将活跃子，
    /// baseValueLookup 与 Piece.baseValue 逐值同源——Ruby P2 实核）。
    func threatTargets(of opponent: Side) -> [(row: Int, col: Int, baseValue: Int)] {
        var out: [(row: Int, col: Int, baseValue: Int)] = []
        for slot in 0..<32 {
            let sq = pieceSquares[slot]
            guard sq >= 0 else { continue }
            let code = pieceCodes[slot]
            guard PieceCode.side(of: code) == opponent else { continue }
            guard PieceCode.kind(of: code) != .general else { continue }
            out.append((Int(sq) / 9, Int(sq) % 9, baseValueLookup(code, at: sq)))
        }
        return out
    }

    // MARK: - 将军检测快路径（v1.2 §2.7）
    //
    // 双分量规格（v1.2-draft，D1-P1-2 + D3-P0-1 双独立确认）：
    // = 分量 1 canAttack 扫描：遍历对方活跃槽位逐子判定能否攻击本方将格
    // ∪ 分量 2 将帅照面：两王同列且中间无遮拦
    // 移植范围 = MoveValidator.isInCheck 全函数（canAttack 段 + 照面段），非仅 canAttack。
    // O(对方活跃子数 × 滑动距离)；A-1 后最高频函数之一。

    /// 本方是否被将军（含将帅照面）。O(对方活跃子数 × 平均滑动距离)。
    func inCheck(_ side: Side) -> Bool {
        let sideIdx = Self.sideIndex(of: side)
        let myKingSq = kingSq[sideIdx]
        guard myKingSq >= 0 else { return true }   // 无将 = 被将（防御极端构造）
        let opponent: Side = (side == .red) ? .black : .red

        // 分量 1：canAttack 扫描
        for slot in 0..<32 {
            let sq = pieceSquares[slot]
            guard sq >= 0 else { continue }
            let code = pieceCodes[slot]
            guard PieceCode.side(of: code) == opponent else { continue }
            if canAttack(slot: slot, target: myKingSq) { return true }
        }

        // 分量 2：将帅照面（两王同列且中间无遮拦）
        let oppKingSq = kingSq[Self.sideIndex(of: opponent)]
        guard oppKingSq >= 0 else { return false }
        let myCol = Int(myKingSq) % 9, oppCol = Int(oppKingSq) % 9
        guard myCol == oppCol else { return false }
        let myRow = Int(myKingSq) / 9, oppRow = Int(oppKingSq) / 9
        let lo = min(myRow, oppRow) + 1, hi = max(myRow, oppRow)
        for r in lo..<hi {
            if mailbox[r * 9 + myCol] != PieceCode.empty { return false }   // 遮拦
        }
        return true   // 无遮拦 → 照面
    }

    /// 某槽位棋子能否攻击目标格（canAttack 语义，对齐 MoveValidator.isMovePatternValid）
    ///
    /// 将/士/象因宫殿/半场约束不可能攻击对方将格，直接 return false（棋规依据：
    /// 对方将格在己方宫殿/半场外）。其余 4 类完整实现，含蹩马腿/炮架计数。
    /// 同格防御 guard（mailbox 下同格不可能，作断言级保险——A3 精神）。
    private func canAttack(slot: Int, target: Int8) -> Bool {
        let fromSq = pieceSquares[slot]
        guard fromSq != target else { return false }              // 同格防御
        let code = pieceCodes[slot]
        let kind = PieceCode.kind(of: code)
        let side = PieceCode.side(of: code)
        let fromRow = Int(fromSq) / 9, fromCol = Int(fromSq) % 9
        let toRow = Int(target) / 9, toCol = Int(target) % 9

        switch kind {
        case .general, .advisor, .elephant:
            return false   // 棋规限制下不可能攻击对方将格
        case .horse:
            let dr = toRow - fromRow, dc = toCol - fromCol
            let adr = abs(dr), adc = abs(dc)
            guard (adr == 2 && adc == 1) || (adr == 1 && adc == 2) else { return false }
            let legRow = adr == 2 ? fromRow + (dr > 0 ? 1 : -1) : fromRow
            let legCol = adc == 2 ? fromCol + (dc > 0 ? 1 : -1) : fromCol
            return mailbox[legRow * 9 + legCol] == PieceCode.empty
        case .chariot:
            guard fromRow == toRow || fromCol == toCol else { return false }
            if fromRow == toRow {
                let step = toCol > fromCol ? 1 : -1
                var c = fromCol + step
                while c != toCol {
                    if mailbox[fromRow * 9 + c] != PieceCode.empty { return false }
                    c += step
                }
            } else {
                let step = toRow > fromRow ? 1 : -1
                var r = fromRow + step
                while r != toRow {
                    if mailbox[r * 9 + fromCol] != PieceCode.empty { return false }
                    r += step
                }
            }
            return true
        case .cannon:
            guard fromRow == toRow || fromCol == toCol else { return false }
            var screenCount = 0
            if fromRow == toRow {
                let step = toCol > fromCol ? 1 : -1
                var c = fromCol + step
                while c != toCol {
                    if mailbox[fromRow * 9 + c] != PieceCode.empty { screenCount += 1 }
                    c += step
                }
            } else {
                let step = toRow > fromRow ? 1 : -1
                var r = fromRow + step
                while r != toRow {
                    if mailbox[r * 9 + fromCol] != PieceCode.empty { screenCount += 1 }
                    r += step
                }
            }
            return screenCount == 1   // 炮吃子需恰好一个炮架
        case .soldier:
            let forward = side == .red ? -1 : 1
            if toRow == fromRow + forward && toCol == fromCol { return true }
            let hasCrossed = side == .red ? fromRow <= 4 : fromRow >= 5
            if hasCrossed && toRow == fromRow && abs(toCol - fromCol) == 1 { return true }
            return false
        }
    }

    /// baseValue 查询（soldier 过河翻倍与 Piece.baseValue 同语义，但经 mailbox 直查免构造）
    private func baseValueLookup(_ code: Int8, at sq: Int8) -> Int {
        switch PieceCode.kind(of: code) {
        case .general:  return 10000
        case .chariot:  return 900
        case .cannon:   return 450
        case .horse:    return 400
        case .advisor:  return 200
        case .elephant: return 200
        case .soldier:
            let row = Int(sq) / 9
            let side = PieceCode.side(of: code)
            let hasCrossed = (side == .red) ? row <= 4 : row >= 5
            return hasCrossed ? 200 : 100
        }
    }
}
