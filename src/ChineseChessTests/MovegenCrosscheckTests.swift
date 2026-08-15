// MovegenCrosscheckTests.swift — P2c 走法生成交叉对比工具（m1-hotpath-redesign v1.2 §8.2）
//
// 五源局面 × 四断言，Legacy vs V2 全等——P2 合入门槛的证据生成器。
// 谓词语义与 SearchBoardV2Tests（单元级三层哨兵）一致，本工具是其规模化版：
//   断言 1（A）  生成集等价：Legacy.allLegalMoves == V2.pseudo − 送将集(Legacy谓词)
//   断言 2（A'） capturesOnly 等价：Legacy.captureMoves == V2.pseudo(capturesOnly) − 送将集
//   断言 3（C）  inCheck 双实现全等（逐局面 × 双方）
//   断言 4（D）  逐局面 make 链 → unmake 回放 == 快照（V2 自洽，谓词已由 A 交叉验证）
//
// 五源（§8.2）：
//   a) 开局带：标准开局 + 开局库加权随机路径 ≤20 半步（SeededRandom 固定 seed）
//   b) 实战采样：calibration-results/move-history/*.txt 逐局面（ICCS 走子）
//   c) 残局集：经典残局形态手写 + SeededRandom 构造 ≤6 子局面
//   d) 随机游走：Legacy 生成器随机走 k 步（k=10..80），seed 版本化（§8.2 d 源）
//   e) 定向构造：将军/应将/送将各型（车口/炮口/马口/照面/照面遮拦）
//
// 规模控制（Intel Mac 全量套件防超时铁律）：
//   MOVEGEN_CROSSCHECK_FULL=1 → 全量（≥5000 局面，Tina/合入门禁执行口径）
//   默认 → stride 5 采样（~1700 局面，全量套件内可承受）
//
// ⚠️ SeededRandom 全局通道独占：suite .serialized + 用后 configure(seed: nil) 清理。

import Testing
import Foundation
@testable import ChineseChess

@Suite("走法生成交叉对比（五源四断言）", .serialized)
struct MovegenCrosscheckTests {

    // MARK: - 样本模型

    struct Sample {
        let tag: String       // "b:game42:ply37" 形态，失败定位到源
        let pieces: [Piece]
        let turn: Side
    }

    private static let full = ProcessInfo.processInfo.environment["MOVEGEN_CROSSCHECK_FULL"] == "1"
    private static let stride = full ? 1 : 5

    // MARK: - 主测试

    @Test("五源交叉对比：生成集/capturesOnly/inCheck/往返 全等")
    func crosscheckFiveSources() {
        let samples = Self.full ? buildAllSamples() : buildAllSamples().strided(Self.stride)
        print("CROSSCHECK-SAMPLES: \(samples.count) (full=\(Self.full))")
        #expect(samples.count >= (Self.full ? 5000 : 500),
                "局面源产出不足：\(samples.count)（full=\(Self.full)）——检查 b 源棋谱目录可达性")

