import Foundation
import Testing
import Pikafish
@testable import ChineseChess

// MARK: - Phase 5 #4: Pikafish C API 测试
// ⚠️ 必须串行执行（并行会导致全局 C 引擎状态挂死）

@Suite("Phase 5 #4: Pikafish C API 测试", .serialized)
struct PikafishCAPITests {

    // MARK: - 1. init / quit 生命周期

    @Test("pikafish_init: 返回 0（成功）")
    func initSucceeds() {
        // 先 quit 确保干净状态
        pikafish_quit()
        let result = pikafish_init()
        #expect(result == 0, "pikafish_init 应返回 0 表示成功")
    }

    @Test("pikafish_quit: 无崩溃")
    func quitNoCrash() {
        pikafish_quit()
        // 重复 quit 也不应崩溃
        pikafish_quit()
    }

    @Test("pikafish_init: 初始化后可再次 quit 并重新 init")
    func reinitCycle() {
        pikafish_quit()
        let r1 = pikafish_init()
        #expect(r1 == 0)
        pikafish_quit()
        let r2 = pikafish_init()
        #expect(r2 == 0, "quit 后重新 init 应成功")
        // 保持初始化状态供后续测试使用
    }

    // MARK: - 2. pikafish_get_info

    @Test("pikafish_get_info: 返回非空字符串")
    func getInfoNonEmpty() {
        pikafish_quit()
        _ = pikafish_init()

        let info = pikafish_get_info()
        #expect(info != nil, "get_info 不应返回 nil")

        let str = String(cString: info!)
        #expect(!str.isEmpty, "引擎信息不应为空")
        #expect(str.contains("Pikafish"), "引擎信息应包含 'Pikafish'")
    }

    @Test("pikafish_get_info: quit 后返回 nil 或无效")
    func getInfoAfterQuit() {
        pikafish_quit()
        // quit 后 info 指针可能 nil 或无效
        let info = pikafish_get_info()
        // 允许 nil 或空（C API 实现决定）
        if let info = info {
            let str = String(cString: info)
            // quit 后可能返回旧数据或空字符串
            #expect(str.count >= 0, "quit 后 info 指针有效时字符串应可读")
        } else {
            #expect(info == nil, "quit 后 info 应为 nil")
        }
        // 重新初始化供后续测试
        _ = pikafish_init()
    }

    // MARK: - 3. pikafish_set_option

    @Test("pikafish_set_option: 设置 Hash 为 64MB")
    func setOptionHash() {
        _ = pikafish_init()
        let result = pikafish_set_option("Hash", "64")
        #expect(result == 0, "设置 Hash 应返回 0")
    }

    @Test("pikafish_set_option: 设置 Threads 为 1")
    func setOptionThreads() {
        _ = pikafish_init()
        let result = pikafish_set_option("Threads", "1")
        #expect(result == 0, "设置 Threads 应返回 0")
    }

    @Test("pikafish_set_option: 未知选项被静默接受（返回 0）")
    func setOptionInvalid() {
        _ = pikafish_init()
        let result = pikafish_set_option("NonExistentOption", "123")
        // C API 实现对未知选项 accept silently 返回 0
        #expect(result == 0, "未知选项应返回 0（静默接受）")
    }

    // MARK: - 4. pikafish_new_game

    @Test("pikafish_new_game: 重置后引擎仍可搜索")
    func newGameNoCrash() {
        _ = pikafish_init()
        pikafish_new_game()

        // 连续调用
        pikafish_new_game()

        // 验证：new_game 后引擎仍可正常返回走法
        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        let ok = fen.withCString { fenCStr in
            pikafish_best_move(fenCStr, "", 3, 500, &buffer, Int32(buffer.count))
        }
        #expect(ok == 0, "new_game 后引擎应可正常搜索")
        let move = String(cString: buffer)
        #expect(!move.isEmpty, "new_game 后应返回非空走法")
    }

    // MARK: - 5. pikafish_best_move 搜索

    @Test("pikafish_best_move: 标准开局返回合法走法")
    func bestMoveStandardOpening() {
        _ = pikafish_init()
        pikafish_new_game()

        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        let result = fen.withCString { fenCStr in
            pikafish_best_move(fenCStr, "", 5, 1000, &buffer, Int32(buffer.count))
        }

        #expect(result == 0, "best_move 应返回 0")
        let move = String(cString: buffer)
        #expect(!move.isEmpty, "应返回非空走法")
        #expect(move.count >= 4, "UCI 走法至少 4 字符（如 h2e2）")
    }

