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
    nonisolated let engineType: EngineType = .external
    private(set) var isReady = false
    private var cachedVersion: String = "unknown"

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

    func shutdown() {
        guard isReady else { return }
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

        // 在 DispatchQueue.global() 执行阻塞调用，避免占用 cooperative pool
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var buffer = [CChar](repeating: 0, count: 32)  // 32 bytes，足够容纳 UCI 走法
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
                    // 正常完成
                    let move = String(cString: buffer)
                    continuation.resume(returning: move.isEmpty ? nil : move)
                case -1:
                    // 搜索被中断，返回截至中断时的最佳走法
                    let move = String(cString: buffer)
                    continuation.resume(returning: move.isEmpty ? nil : move)
                default:
                    // 参数错误或其他失败
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 立即停止搜索（原子操作，线程安全，可从任意线程调用）
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

    /// Map AIDifficulty to pikafish search parameters (depth + time)
    ///
    /// Design:
    /// - Depth controls search strength (lower depth = weaker play)
    /// - Time limit acts as a safety cap to prevent long thinking
    /// - If user specifies timeLimitMs > 0, it overrides difficulty-based time
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
            depth = 8
            defaultTimeMs = 2000
        case .hard:
            depth = 12
            defaultTimeMs = 3000
        case .master:
            depth = 18
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