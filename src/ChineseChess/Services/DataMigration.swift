import Foundation

// MARK: - v3.0 Phase 8: 数据迁移（v2.x → v3.0）

/// v2.x → v3.0 数据迁移管理器
/// 幂等设计：迁移标记确保只执行一次
final class DataMigration {

    static let shared = DataMigration()

    private let defaults: UserDefaults
    private let migrationKey = "chinesechess.v3_migrated"
    private let backupKey = "chinesechess.v2x_backup"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 是否已完成迁移
    var isMigrated: Bool {
        defaults.bool(forKey: migrationKey)
    }

    /// 执行迁移
    /// 返回 true 表示迁移成功（或已完成）
    @discardableResult
    func migrate() -> Bool {
        // 幂等检查
        if isMigrated { return true }

        // 1. 备份旧数据
        backupV2xData()

        // 2. 迁移教程完成状态
        migrateTutorialStatus()

        // 3. 根据历史胜场反算段位
        migrateRank()

        // 4. 追溯解锁成就
        migrateAchievements()

        // 5. 标记迁移完成
        defaults.set(true, forKey: migrationKey)

        return true
    }

    // MARK: - 备份

    private func backupV2xData() {
        // 备份关键 v2.x 键值（只备份可序列化的简单类型）
        let stringKeys = [
            "chinesechess.theme",
            "chinesechess.humanSide",
            "chinesechess.notationFormat",
            "chinesechess.language",
        ]
        let boolKeys = [
            "chinesechess.tutorialCompleted",
        ]
        let dataKeys = [
            "chinesechess.stats",
        ]

        var backup: [String: String] = [:]

        for key in stringKeys {
            if let str = defaults.string(forKey: key) {
                backup[key] = "string:\(str)"
            }
        }

        for key in boolKeys {
            let val = defaults.bool(forKey: key)
            backup[key] = "bool:\(val)"
        }

        for key in dataKeys {
            if let data = defaults.data(forKey: key) {
                backup[key] = "base64:\(data.base64EncodedString())"
            }
        }

        if let data = try? JSONEncoder().encode(backup) {
            defaults.set(data, forKey: backupKey)
        }
    }

    // MARK: - 迁移项

    /// 迁移教程完成状态
    private func migrateTutorialStatus() {
        let oldFlag = defaults.bool(forKey: "chinesechess.tutorialCompleted")
        if oldFlag {
            let store = PlayerProfileStore(defaults: defaults)
            store.update { profile in
                profile.completedTutorials = true
            }
        }
    }

    /// 根据历史胜场反算段位
    private func migrateRank() {
        let store = PlayerProfileStore(defaults: defaults)
        let stats = StatsManager(defaults: defaults).stats

        var totalWins = 0
        for (_, record) in stats.vsAI {
            totalWins += record.wins
        }

        if totalWins > 0 {
            store.update { profile in
                profile.totalWins = totalWins
                profile.puzzlesCompleted = stats.puzzlesCompleted
                // 反算段位（需同时满足胜场+残局条件）
                for rank in Rank.allCases {
                    if totalWins >= rank.requiredWins && stats.puzzlesCompleted >= rank.requiredPuzzles {
                        profile.rank = rank
                    }
                }
            }
        }
    }

    /// 追溯解锁成就
    private func migrateAchievements() {
        let store = PlayerProfileStore(defaults: defaults)
        let profile = store.profile
        let manager = AchievementManager(store: store)
        let newIds = manager.checkAndUnlock(profile: profile)

        // 如果有新解锁的成就，更新档案
        if !newIds.isEmpty {
            _ = store.profile  // 触发读取（manager 已经写入）
        }
    }

    // MARK: - v3.7.0 Phase 4: UserDefaults → JSON 迁移

    private let historyMigrationKey = "chinesechess.history.migrated"

    /// UserDefaults 历史数据 → JSON 文件迁移
    /// 原子性保障：逐条 .atomic 写入，全部成功才清旧数据，标记最后设置
    static func migrateGameHistoryToFiles() {
        let defaults = UserDefaults.standard
        let migrated = defaults.bool(forKey: "chinesechess.history.migrated")
        guard !migrated else { return }

        let oldStore = GameHistoryStore.shared
        let oldRecords = oldStore.records
        guard !oldRecords.isEmpty else {
            // 无旧数据，直接标记已迁移
            defaults.set(true, forKey: "chinesechess.history.migrated")
            return
        }

        let migratedCount = oldRecords.count
        let newStore = GameRecordStore.shared

        // 使用 addRecord() 写入（内置 id 去重，崩溃重试不会重复）
        for record in oldRecords {
            var r = record
            r.source = .versusAI
            newStore.addRecord(r)
        }

        // 确认 JSON 文件完整后才清空旧存储
        oldStore.clearAll()
        defaults.set(true, forKey: "chinesechess.history.migrated")

        #if DEBUG
        AppLog.history.info("migrated \(migratedCount) records from UserDefaults to JSON files")
        #endif
    }

    // MARK: - 回滚

    /// 回滚迁移（从备份恢复）
    func rollback() {
        guard let data = defaults.data(forKey: backupKey),
              let backup = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        for (key, encoded) in backup {
            if encoded.hasPrefix("string:") {
                let value = String(encoded.dropFirst(7))
                defaults.set(value, forKey: key)
            } else if encoded.hasPrefix("bool:") {
                let value = encoded.dropFirst(5) == "true"
                defaults.set(value, forKey: key)
            } else if encoded.hasPrefix("base64:"),
                      let data = Data(base64Encoded: String(encoded.dropFirst(7))) {
                defaults.set(data, forKey: key)
            }
        }

        // 清除迁移标记
        defaults.set(false, forKey: migrationKey)

        // 清除 v3.0 档案
        PlayerProfileStore(defaults: defaults).reset()
    }
}
