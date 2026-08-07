// EngineConfigStore.swift - 引擎配置管理器（简化版）
//
//  Phase C: v3.4.0 macOS Static Embed - 统一 iOS/macOS，简化为布尔开关
//  只保留 useEmbeddedEngine，删除外部进程配置管理

import Foundation

/// 引擎配置管理器（单例）
/// 管理 UserDefaults 持久化的引擎选择（嵌入式 vs 内置）
@MainActor
@Observable
final class EngineConfigStore {
    static let shared = EngineConfigStore()

    /// 是否使用嵌入式 Pikafish 引擎（vs 自研内置引擎）
    var useEmbeddedEngine: Bool {
        didSet {
            UserDefaults.standard.set(useEmbeddedEngine, forKey: "chinesechess.useEmbeddedEngine")
        }
    }

    private init() {
        // v5.5.9: 默认使用嵌入式 Pikafish 引擎
        let key = "chinesechess.useEmbeddedEngine"
        if UserDefaults.standard.object(forKey: key) == nil {
            // 首次安装：默认开启
            useEmbeddedEngine = true
            UserDefaults.standard.set(true, forKey: key)
        } else {
            useEmbeddedEngine = UserDefaults.standard.bool(forKey: key)
        }
        migrateLegacyConfig()
    }

    /// 迁移旧 UserDefaults 数据
    /// 清理外部进程方案的旧配置 key
    private func migrateLegacyConfig() {
        let defaults = UserDefaults.standard
        let legacyKeys = [
            "chinesechess.externalEngines",
            "chinesechess.selectedEngine",
            "chinesechess.pendingEngine",
            "chinesechess.pendingNative",
            "chinesechess.wantsExternalEngine"
        ]
        for key in legacyKeys {
            if defaults.object(forKey: key) != nil {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// 快速切换内置/嵌入式引擎
    /// - Returns: 切换后的引擎类型名称，用于 Toast 提示
    func quickToggleEngine() -> String {
        if useEmbeddedEngine {
            useEmbeddedEngine = false
            return "builtIn"
        } else {
            useEmbeddedEngine = true
            return "external"
        }
    }
}