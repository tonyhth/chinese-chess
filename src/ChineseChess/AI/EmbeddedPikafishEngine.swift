// EmbeddedPikafishEngine.swift - Swift actor directly calling C API
//
//  Implements ChessEngine protocol for iOS/macOS using embedded pikafish engine.
//  Phase B: v3.4.0 macOS Static Embed - unified iOS/macOS, direct C API calls

import Foundation
import CryptoKit
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
    // - StatusBarView/ToolbarView （原开关判断已退场），不依赖 engineType
    nonisolated let engineType: EngineType = .embedded
    // nonisolated(unsafe): 只在 actor 方法内写入，deinit 时无并发访问
    nonisolated(unsafe) private(set) var isReady = false
    private var cachedVersion: String = "unknown"

    // 在途搜索计数（actor 上下文内安全操作）
    // ⚠️ Ruby P2①语义声明：watchdog 超时路径提前 defer 递减，而 C 搜索仍在途——
    // 此计数语义为「已认领调用」（非「C 层在途」）。shutdown() 因此可能看到 0 后 quit，
    // 安全依赖 C 层 quit 自带 stop+CV 等待（pikafish_api.cpp:334 起，不 UAF），仅存在
    // 「quit 等 stray 搜索」的时长放大，无正确性风险。如需真在途计数，另立 cApi 层计数器。
    private var activeSearchCount = 0

    // 校准 v3.0: 记录外部手动设置的 Skill Level，用于 bestMove 判断是否强制 depth=0
    private var lastSkillOverride: Int? = nil

    // C API 调用专用串行队列——保证同一时间只有一个线程进入 C 层
    // actor 的 withCheckedContinuation 在 suspend 点释放锁，DispatchQueue.global() 会导致
    // evaluate 和 bestMove 并发进入 C 层全局单例 g_engine。串行队列物理上阻止并发。
    private nonisolated let cApiQueue = DispatchQueue(label: "com.chinesechess.pikafish.capi")

    // MARK: - v6.3 E2: watchdog 硬超时统一口径
    // 全调用点（bestMove/evaluate/multiPV）统一 15s 硬帽；超时 resume(nil) 走层 2 降级。
    // nonisolated(unsafe)：默认值不可变语义，仅测试（串行 suite）注入短帽验证超时路径。
    nonisolated(unsafe) static var watchdogHardCapMs: Int = 15_000

    /// 一次性 resume 守卫（NSLock 保护，跨 detached task 竞速）
    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if resumed { return false }
            resumed = true
            return true
        }
    }

    /// watchdog 超时后中止在途 C 搜索——否则残留搜索继续占 cApiQueue，
    /// 连坐后续调用（指纹③复现：前一调用残留 8s 占队列，后一 bestMove 5s 超时 →nil，红二/红五同形）
    private nonisolated static func abortInFlightSearch() {
        pikafish_stop()
    }

    /// 通用 watchdog：body 与定时器竞速，先到先 resume（超时 nil + 中止在途搜索）。
    /// ⚠️ body 必须跑在 detached task（非子任务）——withTaskGroup 超时路径会隐式等
    /// 不可取消的 C 调用跑完，兜底形同虚设（指纹②复现修正：原实现超时后仍等 8s）。
    /// C 调用不可中断会继续占 cApiQueue，但调用方即刻拿到降级值（72571fb 先例，扩全调用点）。
    /// ⚠️ Ruby P2②stray-stop 窗口声明：timer claim 后至 stop() 生效间，若目标 C 调用恰好
    /// 返回且下一个搜索已在 cApiQueue 开跑，stop 会误杀无戁1搜索（受方 →nil 降级自愈）。
    /// 窗口 µs 级，且 C 层 g_stopping 每次 go 起跑重置（:244），不残留毒化。备档知悉。
    private func withWatchdog<T: Sendable>(
        budgetMs: Int,
        body: @escaping @Sendable () async -> T?
    ) async -> T? {
        let once = ResumeOnce()
        return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            Task.detached {
                let result = await body()
                if once.claim() { continuation.resume(returning: result) }
            }
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(budgetMs) * 1_000_000)
                if once.claim() {
                    Self.abortInFlightSearch()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - v6.3 E1: NNUE 资产前置校验（期望值引 asset-manifest.json 单源）

    struct NNUEAssetExpectation: Codable {
        let name: String
        let bytes: Int
        let sha256: String
    }

    private struct AssetManifest: Codable {
        struct Entry: Codable { let name: String; let bytes: Int; let sha256: String }
        let version: Int
        let assets: [Entry]
    }

    /// E1 校验结果（测试/诊断消费）
    enum NNUEAssetCheck: Equatable {
        case ok(bytes: Int)
        case failed(reason: String)
    }

    /// Ruby P2④：sha256 快路径缓存——同文件（路径+大小+mtime）进程内只算一次全量哈希，
    /// 后续 start()（预热/回前台反复调）秒回；任一特征变化即重算全量
    private static let nnueVerifyCacheLock = NSLock()
    private nonisolated(unsafe) static var nnueVerifyCache: (path: String, size: Int, mtime: TimeInterval, verified: Bool)?

    /// 校验 bundle 内 pikafish.nnue 与 manifest 单源（大小+sha256）一致。
    /// 任一不符 → .failed → start() 抛错 → EngineRouter 层 2 降级自研（不挂死不空转）。
    nonisolated static func verifyNNUEAsset() -> NNUEAssetCheck {
        // 宿主 bundle 定位（xctest 下 main bundle 是 xctest runner，优先 app bundle——对齐 C 层口径）
        let bundle = Bundle(identifier: "com.chinesechess.app") ?? .main
        guard let nnueURL = bundle.url(forResource: "pikafish", withExtension: "nnue")
            ?? Bundle.main.url(forResource: "pikafish", withExtension: "nnue") else {
            return .failed(reason: "pikafish.nnue missing in bundle")
        }
        guard let manifestURL = bundle.url(forResource: "asset-manifest", withExtension: "json")
            ?? Bundle.main.url(forResource: "asset-manifest", withExtension: "json") else {
            return .failed(reason: "asset-manifest.json missing in bundle")
        }
        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(AssetManifest.self, from: data)
            guard let entry = manifest.assets.first(where: { $0.name == "pikafish.nnue" }) else {
                return .failed(reason: "manifest has no pikafish.nnue entry")
            }
            let attrs = try FileManager.default.attributesOfItem(atPath: nnueURL.path)
            let size = attrs[.size] as? Int ?? -1
            guard size == entry.bytes else {
                return .failed(reason: "nnue size mismatch: bundle=\(size) manifest=\(entry.bytes)")
            }
            let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            // P2④快路径：特征命中且已验证过 → 跳过 50MB sha256（~0.3-1s）
            nnueVerifyCacheLock.lock()
            let cached = nnueVerifyCache
            nnueVerifyCacheLock.unlock()
            if let c = cached, c.path == nnueURL.path, c.size == size, c.mtime == mtime, c.verified {
                return .ok(bytes: size)
            }
            let hash = try sha256Hex(fileURL: nnueURL)
            guard hash == entry.sha256 else {
                nnueVerifyCacheLock.lock()
                nnueVerifyCache = nil
                nnueVerifyCacheLock.unlock()
                return .failed(reason: "nnue sha256 mismatch: bundle=\(hash) manifest=\(entry.sha256)")
            }
            nnueVerifyCacheLock.lock()
            nnueVerifyCache = (nnueURL.path, size, mtime, true)
            nnueVerifyCacheLock.unlock()
            return .ok(bytes: size)
        } catch {
            return .failed(reason: "manifest read/decode error: \(error)")
        }
    }

    private nonisolated static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Lifecycle

    func start() async throws {
        guard !isReady else { return }

        // v6.3 E1: NNUE 资产前置校验（manifest 单源）——缺失/损坏即抛错走层 2 降级，
        // 不再让 C 层静默 nil-fail（拔 nnue 冷启动 → 启动即标注不可用）
        switch Self.verifyNNUEAsset() {
        case .ok:
            break
        case .failed(let reason):
            NSLog("[Pikafish] E1 nnue asset check failed: \(reason)")
            throw EngineError.startFailed
        }

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

        // v6.0: 专业级设置 Skill Level（UCI 选项）
        // pfmatch 模式下用 skillLevelOverride 覆盖
        if let skill = difficulty.skillLevel {
            setSkillLevel(skill)
        }

        let (mappedDepth, timeMs) = mapDifficulty(difficulty, timeLimitMs: timeLimitMs)
        // 校准 v3.0: 当有外部 skillOverride 时，强制 depth=0（无限制搜索）
        // 让 Skill Level 全权控制棋力，避免 mapDifficulty 的 depth 覆盖 pick_best 机制
        let depth = (lastSkillOverride != nil && difficulty.skillLevel == nil) ? 0 : mappedDepth
        let movesStr = moveHistory.joined(separator: " ")

        // 标记搜索开始（actor 上下文，安全）
        activeSearchCount += 1
        defer { activeSearchCount -= 1 }

        // v6.3 E2: watchdog 统一 15s 硬帽（soft budget = timeMs+2s 先行降级，封顶 hard cap）
        let hardCap = Self.watchdogHardCapMs
        let budgetMs = min(timeMs + 2000, hardCap)
        return await withWatchdog(budgetMs: budgetMs) {
            await self.cApiBestMove(fen: fen, movesStr: movesStr, depth: depth, timeMs: timeMs)
        }
    }

    /// C 层 best_move 调用（保持原“闭包不捕获 self”约定：闭包体只引用局部值类型）
    private nonisolated func cApiBestMove(fen: String, movesStr: String, depth: Int, timeMs: Int) async -> String? {
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
        // 校准 v3.0: 清除 skill override，避免跨局污染
        lastSkillOverride = nil
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

    // MARK: - v6.0: Skill Level 设置

    /// 设置 Pikafish Skill Level（UCI 选项）
    /// Skill Level 0-20，控制引擎棋力（完整搜索后按概率选劣变）
    func setSkillLevel(_ skill: Int) {
        guard isReady else {
            NSLog("[Pikafish] setSkillLevel(\(skill)) called before engine ready — ignored")
            return
        }
        lastSkillOverride = skill
        let result = pikafish_set_option("Skill Level", String(skill))
        if result == 0 {
            NSLog("[Pikafish] Skill Level set to \(skill)")
        } else {
            NSLog("[Pikafish] ⚠️ Failed to set Skill Level to \(skill) (result=\(result))")
        }
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

        // v6.3 E2: evaluate 补 watchdog（原仅 bestMove 有）——soft=timeMs+2s，封顶 15s 硬帽
        //（Ruby P2③：直用 15s 帽会截断 movetime>13s 的合法自定义搜索，与 bestMove 口径归一；
        //  Ruby 复审④：timeMs<=0 视为「不限时深搜」→ 归 hardCap，防 0+2s 静默截断语义）
        let evalBudgetMs = timeMs > 0 ? min(timeMs + 2000, Self.watchdogHardCapMs) : Self.watchdogHardCapMs
        return await withWatchdog(budgetMs: evalBudgetMs) {
            await self.cApiEvaluate(fen: fen, movesStr: movesStr, depth: depth, timeMs: timeMs)
        }
    }

    /// C 层单 PV 评估（原 evaluate 内联体，拆出供 watchdog 包裹）
    private nonisolated func cApiEvaluate(fen: String, movesStr: String, depth: Int, timeMs: Int) async -> AnalysisLine? {
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

        // v6.3 E2: multiPV 补 watchdog（原仅 bestMove 有）——soft=timeMs+2s，封顶 15s 硬帽
        //（P2③归一；Ruby 复审④：timeMs<=0 归 hardCap，防 0+2s 静默截断「不限时」语义）
        let mpvBudgetMs = timeMs > 0 ? min(timeMs + 2000, Self.watchdogHardCapMs) : Self.watchdogHardCapMs
        let result: [AnalysisLine]? = await withWatchdog(budgetMs: mpvBudgetMs) {
            await self.cApiMultiPV(fen: fen, movesStr: movesStr, count: count, depth: depth, timeMs: timeMs)
        }
        return result ?? []
    }

    /// C 层多 PV 评估（原 multiPV 内联体，拆出供 watchdog 包裹）
    private nonisolated func cApiMultiPV(fen: String, movesStr: String, count: Int, depth: Int, timeMs: Int) async -> [AnalysisLine]? {
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
    
    /// Map AIDifficulty to search depth + time
    /// 业余级（1-5）：depth 控制
    /// 专业级（6-10）：不限制 depth（Skill Level 全权控制棋力），只用 movetime
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
        case .amateurDan:
            // v6.0: Skill Level 5，不限制 depth（0=无限）
            depth = 0
            defaultTimeMs = 5000
        case .proApprentice:
            // v6.0: Skill Level 8
            depth = 0
            defaultTimeMs = 6000
        case .proExpert:
            // v6.0: Skill Level 12
            depth = 0
            defaultTimeMs = 7000
        case .proMaster:
            // v6.0: Skill Level 16
            depth = 0
            defaultTimeMs = 8000
        case .grandmaster:
            // v6.0: Skill Level 20
            depth = 0
            defaultTimeMs = 10000
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