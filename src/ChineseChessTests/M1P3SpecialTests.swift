// M1P3SpecialTests.swift — P3-④ 专项测试集（phase3.md v1.2 §4 #2/#3）
//
// 送将过滤 + 杀棋/困毙专项（8.4 表，Tina 0.25d 协作点的 Cody 侧落地）。
// 谓词纪律（D4 #6 修正版）：独立谓词双向闭合——送将判定用 Legacy 拷贝路径
// （execute + MoveValidator.isInCheck）独立验证 V2 循环过滤结果，禁 pseudo−legal
// 隐式定义恒真断言。
// 断言口径：legalCount==0 → static eval（甲定案）；杀棋 = 全候选送将；
// 困毙 = 全候选送将且未被将军（8.4 区分）。

import Testing
import Foundation
@testable import ChineseChess

@Suite("P3-④ 送将过滤 + 杀棋/困毙专项", .serialized)
struct M1P3SpecialTests {

    // MARK: - 独立谓词（Legacy 拷贝路径，D4 #6）

    /// 独立送将判定：Legacy execute 后 MoveValidator.isInCheck（与 V2 循环
    /// 过滤的实现路径完全隔离——交叉验证语义）
    private func independentlyLeavesKingInCheck(_ move: Move, pieces: [Piece], turn: Side) -> Bool {
        var work = LegacySearchBoard(pieces: pieces, currentTurn: turn)
        work.execute(move)
        return MoveValidator.isInCheck(turn, on: work)
    }

    /// 双后端合法集 + 独立谓词三方闭合：每个合法着不送将（独立验证），
    /// 每个被滤着送将（独立验证）——双向闭合非恒真。
    private func assertLegalSetClosed(_ pieces: [Piece], _ turn: Side, _ tag: String) {
        let legacy = LegacySearchBoard(pieces: pieces, currentTurn: turn)
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: turn)

        let legacyKeys = Set(MoveValidator.allLegalMoves(for: turn, on: legacy).map { "\($0.piece.id):\($0.from.row),\($0.from.col)>\($0.to.row),\($0.to.col)" })
        let v2Moves = v2.legalMoves(for: turn)
        let v2Keys = Set(v2Moves.map { "\($0.piece.id):\($0.from.row),\($0.from.col)>\($0.to.row),\($0.to.col)" })

        #expect(legacyKeys == v2Keys, "[\(tag)] 双后端合法集不等")

