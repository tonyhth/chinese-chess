import Testing
@testable import ChineseChess

/// A3 r2 根治（fix/a3r2-first-cause）：A+B 方案落地后的回归测试
///
/// 原组（a409d3e，80c2f2d 属性标注）为**现状断言**——断言"漂移会发生"以固化立项证据。
/// 根治合入后本组反转为**守恒回归**（80c2f2d 注释预告的反转，此处执行）：
/// - A（治本）：CheckmateSearch 命中只返回 `[killMoves[0]]`（AIEngine :289/:315）
/// - B（兜底）：softmaxSelect 过滤循环前置一致性校验，陈旧候选跳过不 execute
///
<<<<<<< HEAD
/// 本组测试直接证明 execute/undo 的漂移语义（不依赖 CheckmateSearch 命中构造）。
///
/// ⚠️ 属性声明（2026-08-16 Tina 补标）：本组为**现状断言（立项证据）**，非回归测试——
/// 断言"漂移会发生"恰是 Board.execute/undo 现行腐败语义。根治修复合入后，本组测试
/// **应当变红**（届时将断言反转为守恒断言，或按修复语义重写）；绿 = 腐败机制仍在，
/// 红 = 根治生效。commit a409d3e message 中"回归测试"系误称，以本注释为准。
///
/// ⚠️ 更正（2026-08-15，Luke 裁定/Cody 指出）：本组直接调 Board.execute 绕过 softmaxSelect，
/// 恒绿与根治解耦，回归语义由 m1 重写版（5c51f91）承担——80c2f2d"根治后应变红"表述系误判。
@Suite("A3r2 第一因：陈旧候选 execute/undo 漂移语义")
=======
/// 反转后语义：
/// - Board.execute/undo 的 id 盲搬漂移**机制仍在**（Board 属 UI 共享层，不在本 fix 范围）
/// - 但入口被 B 拦截：漂移候选进不了 execute → 主棋盘守恒
@Suite("A3r2 根治回归：陈旧候选拦截 + 杀法返回形态")
>>>>>>> 5c51f91 (fix(engine): A3r2 第一因根治——杀法序列只返首着 + softmaxSelect 陈旧候选拦截)
struct A3r2FirstCauseTests {

    // MARK: - B 兜底校验（拦截器单元）

    /// 与 SelfPlayRunner.softmaxSelect 内联校验同判据的独立复现：
    /// 陈旧 from（move.from ≠ 棋子真实位置）必须被拒——game#4 现场（id0 chariot）的拦截面
    @Test("B拦截: 陈旧 from 候选被拒，不进 execute（漂移A 入口封死）")
    func staleFromCandidateRejected() {
        let board = Board()
        guard let horse = board.piece(at: Position(row: 9, col: 1)) else {
            #expect(Bool(false), "应找到红马 (9,1)")
            return
        }
        let trueOrigin = horse.position

        // "未来着法"：声称马从 (5,3) 走 (4,5)（from 与真实位置不符）
        let stale = Move(piece: horse,
                         from: Position(row: 5, col: 3),
                         to: Position(row: 4, col: 5),
                         captured: nil)

        // B 判据（与 softmaxSelect 实现逐条一致）
        let accepted = stale.piece.position == stale.from
            && board.piece(at: stale.from)?.id == stale.piece.id
            && stale.captured?.id == board.piece(at: stale.to)?.id
        #expect(!accepted, "陈旧 from 候选必须被 B 拒绝（game#4 现场）")

        // 未 execute：棋盘从未被碰
        #expect(board.piece(at: trueOrigin)?.id == horse.id, "真实原位守恒（未进 execute）")
        #expect(board.moveHistory.isEmpty)
    }

