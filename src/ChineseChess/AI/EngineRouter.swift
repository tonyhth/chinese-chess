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

    private init() {}

    // MARK: - v6.0: 按难度路由

    /// 根据难度获取合适的引擎实例（核心路由方法）
    /// 业余级（1-5）→ 自研 AIEngine
    /// 专业级（6-10）→ EmbeddedPikafishEngine（需已启动）
    /// v6.2 P1-①（选择↔显示同步审计）：开关守卫——useEmbeddedEngine=off 时专业级也走自研，
    /// 不再无视用户选择强拉 Pikafish（原实现“开关被绕过”，与 6/25 假切换 P0 同族）
    func engineFor(difficulty: AIDifficulty) -> any ChessEngine {
        if difficulty.isProfessional && EngineConfigStore.shared.useEmbeddedEngine {
            // 专业级需要 Pikafish（且用户开关允许）
            if let emb = embeddedEngine, emb.isReady {
                return emb
            }
            // Pikafish 不可用——返回自研（调用方应先 validate）
            return nativeEngine
        }
        return nativeEngine
    }

    // MARK: - 层 1：启动检查（进入对弈前）

    /// 检查指定难度的引擎是否可用
    /// - 业余级：总是可用（自研引擎无需初始化）
    /// - 专业级：需要 Pikafish 已启动且就绪
    /// v6.2 P1-①：开关 off 时专业级走自研（用户显式选择），视为可用，
    /// 不再为专业级无视开关强拉 Pikafish（原实现致实际引擎与状态栏显示失步）
    func validateEngineAvailability(for difficulty: AIDifficulty) async -> EngineAvailability {
        guard difficulty.isProfessional, EngineConfigStore.shared.useEmbeddedEngine else { return .available }

        // 确保 Pikafish 已启动
        if embeddedEngine == nil || !embeddedEngine!.isReady {
            // 尝试启动
            do {
                let engine = EmbeddedPikafishEngine()
                try await engine.start()
                embeddedEngine = engine
            } catch {
                NSLog("[EngineRouter] Pikafish start failed for professional level: \(error)")
                return .unavailable(reason: .engineNotReady)
            }
        }

        if let emb = embeddedEngine, emb.isReady {
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
    /// v6.0: 根据难度和 useEmbeddedEngine 开关路由
    /// - Returns: 切换后的活跃引擎。启动失败时 fallback 到自研引擎。
    func switchEngineIfNeeded() async -> any ChessEngine {
        let store = EngineConfigStore.shared

        if store.useEmbeddedEngine {
            if embeddedEngine == nil {
                let engine = EmbeddedPikafishEngine()
                do {
                    try await engine.start()
                    embeddedEngine = engine
                } catch {
                    // NNUE 加载失败或其他初始化错误——fallback
                    NSLog("[EngineRouter] Embedded pikafish failed to start, falling back to native")
                    embeddedEngine = nil
                    // 通知 UI 层引擎启动失败已 fallback
                    NotificationCenter.default.post(name: Self.fallbackNotification, object: nil)
                    return nativeEngine
                }
            }
            guard let engine = embeddedEngine else {
                return nativeEngine
            }
            return engine
        } else {
            // 使用自研引擎——清理嵌入式引擎
            if let emb = embeddedEngine {
                await emb.shutdown()
                embeddedEngine = nil
            }
            return nativeEngine
        }
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
