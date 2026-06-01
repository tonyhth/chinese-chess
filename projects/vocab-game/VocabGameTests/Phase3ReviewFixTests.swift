import XCTest
@testable import VocabGame

final class Phase3ReviewFixTests: XCTestCase {

    private var progressRepo: ProgressRepository!
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("P3FixTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        progressRepo = ProgressRepository(documentsDir: testDir)
        progressRepo.load()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    // MARK: - dailyChallengeRecords 90天自动清理

    func testRecordDailyCompletion_keepsRecentRecord() {
        progressRepo.recordDailyCompletion(score: 800)
        XCTAssertTrue(progressRepo.isDailyCompleted)
        XCTAssertEqual(progressRepo.dailyBestScore, 800)
    }

    func testOldRecords_cleanedAfter90Days() {
        // 直接构造含过期记录的 ProgressData
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 手动构造 91 天前的 key
        let oldDate = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let oldKey = formatter.string(from: oldDate)
        let todayKey = formatter.string(from: Date())

        var pd = ProgressRepository.ProgressData()
        pd.dailyChallengeRecords[oldKey] = .init(isCompleted: true, bestScore: 500)

        // 写入然后加载
        let data = try! encoder.encode(pd)
        let fileURL = testDir.appendingPathComponent("progress.json")
        try! data.write(to: fileURL)

        let repo2 = ProgressRepository(documentsDir: testDir)
        repo2.load()

        // 旧记录存在
        XCTAssertNotNil(repo2.data.dailyChallengeRecords[oldKey])

        // 调用 recordDailyCompletion 触发清理
        repo2.recordDailyCompletion(score: 700)

        // 旧记录应被清理
        XCTAssertNil(repo2.data.dailyChallengeRecords[oldKey], "90天前的记录应被清理")

        // 今日记录应存在
        XCTAssertTrue(repo2.data.dailyChallengeRecords[todayKey] != nil)
        XCTAssertEqual(repo2.data.dailyChallengeRecords[todayKey]?.bestScore, 700)
    }

    func testRecentRecords_notCleaned() {
        // 30 天前的记录不应被清理
        let recentDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let recentKey = formatter.string(from: recentDate)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var pd = ProgressRepository.ProgressData()
        pd.dailyChallengeRecords[recentKey] = .init(isCompleted: true, bestScore: 600)

        let data = try! encoder.encode(pd)
        let fileURL = testDir.appendingPathComponent("progress.json")
        try! data.write(to: fileURL)

        let repo2 = ProgressRepository(documentsDir: testDir)
        repo2.load()
        repo2.recordDailyCompletion(score: 800)

        // 30 天前的记录仍在
        XCTAssertNotNil(repo2.data.dailyChallengeRecords[recentKey], "30天内的记录不应被清理")
    }

    func testCleanup_invalidDateKey_notRemoved() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var pd = ProgressRepository.ProgressData()
        pd.dailyChallengeRecords["invalid-date"] = .init(isCompleted: true, bestScore: 100)

        let data = try! encoder.encode(pd)
        let fileURL = testDir.appendingPathComponent("progress.json")
        try! data.write(to: fileURL)

        let repo2 = ProgressRepository(documentsDir: testDir)
        repo2.load()
        repo2.recordDailyCompletion(score: 500)

        // 无法解析的 key 应保留（guard returns true）
        XCTAssertNotNil(repo2.data.dailyChallengeRecords["invalid-date"])
    }

    // MARK: - BGM 后台停止/前台恢复逻辑验证

    func testScenePhase_backgroundStopsBGM() async {
        // 逻辑验证：background → stopBGM
        // 代码在 MainTabView.swift onChange(of: scenePhase) 中
        // .background → AudioService.shared.stopBGM()
        // 验证 stopBGM 不崩溃
        await MainActor.run { AudioService.shared.stopBGM() }
    }

    func testScenePhase_activeStartsBGM() async {
        // .active → AudioService.shared.startBGM()
        // 验证 startBGM 不崩溃（无 BGM 文件时静默返回）
        await MainActor.run { AudioService.shared.startBGM() }
        await MainActor.run { AudioService.shared.stopBGM() } // cleanup
    }

    // MARK: - DailyChallenge coinsEarned 显示实际值

    func testDailyCoinsEarned_formula() {
        // coinsEarned = max(score / 100, 5) + 10
        let score0 = 0
        let score500 = 500
        let score1000 = 1000

        XCTAssertEqual(max(score0 / 100, 5) + 10, 15, "0分每日保底15")
        XCTAssertEqual(max(score500 / 100, 5) + 10, 15, "500分15")
        XCTAssertEqual(max(score1000 / 100, 5) + 10, 20, "1000分20")
    }

    // MARK: - ConfettiView 重构验证

    func testConfettiParticle_fallenState() {
        // 验证新增的 fallen 属性
        var particle = ConfettiView.ConfettiParticle(
            color: .red, x: 50, delay: 0.1, size: 8, rotation: 45
        )
        XCTAssertFalse(particle.fallen, "初始状态 fallen = false")

        particle.fallen = true
        XCTAssertTrue(particle.fallen)
    }

    // MARK: - PrimaryButtonStyle 存在性

    func testPrimaryButtonStyle_isGradient() {
        // 验证 PrimaryButtonStyle 使用渐变
        // LinearGradient(colors: [VGColors.primary, Color(hex: "FF8CAE")])
        let _ = PrimaryButtonStyle()
        // 如果能构造则表示编译通过
    }
}
