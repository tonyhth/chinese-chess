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
        // T-1019-OC-01 段位制（v2.2 v1.5 §2.4）
        let expected = ["学徒棋手", "业余初段", "业余三段", "业余五段", "业余七段", "地方大师", "大师候补", "国家大师", "特级大师候选", "特级大师"]
        #expect(names == expected, "displayName 应按顺序匹配：\(names)")
    }

    @Test("displayName: 10 个名称唯一不重复")
    func displayNamesUnique() {
        let names = AIDifficulty.allCases.map { $0.displayName }
        #expect(Set(names).count == 10, "10 个 displayName 应唯一")
    }

    // MARK: - 英文显示名（P1-2: displayNameEN 硬编码表已退场，EN 锚点 = l10n en 表经 displayName 单源读取）

    @Test("en displayName: 10 个英文名正确且不重复")
    func displayNamesENAllCorrect() {
        L10n.shared.setLanguage("en")
        defer { L10n.shared.setLanguage("zh-Hans") }
        let names = AIDifficulty.allCases.map { $0.displayName }
        // T-1019-OC-01 段位制（v2.2 v1.5 §2.4）
        let expected = ["Apprentice", "Amateur 1D", "Amateur 3D", "Amateur 5D", "Amateur 7D",
                        "Local Master", "Master Candidate", "National Master", "GM Candidate", "Grandmaster"]
        #expect(names == expected, "en displayName 应按顺序匹配：\(names)")
    }

    @Test("en displayName: 10 个名称唯一不重复")
    func displayNamesENUnique() {
        L10n.shared.setLanguage("en")
        defer { L10n.shared.setLanguage("zh-Hans") }
        let names = AIDifficulty.allCases.map { $0.displayName }
        #expect(Set(names).count == 10, "10 个 en displayName 应唯一")
    }

    // MARK: - 逐个验证 displayName

    @Test("displayName 逐个验证")
    func displayNameIndividual() {
        #expect(AIDifficulty.novice.displayName == "学徒棋手")
        #expect(AIDifficulty.beginner.displayName == "业余初段")
        #expect(AIDifficulty.amateurLow.displayName == "业余三段")
        #expect(AIDifficulty.amateurMid.displayName == "业余五段")
        #expect(AIDifficulty.amateurHigh.displayName == "业余七段")
        #expect(AIDifficulty.amateurDan.displayName == "地方大师")
        #expect(AIDifficulty.proApprentice.displayName == "大师候补")
        #expect(AIDifficulty.proExpert.displayName == "国家大师")
        #expect(AIDifficulty.proMaster.displayName == "特级大师候选")
        #expect(AIDifficulty.grandmaster.displayName == "特级大师")
    }

    // MARK: - 逐个验证 en displayName（P1-2: 经 l10n en 表单源）

    @Test("en displayName 逐个验证")
    func displayNameENIndividual() {
        L10n.shared.setLanguage("en")
        defer { L10n.shared.setLanguage("zh-Hans") }
        #expect(AIDifficulty.novice.displayName == "Apprentice")
        #expect(AIDifficulty.beginner.displayName == "Amateur 1D")
        #expect(AIDifficulty.amateurLow.displayName == "Amateur 3D")
        #expect(AIDifficulty.amateurMid.displayName == "Amateur 5D")
        #expect(AIDifficulty.amateurHigh.displayName == "Amateur 7D")
        #expect(AIDifficulty.amateurDan.displayName == "Local Master")
        #expect(AIDifficulty.proApprentice.displayName == "Master Candidate")
        #expect(AIDifficulty.proExpert.displayName == "National Master")
        #expect(AIDifficulty.proMaster.displayName == "GM Candidate")
        #expect(AIDifficulty.grandmaster.displayName == "Grandmaster")
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
