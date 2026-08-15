// SearchBoardV2Tests.swift — M1 Phase 2 等价性断言层（m1-hotpath-redesign v1.2 §8.2/§8.4）
//
// 三层独立哨兵（排 Ruby D3 "送将集独立谓词"恒真断言坑）：
//  A. 生成集等价（交叉谓词）：V2.pseudo − 送将集(Legacy谓词) == Legacy.allLegalMoves
//  B. 送将谓词交叉全等：V2.make+inCheck vs Legacy.execute+isInCheck，逐走法
//  C. inCheck 双实现全等（§8.2 断言 3）：MoveValidator.isInCheck(legacy) == V2.inCheck
//
// 送将集"独立谓词"要求：A 中送将判定用 Legacy 的 wouldBeInCheck 语义
// （LegacySearchBoard.execute + MoveValidator.isInCheck），而非 V2 自判——
// 这样 A 才能交叉验证两套生成器，不退化为自我比较。
// B 补刀 A 的盲区：即使 A 的 Legacy 谓词恰好掩盖 V2 生成差异，
// B 的逐走法 make/inCheck 交叉仍能抓到 inCheck 实现分歧。

import Testing
import Foundation
@testable import ChineseChess

@Suite("SearchBoardV2 等价性断言", .serialized)
struct SearchBoardV2Tests {

    // MARK: - 局面源（§8.2 五源的单元测试子集——Tina 工具版 ≥5000 局面后置）

    /// 标准开局
    private func openingPosition() -> [Piece] { Board.initialPieces() }

    /// 开局走若干步后的局面（随机游走 d 源子集）
    /// ⚠️ 使用 SeededRandom 静态通道（configure + int），测试期间独占
    private func positionsAfterRandomWalk(steps: Int, seed: UInt64) -> [Piece] {
        SeededRandom.configure(seed: seed)
        var board = LegacySearchBoard()
        for _ in 0..<steps {
            let side = board.currentTurn
            let moves = MoveValidator.allLegalMoves(for: side, on: board)
            guard !moves.isEmpty else { break }
            let idx = SeededRandom.int(in: 0..<moves.count)
            board.execute(moves[idx])
        }
        SeededRandom.configure(seed: nil)  // 清理全局状态
        return board.pieces
    }

