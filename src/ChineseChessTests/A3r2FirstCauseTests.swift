import Testing
@testable import ChineseChess

/// A3 r2 根治立项：第一因复现测试（2026-08-15）
///
/// 现场：overlap-dumps/illegal-position-dump.log（game#4 / game#13，HEAD=dd94f15 运行）
/// 机制：CheckmateSearch 命中时 `killMoves.prefix(topK)` 把杀法序列第 2+ 步（未来局面的着法）
///       当作候选传给 softmaxSelect 过滤循环；Board.execute/undoLastMove 按 id 盲操作：
///       - execute 不校验 from 位，按 id teleport + 按 id 删 captured
///       - undo 把棋子放回 move.from（声称为，非真实原位）、captured 复活到快照 position
///       净效果：每对 execute/undo 把棋子永久漂移到"未来位置"→ 棋盘腐败。
///
/// 本组测试直接证明 execute/undo 的漂移语义（不依赖 CheckmateSearch 命中构造）。
///
/// ⚠️ 属性声明（2026-08-16 Tina 补标）：本组为**现状断言（立项证据）**，非回归测试——
/// 断言"漂移会发生"恰是 Board.execute/undo 现行腐败语义。根治修复合入后，本组测试
/// **应当变红**（届时将断言反转为守恒断言，或按修复语义重写）；绿 = 腐败机制仍在，
/// 红 = 根治生效。commit a409d3e message 中"回归测试"系误称，以本注释为准。
@Suite("A3r2 第一因：陈旧候选 execute/undo 漂移语义")
struct A3r2FirstCauseTests {

    /// 机制一（game#4 现场）：move.from ≠ 棋子真实位置时，
    /// execute→undo 配对完整（栈空、无失败信号），但棋子被永久放到 move.from。
    @Test("漂移A: 陈旧 from 经 execute/undo 对后棋子漂到 move.from")
    func staleFromDrift() {
        let board = Board()
        // 红马开局在 (9,1)
        guard let horse = board.piece(at: Position(row: 9, col: 1)) else {
            #expect(Bool(false), "应找到红马 (9,1)")
            return
        }
        let trueOrigin = horse.position

        // 构造"未来着法"：声称马从 (5,3) 走 (4,5)（from 与真实位置不符，captured=nil）
        let stale = Move(piece: horse,
                         from: Position(row: 5, col: 3),
                         to: Position(row: 4, col: 5),
                         captured: nil)

        board.execute(stale)
        board.undoLastMove()

        // execute/undo 配对完整：栈空、无任何失败信号
        #expect(board.moveHistory.isEmpty, "undo 栈应已空（配对完整）")

        // 但真实原位失守、棋子漂到 move.from —— teleport 残留
        #expect(board.piece(at: trueOrigin) == nil,
                "undo 后真实原位 \(trueOrigin) 应失守（复现 game#4：id0 丢失 (1,4)）")
        let drifted = board.piece(at: Position(row: 5, col: 3))
        #expect(drifted?.id == horse.id,
                "棋子应漂移到陈旧 from=(5,3)（复现 game#4：id0 出现在 (1,3)）")
    }

    /// 机制二（game#13 现场）：captured 快照的 position 是"未来局面的被吃位"，
    /// undo 复活时按快照位置放回 → 被吃子漂移；两步此类漂移即可造出双仕同格。
    @Test("漂移B: captured 复活到快照位置而非消亡前真实位置")
    func staleCapturedReviveDrift() {
        // 最小局面：红仕 (9,5)、黑卒 (7,4)、双帅各归位（省略其余子，腐败演示无需完整开局）
        let board = Board(pieces: [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 5), id: 7),
            Piece(kind: .soldier, side: .black, position: Position(row: 7, col: 4), id: 30),
        ])
        guard let soldier = board.piece(at: Position(row: 7, col: 4)) else {
            #expect(Bool(false), "应找到黑卒 (7,4)")
            return
        }
        // 未来局面快照：仕已应将到 (8,4)，卒吃 (8,4) 的仕
        let capturedSnapshot = Piece(kind: .advisor, side: .red,
                                     position: Position(row: 8, col: 4), id: 7)
        let stale = Move(piece: soldier,
                         from: Position(row: 7, col: 4),
                         to: Position(row: 8, col: 4),
                         captured: capturedSnapshot)

        board.execute(stale)
        board.undoLastMove()

        #expect(board.moveHistory.isEmpty, "undo 栈应已空（配对完整）")

        // 卒回到真实原位（from 恰好一致）
        #expect(board.piece(at: Position(row: 7, col: 4))?.id == soldier.id, "from 一致时卒应回原位")

        // 但仕漂到快照位 (8,4)，真实原位 (9,5) 失守 —— 双子重叠的原料
        #expect(board.piece(at: Position(row: 9, col: 5)) == nil,
                "仕真实原位 (9,5) 应失守")
        #expect(board.piece(at: Position(row: 8, col: 4))?.id == 7,
                "仕应复活在快照位 (8,4)（复现 game#13：id7 漂到 (8,4)）")
    }

    /// 组合演示：两次"机制二"漂移（captured 快照都指向同一格 (8,4)）
    /// 即得到 game#13 ply#56 pre 的现场——id6/id7 双仕同格 (8,4)。
    @Test("漂移C: 两次 captured 复活漂移造出双仕同格（game#13 现场）")
    func doubleAdvisorOverlap() {
        let board = Board(pieces: [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 3), id: 6),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 5), id: 7),
            Piece(kind: .soldier, side: .black, position: Position(row: 7, col: 4), id: 30),
            Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
        ])
        // 模拟 softmaxSelect 过滤循环对两个"未来着法"（m2、m3）各做一次 execute/undo：
        for capId in [7, 6] {
            guard let mover = board.piece(at: Position(row: 0, col: 0)) else {
                #expect(Bool(false), "应找到黑车")
                return
            }
            let snap = Piece(kind: .advisor, side: .red,
                             position: Position(row: 8, col: 4), id: capId)
            let stale = Move(piece: mover,
                             from: Position(row: 0, col: 0),
                             to: Position(row: 8, col: 4),
                             captured: snap)
            board.execute(stale)
            board.undoLastMove()
        }

        // game#13 现场：id6 与 id7 同格 (8,4)，各自原位失守
        let atOverlap = board.pieces.filter { $0.position == Position(row: 8, col: 4) }
        #expect(atOverlap.count == 2, "应有两子同格 (8,4)，实际: \(atOverlap.map(\.id))")
        #expect(Set(atOverlap.map(\.id)) == [6, 7], "同格应为 id6+id7 双仕")
        #expect(board.moveHistory.isEmpty, "undo 栈应已空（全程配对完整、零失败信号）")
    }
}