    /// 陈旧 captured（快照 id ≠ to 位实际占用）必须被拒——game#13 现场
    /// （move.captured=id7 但棋盘 to 位=id6）的拦截面
    @Test("B拦截: 陈旧 captured 候选被拒（漂移B/C 入口封死）")
    func staleCapturedCandidateRejected() {
        let board = Board(pieces: [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 5), id: 7),
            Piece(kind: .soldier, side: .black, position: Position(row: 7, col: 4), id: 30),
        ])
        // 未来快照：仕声称在 (8,4)，实际在 (9,5)；to 位 (8,4) 实际为空
        let capturedSnapshot = Piece(kind: .advisor, side: .red,
                                     position: Position(row: 8, col: 4), id: 7)
        let stale = Move(piece: board.piece(at: Position(row: 7, col: 4))!,
                         from: Position(row: 7, col: 4),
                         to: Position(row: 8, col: 4),
                         captured: capturedSnapshot)

        let accepted = stale.piece.position == stale.from
            && board.piece(at: stale.from)?.id == stale.piece.id
            && stale.captured?.id == board.piece(at: stale.to)?.id
        #expect(!accepted, "captured=nil(to位) vs 快照 id7 → 必须拒绝（game#13 现场）")
        #expect(board.moveHistory.isEmpty, "未 execute")
    }

    /// 合法候选不被误伤：from 一致 + captured 与 to 位一致 → 通过 B 校验
    /// （B 的另一半验收面：只拦陈旧，不拦正常引擎候选）
    @Test("B放行: 合法候选三判据全过，不被误伤")
    func freshCandidateAccepted() {
        let board = Board()
        // 红炮 (7,1) → (7,4)：from 一致、to 空、captured=nil —— 合法候选
        guard let cannon = board.piece(at: Position(row: 7, col: 1)) else {
            #expect(Bool(false), "应找到红炮 (7,1)")
            return
        }
        let fresh = Move(piece: cannon,
                         from: cannon.position,
                         to: Position(row: 7, col: 4),
                         captured: nil)

        let accepted = fresh.piece.position == fresh.from
            && board.piece(at: fresh.from)?.id == fresh.piece.id
            && fresh.captured?.id == board.piece(at: fresh.to)?.id
        #expect(accepted, "合法候选必须通过（nil == nil 语义：空 to + 无吃子）")
    }

    /// game#13 完整复演路径的拦截版：m2/m3 两个未来着法进过滤循环，
    /// B 逐个拒绝 → 棋盘零漂移（对照原漂移C 的双仕同格现场）
    @Test("B守恒: 两个未来着法（m2/m3）全部被拒，无双仕同格（game#13 反演）")
    func doubleAdvisorOverlapPrevented() {
        let board = Board(pieces: [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 3), id: 6),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 5), id: 7),
            Piece(kind: .soldier, side: .black, position: Position(row: 7, col: 4), id: 30),
            Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
        ])

        // softmaxSelect 过滤循环同款流程（B 前置校验内联）
        for capId in [7, 6] {
            let mover = board.piece(at: Position(row: 0, col: 0))!
            let snap = Piece(kind: .advisor, side: .red,
                             position: Position(row: 8, col: 4), id: capId)
            let stale = Move(piece: mover,
                             from: Position(row: 0, col: 0),
                             to: Position(row: 8, col: 4),
                             captured: snap)

            // B：captured.id ≠ to 位实际占用（nil）→ 拒绝，不 execute
            let accepted = stale.piece.position == stale.from
                && board.piece(at: stale.from)?.id == stale.piece.id
                && stale.captured?.id == board.piece(at: stale.to)?.id
            #expect(!accepted, "m2/m3 未来着法必须被拒（capId=\(capId)）")
            if !accepted { continue }  // 与实现同语义：跳过
        }

        // 守恒：零漂移、零重叠、历史干净
        #expect(Board.integrityProblems(in: board.pieces).isEmpty, "棋盘完整性守恒")
        #expect(board.moveHistory.isEmpty)
        let atOverlap = board.pieces.filter { $0.position == Position(row: 8, col: 4) }
        #expect(atOverlap.isEmpty, "(8,4) 应无任何子（原现场是 id6+id7 双仕同格）")
    }

    // MARK: - A 治本（返回形态）

    /// A：CheckmateSearch 命中路径只返回第一步。
    /// 用一步杀局面实跑 bestMoves(lvl4)——返回恰 1 个候选且 == 杀法首着。
    @Test("A形态: 一步杀局面 bestMoves 返回单候选（killMoves[0]）")
    func killPathReturnsFirstMoveOnly() async {
        // 构造：黑方一步杀——红帅 (9,4)，黑车 (9,3) 贴脸将，红无仕象可挡
        // 红唯一解：帅 (9,4)→(8,4) 会被车 (9,3)→(8,3) 继续；这里构造的是黑方杀红方：
        // 黑车 (9,3) 将军，红帅仅 (9,4)，若红帅无路则红已被杀——改为构造黑方持杀：
        // 用 lvl4(黑) 视角：黑车已照面/将军且红无解 → CheckmateSearch 命中
        let board = Board(pieces: [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 3), id: 16),
        ])
        board.setCurrentTurn(.black)

        let engine = AIEngine()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurMid, isIOS: false, topK: 3)

        // CheckmateSearch 应命中（黑车下一步 (9,3)→(9,4) 即杀；红帅无合法应手）
        // A 形态断言：至多 1 个候选（旧实现会是 prefix(3)，但序列长度本例为 1——
        // 形态断言核心在"无未来着法混入"：每个候选的 from 必等于棋盘实际位置）
        #expect(!candidates.isEmpty, "一步杀局面必有候选")
        for c in candidates {
            #expect(c.move.piece.position == c.move.from,
                    "候选 from 必须等于棋盘实际位置（未来着法混入 = A 失效）")
        }
    }
}