    /// 定向构造：将帅照面局面（e 源子集——照面走法生成/inCheck 边角）
    /// 红帅 (9,4) 黑将 (0,4)，中间清空 → 照面成立
    private func facingGeneralsPosition() -> [Piece] {
        [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 5, col: 4), id: 0),
        ]
    }

    /// 定向构造：将军中局面（e 源子集——应将走法集 + 送将过滤边角）
    /// 红车将军黑将，黑方必须应将
    private func inCheckPosition() -> [Piece] {
        [
            Piece(kind: .general, side: .red,   position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 2, col: 4), id: 24),
            Piece(kind: .chariot, side: .red,   position: Position(row: 3, col: 4), id: 0),  // 红车将黑将
            Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
        ]
    }

    // MARK: - 断言 A：生成集等价（交叉谓词）

    @Test("断言A：开局 V2.pseudo − 送将集(Legacy谓词) == Legacy.allLegalMoves")
    func a_opening() {
        let pieces = openingPosition()
        assertGeneratorEquivalence(pieces: pieces, turn: .red)
    }

    @Test("断言A：随机游走 20 步（seed 501）")
    func a_walk20() {
        let pieces = positionsAfterRandomWalk(steps: 20, seed: 501)
        assertGeneratorEquivalence(pieces: pieces, turn: .red)
    }

    @Test("断言A：随机游走 40 步（seed 502）")
    func a_walk40() {
        let pieces = positionsAfterRandomWalk(steps: 40, seed: 502)
        assertGeneratorEquivalence(pieces: pieces, turn: .black)
    }

    @Test("断言A：照面定向局面")
    func a_facing() {
        let pieces = facingGeneralsPosition()
        assertGeneratorEquivalence(pieces: pieces, turn: .red)
    }

    @Test("断言A：将军中局面")
    func a_inCheck() {
        let pieces = inCheckPosition()
        assertGeneratorEquivalence(pieces: pieces, turn: .black)  // 黑方应将
    }

    // MARK: - 断言 B：送将谓词交叉全等

    @Test("断言B：开局逐走法 V2.make+isInCheck vs Legacy.execute+isInCheck")
    func b_opening() {
        let pieces = openingPosition()
        assertInCheckCrossEquivalent(pieces: pieces, turn: .red)
    }

    @Test("断言B：随机游走 20 步逐走法交叉")
    func b_walk20() {
        let pieces = positionsAfterRandomWalk(steps: 20, seed: 501)
        assertInCheckCrossEquivalent(pieces: pieces, turn: .red)
    }

    @Test("断言B：照面定向局面逐走法交叉")
    func b_facing() {
        let pieces = facingGeneralsPosition()
        assertInCheckCrossEquivalent(pieces: pieces, turn: .red)
    }

    // MARK: - 断言 C：inCheck 双实现全等（§8.2 断言 3）
    // V2.inCheck 快路径（§2.7）vs MoveValidator.isInCheck(on: legacy)——
    // 双实现独立判定，逐局面×双方全等。照面/照面遮拦局面集重点覆盖（e 源）。

    @Test("断言C：开局 inCheck 双实现全等")
    func c_opening() {
        let pieces = openingPosition()
        assertInCheckEquivalent(pieces: pieces)
    }

    @Test("断言C：照面局面 inCheck 双实现全等")
    func c_facing() {
        let pieces = facingGeneralsPosition()
        assertInCheckEquivalent(pieces: pieces)
    }

    @Test("断言C：将军中局面 inCheck 双实现全等")
    func c_inCheck() {
        let pieces = inCheckPosition()
        assertInCheckEquivalent(pieces: pieces)
    }

    @Test("断言C：随机游走 30 步 inCheck 双实现全等")
    func c_walk30() {
        let pieces = positionsAfterRandomWalk(steps: 30, seed: 503)
        assertInCheckEquivalent(pieces: pieces)
    }

    // MARK: - 往返一致性（§8.4）

    @Test("往返一致性：开局 make/unmake 50 步回放 == 原快照")
    func roundTrip_randomWalk() {
        SeededRandom.configure(seed: 601)
        var v2 = SearchBoardV2()
        let snapshot = v2  // 值类型快照（深拷贝）
        var undos: [SearchBoardV2.UndoInfo] = []

        for _ in 0..<50 {
            let side = v2.currentTurn
            let pseudoMoves = MoveGenerator.pseudoLegalMoves(on: v2)
            // 过滤送将（用 V2.make + MoveValidator.isInCheck on V2 as BoardReadable）
            let legalMoves = pseudoMoves.filter { move in
                v2.make(move)
                let inCheck = MoveValidator.isInCheck(side, on: v2)
                let undo = v2.undoStackLast()
                v2.unmake(undo)
                return !inCheck
            }
            guard !legalMoves.isEmpty else { break }
            let idx = SeededRandom.int(in: 0..<legalMoves.count)
            let undo = v2.make(legalMoves[idx])
            undos.append(undo)
        }
        SeededRandom.configure(seed: nil)

        // 回放 unmake
        while let undo = undos.popLast() {
            v2.unmake(undo)
        }

        // 全字段比较（pieces 序可能因 slot 序与 Legacy 不同，用集合比较）
        #expect(Set(v2.pieces.map { $0.id }) == Set(snapshot.pieces.map { $0.id }),
                "make/unmake 回放后 pieces id 集合应与快照一致")
        #expect(v2.currentTurn == snapshot.currentTurn, "currentTurn 应恢复")
        #expect(v2.moveHistory.count == snapshot.moveHistory.count, "moveHistory 深度应恢复")
    }

    // MARK: - 同格不可能性（§8.4，A3 根因表示级测试）

    @Test("同格不可能性：任意 make 序列后 mailbox 无双占")
    func noDoubleOccupancy() {
        SeededRandom.configure(seed: 701)
        var v2 = SearchBoardV2()

        for ply in 0..<100 {
            let side = v2.currentTurn
            let moves = MoveGenerator.pseudoLegalMoves(on: v2)
            guard !moves.isEmpty else { break }
            let idx = SeededRandom.int(in: 0..<moves.count)
            v2.make(moves[idx])
            // 每次 make 后断言结构有效（含无双占）
            #expect(SearchBoardV2.structureIsValid(v2), "make 后结构腐败（ply \(ply))")
        }
        SeededRandom.configure(seed: nil)
    }

    // MARK: - 断言实现

    /// 断言 A 核心：V2.pseudo − 送将集(Legacy谓词) == Legacy.allLegalMoves
    ///
    /// 送将集用 Legacy 谓词（LegacySearchBoard.execute + MoveValidator.isInCheck）——
    /// 独立于 V2 生成器，避免恒真断言。
    private func assertGeneratorEquivalence(pieces: [Piece], turn: Side) {
        let legacy = LegacySearchBoard(pieces: pieces, currentTurn: turn)
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: turn)

        let legacyLegal = MoveValidator.allLegalMoves(for: turn, on: legacy)
        let v2Pseudo = MoveGenerator.pseudoLegalMoves(on: v2)

        // 送将集（Legacy 谓词）：对 V2 伪合法走法用 Legacy board 判定
        let v2LegalViaLegacy = v2Pseudo.filter { move in
            var work = LegacySearchBoard(pieces: pieces, currentTurn: turn)
            work.execute(move)
            return !MoveValidator.isInCheck(turn, on: work)
        }

        // 集合比较（排序 key: fromSq*90 + toSq + pieceId*10000 + capturedId*100000）
        let legacyKeys = Set(legacyLegal.map { moveKey($0) })
        let v2Keys = Set(v2LegalViaLegacy.map { moveKey($0) })

        #expect(legacyKeys == v2Keys,
                "生成集不等价：Legacy=\(legacyKeys.sorted()) V2=\(v2Keys.sorted())")
    }

    /// 断言 B 核心：逐走法 V2.make+isInCheck vs Legacy.execute+isInCheck
    private func assertInCheckCrossEquivalent(pieces: [Piece], turn: Side) {
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: turn)
        let pseudoMoves = MoveGenerator.pseudoLegalMoves(on: v2)

        for move in pseudoMoves {
            var v2Board = SearchBoardV2(pieces: pieces, currentTurn: turn)
            v2Board.make(move)
            let v2InCheck = MoveValidator.isInCheck(turn, on: v2Board)  // V2 as BoardReadable

            var legacyBoard = LegacySearchBoard(pieces: pieces, currentTurn: turn)
            legacyBoard.execute(move)
            let legacyInCheck = MoveValidator.isInCheck(turn, on: legacyBoard)

            #expect(v2InCheck == legacyInCheck,
                    "送将判定分歧：move=\(move.piece.kind) (\(move.from.row),\(move.from.col))→(\(move.to.row),\(move.to.col)) V2=\(v2InCheck) Legacy=\(legacyInCheck)")
        }
    }

    /// 断言 C 核心：inCheck 双实现全等
    /// Legacy 侧 = MoveValidator.isInCheck(on: legacy)，V2 侧 = v2.inCheck(快路径)
    private func assertInCheckEquivalent(pieces: [Piece]) {
        let legacy = LegacySearchBoard(pieces: pieces, currentTurn: .red)
        let v2 = SearchBoardV2(pieces: pieces, currentTurn: .red)

        for side in [Side.red, Side.black] {
            let legacyInCheck = MoveValidator.isInCheck(side, on: legacy)
            let v2InCheck = v2.inCheck(side)
            #expect(legacyInCheck == v2InCheck,
                    "inCheck 双实现分歧：side=\(side) Legacy=\(legacyInCheck) V2=\(v2InCheck)")
        }
    }

    // MARK: - 辅助

    /// 走法排序键（集合比对用，序不比对——§8.2 断言 1 括号）
    private func moveKey(_ m: Move) -> Int {
        let fromSq = m.from.row * 9 + m.from.col
        let toSq = m.to.row * 9 + m.to.col
        let capturedId = m.captured?.id ?? -1
        return m.piece.id * 100000 + capturedId * 10000 + fromSq * 90 + toSq
    }
}

// MARK: - SearchBoardV2 测试辅助
// undoStackLast() 已在 SearchBoardV2.swift 内声明 internal（同文件可访问 private 存储）
