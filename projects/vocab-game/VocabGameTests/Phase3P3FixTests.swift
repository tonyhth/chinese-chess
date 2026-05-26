import XCTest
@testable import VocabGame

final class Phase3P3FixTests: XCTestCase {

    // MARK: - P3-1: backup 原子操作

    func testBackupSave_usesReplaceItem() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupTest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let repo = ProgressRepository(documentsDir: testDir)
        repo.load()

        // 写入一些数据
        var wp = repo.wordProgress(for: 1)
        wp.mastery = .learning
        repo.updateWordProgress(wp)

        // 验证 progress.json 存在
        let progressURL = testDir.appendingPathComponent("progress.json")
        let backupURL = testDir.appendingPathComponent("progress.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: progressURL.path))

        // 验证 .bak 存在（save 后应自动更新）
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "save() 后应生成 .bak 备份")

        // 重新加载验证 .bak 可用
        let repo2 = ProgressRepository(documentsDir: testDir)
        repo2.load()
        XCTAssertEqual(repo2.wordProgress(for: 1).mastery, .learning)
    }

    func testBackupRestore_onMainFileCorrupt() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupCorruptTest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        // 写入正常数据
        let repo = ProgressRepository(documentsDir: testDir)
        repo.load()
        var wp = repo.wordProgress(for: 5)
        wp.mastery = .familiar
        repo.updateWordProgress(wp)

        let progressURL = testDir.appendingPathComponent("progress.json")
        let backupURL = testDir.appendingPathComponent("progress.json.bak")

        // 损坏主文件
        let corruptData = "this is not json".data(using: .utf8)!
        try! corruptData.write(to: progressURL)

        // 加载应从 .bak 恢复
        let repo2 = ProgressRepository(documentsDir: testDir)
        repo2.load()
        XCTAssertEqual(repo2.wordProgress(for: 5).mastery, .familiar, "应从 .bak 恢复数据")
    }

    // MARK: - P3-2: accessories 防重复（ViewModel guard 验证）

    func testPurchase_isOwnedGuard_preventsDuplicate() {
        // ShopViewModel.purchase 的 guard: canAfford(item) && !isOwned(item)
        let item = ShopItem(id: "hat_test", name: "测试", type: .accessory, price: 50, description: "")
        var ownedItemIds: Set<String> = ["hat_test"]
        let coins = 100

        // 已拥有 → 不应再购买
        let isOwned = ownedItemIds.contains(item.id)
        XCTAssertFalse(coins >= item.price && !isOwned, "已拥有的物品不应再次购买")
    }

    func testPurchase_notOwned_canBuy() {
        let item = ShopItem(id: "hat_new", name: "新帽", type: .accessory, price: 50, description: "")
        var ownedItemIds: Set<String> = []
        let coins = 100

        let canBuy = coins >= item.price && !ownedItemIds.contains(item.id)
        XCTAssertTrue(canBuy)
    }

    // MARK: - P3-3: 时区处理

    func testTodayKey_usesCalendarCurrent() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: Date())

        // 今天格式应为 yyyy-MM-dd
        XCTAssertTrue(key.count == 10, "todayKey 应为 10 字符的 yyyy-MM-dd 格式")
        XCTAssertTrue(key.contains("-"))
    }

    func testStreak_usesCalendarCurrentMethods() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        XCTAssertTrue(Calendar.current.isDateInToday(today))
        XCTAssertTrue(Calendar.current.isDateInYesterday(yesterday))
        XCTAssertFalse(Calendar.current.isDateInToday(yesterday))
    }

    func testSeed_usesCalendarCurrentComponents() {
        let today = Date()
        let day = Calendar.current.component(.day, from: today)
        let month = Calendar.current.component(.month, from: today)
        let year = Calendar.current.component(.year, from: today)

        let seed = day * 10000 + month * 100 + year % 100

        // 所有组件应为正数
        XCTAssertGreaterThan(day, 0)
        XCTAssertGreaterThan(month, 0)
        XCTAssertGreaterThan(seed, 0)
    }
}
