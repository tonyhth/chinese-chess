// EngineRouter.swift - 引擎路由器（统一版）
//
//  Phase C: v3.4.0 macOS Static Embed - 统一 iOS/macOS，删除外部进程分支
//  只使用 EmbeddedPikafishEngine 或 native AIEngine

import Foundation

/// 根据用户设置返回合适的引擎实例
/// v3.4.0: 统一 iOS/macOS，嵌入式 Pikafish ↔ 自研引擎
@MainActor
final class EngineRouter {
    static let shared = EngineRouter()

    /// 外部引擎启动失败时发送此通知，UI 层可观察并弹 alert
    static let fallbackNotification = Notification.Name("engineRouter.fallback")

    private let nativeEngine = AIEngine()
    private var embeddedEngine: EmbeddedPikafishEngine?

    private init() {}

    /// 获取当前活跃引擎（无副作用，只返回已有实例）
    func activeEngine() -> any ChessEngine {
        if let emb = embeddedEngine {
            return emb
        }
        return nativeEngine
    }

    /// 检查并执行引擎切换（如有必要）——在对局开始前调用
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
    nonisolated var native: AIEngine { nativeEngine }

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
    /// 直接调 C API，不走 actor isolation
    nonisolated func emergencyShutdown() {
        // MainActor 同步访问：applicationWillTerminate 在主线程
        MainActor.assumeIsolated {
            if let emb = embeddedEngine {
                emb.emergencyShutdown()
                embeddedEngine = nil
            }
        }
    }
}
