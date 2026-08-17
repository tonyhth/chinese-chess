// M1P4CheapEvalTests.swift — P4-① 增量全等专项（phase4.md §1.1 熔断线守护）
//
// 守护对象：SearchBoardV2 增量字段族（materialSum / pstSum / pieceCount）
// 与"从零重算参考值"的逐步全等。参考值同源直调（非复刻）：
//   material 参考 = AIEvaluator.dynamicValue（实调，非 V2.incrementalValue 复刻）
//   pst 参考     = PositionTables.positionWeight（实调）
// → V2 内任何复刻漂移 / 增量维护 bug / 相位跨界(16 线)重算失效 /
//   unmake 快照回滚漂移，都会在此被抓（熔断线 = P4-① 冻结）。
//
// 方法论（A3 精神，同 SearchBoardV2Tests 交叉谓词思路）：
// 被测值走 V2 的增量维护路径（make 序列），参考值每步从 board.pieces
// 从零重算——两条独立计算链，全等才有背书力。

import Testing
import Foundation
@testable import ChineseChess

@Suite("M1P4 cheapEval 增量全等", .serialized)
struct M1P4CheapEvalTests {

    private let evaluator = AIEvaluator()

    // MARK: - 参考值（同源直调，零复刻）

    /// material + pst 双方和的参考值（从 pieces 从零重算）
    private func referenceSums<P: SearchBoardProtocol>(_ board: P) -> (red: Int, black: Int, count: Int) {
        let pieces = board.pieces
        let total = pieces.count
        var red = 0, black = 0
        for piece in pieces {
            let v = evaluator.dynamicValue(for: piece, totalPieces: total)
                + PositionTables.positionWeight(for: piece, totalPieces: total)
            if piece.side == .red { red += v } else { black += v }
        }
        return (red, black, total)
    }

