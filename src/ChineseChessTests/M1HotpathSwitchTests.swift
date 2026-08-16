// M1HotpathSwitchTests.swift — P2c 后端协议等价性 + 开关切换测试
// （m1-hotpath-redesign v1.2 §7.1 P2c · D4 拆分方案①②）
//
// 层次分工（不与既有安全网重复）：
//  - SearchBoardV2Tests：V2 本体单元断言（A/B/C 谓词级）
//  - MovegenCrosscheckTests：五源 ≥5000 局面规模化（31,483 局面全绿，54752ed）
//  - 本文件：SearchBoardProtocol 协议面等价（legalMoves/captureCandidates/isLegal/
//    asLegacyForCheckmate 桥）+ 开关行为（commit ②：boardPathOverride 强制 V2 走全链）
//
// ⚠️ SeededRandom 全局通道：suite .serialized + 用后清理（沿用 V2Tests 纪律）。

import Testing
import Foundation
@testable import ChineseChess

@Suite("P2c 后端协议等价 + 开关切换", .serialized)
struct M1HotpathSwitchTests {

    // MARK: - 局面源（单元级子集，规模化归 crosscheck）

    private func samples() -> [(tag: String, pieces: [Piece], turn: Side)] {
        var out: [(String, [Piece], Side)] = []
        out.append(("opening", Board.initialPieces(), .red))
        // 随机游走两档（d 源子集）
        out.append(("walk12", walkPieces(steps: 12, seed: 601), walkTurn(steps: 12, seed: 601)))
        out.append(("walk36", walkPieces(steps: 36, seed: 602), walkTurn(steps: 36, seed: 602)))
        // 照面 / 将军中（e 源子集）
        out.append(("facing", [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 4), id: 0),
        ], .red))
        out.append(("inCheck", [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 2, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 3, col: 4), id: 0),
            Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
        ], .black))
        return out
    }

    /// 随机游走后的 pieces（SeededRandom 独占期内完成）
    private func walkPieces(steps: Int, seed: UInt64) -> [Piece] {
        walk(steps: steps, seed: seed).0
    }
    private func walkTurn(steps: Int, seed: UInt64) -> Side {
        walk(steps: steps, seed: seed).1
    }
    private func walk(steps: Int, seed: UInt64) -> ([Piece], Side) {
        SeededRandom.configure(seed: seed)
        var board = LegacySearchBoard()
        for _ in 0..<steps {
            let moves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
            guard !moves.isEmpty else { break }
            board.execute(moves[SeededRandom.int(in: 0..<moves.count)])
        }
        SeededRandom.configure(seed: nil)
        return (board.pieces, board.currentTurn)
    }

    /// 集合比对键（与 crosscheck 同款安全键：字符串分段无撞键）
    private func key(_ m: Move) -> String {
        "\(m.piece.id):\(m.captured?.id ?? -1):\(m.from.row * 9 + m.from.col):\(m.to.row * 9 + m.to.col)"
    }

    // MARK: - ① 协议面等价（commit ① 交付）

    @Test("协议 legalMoves：V2 == Legacy.allLegalMoves（断言 A 同谓词）")
    func protocolLegalMoves() {
        for s in samples() {
            let legacy = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
            let v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
            let expected = Set(MoveValidator.allLegalMoves(for: s.turn, on: legacy).map(key))
            let got = Set(v2.legalMoves(for: s.turn).map(key))
            #expect(expected == got, "[\(s.tag)] legalMoves 分歧：仅Legacy=\(expected.subtracting(got).sorted()) 仅V2=\(got.subtracting(expected).sorted())")
        }
    }

    @Test("协议 captureCandidates：V2 ⊆ Legacy 且差集全归因吃己方（A' 裁定口径）")
    func protocolCaptureCandidates() {
        for s in samples() {
            let legacy = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
            let v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
            let legacyKeys = Set(MoveValidator.captureMoves(for: s.turn, on: legacy).map(key))
            let v2Caps = v2.captureCandidates(for: s.turn)
            let v2Keys = Set(v2Caps.map(key))
            // ① V2 不多产
            let onlyV2 = v2Caps.filter { !legacyKeys.contains(key($0)) }
            #expect(onlyV2.isEmpty, "[\(s.tag)] V2 多产吃子候选：\(onlyV2.map(key))")
            // ② 仅 Legacy 差集逐条归因 captured.side == 行棋方
            let legacyCaps = MoveValidator.captureMoves(for: s.turn, on: legacy)
            let unattributable = legacyCaps.filter { !v2Keys.contains(key($0)) && $0.captured?.side != s.turn }
            #expect(unattributable.isEmpty, "[\(s.tag)] 非 吃己方 归因的真分歧：\(unattributable.map(key))")
        }
    }

    @Test("协议 isLegal：合法集内全 true + 构造非法全 false")
    func protocolIsLegal() {
        for s in samples() {
            let legacy = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
            let v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
            let legal = MoveValidator.allLegalMoves(for: s.turn, on: legacy)
            for m in legal {
                #expect(v2.isLegal(m), "[\(s.tag)] 合法走法被 V2 判非法：\(key(m))")
            }
            // 构造非法：己方棋子平移到己方占位格（吃己方）+ 随机远程跳（非伪合法形态）
            if let own = s.pieces.first(where: { $0.side == s.turn && $0.kind != .general }),
               let ownTarget = s.pieces.first(where: { $0.side == s.turn && $0.id != own.id }) {
                let selfCapture = Move(piece: own, from: own.position, to: ownTarget.position,
                                       captured: ownTarget)
                #expect(!v2.isLegal(selfCapture), "[\(s.tag)] 吃己方走法应判非法")
            }
            if let mover = s.pieces.first(where: { $0.side == s.turn }) {
                let jump = Position(row: max(0, mover.position.row - 3), col: max(0, mover.position.col - 3))
                if jump != mover.position {
                    let bogus = Move(piece: mover, from: mover.position, to: jump,
                                     captured: s.pieces.first { $0.position == jump })
                    #expect(!v2.isLegal(bogus), "[\(s.tag)] 构造跳格走法应判非法")
                }
            }
        }
    }

    @Test("CheckmateSearch 桥：V2.asLegacyForCheckmate 复算面全等（D3 P1 断言5 守护对象）")
    func bridgeEquivalence() {
        for s in samples() {
            let v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
            let bridge = v2.asLegacyForCheckmate()
            // 桥读面：pieces/turn 逐项全等
            #expect(bridge.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted()
                    == s.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted(),
                    "[\(s.tag)] 桥 pieces 重建偏差")
            #expect(bridge.currentTurn == s.turn)
            // 桥行为面：合法集 == V2.legalMoves（asLegacyForCheckmate 消费路径的正交校验）
            let viaBridge = Set(MoveValidator.allLegalMoves(for: s.turn, on: bridge).map(key))
            let viaV2 = Set(v2.legalMoves(for: s.turn).map(key))
            #expect(viaBridge == viaV2, "[\(s.tag)] 桥走法集不等")
            // inCheck 双侧（照面边角由 facing 样本覆盖）
            for side in [Side.red, .black] {
                #expect(MoveValidator.isInCheck(side, on: bridge) == v2.inCheck(side),
                        "[\(s.tag)] 桥 inCheck 分歧 side=\(side)")
            }
        }
    }

    @Test("协议 make/unmake 泛型链：双后端各 10 步链回放 == 快照（D 谓词协议面版）")
    func protocolRoundTrip() {
        for s in samples() {
            // Legacy 后端
            var legacy = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
            roundTripGeneric(&legacy)
            // V2 后端
            var v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
            roundTripGeneric(&v2)
        }
    }

    /// 泛型辅助：走协议面 make 链（合法集内随机选步），回放后与快照全等
    private func roundTripGeneric<B: SearchBoardProtocol>(_ board: inout B) {
        let snapIds = board.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted()
        let snapTurn = board.currentTurn
        let snapHist = board.moveHistory.count
        var undos: [B.Undo] = []
        SeededRandom.configure(seed: 701)
        defer { SeededRandom.configure(seed: nil) }
        for _ in 0..<10 {
            let legal = board.legalMoves(for: board.currentTurn)
            guard !legal.isEmpty else { break }
            undos.append(board.make(legal[SeededRandom.int(in: 0..<legal.count)]))
        }
        while let u = undos.popLast() { board.unmake(u) }
        #expect(board.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted() == snapIds)
        #expect(board.currentTurn == snapTurn)
        #expect(board.moveHistory.count == snapHist)
    }

    // MARK: - ② 开关行为（commit ② 交付：默认 Legacy + 注入 V2 全链走通）

    @Test("后端开关：编译条件默认 off；boardPathOverride 强制 V2 走全链")
    func backendSwitchBehavior() async {
        let board = Board()
        let engine = AIEngine()

        // 默认态：跟随编译条件（主开发周期 USE_SEARCHBOARD_V2 未定义 → Legacy）
        let defaultBackend = await engine.resolvedSearchBoard(from: board)
        #expect(AIEngine.useSearchBoardV2 == (defaultBackend is SearchBoardV2),
                "默认后端与编译条件不一致：useSearchBoardV2=\(AIEngine.useSearchBoardV2) 实际=\(type(of: defaultBackend))")

        // 注入 V2：novice 全链（legalMoves→make/evaluate→unmake）走通且返回合法走法
        await engine.setBoardPathOverride(true)
        let v2Backend = await engine.resolvedSearchBoard(from: board)
        #expect(v2Backend is SearchBoardV2, "注入后应构造 V2 后端，实际 \(type(of: v2Backend))")
        let move = await engine.bestMove(for: board, difficulty: .novice, isIOS: false)
        #expect(move != nil, "V2 后端 novice 全链应返回走法")
        if let m = move {
            #expect(v2Backend.isLegal(m), "V2 返回的走法应在 V2 谓词下合法：\(m)")
        }
        await engine.setBoardPathOverride(nil)

        // 置 nil 后回落编译条件默认（flag-off 态 = Legacy；flag-on 态 = V2——
        // 本断言双态自洽，不硬编码默认方向）
        let restoredBackend = await engine.resolvedSearchBoard(from: board)
        #expect((restoredBackend is SearchBoardV2) == AIEngine.useSearchBoardV2,
                "置 nil 后应回落编译条件默认，实际 \(type(of: restoredBackend))")
        let restoredMove = await engine.bestMove(for: board, difficulty: .novice, isIOS: false)
        #expect(restoredMove != nil)
    }

    @Test("P3-0 深链冒烟：override+lvl4 全链（IDS+QS+排序+杀法桥真实触发）")
    func backendSwitchLvl4DeepChain() async {
        // Ruby P2 整体审 P2-1 / P5 硬项①：on 态 lvl4 深链覆盖。
        // 走若于开局库命中则不经 IDS——用非开局局面（随机游走 8 步，seed 固定）
        // 遍历 CheckmateSearch 桥（asLegacyForCheckmate 真实触发路径）与 negamax/QS/order。
        // 随机游走 8 步（偶数 → 轮红，与 Board(pieces:) 默认 currentTurn 一致，免 private(set) 限制）
        let pieces = walkPieces(steps: 8, seed: 711)
        let turn = walkTurn(steps: 8, seed: 711)
        #expect(turn == .red, "前提：8 步后轮红（偶数步）")
        let board = Board(pieces: pieces)
        let engine = AIEngine()

        await engine.setBoardPathOverride(true)   // 强制 V2
        defer { Task { await engine.setBoardPathOverride(nil) } }
        let move = await engine.bestMove(for: board, difficulty: .amateurMid, isIOS: false)  // lvl4
        #expect(move != nil, "V2 态 lvl4 深链应返回走法")
        if let m = move {
            // 返回走法须在该局面合法（V2 谓词）——非法走法=0 前线哨兵的单元级版
            let v2 = SearchBoardV2(pieces: pieces, currentTurn: turn)
            #expect(v2.isLegal(m), "V2 lvl4 返回非法走法：\(m)")
        }
    }

    // MARK: - P3-① MoveOrderer V2 双快路径（phase3.md 裁定 A）

    @Test("P3-①：V2 态给将走法排首（checkLegal 恢复兑现）")
    func orderV2GivesCheckFirst() {
        // 红车 (5,4) 上行吃黑车 (2,4) 后与黑将 (0,4) 同列且 (1,4) 空 → 将军；
        // 黑车 (2,4) 同时挡住红车直进吃将路径（无吃将边角）。其余走法均不将军。
        let pieces = [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 4), id: 0),
            Piece(kind: .chariot, side: .black, position: Position(row: 2, col: 4), id: 16),
            Piece(kind: .soldier, side: .red,   position: Position(row: 6, col: 3), id: 12),
        ]
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: .red)
        let legal = v2.legalMoves(for: .red)
        #expect(!legal.isEmpty)
        let orderer = MoveOrderer()
        let ordered = orderer.order(legal, on: v2, checkLegal: true, depth: 3)
        guard let first = ordered.first else {
            IssueRecord("空排序结果")
            return
        }
        // 唯一将军着：红车 (5,4)→(2,4) 吃黑车（将军 +50000，且是吃子加分叠加）
        let isCheckMove = first.from.row == 5 && first.from.col == 4
            && first.to.row == 2 && first.to.col == 4 && first.captured != nil
        #expect(isCheckMove, "给将走法未排首：\(first)")
    }

    @Test("P3-①：order 双后端输出全等（threatBonusV2 等价锚，§4 #6）")
    func orderV2EquivalenceAnchor() {
        // 同局面同参数（checkLegal=false 隔离 givesCheck 路径，纯 threatBonus/公式链比对）。
        // 双后端生成序可能不同（集合等价、序不比对），统一排序输入后再 order，
        // 等分段的稳定排序输出才可逐位比对——threatBonusV2 排序行为等价锚。
        for s in samples() {
            let legacy = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
            let v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
            let canonical: ([Move]) -> [Move] = { $0.sorted { key($0) < key($1) } }
            let legacyMoves = canonical(legacy.legalMoves(for: s.turn))
            let v2Moves = canonical(v2.legalMoves(for: s.turn))
            let orderer = MoveOrderer()
            let viaLegacy = orderer.order(legacyMoves, on: legacy, checkLegal: false, depth: 3)
            let viaV2 = orderer.order(v2Moves, on: v2, checkLegal: false, depth: 3)
            let kl = viaLegacy.map(key)
            let kv = viaV2.map(key)
            #expect(kl == kv, "[\(s.tag)] 排序输出分歧：Legacy=\(kl) V2=\(kv)")
        }
    }

    /// 测试内轻量断言封装（Issue.record 语义）
    private func IssueRecord(_ msg: String) {
        Issue.record(Comment(rawValue: msg))
    }
}