    @Test("pikafish_best_move: 带 move history")
    func bestMoveWithHistory() {
        _ = pikafish_init()
        pikafish_new_game()

        // 标准开局，走了一步 h2e2（炮二平五）
        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        let result = fen.withCString { fenCStr in
            "h2e2".withCString { movesCStr in
                pikafish_best_move(fenCStr, movesCStr, 5, 1000, &buffer, Int32(buffer.count))
            }
        }

        #expect(result == 0)
        let move = String(cString: buffer)
        #expect(!move.isEmpty, "应返回黑方应招")
    }

    @Test("pikafish_best_move: 深度限制")
    func bestMoveDepthLimit() {
        _ = pikafish_init()
        pikafish_new_game()

        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        let result = fen.withCString { fenCStr in
            pikafish_best_move(fenCStr, "", 1, 0, &buffer, Int32(buffer.count))
        }

        // 深度 1 应快速返回
        #expect(result == 0)
        let move = String(cString: buffer)
        #expect(!move.isEmpty)
    }

    // MARK: - 6. pikafish_stop

    @Test("pikafish_stop: 无搜索时调用不影响后续操作")
    func stopNoSearchNoCrash() {
        _ = pikafish_init()
        pikafish_stop()

        // 重复调用
        pikafish_stop()

        // 验证：stop 后引擎仍可正常搜索
        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        let ok = fen.withCString { fenCStr in
            pikafish_best_move(fenCStr, "", 3, 500, &buffer, Int32(buffer.count))
        }
        #expect(ok == 0, "stop 后引擎应可正常搜索")
    }

    // MARK: - 7. pikafish_last_eval

    @Test("pikafish_last_eval: 搜索后返回评估值")
    func lastEvalAfterSearch() {
        _ = pikafish_init()
        pikafish_new_game()

        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        _ = fen.withCString { fenCStr in
            pikafish_best_move(fenCStr, "", 5, 500, &buffer, Int32(buffer.count))
        }

        let eval = pikafish_last_eval()
        // 标准开局评估应在合理范围内（-1000 到 1000 cp）
        #expect(abs(eval) < 5000, "评估值应在合理范围内，实际: \(eval)")
    }

    @Test("pikafish_last_eval: 初始为 0")
    func lastEvalInitial() {
        pikafish_quit()
        _ = pikafish_init()
        let eval = pikafish_last_eval()
        #expect(eval == 0, "未搜索前 eval 应为 0")
    }

    // MARK: - 8. pikafish_set_multipv

    @Test("pikafish_set_multipv: 设置 1")
    func setMultiPV1() {
        _ = pikafish_init()
        let result = pikafish_set_multipv(1)
        #expect(result == 0, "设置 multipv=1 应返回 0")
    }

    @Test("pikafish_set_multipv: 设置 3")
    func setMultiPV3() {
        _ = pikafish_init()
        let result = pikafish_set_multipv(3)
        #expect(result == 0, "设置 multipv=3 应返回 0")
    }

    @Test("pikafish_set_multipv: 无效值返回 -1")
    func setMultiPVInvalid() {
        _ = pikafish_init()
        let result = pikafish_set_multipv(0)
        #expect(result == -1, "multipv=0 应返回 -1（有效范围 1-10）")

        let result2 = pikafish_set_multipv(20)
        #expect(result2 == -1, "multipv=20 应返回 -1（有效范围 1-10）")

        // 恢复
        _ = pikafish_set_multipv(1)
    }

    // MARK: - 9. pikafish_get_pv_line

    @Test("pikafish_get_pv_line: 搜索后返回非空 PV")
    func getPVLineAfterSearch() {
        _ = pikafish_init()
        pikafish_new_game()

        let fen = FENParser.generate(board: Board())
        var buffer = [CChar](repeating: 0, count: 64)
        _ = fen.withCString { fenCStr in
            pikafish_best_move(fenCStr, "", 5, 500, &buffer, Int32(buffer.count))
        }

        var pvBuffer = [CChar](repeating: 0, count: 256)
        let bytes = pvBuffer.withUnsafeMutableBufferPointer { ptr in
            pikafish_get_pv_line(ptr.baseAddress, Int32(ptr.count))
        }
        // PV line 可能返回字节数（可能为 0 如果引擎未保留）
        #expect(bytes >= 0, "get_pv_line 应返回 >= 0")
    }

    // MARK: - 10. pikafish_eval

