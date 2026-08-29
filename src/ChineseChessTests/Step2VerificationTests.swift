import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.3 Step 2 验证批（Tina，Luke 08-29 派单 E1/E2 专项）
//
// 设计说明：两 suite 须分开跑（runner 每 suite 独立进程）——
//  - Step2E2VerificationTests：需 nnue 在位（分析面 multiPV 超时降级，注入 800ms 硬帽）
//  - Step2E1ColdStartTests：运行时拔 nnue（rename）验证冷启动降级链，批内自恢复
// 同进程混跑会互相污染 Router 单例态与资产态。

private let appBundle = Bundle(identifier: "com.chinesechess.app") ?? .main

private func nnueURL() -> URL? {
    appBundle.url(forResource: "pikafish", withExtension: "nnue")
}
private func nnueBackupURL() -> URL? {
    nnueURL()?.deletingLastPathComponent().appendingPathComponent("pikafish.nnue.h1bak")
}

// ---------- E2：分析面 multiPV 超时降级（不挂死） ----------

@Suite("Step2 E2 分析面超时降级", .serialized)
struct Step2E2VerificationTests {

    static let startFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

    @Test("E2-复盘/分析路径: topMoves 长搜索注入 800ms 硬帽 → 硬帽附近返回，不挂死")
    func multiPVTimeoutDegrades() async throws {
        try #require(TestEnvPreflight.nnuePresent, "nnue 缺失——本套件需 nnue 在位")
        let saved = EmbeddedPikafishEngine.watchdogHardCapMs
        EmbeddedPikafishEngine.watchdogHardCapMs = 800
        defer { EmbeddedPikafishEngine.watchdogHardCapMs = saved }

        let t0 = Date()
        // 深度搜索（分析面 multiPV 链路，无显式 time 参数 → 走 hardCap 预算）
        let lines = await PositionAnalyzer.shared.topMoves(fen: Self.startFEN, moveHistory: [], count: 3)
        let elapsed = Date().timeIntervalSince(t0) * 1000
        print("E2_PROBE topMoves elapsed=\(Int(elapsed))ms lines=\(lines.count)")
        #expect(elapsed < 4_000, "watchdog 硬帽 800ms，实测 \(elapsed)ms 返回——超时降级未生效（挂死形态）")
    }
}

// ---------- E1：拔 nnue 冷启动 → 启动即标注不可用 + 层2降级链 ----------

@Suite("Step2 E1 拔nnue冷启动降级链", .serialized)
struct Step2E1ColdStartTests {

    /// defaults 域隔离（Luke 08-29 裁定：bundle id 共享 defaults 跨进程互踩防护）
    /// 批前快照 standard 域，批尾 E1-3 恢复——水套件经 Router/native 引擎路径
    /// 可能写入的 chinesechess.* 键不残留，不污染后续 Phase2cP1 等 defaults 敏感 suite。
    static var savedDefaultsSnapshot: [String: Any]?

    /// 残留自愈：上次异常中断留下的 .h1bak 先还原
    @Test("E1-0 残留自愈 + defaults 域快照")
    func restoreLeftover() throws {
        Step2E1ColdStartTests.savedDefaultsSnapshot = UserDefaults.standard.dictionaryRepresentation()
        guard let bak = nnueBackupURL(), let nnue = nnueURL() else {
            // nnue 缺失且存在 bak → 还原
            if let bak = try? FileManager.default.contentsOfDirectory(
                at: appBundle.resourceURL ?? appBundle.bundleURL,
                includingPropertiesForKeys: nil).first(where: { $0.lastPathComponent == "pikafish.nnue.h1bak" }) {
                try FileManager.default.moveItem(at: bak, to: bak.deletingLastPathComponent().appendingPathComponent("pikafish.nnue"))
            }
            return
        }
        if !FileManager.default.fileExists(atPath: nnue.path),
           FileManager.default.fileExists(atPath: bak.path) {
            try FileManager.default.moveItem(at: bak, to: nnue)
        }
        try #require(TestEnvPreflight.nnuePresent, "自愈后 nnue 应在位")
    }

