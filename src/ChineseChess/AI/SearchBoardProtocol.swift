// SearchBoardProtocol.swift — P2c 切换协议（m1-hotpath-redesign v1.2 §7.1 P2c · D4 拆分方案①）
//
// 搜索循环的棋盘后端协议：统一 Legacy / V2 的消费面，AIEngine 搜索族泛型化后
// 双后端全量编译覆盖——默认 Legacy 构造（零行为变化），P2c-② 落 USE_SEARCHBOARD_V2
// 开关后按 flag 选择后端。
//
// 设计要点（v1.2 §2.4 / §3.2 / D4 P1）：
// - 变异面 = make/unmake（A-1 目标 API）；Legacy shim 走 execute/undoLastMove 原语义
// - 生成面 = legalMoves / captureCandidates，谓词与交叉对比断言 A/A' 同源
//   （31,483 局面四断言全绿，commit 54752ed）
// - V2 吃子候选不含吃己方候选（Legacy QS 粗候选 v3.9 存量行为，A' 归因裁定不修，
//   known-issues 挂账，切换后随 Legacy 废弃自然消亡）
// - CheckmateSearch 桥接：V2 → Legacy 重建（每 lvl4/5 步一次，非热路径，D4 P1 最小方案）
// - isLegal/生成面非 mutating（V2 实现在自副本上 make，协议消费者零 inout 传染）

protocol SearchBoardProtocol: BoardReadable {
    associatedtype Undo

    // ── 变异（A-1 目标 API）──
    @discardableResult mutating func make(_ move: Move) -> Undo
    mutating func unmake(_ undo: Undo)
    mutating func toggleTurn()

    // ── 判定（V2 = mailbox 快路径；谓词等价 = 交叉对比断言 C）──
    func inCheck(_ side: Side) -> Bool
    func isLegal(_ move: Move) -> Bool

    // ── 生成（合法集 = 断言 A 同谓词；吃子候选 = QS 粗候选语义）──
    func legalMoves(for side: Side) -> [Move]
    func captureCandidates(for side: Side) -> [Move]

    // ── A-1 伪合法化（P3-②，phase3.md v1.2 §3.2）──
    /// 搜索循环候选源：Legacy = legalMoves（预过滤集，循环免自将检测）；
    /// V2 = MoveGenerator.pseudoLegalMoves（循环内单遍 make+inCheck 过滤）。
    /// 谓词等价由交叉对比断言 A 背书（pseudo − 送将集 == Legacy 合法集）。
    func pseudoMoves(for side: Side) -> [Move]
    /// true = pseudoMoves 返回集已这合法（Legacy）；false = 需循环内过滤（V2）
    var moveSetPreFiltered: Bool { get }

    // ── CheckmateSearch 桥接（D4 P1：Legacy 直通副本，V2 pieces 重建）──
    func asLegacyForCheckmate() -> LegacySearchBoard

    // ── MoveOrderer.checkLegal 分支可用性（§7.2 P2 守门⑦：V2 无拷贝路径 → false）──
    var supportsCheckLegalOrder: Bool { get }

    // ── NMP 守门快路径（v1.2 §2.4 三层防线②，P3-0 接线）──
    /// 非守子子力和（排除 general/advisor/elephant）。V2 = 槽位扫描直实现；
    /// Legacy = pieces(for:) 循环（原语义，零行为变化）。每节点至多一次（depth≥3 NMP 守门）。
    func nonGuardMaterial(_ side: Side) -> Int
}

// MARK: - Legacy 实现（零行为变化：全部路由到现有 MoveValidator / execute 路径）

extension LegacySearchBoard: SearchBoardProtocol {
    typealias Undo = Void

    mutating func make(_ move: Move) { execute(move) }
    mutating func unmake(_: Void) { _ = undoLastMove() }

    func inCheck(_ side: Side) -> Bool { MoveValidator.isInCheck(side, on: self) }
    func isLegal(_ move: Move) -> Bool { MoveValidator.isLegal(move, on: self) }

    func legalMoves(for side: Side) -> [Move] { MoveValidator.allLegalMoves(for: side, on: self) }
    func captureCandidates(for side: Side) -> [Move] { MoveValidator.captureMoves(for: side, on: self) }

    func pseudoMoves(for side: Side) -> [Move] { legalMoves(for: side) }
    var moveSetPreFiltered: Bool { true }

    func asLegacyForCheckmate() -> LegacySearchBoard { self }

    var supportsCheckLegalOrder: Bool { true }

    func nonGuardMaterial(_ side: Side) -> Int {
        var total = 0
        for piece in pieces(for: side) {
            if piece.kind != .general && piece.kind != .advisor && piece.kind != .elephant {
                total += piece.baseValue
            }
        }
        return total
    }
}

// MARK: - V2 实现（谓词组合 = 交叉对比断言 A + C + D，31,483 局面验证）

extension SearchBoardV2: SearchBoardProtocol {
    typealias Undo = UndoInfo

    // make / unmake / toggleTurn / inCheck 为 §2 原生实现，协议直用
    // nonGuardMaterial 为 §2.4 原生实现（P3-0 接线：槽位扫描直实现，三层防线②）

    /// 伪合法成员匹配 + make 后自将检测（自副本执行，self 不变）。
    /// 谓词 = 断言 A（伪生成全等）∩ 断言 C（inCheck 双实现全等）。
    func isLegal(_ move: Move) -> Bool {
        guard let pseudo = MoveGenerator.pseudoLegalMoves(on: self).first(where: {
            $0.piece.id == move.piece.id && $0.from == move.from && $0.to == move.to
                && $0.captured?.id == move.captured?.id
        }) else { return false }
        var work = self
        work.make(pseudo)
        return !work.inCheck(move.piece.side)
    }

    /// 伪合法 − 送将集（断言 A 同谓词；自副本上逐走法 make/inCheck/unmake 过滤）
    func legalMoves(for side: Side) -> [Move] {
        var work = self
        return MoveGenerator.pseudoLegalMoves(on: self).filter { m in
            let undo = work.make(m)
            let leavesKingInCheck = work.inCheck(side)
            work.unmake(undo)
            return !leavesKingInCheck
        }
    }

    /// QS 粗候选：capturesOnly 伪生成，无送将过滤（与 Legacy QS 候选语义同型）。
    /// V2 净化面不含吃己方候选（A' 归因裁定，见文件头注释）。
    func captureCandidates(for side: Side) -> [Move] {
        MoveGenerator.pseudoLegalMoves(on: self, capturesOnly: true)
    }

    func pseudoMoves(for side: Side) -> [Move] {
        MoveGenerator.pseudoLegalMoves(on: self)
    }
    var moveSetPreFiltered: Bool { false }

    /// Legacy 重建（O(32)，每 lvl4/5 步一次非热路径；pieces 读面 = 交叉对比 b 源复算面）
    func asLegacyForCheckmate() -> LegacySearchBoard {
        LegacySearchBoard(pieces: pieces, currentTurn: currentTurn, moveHistory: moveHistory)
    }

    /// P3-①（phase3.md §3.1）：givesCheckV2 快路径已建，V2 恢复 depth≥3 将军排序增益
    /// （AIEngine 三处 "depth >= 3 && supportsCheckLegalOrder" 门控自然兑现，无需摘除）。
    var supportsCheckLegalOrder: Bool { true }
}