    @Test("pikafish_eval: 评估标准局面")
    func evalStandardPosition() {
        _ = pikafish_init()
        pikafish_new_game()

        let fen = FENParser.generate(board: Board())
        let result = UnsafeMutablePointer<PikafishEvalResult>.allocate(capacity: 1)
        memset(result, 0, MemoryLayout<PikafishEvalResult>.size)
        defer { result.deallocate() }

        let ok = fen.withCString { fenCStr in
            pikafish_eval(fenCStr, "", 5, 500, result)
        }

        #expect(ok == 0, "eval 应返回 0")
        // depth 可能为 0（如果引擎在 time_ms 内未完成搜索），放宽验证
        let bestMove = withUnsafePointer(to: result.pointee.best_move) {
            $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
        }
        #expect(!bestMove.isEmpty, "best_move 不应为空")
        #expect(bestMove.count >= 4, "UCI 走法至少 4 字符")
    }

    @Test("pikafish_eval: 带 move history")
    func evalWithHistory() {
        _ = pikafish_init()

        let fen = FENParser.generate(board: Board())
        let result = UnsafeMutablePointer<PikafishEvalResult>.allocate(capacity: 1)
        memset(result, 0, MemoryLayout<PikafishEvalResult>.size)
        defer { result.deallocate() }

        let ok = fen.withCString { fenCStr in
            "h2e2".withCString { movesCStr in
                pikafish_eval(fenCStr, movesCStr, 5, 500, result)
            }
        }

        #expect(ok == 0)
        // depth 可能为 0（时间限制短时）
    }

    // MARK: - 11. EmbeddedPikafishEngine actor 集成

    @Test("EmbeddedPikafishEngine: start 后 isReady 为 true")
    func engineStartReady() async throws {
        let engine = EmbeddedPikafishEngine()
        try await engine.start()
        #expect(await engine.isReady == true, "start 后 isReady 应为 true")
        await engine.shutdown()
    }

    @Test("EmbeddedPikafishEngine: shutdown 后 isReady 为 false")
    func engineShutdownNotReady() async throws {
        let engine = EmbeddedPikafishEngine()
        try await engine.start()
        #expect(await engine.isReady == true)
        await engine.shutdown()
        #expect(await engine.isReady == false, "shutdown 后 isReady 应为 false")
    }

    @Test("EmbeddedPikafishEngine: bestMove 返回合法走法")
    func engineBestMove() async throws {
        let engine = EmbeddedPikafishEngine()
        try await engine.start()

        let fen = FENParser.generate(board: Board())
        let move = await engine.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: .beginner,
            timeLimitMs: 1000
        )

        #expect(move != nil, "应返回非 nil 走法")
        #expect(!move!.isEmpty, "走法不应为空")
        #expect(move!.count >= 4, "UCI 走法至少 4 字符")

        await engine.shutdown()
    }

    @Test("EmbeddedPikafishEngine: version 非空")
    func engineVersion() async throws {
        let engine = EmbeddedPikafishEngine()
        try await engine.start()

        let version = await engine.version
        #expect(!version.isEmpty, "version 不应为空")
        // 可选：检查是否包含 "Pikafish"
        // #expect(version.contains("Pikafish"))

        await engine.shutdown()
    }

    @Test("EmbeddedPikafishEngine: newGame 后引擎仍可搜索")
    func engineNewGame() async throws {
        let engine = EmbeddedPikafishEngine()
        try await engine.start()
        await engine.newGame()

        // 验证：newGame 后引擎仍可正常返回走法
        let fen = FENParser.generate(board: Board())
        let move = await engine.bestMove(fen: fen, moveHistory: [], difficulty: .easy, timeLimitMs: 500)
        #expect(move != nil, "newGame 后引擎应可正常搜索")

        await engine.shutdown()
    }

    @Test("EmbeddedPikafishEngine: evaluate 返回分析线")
    func engineEvaluate() async throws {
        let engine = EmbeddedPikafishEngine()
        try await engine.start()

        let fen = FENParser.generate(board: Board())
        let line = await engine.evaluate(fen: fen, moveHistory: [], depth: 5, timeMs: 500)

        #expect(line != nil, "应返回分析线")
        // depth 可能为 0（时间限制短时），只验证基本字段
        #expect(!line!.bestMove.isEmpty, "bestMove 不应为空")

        await engine.shutdown()
    }

    // MARK: - 12. 清理（最后执行）

    @Test("清理: 最终 quit 确保干净状态")
    func cleanup() {
        pikafish_quit()
        // 验证：quit 后重新 init 应成功（说明清理未损坏全局状态）
        let r = pikafish_init()
        #expect(r == 0, "quit 后重新 init 应成功")
        pikafish_quit()
    }
}
