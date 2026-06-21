import Foundation

// MARK: - 引擎路由器

/// 根据用户设置返回合适的引擎实例
/// v3.1 Phase 2a: 仅 native 路径，Phase 2c 补充 external 切换
final class EngineRouter {
    static let shared = EngineRouter()

    private let nativeEngine = AIEngine()

    #if os(macOS)
    private var externalEngine: (any ChessEngine)?
    private var currentConfigId: UUID?
    #endif

    private init() {}

    /// 获取当前活跃引擎（无副作用，只返回已有实例）
    func activeEngine() -> any ChessEngine {
        #if os(macOS)
        if let ext = externalEngine {
            return ext
        }
        #endif
        return nativeEngine
    }

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
