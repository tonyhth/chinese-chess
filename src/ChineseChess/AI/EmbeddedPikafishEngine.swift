// EmbeddedPikafishEngine.swift - Swift actor directly calling C API
//
//  Implements ChessEngine protocol for iOS/macOS using embedded pikafish engine.
//  Phase B: v3.4.0 macOS Static Embed - unified iOS/macOS, direct C API calls

import Foundation
import Pikafish  // 通过 modulemap 导入 C API（iOS + macOS 统一）

/// Swift actor that directly calls pikafish C API to implement ChessEngine protocol.
///
/// Thread safety:
/// - Actor isolation ensures all state access is serialized
/// - bestMove runs on DispatchQueue.global() to avoid blocking cooperative pool
/// - stopSearch() is non-blocking, thread-safe C call
actor EmbeddedPikafishEngine: ChessEngine {
    nonisolated let displayName: String = "Pikafish"
    // .external 表示非自研引擎。嵌入式 Pikafish 复用此值：
    // - 与 .native（自研 AIEngine）区分
    // - StatusBarView/ToolbarView 用 useEmbeddedEngine 判断 UI 显示，不依赖 engineType
    nonisolated let engineType: EngineType = .embedded
    // nonisolated(unsafe): 只在 actor 方法内写入，deinit 时无并发访问
    nonisolated(unsafe) private(set) var isReady = false
    private var cachedVersion: String = "unknown"

    // 在途搜索计数（actor 上下文内安全操作）
    private var activeSearchCount = 0

    // C API 调用专用串行队列——保证同一时间只有一个线程进入 C 层
    // actor 的 withCheckedContinuation 在 suspend 点释放锁，DispatchQueue.global() 会导致
    // evaluate 和 bestMove 并发进入 C 层全局单例 g_engine。串行队列物理上阻止并发。
    private nonisolated let cApiQueue = DispatchQueue(label: "com.chinesechess.pikafish.capi")

    // MARK: - Lifecycle

    func start() async throws {
        guard !isReady else { return }

        #if os(iOS)
        // 诊断：检查 NNUE 文件是否在 bundle 中
        if let nnueURL = Bundle.main.url(forResource: "pikafish", withExtension: "nnue") {
            NSLog("[Pikafish] NNUE found at: \(nnueURL.path)")
        } else {
            NSLog("[Pikafish] ⚠️ NNUE file NOT found in Bundle.main!")
            NSLog("[Pikafish] Bundle.main bundlePath: \(Bundle.main.bundlePath)")
            NSLog("[Pikafish] Bundle.main bundleId: \(Bundle.main.bundleIdentifier ?? "nil")")
            // 列出 bundle resources
            if let resURL = Bundle.main.resourceURL,
               let files = try? FileManager.default.contentsOfDirectory(atPath: resURL.path) {
                let nnueFiles = files.filter { $0.contains("nnue") || $0.contains("pikafish") }
                NSLog("[Pikafish] Related files in resources: \(nnueFiles)")
            }
        }
        #endif

        let result = pikafish_init()

        if result != 0 {
            NSLog("[Pikafish] pikafish_init() returned \(result) — NNUE load failed")
            throw EngineError.startFailed
        }
        NSLog("[Pikafish] pikafish_init() success, version: \(cachedVersion ?? "unknown")")

        // 缓存引擎版本（start 后 C API 数据已就绪）
        if let v = pikafish_get_info() {
            cachedVersion = String(cString: v)
        }

        configureTTSize()
        isReady = true
    }

    /// 安全关闭：先 stop 在途搜索，等待搜索完成，再 quit
    func shutdown() async {
        guard isReady else { return }

        // 1. 请求停止所有在途搜索（C API: volatile flag, 线程安全, non-blocking）
        pikafish_stop()

        // 2. 等待在途搜索完成（50ms 轮询，2秒超时）
        let maxWait: Duration = .seconds(2)
        let deadline = ContinuousClock.now + maxWait
        while activeSearchCount > 0 && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        if activeSearchCount > 0 {
            // 超时不 quit——让 OS 在进程退出时回收（比 UAF 安全）
            NSLog("[EmbeddedPikafishEngine] WARNING: \(activeSearchCount) search(es) still active after 2s timeout, skipping quit to avoid UAF")
            isReady = false
            return
        }

        // 3. 所有搜索已结束，安全 quit
        pikafish_quit()
        isReady = false
    }

    deinit {
        // 防御性兜底：正常路径应通过 async shutdown() 完成
        // 如果走到这里且有在途搜索，quit 仍有 UAF 风险，但比泄漏好
        if isReady {
            pikafish_stop()
            NSLog("[EmbeddedPikafishEngine] deinit: defensive pikafish_stop()+quit() (should have called shutdown() first)")
            pikafish_quit()
        }
    }

    // MARK: - ChessEngine

    func bestMove(
        fen: String,
        moveHistory: [String],
        difficulty: AIDifficulty,
        timeLimitMs: Int
    ) async -> String? {
        guard isReady else {
            NSLog("[EmbeddedPikafishEngine] bestMove called before start(), returning nil")
            return nil
        }

        let (depth, timeMs) = mapDifficulty(difficulty, timeLimitMs: timeLimitMs)
        let movesStr = moveHistory.joined(separator: " ")

        // 标记搜索开始（actor 上下文，安全）
        activeSearchCount += 1
        defer { activeSearchCount -= 1 }

        // 闭包不捕获 self，只捕获局部值类型（fen/movesStr/depth/timeMs/buffer）
        return await withCheckedContinuation { continuation in
            cApiQueue.async {
                var buffer = [CChar](repeating: 0, count: 64)
                let result = fen.withCString { fenCStr in
                    movesStr.withCString { movesCStr in
                        pikafish_best_move(
                            fenCStr, movesCStr,
                            Int32(depth), Int32(timeMs),
                            &buffer, Int32(buffer.count)
                        )
                    }
                }

                switch result {
                case 0:
                    let move = String(cString: buffer)
                    continuation.resume(returning: move.isEmpty ? nil : move)
                case -1:
                    let move = String(cString: buffer)
                    continuation.resume(returning: move.isEmpty ? nil : move)
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
        // withCheckedContinuation 返回后，defer 执行 activeSearchCount -= 1
    }

    /// 立即停止搜索（原子操作，线程安全，可从任意线程调用）
    /// Reserved for future cancellation support
    nonisolated func stopSearchImmediate() {
        pikafish_stop()
    }

    /// 紧急同步关闭：不走 actor isolation，用于 applicationWillTerminate 等
    /// 主线程阻塞场景。stop → 短暂等待 → quit。
    nonisolated func emergencyShutdown() {
        pikafish_stop()
        // 短暂等待让 stop flag 生效（比直接 quit 安全）
        Thread.sleep(forTimeInterval: 0.5)
        pikafish_quit()
        NSLog("[EmbeddedPikafishEngine] emergencyShutdown() completed")
    }

    func stopSearch() {
        pikafish_stop()
    }

    func newGame() {
        // v4.1 Bug 1 fix: 通过 cApiQueue 串行化，避免与正在进行的 bestMove/evaluate 并发
        // pikafish_new_game() 如果与 pikafish_best_move 并发执行，会导致 C 引擎内部状态混乱
        cApiQueue.sync {
            pikafish_new_game()
        }
    }

    var version: String { cachedVersion }

    // MARK: - Configuration

    private func configureTTSize() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let ttSizeMB: Int

        #if os(iOS)
        // iOS：保守策略（后台内存压力更大）
        if physicalMemory < 2_000_000_000 {
            ttSizeMB = 16
        } else if physicalMemory >= 4_000_000_000 {
            ttSizeMB = 64
        } else {
            ttSizeMB = 32
        }
        #else
        // macOS：基于物理内存的 10%，上限 256MB，下限 64MB
        let dynamicMB = Int(physicalMemory / 10 / 1_000_000)
        ttSizeMB = max(64, min(dynamicMB, 256))
        #endif

        let _ = pikafish_set_option("Hash", String(ttSizeMB))
    }

    // MARK: - Analysis (for PositionAnalyzer)

    /// 评估当前局面（单 PV）
    func evaluate(fen: String, moveHistory: [String], depth: Int, timeMs: Int) async -> AnalysisLine? {
        guard isReady else {
            NSLog("[EmbeddedPikafishEngine] evaluate called before start(), returning nil")
            return nil
        }

        let movesStr = moveHistory.joined(separator: " ")
        activeSearchCount += 1
        defer { activeSearchCount -= 1 }

        return await withCheckedContinuation { (continuation: CheckedContinuation<AnalysisLine?, Never>) in
            cApiQueue.async {
                let result = UnsafeMutablePointer<PikafishEvalResult>.allocate(capacity: 1)
                memset(result, 0, MemoryLayout<PikafishEvalResult>.size)
                defer { result.deallocate() }

                let ok = fen.withCString { fenCStr in
                    movesStr.withCString { movesCStr in
                        pikafish_eval(fenCStr, movesCStr, Int32(depth), Int32(timeMs), result)
                    }
                }

                if ok == 0 {
                    let bestMove = withUnsafePointer(to: result.pointee.best_move) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
                    }
                    let pv = withUnsafePointer(to: result.pointee.pv) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                    }
                    continuation.resume(returning: AnalysisLine(
                        scoreCp: Int(result.pointee.score_cp),
                        depth: Int(result.pointee.depth),
                        bestMove: bestMove,
                        pv: pv
                    ))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 获取多条候选走法（MultiPV）
    func multiPV(fen: String, moveHistory: [String], count: Int, depth: Int, timeMs: Int) async -> [AnalysisLine] {
        guard isReady else {
            NSLog("[EmbeddedPikafishEngine] multiPV called before start(), returning []")
            return []
        }

        let movesStr = moveHistory.joined(separator: " ")
        activeSearchCount += 1
        defer { activeSearchCount -= 1 }

        return await withCheckedContinuation { (continuation: CheckedContinuation<[AnalysisLine], Never>) in
            cApiQueue.async {
                let results = UnsafeMutablePointer<PikafishEvalResult>.allocate(capacity: count)
                memset(results, 0, MemoryLayout<PikafishEvalResult>.size * count)
                defer { results.deallocate() }

                let actualCount = fen.withCString { fenCStr in
                    movesStr.withCString { movesCStr in
                        pikafish_multi_pv(fenCStr, movesCStr, Int32(count), Int32(depth), Int32(timeMs), results, Int32(count))
                    }
                }

                var lines: [AnalysisLine] = []
                let safeCount = max(0, Int(actualCount))
                for i in 0..<safeCount {
                    let bestMove = withUnsafePointer(to: results[i].best_move) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
                    }
                    let pv = withUnsafePointer(to: results[i].pv) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                    }
                    lines.append(AnalysisLine(
                        scoreCp: Int(results[i].score_cp),
                        depth: Int(results[i].depth),
                        bestMove: bestMove,
                        pv: pv
                    ))
                }
                continuation.resume(returning: lines)
            }
        }
    }

    // MARK: - Difficulty Mapping
    
    /// Map AIDifficulty to search depth
    /// Depth controls search strength: lower depth = weaker play
    private func mapDifficulty(_ difficulty: AIDifficulty, timeLimitMs: Int) -> (depth: Int, timeMs: Int) {
        let depth: Int
        let defaultTimeMs: Int

        switch difficulty {
        case .novice:
            depth = 2
            defaultTimeMs = 500
        case .beginner:
            depth = 5
            defaultTimeMs = 1000
        case .amateurLow:
            depth = 10
            defaultTimeMs = 2000
        case .amateurMid:
            depth = 18
            defaultTimeMs = 3000
        case .amateurHigh:
            depth = 24
            defaultTimeMs = 5000
        default:
            // v6.0 Phase 2: 专业级用 Skill Level，不再走 depth 映射
            // 临时 fallback：当作 amateurHigh
            depth = 24
            defaultTimeMs = 5000
        }

        let timeMs = timeLimitMs > 0 ? timeLimitMs : defaultTimeMs
        return (depth, timeMs)
    }
}

// MARK: - Engine Error

enum EngineError: LocalizedError {
    case startFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "Failed to start pikafish engine (NNUE load error?)"
        }
    }
}