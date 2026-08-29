// EngineRouter.swift - 引擎路由器（v6.0 统一版）
//
//  Phase C: v3.4.0 macOS Static Embed - 统一 iOS/macOS，删除外部进程分支
//  Phase 3: v6.0 按难度路由（业余级→自研，专业级→Pikafish）+ 三层 Fallback

import Foundation

/// 引擎可用性检查结果
enum EngineAvailability: Equatable {
    case available
    case unavailable(reason: EngineUnavailableReason)
}

enum EngineUnavailableReason: Equatable {
    case engineNotReady     // Pikafish 未启动或初始化失败
    case engineFailed       // Pikafish 中途崩溃
}

/// 根据用户设置和难度返回合适的引擎实例
/// v6.0: 按难度自动路由——业余级（1-5）→自研，专业级（6-10）→Pikafish
@MainActor
final class EngineRouter {
    static let shared = EngineRouter()

    /// 外部引擎启动失败时发送此通知，UI 层可观察并弹 alert
    static let fallbackNotification = Notification.Name("engineRouter.fallback")

    private let nativeEngine = AIEngine()
    private var embeddedEngine: EmbeddedPikafishEngine?
    /// 启动 in-flight 单飞（Ruby P1 消项：start 挂起点重入会双实例并发 start，
    /// 落败实例 deinit 防御 quit 杀全局 C 引擎→存活方假活）
    private var embeddedStartTask: Task<EmbeddedPikafishEngine?, Never>?

    private init() {}

    // MARK: - v6.3 E3: 全仓唯一合法构造点

    /// 统一构造/获取入口——所有需要 EmbeddedPikafishEngine 的调用面必须经此，
    /// 禁止旁路 `EmbeddedPikafishEngine()` 直构（旁路绕过单例+可用性检查+降级，
    /// PA-1/红二/红五同根形态）。启动失败返回 nil，调用方走层 2 native fallback。
    func acquireEmbeddedEngine() async -> EmbeddedPikafishEngine? {
        if let emb = embeddedEngine, emb.isReady {
            return emb
        }
        // P1 修复：首启期间后续重入调用 await 同一 in-flight Task（单飞），
        // 物理消除双实例并发 start + 落败 deinit quit 假活竞态
        if let inflight = embeddedStartTask {
            return await inflight.value
        }
        let task = Task<EmbeddedPikafishEngine?, Never> { [weak self] in
            guard let self else { return nil }
            let engine = EmbeddedPikafishEngine()
            do {
                try await engine.start()
                await MainActor.run { self.embeddedEngine = engine }
                return engine
            } catch {
                NSLog("[EngineRouter] acquireEmbeddedEngine: Pikafish start failed: \(error)")
                return nil
            }
        }
        embeddedStartTask = task
        let result = await task.value
        embeddedStartTask = nil
        return result
    }

    // MARK: - v6.0: 按难度路由

    /// 根据难度获取合适的引擎实例（核心路由方法）
    /// 业余级（1-5）→ 自研 AIEngine
    /// 专业级（6-10）→ EmbeddedPikafishEngine（需已启动；不可用时 native fallback）
    /// v6.3 E5: 引擎开关退场——专业级恒走 Pikafish（不可用降自研），
    /// 对账 ad9126b 守卫：开关不存在后守卫恒真，仅保留可用性 fallback
    func engineFor(difficulty: AIDifficulty) -> any ChessEngine {
        if difficulty.isProfessional {
            // 专业级需要 Pikafish（不可用时返回自研——调用方应先 validate）
            if let emb = embeddedEngine, emb.isReady {
                return emb
            }
            return nativeEngine
        }
        return nativeEngine
    }

    // MARK: - 层 1：启动检查（进入对弈前）

    /// 检查指定难度的引擎是否可用
    /// - 业余级：总是可用（自研引擎无需初始化）
    /// - 专业级：需要 Pikafish 已启动且就绪
    /// v6.3 E5: 开关退场，专业级恒校验 Pikafish 可用性
    func validateEngineAvailability(for difficulty: AIDifficulty) async -> EngineAvailability {
        guard difficulty.isProfessional else { return .available }

        // 确保 Pikafish 已启动
        if let emb = await acquireEmbeddedEngine(), emb.isReady {
            return .available
        }
        return .unavailable(reason: .engineNotReady)
    }

    // MARK: - 层 2：对弈中途异常处理

    /// Pikafish 中途不可用时的非静默 fallback
    func handleEngineFailure(difficulty: AIDifficulty) {
        let fallbackLevel = difficulty.fallbackToAmateur

        // 1. 发送用户通知（包含原始难度和 fallback 难度）
        NotificationCenter.default.post(
            name: Self.fallbackNotification,
            object: nil,
            userInfo: [
                "originalLevel": difficulty,
                "fallbackLevel": fallbackLevel,
            ]
        )

        // 2. 清理崩溃的 Pikafish 实例
        embeddedEngine = nil

        // 3. 记录错误日志
        NSLog("[EngineRouter] Engine failure: \(difficulty.rawValue) → fallback to \(fallbackLevel.rawValue)")
    }

    // MARK: - 兼容旧接口

    /// 获取当前活跃引擎（无副作用，只返回已有实例）
    func activeEngine() -> any ChessEngine {
        if let emb = embeddedEngine {
            return emb
        }
        return nativeEngine
    }

    /// 检查并执行引擎切换（如有必要）——在对局开始前调用
    /// v6.0: 根据难度和 引擎开关路由
    /// - Returns: 切换后的活跃引擎。启动失败时 fallback 到自研引擎。
    /// v6.3 E3/E5: 开关退场——统一经 acquireEmbeddedEngine 确保引擎就绪，
    /// 失败 → fallbackNotification + native fallback（层 2 降级）
    func switchEngineIfNeeded() async -> any ChessEngine {
        if let engine = await acquireEmbeddedEngine() {
            return engine
        }
        NSLog("[EngineRouter] Embedded pikafish failed to start, falling back to native")
        // 通知 UI 层引擎启动失败已 fallback
        NotificationCenter.default.post(name: Self.fallbackNotification, object: nil)
        return nativeEngine
    }

    /// 获取自研引擎（直接访问，不受路由影响）
    func getNativeEngine() -> AIEngine { nativeEngine }

    /// 获取嵌入式引擎（如果已启动）
    func getEmbeddedEngine() -> EmbeddedPikafishEngine? { embeddedEngine }

    /// 通知引擎开始新对局
    func newGame() {
        Task { await nativeEngine.newGame() }
        if let emb = embeddedEngine {
            Task { await emb.newGame() }
        }
    }

    /// 关闭所有引擎（App 退出时调用）
    func shutdown() async {
        if let emb = embeddedEngine {
            await emb.shutdown()
            embeddedEngine = nil
        }
    }

    /// 主线程同步紧急关闭（用于 applicationWillTerminate，不能 await）
    nonisolated func emergencyShutdown() {
        MainActor.assumeIsolated {
            if let emb = embeddedEngine {
                emb.emergencyShutdown()
                embeddedEngine = nil
            }
        }
    }
}