    // 注：进程内无法伪造真冷启动（宿主 app 启动即预热引擎，nnue 在位时已 isReady）。
    // 本套件锢定单元面（资产校验 failed + start() 抛错）；
    // Router 降级链（标注不可用/降自研）由冷启动探针脚本验证：拷贝 .app → 拔 nnue → 直启二进制 → 取 syslog。
    // 观察项（合理）：预热后中途拔 nnue 不触发降级——资产校验是启动时点，非持续监控。
    @Test("E1-1 拔 nnue → verifyNNUEAsset 判 failed + start() 抛错（启动即拒，不静默 nil-fail）", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：环境破缺 skip"))
    @MainActor
    func coldStartDegradeChain() async throws {
        let nnue = try #require(nnueURL())
        let bak = try #require(nnueBackupURL())
        // 拔 nnue
        try FileManager.default.moveItem(at: nnue, to: bak)
        defer { // 批内自恢复（defer 兜底 + E1-2 显式复核）
            if !FileManager.default.fileExists(atPath: nnue.path),
               FileManager.default.fileExists(atPath: bak.path) {
                try? FileManager.default.moveItem(at: bak, to: nnue)
            }
        }

        // ① 资产校验判 failed
        guard case .failed = EmbeddedPikafishEngine.verifyNNUEAsset() else {
            Issue.record("拔 nnue 后 verifyNNUEAsset 应 failed")
            return
        }
        // ② start() 即抛错（不静默 nil-fail）
        do {
            try await EmbeddedPikafishEngine().start()
            Issue.record("拔 nnue 后 start() 应抛 EngineError.startFailed")
        } catch { /* 期望路径 */ }
        // ③ 真冷启动等价链：shutdown 清空单例态（模拟未预热冷启动）→ Router 层1标注不可用
        await EngineRouter.shared.shutdown()
        let avail = await EngineRouter.shared.validateEngineAvailability(for: .grandmaster)
        guard case .unavailable = avail else {
            Issue.record("拔 nnue 后冷启动 validateEngineAvailability(.grandmaster) 应 unavailable，实测 \(avail)")
            return
        }
        // ④ Router 路由降级：专业级拿到的不是 EmbeddedPikafishEngine
        let engine = await EngineRouter.shared.engineFor(difficulty: .grandmaster)
        #expect(!(engine is EmbeddedPikafishEngine), "降级链断：专业级仍返回 Pikafish 实例")
    }

    @Test("E1-2 恢复 nnue → 校验回 ok（自恢复复核）")
    func restoreAndVerifyOk() throws {
        if let bak = nnueBackupURL(), let nnue = nnueURL(),
           !FileManager.default.fileExists(atPath: nnue.path) {
            try FileManager.default.moveItem(at: bak, to: nnue)
        }
        guard case .ok = EmbeddedPikafishEngine.verifyNNUEAsset() else {
            Issue.record("恢复后 verifyNNUEAsset 应 ok")
            return
        }
    }

    @Test("E1-3 defaults 域隔离复核：standard 域无残留写入")
    func defaultsDomainClean() throws {
        let d = UserDefaults.standard
        // 引擎路径可能触碰的键族，批尾应为快照态（新增即残留）
        let engineKeys = ["chinesechess.externalEngines", "chinesechess.selectedEngine",
                          "chinesechess.pendingEngine", "chinesechess.pendingNative",
                          "chinesechess.wantsExternalEngine", "chinesechess.language"]
        let snap = Step2E1ColdStartTests.savedDefaultsSnapshot ?? [:]
        for k in engineKeys where snap[k] == nil {
            if d.object(forKey: k) != nil {
                d.removeObject(forKey: k)  // 隔离处置：清掉本套件引入的残留
                Issue.record("defaults 域残留写入：\(k)（已清理）")
            }
        }
    }
}
