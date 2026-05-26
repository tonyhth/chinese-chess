import XCTest
@testable import VocabGame

final class LevelTests: XCTestCase {

    // MARK: - 关卡定义完整性

    func testAllLevels_countIs25() {
        XCTAssertEqual(LevelDefinition.allLevels.count, 25)
    }

    func testAllLevels_idsAreSequential() {
        let ids = LevelDefinition.allLevels.map(\.id)
        XCTAssertEqual(ids, Array(1...25))
    }

    func testAllLevels_wordGroupsMatchIds() {
        for def in LevelDefinition.allLevels {
            XCTAssertEqual(def.wordGroup, def.id, "关卡 \(def.id) 的 wordGroup 应等于 id")
        }
    }

    func testAllLevels_haveNonEmptyNames() {
        for def in LevelDefinition.allLevels {
            XCTAssertFalse(def.name.isEmpty, "关卡 \(def.id) 缺少名称")
        }
    }

    func testAllLevels_namesAreUnique() {
        let names = LevelDefinition.allLevels.map(\.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "关卡名称不应重复")
    }

    // MARK: - LevelProgress

    func testLevelProgress_initial() {
        let lp = LevelProgress.initial(levelId: 5)
        XCTAssertEqual(lp.levelId, 5)
        XCTAssertFalse(lp.isCompleted)
        XCTAssertEqual(lp.stars, 0)
        XCTAssertEqual(lp.bestScore, 0)
    }

    func testLevelProgress_codable() throws {
        var lp = LevelProgress.initial(levelId: 3)
        lp.isCompleted = true
        lp.stars = 2
        lp.bestScore = 850

        let data = try JSONEncoder().encode(lp)
        let decoded = try JSONDecoder().decode(LevelProgress.self, from: data)

        XCTAssertEqual(decoded.levelId, 3)
        XCTAssertTrue(decoded.isCompleted)
        XCTAssertEqual(decoded.stars, 2)
        XCTAssertEqual(decoded.bestScore, 850)
    }

    // MARK: - LevelDefinition Codable

    func testLevelDefinition_codable() throws {
        let def = LevelDefinition(id: 1, name: "新手村庄", wordGroup: 1)
        let data = try JSONEncoder().encode(def)
        let decoded = try JSONDecoder().decode(LevelDefinition.self, from: data)

        XCTAssertEqual(decoded.id, 1)
        XCTAssertEqual(decoded.name, "新手村庄")
        XCTAssertEqual(decoded.wordGroup, 1)
    }
}