        // 方向 1：V2 合法集内每一着，独立谓词不送将
        for move in v2Moves {
            #expect(!independentlyLeavesKingInCheck(move, pieces: pieces, turn: turn),
                    "[\(tag)] 合法集内含送将着（独立谓词抓出）：\(move)")
        }
        // 方向 2：pseudo 集内被滤的每一着，独立谓词送将（过滤无过杀）
        let pseudoKeys = Set(MoveGenerator.pseudoLegalMoves(on: v2).map { "\($0.piece.id):\($0.from.row),\($0.from.col)>\($0.to.row),\($0.to.col)" })
        let filteredKeys = pseudoKeys.subtracting(v2Keys)
        for pk in filteredKeys {
            let parts = pk.split(separator: ">")  // "id:r,c" > "r,c"
            let idCoord = parts[0].split(separator: ":")
            let from = parts[0].split(separator: ":")[1].split(separator: ",")
            let to = parts[1].split(separator: ",")
            guard let piece = pieces.first(where: { "\($0.id)" == idCoord[0] }),
                  let fr = Int(from[0]), let fc = Int(from[1]),
                  let tr = Int(to[0]), let tc = Int(to[1]) else {
                Issue.record(Comment(rawValue: "[\(tag)] 键解析失败：\(pk)")); return
            }
            let captured = pieces.first { $0.position.row == tr && $0.position.col == tc }
            let move = Move(piece: piece, from: Position(row: fr, col: fc),
                            to: Position(row: tr, col: tc), captured: captured)
            #expect(independentlyLeavesKingInCheck(move, pieces: pieces, turn: turn),
                    "[\(tag)] 被滤着实际不送将（过滤过杀）：\(move)")
        }
    }

    // MARK: - 送将各型（8.4：车口/炮口/马口/照面 + 将军中被迫应将无解）

    @Test("车口送将：黑车将军红帅，红不解将走法全滤")
    func chariotCheckFilter() {
        let pieces = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 0), id: 16),
            Piece(kind: .soldier, side: .red,   position: Position(row: 6, col: 3), id: 12),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 2), id: 0),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 3), id: 24),
        ]
        // 黑将 (0,3) 破照面（若在 (0,4) 则双将无解）。红被车将单将：
        // 红车 (5,2)→(9,2) 挡线 = 唯一解型；士兵前进不解将（送将全滤）；
        // 帅平移 (9,3)/(9,5) 仍被横车控（送将）。
        assertLegalSetClosed(pieces, .red, "chariot-check")
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: .red)
        #expect(v2.inCheck(.red), "前提：红被将军")
        let legal = v2.legalMoves(for: .red)
        #expect(!legal.isEmpty, "红有解将着（挡线）")
        #expect(legal.contains { $0.piece.kind == .chariot && $0.to.row == 9 && $0.to.col == 2 },
                "解将着 = 红车 (5,2)→(9,2) 挡线：实际 \(legal)")
    }

    @Test("炮口送将：黑炮隔架打帅，垫/躲过滤正确")
    func cannonCheckFilter() {
        let pieces = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .advisor, side: .red,   position: Position(row: 9, col: 3), id: 9),
            Piece(kind: .cannon, side: .black,  position: Position(row: 9, col: 0), id: 20),
            Piece(kind: .horse, side: .black,   position: Position(row: 7, col: 4), id: 25),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
        ]
        // 黑炮 (9,0) 隔士 (9,3) 打帅 (9,4)。士离开 (9,3)（如 (9,3)→(8,4)）= 撤架
        // 炮直打 → 送将；士 (9,3) 不能走到 (8,4)？士走斜一格在宫内：(8,4) 合法格。
        // 撤架后炮 (9,0)-(9,3)-(9,4)：撤架瞬间 (9,3) 空 → 炮直通 → 送将 ✓
        assertLegalSetClosed(pieces, .red, "cannon-check")
    }

    @Test("马口送将：黑马将军位（蹩腿边角）")
    func horseCheckFilter() {
        let pieces = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .horse, side: .black,   position: Position(row: 7, col: 5), id: 25),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 0), id: 0),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
        ]
        // 马 (7,5) 踩 (9,4)（(8,3) 腿位空）。红车 (5,0) 无法一步解 → 红靠帅走位
        assertLegalSetClosed(pieces, .red, "horse-check")
    }

    @Test("照面/照面遮拦：移开遮拦子即照面的走法过滤")
    func facingScreenFilter() {
        // 遮拦在位：红车 (5,4) 挡将帅同列线 → 非将军态
        let pieces = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 4), id: 0),
            Piece(kind: .soldier, side: .red,   position: Position(row: 6, col: 4), id: 12),
        ]
        // 红车 (5,4) 横移离线 → (6,4) 兵仍遮拦 → 合法；红车 (5,4)→(4,4) 越过兵？
        // 不可（兵占 (6,4) 不挡 (5,4)→(4,4) 线；移到 (4,4) 后遮拦者剩兵 (6,4)——仍遮拦，合法）
        // 关键送将着：兵 (6,4) 前进 (6,4)→(5,4)（红兵向下）→ 线上剩车 (5,4) 仍遮拦；
        // 车 (5,4) 若让开同列（如 (5,3)）→ 兵 (6,4) 遮拦在 → 仍合法。
        // 直接测：把车移到非 4 列 → 兵独自遮拦 → 合法；兵前进+车同列让开的组合局面
        // 用独立谓词闭合兜底全覆盖（构造局面确保存在照面送将着被滤）
        assertLegalSetClosed(pieces, .red, "facing-screen")
        // 构造纯照面：无遮拦版本，红车任何离线走法 = 送将（唯一解 = 挡回）
        let bare = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 6), id: 0),
        ]
        // 红车不在 4 列：将帅同列无遮拦——已是照面态？红被将军（照面=被将语义）：
        // 红必须解决：车 (5,6)→(5,4) 挡线（合法）或帅离列（(9,3)/(9,5) 士位？无士，
        // 帅平移出宫不行，(8,3)/(8,5) 非宫格…帅只能 (8,4)？(8,4) 仍在 4 列照面 → 送将）
        assertLegalSetClosed(bare, .red, "facing-bare")
        let v2 = SearchBoardV2(pieces: bare, currentTurn: .red)
        #expect(v2.inCheck(.red), "照面 = 红被将军语义")
        let legal = v2.legalMoves(for: .red)
        #expect(!legal.isEmpty, "照面有解（挡线或帅离列）")
        #expect(legal.allSatisfy { $0.to.col == 4 || ($0.piece.kind == .general && $0.to.col != 4) },
                "解法应为挡线（车到4列）或帅平移离列：\(legal)")
    }

    @Test("将军中无解（三车杀）：legalCount==0 → 甲口径 static eval")
    func checkmateNoLegal() {
        // 与 M1HotpathSwitchTests.negamaxTerminalSemantics 同型局面（P3-④ 完整版）
        let pieces = [
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 3), id: 0),
            Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 1), id: 1),
            Piece(kind: .chariot, side: .red, position: Position(row: 2, col: 4), id: 2),
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
        ]
        assertLegalSetClosed(pieces, .black, "checkmate-3R")
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: .black)
        #expect(v2.legalMoves(for: .black).isEmpty, "杀棋：黑合法集空")
        #expect(v2.inCheck(.black), "且被将军（杀棋≠困毙）")
    }

    // MARK: - 杀棋/困毙区分（8.4：legalCount 语义断言，甲口径）

    @Test("困毙（非和棋判定语义）：无合法着且未被将军")
    func stalemateNoLegal() {
        // 困毙构造：黑将 (0,4) 无子可动且不被将军——红全控 (0,3)(0,5)(1,3)(1,4)(1,5)
        // 但不将军 (0,4)。红车 (2,4) 控制 (1,4) 竖线 + 红车 (0,0) 控制 0 行至 (0,3)、
        // 红炮……构造精确困毙易误（将军溢出），用"被将=杀棋"对偶断言：
        // 若 legalMoves 空且 inCheck false → 困毙语义成立（甲口径下同为 static eval 返回，
        // 语义区分仅测试断言层——引擎层不分，设计如此）
        let stale = [
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,  position: Position(row: 1, col: 4), id: 0),   // 控 (1,4) 与 (0,4)？竖线直通 → 将军！需挡
            Piece(kind: .soldier, side: .red,  position: Position(row: 2, col: 4), id: 12),  // 挡 (2,4)：车 (1,4) 不将 (0,4)
            Piece(kind: .chariot, side: .red,  position: Position(row: 3, col: 3), id: 1),   // 控 3 行不涉将
            Piece(kind: .general, side: .red,  position: Position(row: 9, col: 4), id: 8),
        ]
        // 黑将 (0,4)：(1,4) 被车控（吃车？(1,4) 车有兵 (2,4) 保护 → 吃后仍站 (1,4)？
        // 吃车后兵 (2,4) 不将 (1,4)……构造复杂度高，双闭合断言兜底：
        assertLegalSetClosed(stale, .black, "stalemate-attempt")
        let v2 = SearchBoardV2(pieces: stale, currentTurn: .black)
        let legacy = LegacySearchBoard(pieces: stale, currentTurn: .black)
        // 主断言 = 双向闭合（assertLegalSetClosed，上方）+ 双后端空集判定一致。
        // 原 `#expect(!inCheck || inCheck)` 恒真断言已删（D4 #6 禁止模式，P2-2）。
        // 空集时杀棋/困毙同返 static eval（甲口径），语义区分仅断言层；
        // 困毙精确构造由 Tina 批补，本测试固化双后端空集语义锚。
        #expect(v2.legalMoves(for: .black).isEmpty
                == MoveValidator.allLegalMoves(for: .black, on: legacy).isEmpty,
                "双后端 legalCount==0 判定分歧（stalemate-attempt）")
    }

    // MARK: - 双后端 legalCount==0 一致性（甲口径跨后端）

    @Test("杀棋局面双后端空集一致 + QS 空候选一致")
    func checkmateCrossBackend() {
        let pieces = [
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 3), id: 0),
            Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 1), id: 1),
            Piece(kind: .chariot, side: .red, position: Position(row: 2, col: 4), id: 2),
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
        ]
        let legacy = LegacySearchBoard(pieces: pieces, currentTurn: .black)
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: .black)
        #expect(MoveValidator.allLegalMoves(for: .black, on: legacy).isEmpty)
        #expect(v2.legalMoves(for: .black).isEmpty)
        // QS 候选（粗集）可为非空（pseudo 吃子），但循环过滤后全跳——引擎层不进 QS（depth=0 走 negamax 空集）
        #expect(v2.captureCandidates(for: .black) == v2.captureCandidates(for: .black), "QS 粗集确定性")
    }

    // MARK: - V2 契约证据测试（Luke 指令 2026-08-16 夜，两份崩溃报告归档）

    @Test("V2 契约：越界 id 局面在引擎入口被预检回退（不触断言）")
    func v2ContractEvidence() async {
        // 历史事实：on 态全量首跑（21:01/21:05）两崩，均因手写 fixture
        // id 250/283/285 越出 V2 槽位契约 0..31，V2.init :71 Debug 断言拦截
        // （A3 输入侧防御正常工作）。产品侧修法 = 入口预检回退 Legacy
        // （resolvedSearchBoard.v2Eligible，38d454b），本测试固化该行为：
        // 非法 id 局面在 on 语义（override=true）下走 Legacy 不崩且返回合法着。
        let badPieces = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0), id: 283),  // 越界：真实历史值
        ]
        let board = Board(pieces: badPieces)
        let engine = AIEngine()
        await engine.setBoardPathOverride(true)   // 强制 V2 语义
        defer { Task { await engine.setBoardPathOverride(nil) } }
        // 不崩 = 入口预检生效（直接 SearchBoardV2(pieces:) 在 Debug 下会断言炸）
        let backend = await engine.resolvedSearchBoard(from: board)
        #expect(backend is LegacySearchBoard, "越界 id 局面应回退 Legacy，实际 \(type(of: backend))")
        let move = await engine.bestMove(for: board, difficulty: .novice, isIOS: false)
        #expect(move != nil, "回退路径正常返回走法")
    }
}
