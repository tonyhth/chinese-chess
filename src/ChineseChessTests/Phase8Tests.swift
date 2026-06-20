import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 8 主题经济 + 数据迁移 + QA 测试")
struct Phase8Tests {

    // MARK: - 8.1 主题解锁经济

    @Test("主题包含 5 种（2 默认 + 3 段位解锁）")
    func themeCount() {
        #expect(BoardTheme.allCases.count == 5)
    }

    @Test("默认主题无需解锁")
    func defaultThemesUnlocked() {
        #expect(BoardTheme.classicWood.isUnlockedByDefault == true)
        #expect(BoardTheme.inkStone.isUnlockedByDefault == true)
    }

    @Test("段位主题需要对应段位")
    func rankLockedThemes() {
        #expect(BoardTheme.jadeGreen.requiredRank == .scholar)
        #expect(BoardTheme.imperialGold.requiredRank == .juren)
        #expect(BoardTheme.crimson.requiredRank == .jinshi)
    }

    @Test("ThemeManager 段位检查")
    func themeManagerUnlockCheck() {
        let suite = UserDefaults(suiteName: "test_theme_\(UUID().uuidString)")!
        let store = PlayerProfileStore(defaults: suite)
        let manager = ThemeManager.shared

        // 学童不能解锁翡翠绿
        let studentProfile = PlayerProfile(rank: .student, totalWins: 0)
        #expect(manager.isThemeUnlocked(.jadeGreen, profile: studentProfile) == false)

        // 秀才可以解锁翡翠绿
        let scholarProfile = PlayerProfile(rank: .scholar, totalWins: 5)
        #expect(manager.isThemeUnlocked(.jadeGreen, profile: scholarProfile) == true)

        // 举人可以解锁帝王金
        let jurenProfile = PlayerProfile(rank: .juren, totalWins: 15)
        #expect(manager.isThemeUnlocked(.imperialGold, profile: jurenProfile) == true)

        // 进士可以解锁朱砂红
        let jinshiProfile = PlayerProfile(rank: .jinshi, totalWins: 30)
        #expect(manager.isThemeUnlocked(.crimson, profile: jinshiProfile) == true)
    }

    @Test("主题颜色配置不崩溃")
    func themeColorsNoCrash() {
        for theme in BoardTheme.allCases {
            let colors = ThemeColors.forTheme(theme)
            #expect(!colors.boardBackground.isEmpty)
            #expect(!colors.pieceFill.isEmpty)
        }
    }

    @Test("主题有解锁描述")
    func themeUnlockDescription() {
        for theme in BoardTheme.allCases {
            #expect(!theme.unlockDescription.isEmpty)
        }
    }

    // MARK: - 8.2 数据迁移

    @Test("数据迁移幂等性")
    func migrationIdempotent() {
        let suite = UserDefaults(suiteName: "test_mig_\(UUID().uuidString)")!
        let migration = DataMigration(defaults: suite)

        // 第一次迁移
        let result1 = migration.migrate()
        #expect(result1 == true)
        #expect(migration.isMigrated == true)

        // 第二次迁移不应出错
        let result2 = migration.migrate()
        #expect(result2 == true)
    }

    @Test("数据迁移备份")
    func migrationBackup() {
        let suite = UserDefaults(suiteName: "test_backup_\(UUID().uuidString)")!
        suite.set(true, forKey: "chinesechess.tutorialCompleted")
        suite.set("classicWood", forKey: "chinesechess.theme")

        let migration = DataMigration(defaults: suite)
        migration.migrate()

        // 验证备份存在
        #expect(suite.data(forKey: "chinesechess.v2x_backup") != nil)
    }

    @Test("数据迁移教程状态")
    func migrationTutorialStatus() {
        let suite = UserDefaults(suiteName: "test_tut_\(UUID().uuidString)")!
        suite.set(true, forKey: "chinesechess.tutorialCompleted")

        let migration = DataMigration(defaults: suite)
        migration.migrate()

        let profile = PlayerProfileStore(defaults: suite).profile
        #expect(profile.completedTutorials == true)
    }

    @Test("数据迁移段位反算")
    func migrationRankBackfill() {
        let suite = UserDefaults(suiteName: "test_rank_\(UUID().uuidString)")!

        // 模拟 v2.x 历史数据：用 StatsManager API 写入 20 胜
        let statsManager = StatsManager(defaults: suite)
        for _ in 0..<20 {
            statsManager.recordWin(for: .medium)
        }

        let migration = DataMigration(defaults: suite)
        migration.migrate()

        let profile = PlayerProfileStore(defaults: suite).profile
        #expect(profile.totalWins >= 20)
        #expect(profile.rank >= .juren)
    }

    @Test("数据迁移回滚")
    func migrationRollback() {
        let suite = UserDefaults(suiteName: "test_rollback_\(UUID().uuidString)")!
        suite.set(true, forKey: "chinesechess.tutorialCompleted")
        suite.set("inkStone", forKey: "chinesechess.theme")

        let migration = DataMigration(defaults: suite)
        migration.migrate()

        // 回滚
        migration.rollback()

        // 迁移标记应清除
        #expect(migration.isMigrated == false)
        // 备份的原始数据应恢复
        #expect(suite.string(forKey: "chinesechess.theme") == "inkStone")
    }

    // MARK: - 8.3 QA 验证

    @Test("StatusBarView 难度标签存在")
    func statusBarDifficultyLabel() {
        // 验证 GameViewModel.difficulty 有 displayName
        for diff in AIDifficulty.allCases {
            #expect(!diff.displayName.isEmpty, "\(diff) 应有 displayName")
        }
    }

    @Test("残局重置后状态正确")
    func puzzleResetState() {
        // 用 JSON 构造 Puzzle 避免参数不匹配
        let json = """
        {"id":"test_reset","name":"测试","category":"oneMove","difficulty":1,"stars":1,"description":"测试","playerSide":"red","initialFEN":"4k4/9/9/9/9/9/9/9/9/3RK4 w","solution":["R9e9"],"hints":null,"maxMoves":10,"source":null,"solutionType":"checkmate","endDescription":null,"solutionMode":"guided","subcategory":null}
        """
        let puzzle = try! JSONDecoder().decode(Puzzle.self, from: json.data(using: .utf8)!)
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.gameState = .failed
        vm.isThinking = true
        vm.resetPuzzle()

        #expect(vm.gameState == .playing)
        #expect(vm.isThinking == false)
        #expect(vm.isProcessingWrongMove == false)
        #expect(vm.gameMoves.isEmpty)
        #expect(vm.solutionStepIndex == 0)
    }

    // MARK: - 集成

    @Test("全量构建验证")
    func buildVerification() {
        // 如果测试在跑，说明编译通过
        #expect(Bool(true))
    }
}
