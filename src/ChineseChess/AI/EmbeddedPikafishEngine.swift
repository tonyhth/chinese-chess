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
    nonisolated let engineType: EngineType = .external
    // nonisolated(unsafe): 只在 actor 方法内写入，deinit 时无并发访问
    nonisolated(unsafe) private(set) var isReady = false
    private var cachedVersion: String = "unknown"

    // 在途搜索计数（actor 上下文内安全操作）
    private var activeSearchCount = 0

    // MARK: - Lifecycle

    func start() async throws {
        guard !isReady else { return }

        let result = pikafish_init()

        if result != 0 {
            throw EngineError.startFailed
        }

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
        if isReady {
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
            DispatchQueue.global(qos: .userInitiated).async {
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

    func stopSearch() {
        pikafish_stop()
    }

    func newGame() {
        pikafish_new_game()
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

    // MARK: - Difficulty Mapping
    
    /// Map AIDifficulty to search depth
    /// Depth controls search strength: lower depth = weaker play
    private func mapDifficulty(_ difficulty: AIDifficulty, timeLimitMs: Int) -> (depth: Int, timeMs: Int) {
        let depth: Int
        let defaultTimeMs: Int

        switch difficulty {
        case .beginner:
            depth = 2
            defaultTimeMs = 500
        case .easy:
            depth = 5
            defaultTimeMs = 1000
        case .medium:
            depth = 10
            defaultTimeMs = 2000
        case .hard:
            depth = 18
            defaultTimeMs = 3000
        case .master:
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