import Foundation
import Testing
@testable import ChineseChess

// MARK: - T-1102-1 判别锚路线二：判定循环语义钉（loop-semantics pin）
//
// 裁定口径（权威 spec）：docs/reviews/T-1101-5-anchor-verdict-vera.md §3.2
// 夹具：复用 Phase2bTests.swift nineResponsesFullValidationContract 既有 10 应将锚局面
//（真实合法局面，零作曲——裁定 §3.2「复用既有锚局面」）。
//
// 保护面声明（裁定 §3.2 诚实披露，随测试固化）：
//   本钉护「全量校验循环语义」回归向量（prefix(k) 截断回潮 / 早退假优化——750ms 全量
//   成本压力是现实回归向量，P3-N1 fix 注记自认）；它**不证明战略层 FP 行为**（真实局面
//   假阳性）——后者只能靠作曲锚（裁定 §3.4 路线一域，冻结候重开三条款）。
//   对 P3 强化资产目标，语义层判红已足够（裁定 §3.2 原文）。

@Suite("T1102 判定循环语义钉", .serialized)
struct CheckmateLoopSemanticsTests {

    // MARK: 夹具（与 nineResponsesFullValidationContract 同源复用，零作曲）
    // 红帅 (9,3)，红车 R1 (3,3)；黑将 (0,4)，士 (0,3)/(0,5)，马 (2,2)/(2,6)，
    // 相 (4,2)/(4,6)，车 (3,1)/(3,8)。R1 (3,3)→(3,4) 直将后黑方恰 10 应将。

    private func anchorPieces() -> [Piece] {
        [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 3), id: 8),
            TestPieceFactory.blackGeneral(0, 4),
            TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 3, col: 3)),
            TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 0, col: 3)),
            TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 0, col: 5)),
            TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 2)),
            TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 6)),
            TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 2)),
            TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 6)),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 1)),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 8)),
        ]
    }

    /// pre-check 局面（红先行，R1 尚在 (3,3)——search 的探索起点）
    private func anchorPreCheckBoard() -> Board {
        let b = Board(pieces: anchorPieces())
        b.setCurrentTurn(.red)
        return b
    }

    /// 应将态局面（R1 (3,3)→(3,4) 已执行——应将清点/夹具漂移门用）
    private func anchorCheckedBoard() -> Board {
        let b = Board(pieces: anchorPieces())
        b.setCurrentTurn(.red)
        let r1 = b.piece(at: Position(row: 3, col: 3))!
        b.execute(Move(piece: r1, from: Position(row: 3, col: 3), to: Position(row: 3, col: 4), captured: nil))
        return b
    }

    @Test("语义钉：受控 oracle 下全量循环越过 prefix(8) 窗口（裁定 §3.2 验收四条）")
    func loopSemanticsPinUnderControlledOracle() {
        // ── ④ 前置断言：应将 ≥9（夹具漂移门——:81 模式沿用） ──
        let checked = anchorCheckedBoard()
        let responses = MoveValidator.allLegalMoves(for: .black, on: checked)
        #expect(responses.count >= 9, "夹具应将手数应 ≥9（实测 \(responses.count)）——语义钉前提（裁定 §3.2④）")

        // ── ①+② 受控 oracle 注入（裁定 §3.2① + 实施适配注记） ──
        // 原口径=纯调用计数（前 8 次调用判红赢、第 9 次起判黑活）。实施首跑实证
        // （证据 ~/DevTeam/evidence/t1102-1-cody/first-run-order-proof.log，Ruby P3-4 路径勘误）：本夹具有两条将军线（锦线 R1→(3,4) 十应将 /
        // 非锦线 R1xa2+ 仅 2 应将），checkMoves 生成序非锦线先行——纯调用计数下 R1xa2+ 的
        // 2 次调用全落前窗口即翻 mate，断言①失效。适配=oracle 增 checkMove 判别键：
        // 锦线按 responseIndex 注入（前 8 应将=败着、第 9 起活手），非锦线注入真实语义
        // 对齐真值（恒黑活——该线本不构成强制杀，与真实 dfs 判定一致）。适配回 Vera
        // 再裁通道注记在缝头（裁定单 §六实施异议回流）。
        var oracleCalls = 0
        CheckmateSearch.debugResponseOracle = { checkMove, responseIndex in
            oracleCalls += 1
            if checkMove.to.row == 3 && checkMove.to.col == 4 {
                return responseIndex < 8   // 锦线：前 8 应将判红赢（败着）、第 9 起判黑活
            }
            return false                    // 非锦将军线：真实语义对齐真值（黑活）
        }
        defer { CheckmateSearch.debugResponseOracle = nil }

        let preCheck = anchorPreCheckBoard()
        let result = CheckmateSearch.search(board: LegacySearchBoard(from: preCheck), for: .red, maxDepth: 8)
        #expect(result == nil, "受控 oracle（前 8 败着、第 9 起活手）下全量校验须拒杀——prefix(k) 截断回潮则此处翻 mate（裁定 §3.2①）")
        #expect(oracleCalls >= 9, "oracle 调用计数 ≥9 = 全量循环越过旧 prefix(8) 窗口（实测 \(oracleCalls)；注：本断言为正向窗口判别且序依赖，截断回潮的序免疫硬门=断言① search==nil——Ruby P3-2 勘误）（裁定 §3.2②）")

        // ── ③ 判别力自证（文档级对照，不承担生产门禁——裁定 §3.2③） ──
        // 测试侧 prefix(8) 克隆循环喂同语义判定（只问前 8 次调用）→ 前窗口全胜 → 克隆判 mate，
        // 与①search==nil 成判别对照：旧语义（prefix 截断）在相同注入真值下结论翻红。
        // 注（Ruby P3-3）：克隆为演示性文档级对照——构造上不可失败（同义反复），其判别
        // 价值在文档叙事不在断言门禁（spec §3.2③ 定位如此）。
        func oracleSemantics(callCount: Int) -> Bool { callCount <= 8 }
        var cloneCalls = 0
        var cloneDeclaresMate = true
        for _ in responses {
            if cloneCalls >= 8 { break }                    // 旧 prefix(8)：窗口外不问
            cloneCalls += 1
            if !oracleSemantics(callCount: cloneCalls) {
                cloneDeclaresMate = false
                break
            }
        }
        #expect(cloneDeclaresMate, "③ prefix(8) 克隆循环在前 8 次全胜下判 mate——旧语义模拟，与① search==nil 成判别对照（裁定 §3.2③）")
    }
}
