import XCTest
@testable import ChineseChess

/// A3 自对弈 EXIT:132 (EXC_BAD_INSTRUCTION/SIGILL) 崩溃回归测试
///
/// 崩溃链（2026-08-14 22:57 A3 重跑第 11 局，HEAD=1d2fdd1）：
/// SelfPlayRunner.playGame → AIEngine.bestMoves(lvl3) → mediumSearchScored
/// → rootSearchScored → allLegalMoves → isLegal → wouldBeInCheck → isInCheck
/// → canAttack(車, target: 将位) → isValidChariotMove → countPiecesBetween
/// → 行分支 (minC+1)..<maxC 在 from==to 时变成 (c+1)..<c
/// → Swift runtime trap "Range requires lowerBound <= upperBound"
///
/// 触发条件：棋盘数据腐败（对方車与己方将同格）时，canAttack 以
/// piece.position == target 调入 isMovePatternValid，車分支 guard 同行/同列恒真。
final class A3Exit132CrashTests: XCTestCase {

    // MARK: - 1. 崩溃触发点回归：from == to 不再 trap

    /// 构造"黑车与红帅同格"的腐败棋盘，沿原崩溃栈路径调用。
    /// 修复前：本测试进程直接 SIGILL（不是断言失败，是崩溃）。
    func testInCheckOnCorruptedBoardDoesNotTrap() {
        // 红帅 (0,4) 与黑车 (0,4) 同格 —— 模拟腐败态
        let general = Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 8)
        let chariot = Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 4), id: 16)
        let board = Board(pieces: [general, chariot])

        // 崩溃帧直接上游：isInCheck 遍历对方棋子 canAttack(黑车, 红帅位)
        _ = MoveValidator.isInCheck(.red, on: board)

        // canAttack 对同格目标必须返回 false（棋子不攻击自己所在的格子）
        XCTAssertFalse(MoveValidator.canAttack(piece: chariot, target: general.position, on: board))
    }

    /// 同一腐败态沿 isLegal（含 wouldBeInCheck）完整路径验证
    func testIsLegalOnCorruptedBoardDoesNotTrap() {
        let general = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 9, col: 4), id: 16)
        let redChariot = Piece(kind: .chariot, side: .red, position: Position(row: 8, col: 4), id: 0)
        let board = Board(pieces: [general, blackChariot, redChariot])

        let move = Move(piece: redChariot, from: redChariot.position,
                        to: Position(row: 9, col: 4), captured: blackChariot)
        _ = MoveValidator.isLegal(move, on: board)
    }

    /// 車/炮共用 countPiecesBetween：炮分支同格也不 trap（甲目标含同格炮架语义）
    func testCannonSameSquareTargetDoesNotTrap() {
        let cannon = Piece(kind: .cannon, side: .black, position: Position(row: 5, col: 4), id: 25)
        // 构造炮"攻击"自己所在格（同格）——countPiecesBetween(from==to) 必须返回 0 而非 trap
        let board = Board(pieces: [cannon])
        XCTAssertFalse(MoveValidator.canAttack(piece: cannon, target: cannon.position, on: board))
    }

    // MARK: - 2. 完整性校验器自身

    func testIntegrityProblemsDetectsCorruption() {
        let a = Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 8)
        let b = Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 4), id: 16)
        XCTAssertFalse(Board.integrityProblems(in: [a, b]).isEmpty, "同格两子必须被检出")

        let c = Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 8), id: 16)
        XCTAssertTrue(Board.integrityProblems(in: [a, c]).isEmpty, "正常布局不应报问题")

        let d = Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1), id: 16)
        XCTAssertFalse(Board.integrityProblems(in: [c, d]).isEmpty, "重复 ID 必须被检出")
    }

    // MARK: - 3. 走子/撤销保完整性 fuzz（防棋盘腐败复发）

    /// 确定性 LCG（可复现）
    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    /// 随机对局逐 ply execute，每步校验棋盘完整性（Debug 下 Board.execute 自带断言，此处双重确认）
    func testRandomGamesMaintainIntegrity() {
        for seed in 1...12 {
            var rng = SeededRNG(seed: UInt64(seed))
            let board = Board()
            var ply = 0
            while ply < 100 {
                let side = board.currentTurn
                let moves = MoveValidator.allLegalMoves(for: side, on: board)
                guard !moves.isEmpty else { break }
                let move = moves[Int(rng.next() % UInt64(moves.count))]
                board.execute(move)
                let problems = Board.integrityProblems(in: board.pieces)
                XCTAssertTrue(problems.isEmpty, "seed=\(seed) ply=\(ply) execute 后腐败: \(problems)")
                ply += 1
            }
        }
    }

    /// 模拟 negamax 搜索的嵌套 make/unmake + null-move toggleTurn，每层校验完整性
    func testNestedMakeUnmakeMaintainIntegrity() {
        for seed in 101...106 {
            var rng = SeededRNG(seed: UInt64(seed))
            var board = SearchBoard()
            nestedSearch(&board, depth: 3, rng: &rng, label: "seed=\(seed)")
        }
    }

    private func nestedSearch(_ board: inout SearchBoard, depth: Int,
                              rng: inout SeededRNG, label: String) {
        guard depth > 0 else { return }
        let side = board.currentTurn

        // null-move 模拟
        if rng.next() % 5 == 0 {
            board.toggleTurn()
            nestedSearch(&board, depth: depth - 1, rng: &rng, label: label)
            board.toggleTurn()
        }

        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return }

        // 每层只展开少量走法（模拟 PVS/LMR 的部分展开）
        let expandCount = min(4, moves.count)
        for _ in 0..<expandCount {
            let move = moves[Int(rng.next() % UInt64(moves.count))]
            board.execute(move)
            var problems = Board.integrityProblems(in: board.pieces)
            XCTAssertTrue(problems.isEmpty, "\(label) depth=\(depth) execute 后腐败: \(problems)")

            nestedSearch(&board, depth: depth - 1, rng: &rng, label: label)

            board.undoLastMove()
            problems = Board.integrityProblems(in: board.pieces)
            XCTAssertTrue(problems.isEmpty, "\(label) depth=\(depth) undo 后腐败: \(problems)")
        }
    }

    /// softmaxSelect 的 C1 过滤模式：同一棋盘连续 execute/undo 多个候选（含互相吃同子的候选）
    func testSoftmaxFilterPatternRoundTrip() {
        for seed in 201...204 {
            var rng = SeededRNG(seed: UInt64(seed))
            let board = Board()
            var ply = 0
            while ply < 80 {
                let side = board.currentTurn
                let moves = MoveValidator.allLegalMoves(for: side, on: board)
                guard !moves.isEmpty else { break }

                // 模拟 softmaxSelect：逐候选 execute → 读 FEN → undo
                // 注：undo 的 append(captured) 会改变 pieces 数组顺序（被吃子挪到末尾），
                // 但语义中立（id/位置均不变），故按排序后比较
                let snapshot = board.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted()
                let turn = board.currentTurn
                let histCount = board.moveHistory.count
                for move in moves.prefix(6) {
                    board.execute(move)
                    _ = FENParser.generate(board: board)
                    board.undoLastMove()
                }
                // 过滤循环后棋盘必须完全复原（顺序无关）
                let restored = board.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted()
                XCTAssertEqual(restored, snapshot, "seed=\(seed) ply=\(ply) C1 过滤后棋盘未复原")
                XCTAssertEqual(board.currentTurn, turn, "seed=\(seed) ply=\(ply) 走子方未复原")
                XCTAssertEqual(board.moveHistory.count, histCount, "seed=\(seed) ply=\(ply) moveHistory 未复原")

                let move = moves[Int(rng.next() % UInt64(moves.count))]
                board.execute(move)
                ply += 1
            }
        }
    }

    // MARK: - 4. 重放历史自对弈记录（如果存在）

    /// 重放 calibration-results/move-history 下的 A34 走法序列，
    /// 每步校验棋盘完整性（走法记录格式：列字母a-i + 行数字0-9，与 SelfPlayRunner.iccsNotation 一致）
    func testReplaySavedA34MoveHistories() throws {
        let testFile = #filePath
        let srcDir = (testFile as NSString).deletingLastPathComponent          // .../src/ChineseChessTests
        let projectRoot = ((srcDir as NSString).deletingLastPathComponent      // .../src
            as NSString).deletingLastPathComponent                            // 项目根
        let mhDir = (projectRoot as NSString).appendingPathComponent("calibration-results/move-history")

        guard FileManager.default.fileExists(atPath: mhDir) else {
            throw XCTSkip("无 move-history 目录，跳过重放")
        }
        let files = (try FileManager.default.contentsOfDirectory(atPath: mhDir))
            .filter { $0.hasPrefix("A34_") && $0.hasSuffix(".txt") }
            .sorted()
        guard !files.isEmpty else { throw XCTSkip("无 A34 走法文件") }

        var replayed = 0
        for file in files {
            let path = (mhDir as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let iccsMoves = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            guard !iccsMoves.isEmpty, replaySavedGame(iccsMoves, label: file) else { continue }
            replayed += 1
        }
        XCTAssertGreaterThan(replayed, 0, "至少应重放一局（若全部失败说明格式约定变化）")
    }

    @discardableResult
    private func replaySavedGame(_ iccsMoves: [String], label: String) -> Bool {
        let board = Board()
        for (i, iccs) in iccsMoves.enumerated() {
            guard iccs.count == 4 else { return false }
            let chars = Array(iccs)
            guard let fC = colIndex(chars[0]), let fR = rowIndex(chars[1]),
                  let tC = colIndex(chars[2]), let tR = rowIndex(chars[3]) else { return false }
            let from = Position(row: fR, col: fC)
            let to = Position(row: tR, col: tC)
            guard let piece = board.piece(at: from) else { return false }
            let captured = board.piece(at: to)
            let move = Move(piece: piece, from: from, to: to, captured: captured)
            guard MoveValidator.isLegal(move, on: board) else { return false }
            board.execute(move)
            let problems = Board.integrityProblems(in: board.pieces)
            XCTAssertTrue(problems.isEmpty, "\(label) 第\(i+1)步后棋盘腐败: \(problems) move=\(iccs)")
        }
        return true
    }

    private func colIndex(_ c: Character) -> Int? {
        guard let a = c.asciiValue, a >= 97, a <= 105 else { return nil }
        return Int(a - 97)
    }

    private func rowIndex(_ c: Character) -> Int? {
        guard let a = c.asciiValue, a >= 48, a <= 57 else { return nil }
        return Int(a - 48)
    }

    // MARK: - 5. OVERLAP dump 遥测与 --save-moves 落盘

    /// OVERLAP dump 必须落盘（单文件 append + OVERLAP 关键字 + 重叠对 + 上下文 + 最近走法含 captured）。
    /// 注：canAttack 同格 guard 挡在 countPiecesBetween 之前；防御点 dump 是第二道网，
    /// 真实运行时第一现场由 playGame 边界 checkpoint（每 ply 检查）捕获。
    func testOverlapDumpWritesLogFile() throws {
        let dir = NSTemporaryDirectory() + "overlap-test-\(UUID().uuidString)"
        BoardIntegrityLogger.logDirectory = dir
        BoardIntegrityLogger.currentContext = "selfplay red=lvl3 black=lvl4 game#11 ply#421 turn=lvl3"
        defer {
            try? FileManager.default.removeItem(atPath: dir)
            BoardIntegrityLogger.currentContext = ""
        }

        let general = Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 8)
        let chariot = Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 4), id: 16)
        let lastMove = Move(piece: chariot, from: Position(row: 5, col: 4),
                            to: Position(row: 0, col: 4), captured: nil)

        BoardIntegrityLogger.dumpOverlap(reason: "test_overlap_dump",
                                         pieces: [general, chariot],
                                         recentMoves: [lastMove],
                                         detail: "测试触发")

        let path = "\(dir)/illegal-position-dump.log"
        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("OVERLAP"), "日志必须含 OVERLAP 关键字（供 grep）")
        XCTAssertTrue(content.contains("selfplay red=lvl3"), "必须带 lvl 运行上下文")
        XCTAssertTrue(content.contains("overlap pairs (1)"), "重叠对数量必须标出")
        XCTAssertTrue(content.contains("id=16 chariot") && content.contains("id=8 general"),
                      "重叠两组件必须在 overlap pairs 段落成对出现")
        XCTAssertTrue(content.contains("(5,4)→(0,4)"), "最近走法必须含 from→to")
    }

    /// overlapPairs 提取器：同格成组
    func testOverlapPairsExtraction() {
        let a = Piece(kind: .general, side: .red, position: Position(row: 0, col: 4), id: 8)
        let b = Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 4), id: 16)
        let c = Piece(kind: .horse, side: .red, position: Position(row: 9, col: 1), id: 2)
        let pairs = BoardIntegrityLogger.overlapPairs(in: [a, b, c])
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(Set(pairs[0].map { $0.id }), [8, 16])
    }

    /// 去抖：同 reason 60s 窗口内第二次不重复落盘（热路径保护）；单文件内 entry 数不变
    func testOverlapDumpDedupWithinWindow() throws {
        let dir = NSTemporaryDirectory() + "overlap-dedup-\(UUID().uuidString)"
        BoardIntegrityLogger.logDirectory = dir
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let piece = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let reason = "test_dedup_\(UUID().uuidString)"
        BoardIntegrityLogger.dumpOverlap(reason: reason, pieces: [piece], recentMoves: [])
        BoardIntegrityLogger.dumpOverlap(reason: reason, pieces: [piece], recentMoves: [])

        let content = try String(contentsOfFile: "\(dir)/illegal-position-dump.log", encoding: .utf8)
        let entryCount = content.components(separatedBy: "=== OVERLAP").count - 1
        XCTAssertEqual(entryCount, 1, "同 reason 去抖窗口内只落盘一次")
    }

    /// --save-moves：逐局即时落盘的文件名与内容格式
    func testWriteMoveHistoryFilenameAndContent() throws {
        let dir = NSTemporaryDirectory() + "mh-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let game = SelfPlayGameResult(
            gameIndex: 10, redDifficulty: .amateurLow, blackDifficulty: .amateurMid,
            result: .draw, totalMoves: 87, reason: .moveLimit,
            moveHistory: ["b0c2", "h9g7"])
        SelfPlayRunner.writeMoveHistory(game, to: dir, groupLabel: "A34")

        let files = try FileManager.default.contentsOfDirectory(atPath: dir)
        XCTAssertEqual(files, ["A34_game11_lvl3vslvl4_87.txt"], "文件名格式与 --calibrate-native 约定一致")
        let content = try String(contentsOfFile: "\(dir)/\(files[0])", encoding: .utf8)
        XCTAssertEqual(content, "b0c2\nh9g7")
    }

    func testLevelNumberExtraction() {
        XCTAssertEqual(SelfPlayRunner.levelNumber("lvl3"), "3")
        XCTAssertEqual(SelfPlayRunner.levelNumber("lvl10"), "10")
        XCTAssertNil(SelfPlayRunner.levelNumber("beginner"))
        XCTAssertNil(SelfPlayRunner.levelNumber("lvlx"))
    }

    // MARK: - 6. 腐败机制确定性证明（probe 实测机制的因果链）

    /// 机制：softmaxSelect 的 C1 过滤在游戏 Board 上 execute/undo 引擎候选；
    /// 若候选是陈旧快照（from/captured 落后实际局面），undo 会把棋子传送回陈旧位置。
    /// 注：softmaxSelect 是 private static，此处直接验证同模式（execute→读→undo）的等价序列。
    /// 用受控最小局面（陈旧 from/to 均为空格，避开 execute/undo 内置完整性断言）。
    func testStaleCandidateFilterPatternTeleportsPiece() {
        // 受控局面：红帅(9,4) 黑将(0,4) 黑车 id16 实际在 (5,4)；候选快照里 id16 在 (2,2)
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let actualChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 4), id: 16)
        let gameBoard = Board(pieces: [redGeneral, blackGeneral, actualChariot])

        // 陈旧候选：引擎旧视角（id16 在 (2,2)，拟去 (2,4)，两格均空）
        let stalePiece = Piece(kind: .chariot, side: .black, position: Position(row: 2, col: 2), id: 16)
        let staleMove = Move(piece: stalePiece, from: Position(row: 2, col: 2),
                             to: Position(row: 2, col: 4), captured: nil)

        // C1 过滤模式：execute → 读 FEN → undo（SelfPlayRunner.softmaxSelect 同款序列）
        gameBoard.execute(staleMove)
        _ = FENParser.generate(board: gameBoard)
        gameBoard.undoLastMove()

        // 断言：id16 被传送回陈旧 from (2,2)，而非实际位置 (5,4)
        let actual = gameBoard.piece(at: Position(row: 5, col: 4))
        let teleported = gameBoard.piece(at: Position(row: 2, col: 2))
        XCTAssertNil(actual, "id16 的真实位置 (5,4) 被清空——位置级腐败（重叠的前提态）")
        XCTAssertNotNil(teleported, "id16 被传送回陈旧快照位置 (2,2)")
        XCTAssertEqual(teleported?.id, 16)
        // 棋盘历史计数不变（腐败对历史不可见——与 probe 观测一致）
        XCTAssertEqual(gameBoard.moveHistory.count, 0)
    }

    /// 同机制的 captured 变体：陈旧 captured 会让被吃子复活在陈旧位置
    func testStaleCapturedFilterPatternTeleportsVictim() {
        // 受控：红帅(9,4) 黑将(0,4) 红车 id0 在 (5,5)，黑马 id18 实际在 (3,3)（陈旧快照说在 (6,6)，均空格）
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let redChariot = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 5), id: 0)
        let actualHorse = Piece(kind: .horse, side: .black, position: Position(row: 3, col: 3), id: 18)
        let gameBoard = Board(pieces: [redGeneral, blackGeneral, redChariot, actualHorse])

        let staleVictim = Piece(kind: .horse, side: .black, position: Position(row: 6, col: 6), id: 18)
        let staleMove = Move(piece: redChariot, from: redChariot.position,
                             to: Position(row: 6, col: 6), captured: staleVictim)

        gameBoard.execute(staleMove)   // 按 id 移除 id18（实际在 (3,3)），红车到 (6,6)
        gameBoard.undoLastMove()        // 红车回 (5,5)，id18 复活在陈旧 captured 位置 (6,6)

        XCTAssertNil(gameBoard.piece(at: Position(row: 3, col: 3)), "id18 实际位置被清空")
        let revived = gameBoard.piece(at: Position(row: 6, col: 6))
        XCTAssertNotNil(revived, "id18 复活在陈旧 captured 位置——位置级腐败")
        XCTAssertEqual(revived?.id, 18)
        XCTAssertEqual(gameBoard.piece(at: Position(row: 5, col: 5))?.id, 0, "行棋方正常复原")
    }
}
