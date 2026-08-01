import Testing
@testable import ChineseChess

@Suite("Phase 2a 搜索算法升级测试", .serialized)
struct Phase2aSearchTests {

    // MARK: - PVS 测试

    @Test("PVS 启用时不改变最佳走法正确性（beginner）")
    func pvsBeginnerCorrectness() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil, "PVS 启用后仍应返回合法走法")
    }

    @Test("PVS 启用时不改变最佳走法正确性（hard）")
    func pvsHardCorrectness() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .hard, isIOS: false)
        #expect(move != nil, "hard 难度启用 PVS 后仍应返回合法走法")
    }

    @Test("PVS 启用时不改变最佳走法正确性（master）")
    func pvsMasterCorrectness() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        #expect(move != nil, "master 难度启用 PVS 后仍应返回合法走法")
    }

    @Test("PVS 结果一致性：同一局面多次搜索结果相同")
    func pvsConsistency() async {
        let engine = AIEngine()
        let board = Board()
        // master 使用确定性开局，所以前几步固定
        let move1 = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        let move2 = await engine.bestMove(for: board, difficulty: .master, isIOS: false)
        #expect(move1 != nil)
        #expect(move2 != nil)
        // 确定性开局应返回相同走法
        if let m1 = move1, let m2 = move2 {
            #expect(m1.from == m2.from, "确定性开局应返回相同起点")
            #expect(m1.to == m2.to, "确定性开局应返回相同终点")
        }
    }

    // MARK: - Countermove 测试

    @Test("Countermove 表记录和查询")
    func countermoveRecordAndGet() {
        var orderer = MoveOrderer()
        let opponentMove = Move(
            piece: Piece(kind: .soldier, side: .red, position: Position(row: 3, col: 0), id: 130),
            from: Position(row: 3, col: 0),
            to: Position(row: 4, col: 0),
            captured: nil
        )
        let response = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
            from: Position(row: 0, col: 0),
            to: Position(row: 4, col: 0),
            captured: opponentMove.piece
        )

        // 记录前查询应为 nil
        #expect(orderer.getCountermove(for: opponentMove) == nil)

        // 记录后查询应返回 response
        orderer.recordCountermove(move: response, opponentMove: opponentMove)
        let result = orderer.getCountermove(for: opponentMove)
        #expect(result != nil)
        if let r = result {
            #expect(r.from == response.from)
            #expect(r.to == response.to)
        }
    }

    @Test("Countermove nil 对手走法安全处理")
    func countermoveNilOpponent() {
        var orderer = MoveOrderer()
        let move = Move(
            piece: Piece(kind: .soldier, side: .red, position: Position(row: 3, col: 0), id: 130),
            from: Position(row: 3, col: 0),
            to: Position(row: 4, col: 0),
            captured: nil
        )
        // nil opponentMove 不应崩溃
        orderer.recordCountermove(move: move, opponentMove: nil)
        #expect(orderer.getCountermove(for: nil) == nil)
    }

    @Test("Countermove clearHistory 清空")
    func countermoveClear() {
        var orderer = MoveOrderer()
        let opponentMove = Move(
            piece: Piece(kind: .soldier, side: .red, position: Position(row: 3, col: 0), id: 130),
            from: Position(row: 3, col: 0),
            to: Position(row: 4, col: 0),
            captured: nil
        )
        let response = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
            from: Position(row: 0, col: 0),
            to: Position(row: 4, col: 0),
            captured: opponentMove.piece
        )

        orderer.recordCountermove(move: response, opponentMove: opponentMove)
        orderer.clearHistory()
        #expect(orderer.getCountermove(for: opponentMove) == nil)
    }

    @Test("Countermove 排序加分：countermove 在走法列表中排序提前")
    func countermoveOrderingBoost() {
        var orderer = MoveOrderer()
        let board = Board()
        let opponentMove = Move(
            piece: Piece(kind: .soldier, side: .red, position: Position(row: 3, col: 0), id: 130),
            from: Position(row: 3, col: 0),
            to: Position(row: 4, col: 0),
            captured: nil
        )
        let cmMove = Move(
            piece: Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0), id: 16),
            from: Position(row: 0, col: 0),
            to: Position(row: 4, col: 0),
            captured: nil
        )

        orderer.recordCountermove(move: cmMove, opponentMove: opponentMove)

        // 获取所有黑方走法，验证 cmMove 排序靠前
        let blackMoves = MoveValidator.allLegalMoves(for: .black, on: board)
        let cmRetrieved = orderer.getCountermove(for: opponentMove)
        #expect(cmRetrieved != nil)

        // 排序后验证 cmMove 的位置
        let ordered = orderer.order(blackMoves, on: board, countermove: cmMove)
        // cmMove 应该在比较前的位置（有加分）
        if let cmIdx = ordered.firstIndex(where: { $0.from == cmMove.from && $0.to == cmMove.to }),
           let originalIdx = blackMoves.firstIndex(where: { $0.from == cmMove.from && $0.to == cmMove.to }) {
            // countermove 加分 6000，应比无加分走法排前
            #expect(cmIdx <= originalIdx, "countermove 应排序提前或持平")
        }
    }

    // MARK: - 搜索配置测试

    @Test("SearchConfig PVS 和 Countermove 默认关闭")
    func searchConfigDefaultsOff() {
        let config = AISearchConfig.default
        #expect(config.enablePVS == false, "默认配置 PVS 应关闭")
        #expect(config.enableCountermove == false, "默认配置 Countermove 应关闭")
    }

    @Test("SearchConfig master 配置启用 PVS 和 Countermove")
    func searchConfigMasterEnabled() {
        let config = AISearchConfig.master
        #expect(config.enablePVS == true, "master 配置应启用 PVS")
        #expect(config.enableCountermove == true, "master 配置应启用 Countermove")
    }

    @Test("SearchConfig hard 配置启用 PVS 和 Countermove")
    func searchConfigHardEnabled() {
        let config = AISearchConfig.hard
        #expect(config.enablePVS == true, "hard 配置应启用 PVS")
        #expect(config.enableCountermove == true, "hard 配置应启用 Countermove")
    }

    @Test("SearchConfig medium 配置不启用 PVS")
    func searchConfigMediumDisabled() {
        let config = AISearchConfig.medium
        #expect(config.enablePVS == false, "medium 配置不应启用 PVS")
        #expect(config.enableCountermove == false, "medium 配置不应启用 Countermove")
    }
}
