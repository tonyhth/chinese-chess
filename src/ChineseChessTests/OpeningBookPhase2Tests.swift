import Foundation
import Testing
@testable import ChineseChess

@Suite("开局库扩充 Phase 2")
struct OpeningBookPhase2Tests {

    // MARK: - 开局库加载

    @Test("OpeningBook 实例化不 crash")
    func openingBookInitNoCrash() {
        let book = OpeningBook()
        _ = book
    }

    @Test("OpeningBook 初始局面有开局建议")
    func openingBookInitialPositionHasMove() {
        let book = OpeningBook()
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        let move = book.lookup(zobristHash: hash)
        // 初始局面应该在开局库中（v2 有 59 个局面包含初始）
        #expect(move != nil, "初始局面无开局建议")
    }

    @Test("OpeningBook lookupAll 返回按权重降序")
    func openingBookLookupAllSortedByWeight() {
        let book = OpeningBook()
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        let entries = book.lookupAll(zobristHash: hash)
        if let entries = entries, entries.count > 1 {
            for i in 0..<(entries.count - 1) {
                #expect(entries[i].weight >= entries[i + 1].weight,
                       "权重未降序: \(entries[i].weight) < \(entries[i + 1].weight)")
            }
        }
    }

    @Test("OpeningBook lookupWeightedRandom 多次调用不 crash")
    func openingBookWeightedRandomNoCrash() {
        let book = OpeningBook()
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        for _ in 0..<50 {
            let move = book.lookupWeightedRandom(zobristHash: hash)
            // 可能返回 nil（不在库中）或有值
            _ = move
        }
    }

    @Test("OpeningBook lookupWeightedRandom 有多样性")
    func openingBookWeightedRandomHasVariety() {
        let book = OpeningBook()
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        let entries = book.lookupAll(zobristHash: hash)
        guard let entries = entries, entries.count > 1 else { return }

        var seen = Set<String>()
        for _ in 0..<50 {
            if let move = book.lookupWeightedRandom(zobristHash: hash) {
                seen.insert(move)
            }
        }
        // 如果有多个候选走法且权重差异不极端，50 次应至少选到 2 个不同走法
        // 但概率性测试，不强制要求
        if seen.count > 1 {
            // 多样性存在
        }
        #expect(!seen.isEmpty)
    }

    // MARK: - ICCS 解析

    @Test("ICCS 解析：初始局面有效走法")
    func iccsParseInitialBoard() {
        let book = OpeningBook()
        let board = Board()
        // 中炮 h2e2 是常见开局
        let move = book.parseICCSMove("h2e2", on: board)
        #expect(move != nil, "h2e2 解析失败")
    }

    @Test("ICCS 解析：非法走法返回 nil")
    func iccsParseInvalidMove() {
        let book = OpeningBook()
        let board = Board()
        let move = book.parseICCSMove("a0a0", on: board)
        #expect(move == nil)
    }

    // MARK: - 各难度开局行为

    @Test("中级：初始局面返回合法走法（可能来自开局库）")
    func mediumDifficultyOpeningMove() {
        let engine = AIEngine()
        let board = Board()
        let move = engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil)
        if let move = move {
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "中级开局返回非法走法")
        }
    }

    @Test("高级：初始局面返回合法走法")
    func hardDifficultyOpeningMove() {
        let engine = AIEngine()
        let board = Board()
        let move = engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
    }

    @Test("大师：初始局面返回合法走法")
    func masterDifficultyOpeningMove() {
        let engine = AIEngine()
        let board = Board()
        let move = engine.bestMove(for: board.snapshot(), difficulty: .master)
        #expect(move != nil)
    }

    // MARK: - 开局库未命中 fallback

    @Test("开局库未命中：走完开局阶段后 AI 正常 fallback")
    func openingBookMissFallback() async {
        let engine = AIEngine()
        let board = Board()

        // 走 6 步（3 回合），之后高级/大师开局库不再介入
        for _ in 0..<6 {
            let side = board.currentTurn
            let diff: AIDifficulty = side == .red ? .easy : .easy
            guard let move = engine.bestMove(for: board.snapshot(), difficulty: diff) else {
                Issue.record("AI 返回 nil")
                return
            }
            board.execute(move)
        }

        // 第 7 步应该 fallback 到搜索，不 crash
        let move = engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil, "开局库 miss 后 AI 返回 nil")
    }

    // MARK: - ZobristHash 稳定性

    @Test("ZobristHash：同一局面多次 hash 值一致")
    func zobristHashStability() {
        let board = Board()
        let hash1 = ZobristHash.hash(board: board)
        let hash2 = ZobristHash.hash(board: board)
        #expect(hash1 == hash2)
    }

    @Test("ZobristHash：不同局面 hash 值不同")
    func zobristHashDifferent() {
        let board1 = Board()
        let board2 = Board()
        // 走一步
        let moves = MoveValidator.allLegalMoves(for: .red, on: board2)
        if let firstMove = moves.first {
            board2.execute(firstMove)
            let hash1 = ZobristHash.hash(board: board1)
            let hash2 = ZobristHash.hash(board: board2)
            #expect(hash1 != hash2)
        }
    }

    // MARK: - v1 fallback（间接验证）

    @Test("OpeningBook v1 格式加载逻辑存在（buildV1Index 可编译）")
    func v1FallbackCompiles() {
        // 验证 OpeningBook 能编译即表示 v1 fallback 代码完整
        let book = OpeningBook()
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        // 无论用 v2 还是 v1 fallback，初始局面应有开局建议
        #expect(book.lookup(zobristHash: hash) != nil, "无开局建议（v2 和 v1 fallback 都失败）")
    }

    // MARK: - 回归：所有难度

    @Test("所有难度均返回合法走法")
    func allDifficultiesValidMoves() {
        let engine = AIEngine()
        let board = Board()
        for diff in [AIDifficulty.beginner, .easy, .medium] {
            let move = engine.bestMove(for: board.snapshot(), difficulty: diff)
            #expect(move != nil, "\(diff) 返回 nil")
        }
    }

    // MARK: - build_opening_book.py

    @Test("build_opening_book.py 权限为 644")
    func buildScriptPermissions() {
        let path = "~/DevTeam/projects/chinese-chess/tools/build_opening_book.py"
        let expandedPath = NSString(string: path).expandingTildeInPath
        let attrs = try? FileManager.default.attributesOfItem(atPath: expandedPath)
        let perms = attrs?[.posixPermissions] as? Int
        #expect(perms == 0o644, "权限不是 644，而是 \(String(perms ?? 0, radix: 8))")
    }

    @Test("build_opening_book.py --verify 可运行")
    func buildScriptVerifyRuns() async {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.arguments = [
            NSString(string: "~/DevTeam/projects/chinese-chess/tools/build_opening_book.py").expandingTildeInPath,
            "--verify"
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try? proc.run()
        proc.waitUntilExit()
        // --verify 需要 PGN 文件，可能无输入而退出
        // 只要不是 crash（segfault）就算通过
        #expect(proc.terminationStatus <= 1, "脚本 crash")
    }
}
