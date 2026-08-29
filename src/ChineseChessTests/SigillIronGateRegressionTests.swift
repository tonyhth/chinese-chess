import Foundation
import Testing
@testable import ChineseChess

// MARK: - 2026-08-29 11:03 SIGILL 崩溃案回归锚（v6.3，Eric）
//
// 案情：crash log ChineseChess-2026-08-29-110350.ips
//   Thread 7: noLegalMovesReturnsNil → bestMove → rootSearch → negamax
//             → AIEvaluator.evaluate → bonusPatterns:105 → isIronGate:288
//   Fatal: "Range requires lowerBound <= upperBound"（minRow..<maxRow 空 Range trap）
//
// 根因链（runner 日志 full-110044.log + overlap-dumps 实证）：
//   1. 全量批单进程共享 TestPieceFactory id 池，池轮转回落 0..31 时与手写
//      字面量 fixture（id:8/24 等）同盘撞 id（dump 实证：LegacySearchBoard.execute
//      "重复 ID: 8"；Board.execute "重复位置(9,4): cannon 与 general"）
//   2. LegacySearchBoard.execute/undo 按 firstIndex(id) 定位 → 错移棋子（将瞬移）
//   3. 车将同格 → isIronGate minRow(=row+1) > maxRow(=row) → SIGILL
//
// 修复双件套：
//   A. TestPieceFactory 池迁 64..127（与字面量 0..31 物理隔离）——根因层
//   B. isIronGate 空 Range 防御（dump + return false）——防御层
//
// 本 suite 钉两层指纹：根因层（id 区段隔离）+ 防御层（腐败局面评估不杀进程）。
// 注："恒真断言"是有意的——语义是"执行到达此处 = 未 trap"，trap 会直接杀进程。

@Suite("SIGILL 铁门栓案回归（2026-08-29）")
struct SigillIronGateRegressionTests {

    // MARK: - 根因层：工厂 id 区段隔离

    @Test("工厂 id 全轮转周期（129 次分配）永不落入 0..31 字面量区")
    func factoryIdsNeverCollideWithLiteralRange() {
        TestPieceFactory.resetForFreshPosition()
        var seen = Set<Int>()
        for i in 0..<129 {  // > 2× 池位，覆盖整轮转周期
            let p = TestPieceFactory.makePiece(kind: .soldier, side: .red,
                                               position: Position(row: 6, col: i % 9))
            #expect(p.id >= 64 && p.id <= 127, "工厂 id \(p.id) 越出 64..127 隔离区（第 \(i) 次分配）")
            seen.insert(p.id)
        }
        // 单轮转周期（64 池位）内不重复
        #expect(seen.count == 64, "64 池位轮转周期内应无重复，实际 \(seen.count)")
    }

    @Test("工厂 id 与手写字面量 fixture 同盘不撞（原案现场重构）")
    func factoryIdDoesNotCollideWithHandwrittenGenerals() {
        // 原 AIEngineTests.noLegalMovesReturnsNil 构造形态：手写将帅 8/24 + 工厂车
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let ch1 = TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 8, col: 3))
        let ch2 = TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 8, col: 5))
        let allIds = [redGeneral.id, blackGeneral.id, ch1.id, ch2.id]
        #expect(Set(allIds).count == allIds.count, "同盘 id 必须互异：\(allIds)")
    }

    // MARK: - 防御层：腐败局面评估不杀进程

    /// 直接复刻崩点形态：车与将同格（重复 id 的 execute 错移产物），
    /// isIronGate 必须经防御分支返回 false，绝不能 trap。
    @Test("车将同格腐败局面：bonusPatterns 不崩（铁门栓防御分支指纹）")
    func ironGateOverlappingPiecesDoesNotTrap() {
        // 黑车与红将同格 (4,4)；同列同格 = 原 SIGILL 的精确前置条件
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 4, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let chariot = Piece(kind: .chariot, side: .black, position: Position(row: 4, col: 4), id: 64)
        let board = LegacySearchBoard(pieces: [redGeneral, blackGeneral, chariot], currentTurn: .black)

        // 双视角评估：黑方视角 isIronGate(黑车, 红将) 同格 → 原 trap 点
        _ = PatternRecognizer.bonusPatterns(on: board, for: .red)
        _ = PatternRecognizer.bonusPatterns(on: board, for: .black)
        #expect(true)  // 到达即未 trap
    }

    /// 端到端指纹：原案触发局面（含故意注入的重复 id）走完整 bestMove 搜索不崩。
    @Test("终局退化局面 + 重复 id：bestMove 全搜索不崩（端到端指纹）")
    func endgameDegenerateWithDuplicateIdDoesNotCrash() async {
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        // 故意复刻案发形态：字面量 8 与黑车同 id（修复前 = 池轮转撞上的等效态）
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 8, col: 3), id: 8)
        let blackChariot2 = TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 8, col: 5))
        let board = Board(pieces: [redGeneral, blackGeneral, blackChariot, blackChariot2])
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        // 防御层生效 = 进程必须存活（返回值本身不作断言）
        _ = await engine.bestMove(for: board, difficulty: .beginner)
        #expect(true)  // 到达即未 SIGILL
    }
}
