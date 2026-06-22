import Foundation

// MARK: - 引擎路由器

/// 根据用户设置返回合适的引擎实例
/// v3.1 Phase 2a: 仅 native 路径，Phase 2c 补充 external 切换
final class EngineRouter {
    static let shared = EngineRouter()

    /// P1-2: 外部引擎启动失败时发送此通知，UI 层可观察并弹 alert
    static let fallbackNotification = Notification.Name("engineRouter.fallback")

    private let nativeEngine = AIEngine()

    #if os(macOS)
    private var externalEngine: (any ChessEngine)?
    private var currentConfigId: UUID?
    #endif

    private init() {}

    /// 获取当前活跃引擎（无副作用，只返回已有实例）
    @MainActor
    func activeEngine() -> any ChessEngine {
        #if os(macOS)
        if let ext = externalEngine {
            return ext
        }
        #endif
        return nativeEngine
    }

    #if os(macOS)
    /// 检查并执行引擎切换（如有必要）——在对局开始前调用
    /// - Returns: 切换后的活跃引擎。启动失败时 fallback 到自研引擎。
    @MainActor
    func switchEngineIfNeeded() async -> any ChessEngine {
        let store = EngineConfigStore.shared

        if let selectedId = store.selectedEngineId,
           let config = store.engines.first(where: { $0.id == selectedId }),
           config.isEnabled {
            // 配置没变，引擎已存在——无需切换
            if currentConfigId == config.id {
                return externalEngine ?? nativeEngine
            }
            // 配置变更——重新创建并启动
            if let ext = externalEngine {
                await ext.shutdown()
            }
            let newEngine = ExternalEngineManager(config: config)
            do {
                try await newEngine.start()
                externalEngine = newEngine
                currentConfigId = config.id
                return newEngine
            } catch {
                // 启动失败——fallback
                externalEngine = nil
                currentConfigId = nil
                // P1-2: 通知 UI 层引擎启动失败已 fallback
                NotificationCenter.default.post(name: Self.fallbackNotification, object: nil)
                return nativeEngine
            }
        } else {
            // 使用自研引擎——清理外部引擎
            if let ext = externalEngine {
                await ext.shutdown()
                externalEngine = nil
                currentConfigId = nil
            }
            return nativeEngine
        }
    }
    #endif

    /// 获取自研引擎（直接访问，不受路由影响）
    var native: AIEngine { nativeEngine }

    /// 通知引擎开始新对局
    func newGame() {
        nativeEngine.newGame()
        #if os(macOS)
        if let ext = externalEngine {
            Task { await ext.newGame() }
        }
        #endif
    }

    /// 关闭所有引擎（App 退出时调用）
    func shutdown() {
        #if os(macOS)
        if let ext = externalEngine {
            Task { await ext.shutdown() }
            externalEngine = nil
            currentConfigId = nil
        }
        #endif
    }
}
