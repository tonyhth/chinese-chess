import XCTest
@testable import ChineseChess

// MARK: - 难度重置 Bug 修复测试 (commit 82f977e)

@MainActor
final class DifficultyResetBugFixTests: XCTestCase {

    /// 测试1: 学童段位下手动选"新手"难度 → newGame() 后难度保持"新手"
    func testUserSelectedDifficulty_NotReset_OnNewGame_StudentRank() {
        let vm = GameViewModel()
        // 确保段位是学童（推荐难度 = .easy）
        // 先 newGame 让初始难度设为段位推荐
        vm.newGame()
        let initialDifficulty = vm.difficulty

        // 手动选"新手"（beginner）
        vm.setDifficulty(.beginner)
        XCTAssertEqual(vm.difficulty, .beginner, "手动设置后难度应为 beginner")

        // 点新局
        vm.newGame()

        // 难度应保持 beginner，不被重置
        XCTAssertNotEqual(vm.difficulty, initialDifficulty, "难度不应被重置为段位推荐")
        XCTAssertEqual(vm.difficulty, .beginner, "newGame 后应保持用户手动选择的 beginner")
    }

    /// 测试2: 选"大师"难度 → newGame() 后保持"大师"
    func testUserSelectedDifficulty_Master_NotReset() {
        let vm = GameViewModel()
        vm.newGame()

        vm.setDifficulty(.master)
        XCTAssertEqual(vm.difficulty, .master)

        vm.newGame()
        XCTAssertEqual(vm.difficulty, .master, "newGame 后应保持 master")
    }

    /// 测试3: 不手动选难度 → newGame() 应为段位推荐难度
    func testNoUserSelection_UsesRankRecommended() {
        let vm = GameViewModel()
        // 第一次 newGame：用户未手动选过，应用段位推荐
        vm.newGame()
        let rank = PlayerProfileStore.shared.profile.rank
        XCTAssertEqual(vm.difficulty, rank.recommendedCoachDifficulty,
                       "未手动选难度时，newGame 应使用段位推荐难度")
    }

    /// 测试4: 多次 newGame 不覆盖用户选择
    func testMultipleNewGames_PreserverUserChoice() {
        let vm = GameViewModel()
        vm.newGame()
        vm.setDifficulty(.hard)

        vm.newGame()
        XCTAssertEqual(vm.difficulty, .hard, "第一次 newGame 后应保持 hard")

        vm.newGame()
        XCTAssertEqual(vm.difficulty, .hard, "第二次 newGame 后应保持 hard")

        vm.newGame()
        XCTAssertEqual(vm.difficulty, .hard, "第三次 newGame 后应保持 hard")
    }

    /// 测试5: setDifficulty 逐次切换都被保留
    func testSwitchDifficulty_AllPreserved() {
        let vm = GameViewModel()
        vm.newGame()

        vm.setDifficulty(.beginner)
        vm.newGame()
        XCTAssertEqual(vm.difficulty, .beginner)

        vm.setDifficulty(.medium)
        vm.newGame()
        XCTAssertEqual(vm.difficulty, .medium)

        vm.setDifficulty(.master)
        vm.newGame()
        XCTAssertEqual(vm.difficulty, .master)
    }

    /// 测试6: 段位推荐难度验证（学童 → easy）
    func testStudentRank_RecommendsEasy() {
        let rank = Rank.student
        XCTAssertEqual(rank.recommendedCoachDifficulty, .easy, "学童段位推荐难度应为 easy")
    }
}
