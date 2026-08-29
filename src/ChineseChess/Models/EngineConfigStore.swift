// EngineConfigStore.swift - 引擎配置管理器（v6.3 E5 简化版）
//
//  v6.3 E5: 引擎开关全清退场——双引擎按难度自动路由（业余 1-5 自研 /
//  专业 6-10 Pikafish），无用户切换面。本类仅保留旧配置迁移清理（防脏 key 复活）。

import Foundation

/// 引擎配置管理器（单例，v6.3 后仅承担旧配置迁移清理）
@MainActor
@Observable
final class EngineConfigStore {
    static let shared = EngineConfigStore()

    private init() {
        migrateLegacyConfig()
    }

    /// 迁移旧 UserDefaults 数据
    /// v6.3 E5: （E5 退场 key） 并入旧 key 清理（开关退场）
    private func migrateLegacyConfig() {
        let defaults = UserDefaults.standard
        let legacyKeys = [
            "chinesechess.useEmbeddedEngine",
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
}