        var checked = 0
        for s in samples {
            assertPosition(s)
            checked += 1
        }
        // 分歧聚合上报（IssueRecorder 收集的阈值内一次性报出）
        let issues = IssueRecorder.drain()
        #expect(issues.isEmpty,
                "交叉对比分歧 \(issues.count) 处（首 20 条）：\n\(issues.joined(separator: "\n"))")
        #expect(checked == samples.count)
    }

    // MARK: - 五源生成

    private func buildAllSamples() -> [Sample] {
        SeededRandom.configure(seed: 88001)  // 全工具单一 seed 根（版本化：88001）
        defer { SeededRandom.configure(seed: nil) }

        var samples: [Sample] = []
        samples.append(contentsOf: sourceA_openingBook())
        samples.append(contentsOf: sourceB_gameRecords())
        samples.append(contentsOf: sourceC_endgames())
        samples.append(contentsOf: sourceD_randomWalks())
        samples.append(contentsOf: sourceE_directed())
        return samples
    }

    /// a) 开局带：开局库加权随机路径（≤20 半步）逐局面 + 标准开局
    private func sourceA_openingBook() -> [Sample] {
        var out: [Sample] = [Sample(tag: "a:initial", pieces: Board.initialPieces(), turn: .red)]
        for seedBase in 0..<10 {
            SeededRandom.configure(seed: 88100 + UInt64(seedBase))
            var board = LegacySearchBoard()
            for ply in 0..<20 {
                let hash = ZobristHash.hash(board: board)
                guard let iccs = OpeningBook.shared.lookupWeightedRandom(zobristHash: hash),
                      let move = ICCSParser.parse(iccs, on: board) else { break }
                board.execute(move)
                out.append(Sample(tag: "a:book\(seedBase):ply\(ply + 1)",
                                  pieces: board.pieces, turn: board.currentTurn))
            }
            SeededRandom.configure(seed: 88001)  // 恢复根，下轮 book seed 独立生效
        }
        return out
    }

    /// b) 实战采样：move-history/*.txt（含 A3 棋谱）ICCS 逐局面
    /// 目录不可达时返回空（b 源缺席由总量断言兜底——a/c/d/e 合计不足 5000 时测试红）
    private func sourceB_gameRecords() -> [Sample] {
        let testsDir = (#filePath as NSString).deletingLastPathComponent
        let dir = testsDir + "/../../calibration-results/move-history"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir).sorted() else {
            return []
        }
        var out: [Sample] = []
        let strideB = Self.full ? 1 : 10   // FULL 全收 164 局 × ~50 局面；默认 1/10
        for (fi, fname) in files.enumerated() where fi % strideB == 0 {
            guard let lines = try? String(contentsOfFile: dir + "/" + fname, encoding: .utf8)
                .split(separator: "\n").map(String.init) else { continue }
            var board = LegacySearchBoard()
            for (li, iccs) in lines.enumerated() {
                guard !iccs.isEmpty, let move = ICCSParser.parse(iccs, on: board) else { break }
                board.execute(move)
                out.append(Sample(tag: "b:\(fname):ply\(li + 1)",
                                  pieces: board.pieces, turn: board.currentTurn))
            }
        }
        return out
    }

    /// c) 残局集：经典形态手写 + SeededRandom 构造 ≤6 子
    private func sourceC_endgames() -> [Sample] {
        var out: [Sample] = []
        // 经典残局形态（Phase7Tests FEN 同型，手写 Piece 保证 id 唯一）
        out.append(Sample(tag: "c:RvK", pieces: [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .chariot, side: .red, position: Position(row: 3, col: 4), id: 0),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
        ], turn: .red))
        out.append(Sample(tag: "c:RRvKA", pieces: [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .chariot, side: .red, position: Position(row: 4, col: 3), id: 0),
            Piece(kind: .chariot, side: .red, position: Position(row: 4, col: 5), id: 1),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .advisor, side: .black, position: Position(row: 0, col: 3), id: 25),
        ], turn: .black))
        out.append(Sample(tag: "c:CCvbb", pieces: [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .cannon, side: .red, position: Position(row: 4, col: 2), id: 4),
            Piece(kind: .cannon, side: .red, position: Position(row: 4, col: 6), id: 5),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .elephant, side: .black, position: Position(row: 2, col: 4), id: 26),
        ], turn: .red))
        // 随机 ≤6 子构造（结构合法：双将在九宫、位置唯一、id 唯一；SeededRandom 可复现）
        let kinds: [PieceKind] = [.chariot, .cannon, .horse, .advisor, .elephant, .soldier]
        func palaceSquares(_ side: Side) -> [(Int, Int)] {
            let rows = side == .red ? Array(7...9) : Array(0...2)
            let cols = Array(3...5)
            return rows.flatMap { r in cols.map { (r, $0) } }
        }
        for i in 0..<400 {
            var pieces: [Piece] = []
            var usedSq = Set<Int>()
            // 双将：九宫随机（SeededRandom，局面可复现）
            for side in [Side.red, .black] {
                let palace = palaceSquares(side)
                let pick = SeededRandom.int(in: 0..<palace.count)
                let (kr, kc) = palace[pick]
                let base = side == .red ? 0 : 16
                pieces.append(Piece(kind: .general, side: side,
                                    position: Position(row: kr, col: kc), id: base + 8))
                usedSq.insert(kr * 9 + kc)
            }
            let extra = 2 + i % 5   // 2..6 子
            var nextId = 0
            for _ in 0..<extra {
                let kind = kinds[i % kinds.count]
                let side: Side = (nextId % 2 == 0) ? .red : .black
                var tries = 0
                while tries < 50 {
                    let r = SeededRandom.int(in: 0..<10), c = SeededRandom.int(in: 0..<9)
                    if usedSq.contains(r * 9 + c) { tries += 1; continue }
                    // 士象过河限制跳过（生成器对非法位产 0 走法，避开噪声；两实现仍等价比对）
                    if kind == .advisor || kind == .elephant {
                        let home = side == .red ? 5 : 4
                        if (side == .red && r < home) || (side == .black && r > home) { tries += 1; continue }
                    }
                    usedSq.insert(r * 9 + c)
                    // id 冲突防御：general 占 base+8，随机子避开 8/24 段
                    var pid = nextId
                    while pid == 8 || pid == 24 || pid == 16 + 8 { pid += 7 }
                    pieces.append(Piece(kind: kind, side: side,
                                        position: Position(row: r, col: c), id: pid))
                    nextId += 1
                    break
                }
            }
            let ids = pieces.map { $0.id }
            guard Set(ids).count == ids.count else { continue }
            out.append(Sample(tag: "c:rand\(i)", pieces: pieces,
                              turn: i % 2 == 0 ? .red : .black))
        }
        return out
    }

    /// d) 随机游走：k=10..80 步（Legacy 生成器语义，seed 版本化）
    private func sourceD_randomWalks() -> [Sample] {
        var out: [Sample] = []
        for i in 0..<200 {
            let seed = 88200 + UInt64(i)
            let steps = 10 + i % 71
            SeededRandom.configure(seed: seed)
            var board = LegacySearchBoard()
            for _ in 0..<steps {
                let side = board.currentTurn
                let moves = MoveValidator.allLegalMoves(for: side, on: board)
                guard !moves.isEmpty else { break }
                board.execute(moves[SeededRandom.int(in: 0..<moves.count)])
            }
            out.append(Sample(tag: "d:walk\(i):k\(steps)", pieces: board.pieces, turn: board.currentTurn))
            SeededRandom.configure(seed: 88001)
        }
        return out
    }

    /// e) 定向构造：将军/应将/送将各型 + 照面遮拦
    private func sourceE_directed() -> [Sample] {
        var out: [Sample] = []
        func add(_ tag: String, _ turn: Side, _ pieces: [Piece]) {
            out.append(Sample(tag: "e:\(tag)", pieces: pieces, turn: turn))
        }
        // 将帅照面（无遮拦）——照面走法生成边角
        add("facing", .red, [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 4), id: 0),
        ])
        // 照面遮拦：红车在将线中间，移开即照面（送将过滤应拦截移车走法）
        add("facing-screen", .red, [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 4), id: 0),
            Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 12),
        ])
        // 车口送将：黑车将军红帅，红方任何不解将走法应被过滤
        add("chariot-check", .red, [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 0), id: 16),
            Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 3), id: 12),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
        ])
        // 炮口送将：黑炮隔架打红帅
        add("cannon-check", .red, [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 3), id: 9),
            Piece(kind: .cannon, side: .black, position: Position(row: 9, col: 0), id: 20),
            Piece(kind: .horse, side: .black, position: Position(row: 7, col: 4), id: 25),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
        ])
        // 马口送将：黑马将军位（蹩腿边角）
        add("horse-check", .red, [
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
            Piece(kind: .horse, side: .black, position: Position(row: 7, col: 5), id: 25),
            Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 0),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
        ])
        // 被将军无解（负局）：红双车错杀位，黑无论如何都送将——legal 集应为空
        add("checkmate-no-legal", .black, [
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24),
            Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 3), id: 0),
            Piece(kind: .chariot, side: .red, position: Position(row: 1, col: 4), id: 1),
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8),
        ])
        return out
    }

    // MARK: - 四断言（谓词语义 = SearchBoardV2Tests A/A'/C/D 规模化）

    private func assertPosition(_ s: Sample) {
        let legacy = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
        let v2 = SearchBoardV2(pieces: s.pieces, currentTurn: s.turn)
        let side = s.turn

        // ── 断言 1（A）生成集等价 ──
        let legacyLegal = MoveValidator.allLegalMoves(for: side, on: legacy)
        let v2Pseudo = MoveGenerator.pseudoLegalMoves(on: v2)
        let v2LegalViaLegacy = v2Pseudo.filter { move in
            var work = LegacySearchBoard(pieces: s.pieces, currentTurn: s.turn)
            work.execute(move)
            return !MoveValidator.isInCheck(side, on: work)
        }
        let legacyKeys = Set(legacyLegal.map { moveKey($0) })
        let v2Keys = Set(v2LegalViaLegacy.map { moveKey($0) })
        if legacyKeys != v2Keys {
            let onlyLegacy = legacyKeys.subtracting(v2Keys).sorted()
            let onlyV2 = v2Keys.subtracting(legacyKeys).sorted()
            IssueRecorder.record("A 生成集不等价 [\(s.tag)]：仅Legacy=\(onlyLegacy) 仅V2=\(onlyV2)")
        }

        // ── 断言 2（A'）capturesOnly 等价（净化子集语义）──
        // 实锤（P2c 工具首跑发现）：MoveValidator.captureMoves 是极粗 QS 候选源，
        // 含吃己方候选（开局 8 条中 6 条：车吃己方马/帅吃己方士），QS 循环无过滤
        // 消费——存量行为（v3.9 起），Legacy 侧不修（原样保留铁律）。
        // V2 侧（appendTarget 己方跳过）是净化语义。故 A' 口径：
        //   ① 仅 V2 集 == 空（V2 不多产）
        //   ② 仅 Legacy 集逐条可归因：captured.side == 行棋方（吃己方候选）
        // 真吃子候选两侧全等。
        let legacyCaps = MoveValidator.captureMoves(for: side, on: legacy)
        let v2CapsPseudo = MoveGenerator.pseudoLegalMoves(on: v2, capturesOnly: true)
        let legacyCapKeys = Set(legacyCaps.map { moveKey($0) })
        let v2CapKeys = Set(v2CapsPseudo.map { moveKey($0) })
        let onlyV2Caps = v2CapsPseudo.filter { !legacyCapKeys.contains(moveKey($0)) }
        if !onlyV2Caps.isEmpty {
            IssueRecorder.record("A' V2 多产吃子候选（真分歧）[\(s.tag)]：\(onlyV2Caps.map { moveKey($0) }.sorted())")
        }
        let onlyLegacyCaps = legacyCaps.filter { !v2CapKeys.contains(moveKey($0)) }
        let unattributable = onlyLegacyCaps.filter { $0.captured?.side != side }
        if !unattributable.isEmpty {
            IssueRecorder.record("A' 仅Legacy 且非吃己方候选（真分歧）[\(s.tag)]：\(unattributable.map { moveKey($0) }.sorted())")
        }

        // ── 断言 3（C）inCheck 双实现全等（× 双方）──
        for chkSide in [Side.red, Side.black] {
            let legacyInCheck = MoveValidator.isInCheck(chkSide, on: legacy)
            let v2InCheck = v2.inCheck(chkSide)
            if legacyInCheck != v2InCheck {
                IssueRecorder.record("C inCheck 分歧 [\(s.tag)] side=\(chkSide)：Legacy=\(legacyInCheck) V2=\(v2InCheck)")
            }
        }

        // ── 断言 4（D）V2 make 链 → unmake 回放 == 快照 ──
        assertRoundTrip(v2: v2, tag: s.tag)
    }

    /// D：4 步链（V2 legal 集随机选步），回放后快照全等
    private func assertRoundTrip(v2 original: SearchBoardV2, tag: String) {
        var v2 = original
        let snapshotIds = Set(original.pieces.map { $0.id })
        let snapshotTurn = original.currentTurn
        let snapshotHistCount = original.moveHistory.count
        var undos: [SearchBoardV2.UndoInfo] = []
        for step in 0..<4 {
            let side = v2.currentTurn
            let pseudo = MoveGenerator.pseudoLegalMoves(on: v2)
            let legal = pseudo.filter { m in
                let undo = v2.make(m)
                let bad = v2.inCheck(side)
                v2.unmake(undo)
                return !bad
            }
            guard !legal.isEmpty else { break }
            let idx = SeededRandom.int(in: 0..<legal.count)
            undos.append(v2.make(legal[idx]))
            if !SearchBoardV2.structureIsValid(v2) {
                IssueRecorder.record("D make 后结构腐败 [\(tag)] step=\(step)")
                return
            }
        }
        while let u = undos.popLast() { v2.unmake(u) }
        if Set(v2.pieces.map { $0.id }) != snapshotIds
            || v2.currentTurn != snapshotTurn
            || v2.moveHistory.count != snapshotHistCount {
            IssueRecorder.record("D 回放后快照不等 [\(tag)]")
        }
    }

    // MARK: - 辅助

    /// 走法键（集合比对用，序不比对——§8.2 断言 1 括号）
    /// ⚠️ 安全键：字符串分段，避免位域歧义（V2Tests.moveKey 的整数键存在
    /// id3×cap1 ≡ id0×cap31 撞键可能——分段字符串无此问题）
    private func moveKey(_ m: Move) -> String {
        let fromSq = m.from.row * 9 + m.from.col
        let toSq = m.to.row * 9 + m.to.col
        return "\(m.piece.id):\(m.captured?.id ?? -1):\(fromSq):\(toSq)"
    }
}

/// 5000 局面循环内的分歧聚合：循环内逐次 #expect 开销大且失败信息碎片化，
/// 这里收集（上限 20 条防爆日志）后在测试函数内一次性 drain 报出。
enum IssueRecorder {
    private static var issues: [String] = []
    private static let lock = NSLock()

    static func record(_ message: String) {
        lock.lock()
        if issues.count < 20 { issues.append(message) }
        lock.unlock()
    }

    /// 仅在 @Test 函数内调用（#expect 需测试上下文）
    static func drain() -> [String] {
        lock.lock()
        let all = issues
        issues = []
        lock.unlock()
        return all
    }
}

extension Array {
    func strided(_ n: Int) -> [Element] {
        enumerated().compactMap { $0.offset % n == 0 ? $0.element : nil }
    }
}
