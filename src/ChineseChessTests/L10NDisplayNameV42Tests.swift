import Testing
import Foundation
@testable import ChineseChess

/// l10n 难度显示名 v4.2 测试
@Suite("l10n 难度显示名 v4.2 测试")
struct L10NDisplayNameV42Tests {

    // MARK: - displayName 中文显示名

    @Test("displayName: 10 个中文名正确且不重复")
    func displayNamesAllCorrect() {
        let names = AIDifficulty.allCases.map { $0.displayName }
        let expected = ["入门", "初级", "中级", "高级", "精通", "棋友", "棋手", "棋师", "大师", "棋圣"]
        #expect(names == expected, "displayName 应按顺序匹配：\(names)")
    }

    @Test("displayName: 10 个名称唯一不重复")
    func displayNamesUnique() {
        let names = AIDifficulty.allCases.map { $0.displayName }
        #expect(Set(names).count == 10, "10 个 displayName 应唯一")
    }

    // MARK: - displayNameEN 英文显示名

    @Test("displayNameEN: 10 个英文名正确且不重复")
    func displayNamesENAllCorrect() {
        let names = AIDifficulty.allCases.map { $0.displayNameEN }
        let expected = ["Beginner", "Elementary", "Intermediate", "Advanced", "Proficient",
                        "Player", "Expert", "Master", "Grandmaster", "Legend"]
        #expect(names == expected, "displayNameEN 应按顺序匹配：\(names)")
    }

    @Test("displayNameEN: 10 个英文名唯一不重复")
    func displayNamesENUnique() {
        let names = AIDifficulty.allCases.map { $0.displayNameEN }
        #expect(Set(names).count == 10, "10 个 displayNameEN 应唯一")
    }

    // MARK: - 逐个验证 displayName

    @Test("displayName 逐个验证")
    func displayNameIndividual() {
        #expect(AIDifficulty.novice.displayName == "入门")
        #expect(AIDifficulty.beginner.displayName == "初级")
        #expect(AIDifficulty.amateurLow.displayName == "中级")
        #expect(AIDifficulty.amateurMid.displayName == "高级")
        #expect(AIDifficulty.amateurHigh.displayName == "精通")
        #expect(AIDifficulty.amateurDan.displayName == "棋友")
        #expect(AIDifficulty.proApprentice.displayName == "棋手")
        #expect(AIDifficulty.proExpert.displayName == "棋师")
        #expect(AIDifficulty.proMaster.displayName == "大师")
        #expect(AIDifficulty.grandmaster.displayName == "棋圣")
    }

    // MARK: - 逐个验证 displayNameEN

    @Test("displayNameEN 逐个验证")
    func displayNameENIndividual() {
        #expect(AIDifficulty.novice.displayNameEN == "Beginner")
        #expect(AIDifficulty.beginner.displayNameEN == "Elementary")
        #expect(AIDifficulty.amateurLow.displayNameEN == "Intermediate")
        #expect(AIDifficulty.amateurMid.displayNameEN == "Advanced")
        #expect(AIDifficulty.amateurHigh.displayNameEN == "Proficient")
        #expect(AIDifficulty.amateurDan.displayNameEN == "Player")
        #expect(AIDifficulty.proApprentice.displayNameEN == "Expert")
        #expect(AIDifficulty.proExpert.displayNameEN == "Master")
        #expect(AIDifficulty.proMaster.displayNameEN == "Grandmaster")
        #expect(AIDifficulty.grandmaster.displayNameEN == "Legend")
    }

    // MARK: - 不变性验证（rawValue/order/isProfessional 不受影响）

    @Test("rawValue: 持久化值不变（lvl1-lvl10）")
    func rawValuesUnchanged() {
        #expect(AIDifficulty.novice.rawValue == "lvl1")
        #expect(AIDifficulty.beginner.rawValue == "lvl2")
        #expect(AIDifficulty.amateurLow.rawValue == "lvl3")
        #expect(AIDifficulty.amateurMid.rawValue == "lvl4")
        #expect(AIDifficulty.amateurHigh.rawValue == "lvl5")
        #expect(AIDifficulty.amateurDan.rawValue == "lvl6")
        #expect(AIDifficulty.proApprentice.rawValue == "lvl7")
        #expect(AIDifficulty.proExpert.rawValue == "lvl8")
        #expect(AIDifficulty.proMaster.rawValue == "lvl9")
        #expect(AIDifficulty.grandmaster.rawValue == "lvl10")
    }

    @Test("order: 0-9 递增不变")
    func orderUnchanged() {
        for (i, diff) in AIDifficulty.allCases.enumerated() {
            #expect(diff.order == i, "\(diff) order 应为 \(i)")
        }
    }

    @Test("isProfessional: 业余级 false / 棋士级 true")
    func isProfessionalUnchanged() {
        #expect(AIDifficulty.novice.isProfessional == false)
        #expect(AIDifficulty.beginner.isProfessional == false)
        #expect(AIDifficulty.amateurLow.isProfessional == false)
        #expect(AIDifficulty.amateurMid.isProfessional == false)
        #expect(AIDifficulty.amateurHigh.isProfessional == false)
        #expect(AIDifficulty.amateurDan.isProfessional == true)
        #expect(AIDifficulty.proApprentice.isProfessional == true)
        #expect(AIDifficulty.proExpert.isProfessional == true)
        #expect(AIDifficulty.proMaster.isProfessional == true)
        #expect(AIDifficulty.grandmaster.isProfessional == true)
    }

    // MARK: - skillLevel v4.2 重映射验证

    @Test("skillLevel: v4.2 重映射值正确")
    func skillLevelV42Remap() {
        #expect(AIDifficulty.amateurDan.skillLevel == 0)
        #expect(AIDifficulty.proApprentice.skillLevel == 4)
        #expect(AIDifficulty.proExpert.skillLevel == 7)
        #expect(AIDifficulty.proMaster.skillLevel == 10)
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
        // 业余级无 skillLevel
        #expect(AIDifficulty.novice.skillLevel == nil)
        #expect(AIDifficulty.beginner.skillLevel == nil)
        #expect(AIDifficulty.amateurLow.skillLevel == nil)
        #expect(AIDifficulty.amateurMid.skillLevel == nil)
        #expect(AIDifficulty.amateurHigh.skillLevel == nil)
    }

    // MARK: - Codable 兼容性

    @Test("Codable: rawValue 编解码不变")
    func codableCompatibility() throws {
        let difficulty = AIDifficulty.amateurMid
        let data = try JSONEncoder().encode(difficulty)
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: data)
        #expect(decoded == difficulty)
    }

    @Test("Codable: 从 rawValue 字符串解码")
    func codableFromRawValue() throws {
        let json = "\"lvl5\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurHigh)
    }
}
