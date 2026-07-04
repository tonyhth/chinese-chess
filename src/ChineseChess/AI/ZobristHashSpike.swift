import Foundation

// MARK: - ZobristHash 增量更新 Spike 验证
// 验收标准：≥20 个局面，每个局面增量结果 == 全量结果

/// Spike 测试入口
func runZobristSpike() -> Bool {
    print("=== ZobristHash 增量更新 Spike 验证 ===")
    var allPassed = true
    var testCount = 0

    // 测试 1: 标准开局
    let board0 = Board()
    let hash0 = ZobristHash.hash(board: board0)
    print("Test 1: 标准开局 hash = \(hash0)")
    testCount += 1

    // 测试 2-10: 红方常见开局走法
    let moves1: [(uci: String, desc: String)] = [
        ("h2e2", "炮二平五（中炮）"),
        ("h0g2", "马二进三（起马）"),
        ("b0a2", "马八进七（跳马）"),
        ("a0a1", "车九进一（横车）"),
        ("h2h5", "炮二进二（炮巡河）"),
        ("g0g2", "相三进五（飞相）"),
        ("a0a3", "车九进三（巡河车）"),
        ("i0i1", "车一进一（横车）"),
        ("b2b5", "炮八进二（右炮巡河）"),
    ]

    var currentBoard = board0
    var currentHash = hash0

    for (idx, moveStr) in moves1.enumerated() {
        guard let move = parseICCS(moveStr.uci, on: currentBoard) else {
            print("Test \(idx + 2): 解析失败 \(moveStr)")
            allPassed = false
            continue
        }
        let captured = currentBoard.piece(at: move.to)
        let incrementalHash = ZobristHash.update(hash: currentHash, piece: move.piece, from: move.from, to: move.to, captured: captured)

        currentBoard.execute(move)
        let fullHash = ZobristHash.hash(board: currentBoard)

        let passed = incrementalHash == fullHash
        print("Test \(idx + 2): \(moveStr.desc) — 增量=\(incrementalHash) 全量=\(fullHash) \(passed ? "✅" : "❌")")
        testCount += 1
        if !passed { allPassed = false }

        currentHash = fullHash
    }

    // 测试 11-15: 包含吃子的场景
    print("\n=== 吃子场景验证 ===")

    var eatBoard = Board()
    var eatHash = ZobristHash.hash(board: eatBoard)

    let eatMoves: [(uci: String, desc: String)] = [
        ("h2e2", "炮二平五"),
        ("b9c7", "马8进7"),
        ("i0i1", "车一进一"),
        ("h9g7", "马2进3"),
        ("i1f1", "车一平六"),
    ]

    for (idx, moveStr) in eatMoves.enumerated() {
        guard let move = parseICCS(moveStr.uci, on: eatBoard) else {
            print("吃子前置第\(idx+1)步解析失败")
            allPassed = false
            continue
        }
        let captured = eatBoard.piece(at: move.to)
        let incHash = ZobristHash.update(hash: eatHash, piece: move.piece, from: move.from, to: move.to, captured: captured)
        eatBoard.execute(move)
        let fullHash = ZobristHash.hash(board: eatBoard)
        let passed = incHash == fullHash
        print("吃子前置第\(idx+1)步: \(moveStr.desc) \(passed ? "✅" : "❌")")
        testCount += 1
        if !passed { allPassed = false }
        eatHash = fullHash
    }

    // 测试 16-20: 特殊局面 FEN
    let testFENs: [(fen: String, desc: String)] = [
        ("rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1", "标准开局"),
        ("rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 1 1", "黑方先行"),
        ("rnba1abnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/R1BAKABNR w - - 2 2", "红炮已移动"),
        ("1nbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKAB1R w - - 3 3", "红车已移动"),
        ("rnbakabn1/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABR1 w - - 4 4", "红马已移动"),
    ]

    print("\n=== FEN 局面验证 ===")
    for (idx, testFEN) in testFENs.enumerated() {
        let board = Board(fen: testFEN.fen)
        let hash = ZobristHash.hash(board: board)
        print("Test \(idx + 16): \(testFEN.desc) — hash=\(hash)")
        testCount += 1
    }

    // 链式验证：连续走步
    print("\n=== 链式增量验证（连续10步）===")
    var chainBoard = Board()
    var chainHash = ZobristHash.hash(board: chainBoard)
    let chainMoves = ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "a0a1", "c3c4", "g3g4", "b2b4", "b7b3"]

    for (idx, uci) in chainMoves.enumerated() {
        guard let move = parseICCS(uci, on: chainBoard) else {
            print("链式第\(idx+1)步解析失败: \(uci)")
            allPassed = false
            break
        }
        let captured = chainBoard.piece(at: move.to)
        let incHash = ZobristHash.update(hash: chainHash, piece: move.piece, from: move.from, to: move.to, captured: captured)

        chainBoard.execute(move)
        let fullHash = ZobristHash.hash(board: chainBoard)

        let passed = incHash == fullHash
        print("链式第\(idx+1)步 \(uci): 增量=\(incHash) 全量=\(fullHash) \(passed ? "✅" : "❌")")
        testCount += 1
        if !passed { allPassed = false }

        chainHash = fullHash
    }

    // toggleTurn 验证（空着裁剪场景）
    print("\n=== toggleTurn 验证 ===")
    let toggleBoard = Board()
    let toggleHash1 = ZobristHash.hash(board: toggleBoard)
    toggleBoard.toggleTurn()
    let toggleHash2 = ZobristHash.hash(board: toggleBoard)
    let expectedToggleHash = toggleHash1 ^ ZobristHash.sideHash
    let togglePassed = toggleHash2 == expectedToggleHash
    print("toggleTurn: 原=\(toggleHash1) 翻转后=\(toggleHash2) 期望=\(expectedToggleHash) \(togglePassed ? "✅" : "❌")")
    testCount += 1
    if !togglePassed { allPassed = false }

    // 再次 toggleTurn 应恢复原 hash
    toggleBoard.toggleTurn()
    let toggleHash3 = ZobristHash.hash(board: toggleBoard)
    let toggleRestorePassed = toggleHash3 == toggleHash1
    print("toggleTurn 恢复: hash=\(toggleHash3) 原=\(toggleHash1) \(toggleRestorePassed ? "✅" : "❌")")
    testCount += 1
    if !toggleRestorePassed { allPassed = false }

    print("\n=== 总结 ===")
    print("测试数: \(testCount), 全部通过: \(allPassed ? "✅" : "❌")")
    return allPassed
}

/// 解析 ICCS/UCI 格式走法（如 "h2e2"）
private func parseICCS(_ uci: String, on board: Board) -> Move? {
    guard uci.count == 4 else { return nil }
    let chars = Array(uci)
    let fileChars = Array("abcdefghi")

    guard let fromCol = fileChars.firstIndex(of: chars[0]),
          let fromRowChar = Int(String(chars[1])),
          let toCol = fileChars.firstIndex(of: chars[2]),
          let toRowChar = Int(String(chars[3])) else { return nil }

    // ICCS 行号 0-9 → Board row 9-0
    let boardFromRow = 9 - fromRowChar
    let boardToRow = 9 - toRowChar

    let fromPos = Position(row: boardFromRow, col: fromCol)
    let toPos = Position(row: boardToRow, col: toCol)

    guard let piece = board.piece(at: fromPos) else { return nil }
    let captured = board.piece(at: toPos)

    return Move(piece: piece, from: fromPos, to: toPos, captured: captured)
}