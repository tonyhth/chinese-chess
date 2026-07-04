import Foundation

/// UserDefaults 跨 Bundle ID 迁移管理器
///
/// 解决 v3.7.1 Bundle ID 偏离导致的用户偏好丢失问题。
/// 启动时从旧 Bundle ID 的 plist 文件读取偏好，迁移到当前 Bundle ID。
///
/// 采用全量 key 迁移策略：遍历旧 plist 中所有 `chinesechess.` 前缀的 key，
/// 不限于固定列表，避免遗漏未来新增的 key。
final class PreferencesMigration {

    // MARK: - 配置

    /// 迁移版本标记（自身不参与迁移）
    static let migrationFlagKey = "chinesechess.migrationDone_v1"

    /// 迁移 key 前缀：只迁移以此开头的 key
    static let keyPrefix = "chinesechess."

    /// 旧 Bundle ID 列表（按数据新鲜度排序，新的优先）
    static let legacyBundleIds: [String] = [
        "com.hth.ChineseChess",      // v3.7.1
        "com.hongtao.ChineseChess",  // 历史测试
    ]

    // MARK: - 公开接口

    /// 执行迁移（幂等）
    /// 在 ChineseChessApp.init() 中调用
    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        let homeDir = NSHomeDirectory()
        migrate(homeDir: homeDir, defaults: defaults)
    }

    // MARK: - 核心迁移逻辑（可测试入口）

    /// 执行迁移的核心逻辑
    /// - Parameters:
    ///   - homeDir: 用户主目录路径（用于定位 ~/Library/Preferences/）
    ///   - defaults: 目标 UserDefaults 实例
    /// - Returns: 实际迁移的 key 数量
    @discardableResult
    static func migrate(homeDir: String, defaults: UserDefaults) -> Int {
        // 幂等检查
        guard !defaults.bool(forKey: migrationFlagKey) else { return 0 }

        var migratedCount = 0

        for bundleId in legacyBundleIds {
            let plistPath = preferencesPath(for: bundleId, homeDir: homeDir)
            guard FileManager.default.fileExists(atPath: plistPath) else { continue }

            // NSDictionary(contentsOfFile:) 读取旧 plist（二进制或 XML 格式均可）
            guard let legacyPrefs = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
                continue
            }

            // 遍历旧 plist 中所有 chinesechess.* 前缀的 key
            for (key, value) in legacyPrefs {
                // 只迁移 chinesechess.* 前缀的 key
                guard key.hasPrefix(keyPrefix) else { continue }
                // 排除迁移标记自身，避免提前标记
                guard key != migrationFlagKey else { continue }

                // 只在当前 key 未设置时迁移
                // 注意：UserDefaults.standard.object(forKey:) 返回 nil 表示未设置
                // 不能用 .bool(forKey:) 或 .string(forKey:)，因为它们返回默认值而非 nil
                guard defaults.object(forKey: key) == nil else { continue }

                defaults.set(value, forKey: key)
                migratedCount += 1
            }
        }

        // 标记迁移完成（无论是否实际迁移了数据）
        defaults.set(true, forKey: migrationFlagKey)

        if migratedCount > 0 {
            AppLog.preferences.info("migrated \(migratedCount) keys from legacy Bundle IDs")
        }

        return migratedCount
    }

    // MARK: - 私有辅助

    /// 获取指定 Bundle ID 的 preferences plist 路径
    private static func preferencesPath(for bundleId: String, homeDir: String) -> String {
        "\(homeDir)/Library/Preferences/\(bundleId).plist"
    }
}