    private func assertIncrementalEqual<P: SearchBoardProtocol>(_ board: P, _ label: String,
                                                                sourceLocation: SourceLocation = #_sourceLocation) {
        let ref = referenceSums(board)
        let diff = board.cheapEval(for: .red)  // red - black
        let refDiff = ref.red - ref.black
        #expect(diff == refDiff, "\(label): cheapEval=\(diff) 参考=\(refDiff)（红和 \(ref.red) 黑和 \(ref.black) 子数 \(ref.count)）",
                sourceLocation: sourceLocation)
        #expect(board.pieceCount == ref.count, "\(label): pieceCount=\(board.pieceCount) 参考=\(ref.count)",
                sourceLocation: sourceLocation)
    }

    // MARK: - 1. init 全等（标准开局 + 中局残局构造源）

    @Test("init 全等：标准开局（32 子，双相位线之上）")
    func initOpening() {
        let board = SearchBoardV2(pieces: Board.initialPieces(), currentTurn: .red, moveHistory: [])
        assertIncrementalEqual(board, "开局")
    }

    @Test("init 全等：残局稀疏局面（≤16 子，Endgame 相位域）")
    func initSparseEndgame() {
        let pieces = [
            Piece(kind: .general,   side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .chariot,   side: .red,   position: Position(row: 5, col: 4), id: 0),
            Piece(kind: .soldier,   side: .red,   position: Position(row: 4, col: 2), id: 4),  // 过河兵（残局翻倍 ×2 链）
            Piece(kind: .general,   side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .advisor,   side: .black, position: Position(row: 0, col: 3), id: 20),
            Piece(kind: .elephant,  side: .black, position: Position(row: 2, col: 6), id: 18),
        ]
        let board = SearchBoardV2(pieces: pieces, currentTurn: .red, moveHistory: [])
        assertIncrementalEqual(board, "残局6子")
    }

    // MARK: - 2. 随机游走逐步全等（吃子偏好——覆盖 16 线相位跨界 + 6 子守卫线）

    @Test("随机游走逐步全等：吃子偏好 ×5 局 ×80 ply（跨 16 线相位与 ≤6 子域）")
    func randomWalkCaptureBias() {
        for seed in UInt64(601)...605 {
            SeededRandom.configure(seed: seed)
            var board = SearchBoardV2(pieces: Board.initialPieces(), currentTurn: .red, moveHistory: [])
            var ply = 0
            while ply < 80 {
                let side = board.currentTurn
                // 吃子偏好：有吃子走吃子（加速跨界），否则随机合法着
                let caps = board.captureCandidates(for: side)
                    .filter { board.isLegal($0) }
                let moves = board.legalMoves(for: side)
                guard !moves.isEmpty else { break }
                let move: Move
                if !caps.isEmpty {
                    move = caps[SeededRandom.int(in: 0..<caps.count)]
                } else {
                    move = moves[SeededRandom.int(in: 0..<moves.count)]
                }
                let preCount = board.pieceCount
                board.make(move)
                assertIncrementalEqual(board, "seed=\(seed) ply=\(ply) make后（pre=\(preCount) → post=\(board.pieceCount)）")
                ply += 1
            }
            #expect(ply > 0, "seed=\(seed) 游走零步即终局，测试失效")
            SeededRandom.configure(seed: nil)
        }
    }

    // MARK: - 3. 相位跨界定向（17↔16↔15，recomputeIncrementalSums 触发线）

    @Test("相位跨界定向：17→16→15 逐步全等（16 线 recompute 触发）")
    func phaseCrossing16Line() {
        // 17 子构造（soldier 过河相位敏感区 + 双车炮马，吃子机会充足）。
        // 定向着法用扫描发现（手指定着法易踩 isLegal 边角，两轮构造学费）
        var pieces: [Piece] = [
            Piece(kind: .general,  side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general,  side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .soldier,  side: .red,   position: Position(row: 5, col: 0), id: 0),
            Piece(kind: .soldier,  side: .red,   position: Position(row: 4, col: 2), id: 2),
            Piece(kind: .soldier,  side: .red,   position: Position(row: 5, col: 6), id: 3),
            Piece(kind: .soldier,  side: .red,   position: Position(row: 5, col: 8), id: 4),
            Piece(kind: .soldier,  side: .black, position: Position(row: 4, col: 1), id: 16),
            Piece(kind: .soldier,  side: .black, position: Position(row: 4, col: 3), id: 17),
            Piece(kind: .soldier,  side: .black, position: Position(row: 4, col: 5), id: 18),
            Piece(kind: .soldier,  side: .black, position: Position(row: 4, col: 7), id: 19),
            Piece(kind: .chariot,  side: .red,   position: Position(row: 6, col: 4), id: 9),
            Piece(kind: .chariot,  side: .black, position: Position(row: 2, col: 4), id: 25),
            Piece(kind: .cannon,   side: .red,   position: Position(row: 7, col: 0), id: 10),
            Piece(kind: .cannon,   side: .black, position: Position(row: 2, col: 8), id: 26),
            Piece(kind: .horse,    side: .red,   position: Position(row: 9, col: 1), id: 11),
            Piece(kind: .advisor,  side: .black, position: Position(row: 0, col: 5), id: 21),
            Piece(kind: .elephant, side: .red,   position: Position(row: 9, col: 2), id: 12),
        ]
        #expect(pieces.count == 17)
        var board = SearchBoardV2(pieces: pieces, currentTurn: .red, moveHistory: [])
        assertIncrementalEqual(board, "17子init")
        var undoStackAll: [SearchBoardV2.UndoInfo] = []
        var crossed17to16 = false, crossed16to15 = false

        // 扫描发现（最多游走 40 ply）：遇 17→16 合法吃子即锚定，续扫 16→15
        for _ in 0..<40 {
            let side = board.currentTurn
            let moves = board.legalMoves(for: side)
            guard !moves.isEmpty else { break }
            let pick: Move
            if !crossed17to16, board.pieceCount == 17,
               let cap = moves.first(where: { $0.captured != nil }) {
                pick = cap
            } else if crossed17to16 && !crossed16to15, board.pieceCount == 16,
               let cap = moves.first(where: { $0.captured != nil }) {
                pick = cap
            } else {
                pick = moves.first!
            }
            let pre = board.pieceCount
            undoStackAll.append(board.make(pick))
            assertIncrementalEqual(board, "扫描 ply pre=\(pre) post=\(board.pieceCount)")
            if pre == 17 && board.pieceCount == 16 { crossed17to16 = true }
            if pre == 16 && board.pieceCount == 15 { crossed16to15 = true }
            if crossed17to16 && crossed16to15 { break }
        }
        guard crossed17to16 else {
            Issue.record("40 ply 内未遇到 17→16 吃子，构造失效"); return
        }
        guard crossed16to15 else {
            Issue.record("未遇到 16→15 吃子，构造失效"); return
        }

        // 全栈逐层回滚：每层全等断言（跨界线快照恢复精确性直接受考）
        while let undo = undoStackAll.popLast() {
            board.unmake(undo)
            assertIncrementalEqual(board, "回滚剩栈深=\(undoStackAll.count) count=\(board.pieceCount)")
        }
        #expect(board.pieceCount == 17)
        assertIncrementalEqual(board, "全栈归零终态（跨 16 线回滚）")
        pieces.removeAll()
    }

    // MARK: - 4. make/unmake 深栈快照回滚（乱序回滚漂移守护）

    @Test("make/unmake 深栈回滚：40 层栈逐层 unmake，每层双向全等")
    func deepUndoSnapshot() {
        SeededRandom.configure(seed: 701)
        var board = SearchBoardV2(pieces: Board.initialPieces(), currentTurn: .red, moveHistory: [])
        var undos: [SearchBoardV2.UndoInfo] = []
        for ply in 0..<40 {
            let side = board.currentTurn
            let moves = board.legalMoves(for: side)
            guard !moves.isEmpty else { break }
            undos.append(board.make(moves[SeededRandom.int(in: 0..<moves.count)]))
            assertIncrementalEqual(board, "深栈 push ply=\(ply)")
        }
        while let undo = undos.popLast() {
            board.unmake(undo)
            assertIncrementalEqual(board, "深栈 pop 剩余栈深=\(undos.count)")
        }
        // 终态回到开局：与 init 参考再对一次
        assertIncrementalEqual(board, "深栈归零终态")
        SeededRandom.configure(seed: nil)
    }

    // MARK: - 5. Legacy witness 契约（门控不变式）

    @Test("Legacy witness：supportsCheapEval=false / cheapEval=0 / pieceCount=pieces.count")
    func legacyWitnessContract() {
        let legacy = LegacySearchBoard(from: Board())
        #expect(legacy.supportsCheapEval == false)
        #expect(legacy.cheapEval(for: .red) == 0 && legacy.cheapEval(for: .black) == 0)
        #expect(legacy.pieceCount == legacy.pieces.count)
        #expect(legacy.pieceCount == 32)
    }

    // MARK: - 6. standPat ≤6 子守卫线参考（6↔7 子域全等不受守卫影响的增量正确性）

    @Test("≤6 子 Endgame 域全等（守卫线内增量仍须正确）")
    func sparseDomain() {
        // 构造 7 子局，游走吃子到 ≤6 子以下，增量全等全程守护
        let pieces = [
            Piece(kind: .general,  side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general,  side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot,  side: .red,   position: Position(row: 5, col: 3), id: 0),
            Piece(kind: .chariot,  side: .black, position: Position(row: 4, col: 5), id: 16),
            Piece(kind: .cannon,   side: .red,   position: Position(row: 7, col: 1), id: 9),
            Piece(kind: .horse,    side: .black, position: Position(row: 2, col: 7), id: 17),
            Piece(kind: .soldier,  side: .red,   position: Position(row: 3, col: 8), id: 4),
        ]
        var board = SearchBoardV2(pieces: pieces, currentTurn: .red, moveHistory: [])
        #expect(board.pieceCount == 7)
        assertIncrementalEqual(board, "7子init")

        SeededRandom.configure(seed: 801)
        var ply = 0
        while ply < 40 {
            let side = board.currentTurn
            let caps = board.captureCandidates(for: side).filter { board.isLegal($0) }
            let moves = board.legalMoves(for: side)
            guard !moves.isEmpty else { break }
            let move = !caps.isEmpty ? caps[SeededRandom.int(in: 0..<caps.count)]
                                     : moves[SeededRandom.int(in: 0..<moves.count)]
            board.make(move)
            assertIncrementalEqual(board, "≤6子域 ply=\(ply) count=\(board.pieceCount)")
            ply += 1
        }
        SeededRandom.configure(seed: nil)
    }
}
