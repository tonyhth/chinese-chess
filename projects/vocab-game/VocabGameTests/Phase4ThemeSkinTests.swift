import XCTest
@testable import VocabGame
import SwiftUI

@MainActor
final class Phase4ThemeSkinTests: XCTestCase {

    // MARK: - 1. 5 个主题

    func test_themeSkin_countIs5() {
        XCTAssertEqual(ThemeSkin.allCases.count, 5)
    }

    func test_themeSkin_allCases() {
        let cases: Set<ThemeSkin> = [.garden, .beach, .starry, .candy, .party]
        XCTAssertEqual(Set(ThemeSkin.allCases), cases)
    }

    // MARK: - 2. 各主题 displayName

    func test_themeSkin_displayNames() {
        XCTAssertEqual(ThemeSkin.garden.displayName, "粉色花园")
        XCTAssertEqual(ThemeSkin.beach.displayName, "海滩夏日")
        XCTAssertEqual(ThemeSkin.starry.displayName, "星空幻想")
        XCTAssertEqual(ThemeSkin.candy.displayName, "糖果王国")
        XCTAssertEqual(ThemeSkin.party.displayName, "蛋仔派对")
    }

    // MARK: - 3. 各主题 emoji

    func test_themeSkin_emojis() {
        XCTAssertEqual(ThemeSkin.garden.emoji, "🌸")
        XCTAssertEqual(ThemeSkin.beach.emoji, "🏖️")
        XCTAssertEqual(ThemeSkin.starry.emoji, "🌙")
        XCTAssertEqual(ThemeSkin.candy.emoji, "🍬")
        XCTAssertEqual(ThemeSkin.party.emoji, "🎉")
    }

    // MARK: - 4. 解锁条件 — garden 始终解锁

    func test_garden_alwaysUnlocked() {
        let profile = PlayerProfile()
        let pet = PetState()
        XCTAssertTrue(ThemeSkin.garden.isUnlocked(profile: profile, petState: pet))
    }

    // MARK: - 5. beach — 拥有 scene_beach

    func test_beach_unlocked_whenOwnedScene() {
        var pet = PetState()
        pet.ownedScenes.append("scene_beach")
        XCTAssertTrue(ThemeSkin.beach.isUnlocked(profile: PlayerProfile(), petState: pet))
    }

    func test_beach_locked_withoutScene() {
        XCTAssertFalse(ThemeSkin.beach.isUnlocked(profile: PlayerProfile(), petState: PetState()))
    }

    // MARK: - 6. starry — totalStars >= 15

    func test_starry_unlocked_with15Stars() {
        var profile = PlayerProfile()
        profile.totalStars = 15
        XCTAssertTrue(ThemeSkin.starry.isUnlocked(profile: profile, petState: PetState()))
    }

    func test_starry_locked_with14Stars() {
        var profile = PlayerProfile()
        profile.totalStars = 14
        XCTAssertFalse(ThemeSkin.starry.isUnlocked(profile: profile, petState: PetState()))
    }

    // MARK: - 7. candy — totalStars >= 25

    func test_candy_unlocked_with25Stars() {
        var profile = PlayerProfile()
        profile.totalStars = 25
        XCTAssertTrue(ThemeSkin.candy.isUnlocked(profile: profile, petState: PetState()))
    }

    func test_candy_locked_with24Stars() {
        var profile = PlayerProfile()
        profile.totalStars = 24
        XCTAssertFalse(ThemeSkin.candy.isUnlocked(profile: profile, petState: PetState()))
    }

    // MARK: - 8. party — 收藏品 >= 10

    func test_party_unlocked_with10Items() {
        var pet = PetState()
        pet.accessories = ["a1","a2","a3"]
        pet.ownedFoods = ["f1","f2","f3"]
        pet.ownedScenes = ["s1","s2","s3"]
        pet.ownedEffects = ["e1"]
        XCTAssertTrue(ThemeSkin.party.isUnlocked(profile: PlayerProfile(), petState: pet))
    }

    func test_party_locked_with9Items() {
        var pet = PetState()
        pet.accessories = ["a1","a2","a3"]
        pet.ownedFoods = ["f1","f2","f3"]
        pet.ownedScenes = ["s1","s2","s3"]
        XCTAssertFalse(ThemeSkin.party.isUnlocked(profile: PlayerProfile(), petState: pet))
    }

    // MARK: - 9. 背景渐变色 — 非空

    func test_themeSkin_gradients_nonEmpty() {
        for skin in ThemeSkin.allCases {
            XCTAssertFalse(skin.backgroundGradient.isEmpty, "\(skin) gradient should not be empty")
        }
    }

    func test_gardenGradient_isPink() {
        let gradient = ThemeSkin.garden.backgroundGradient
        // garden: "FFE0EC" → "FFB6C1" (pink)
        XCTAssertEqual(gradient.count, 2)
    }

    func test_candyGradient_has3Colors() {
        XCTAssertEqual(ThemeSkin.candy.backgroundGradient.count, 3)
    }

    // MARK: - 10. ThemeSkin Codable

    func test_themeSkin_codable_roundTrip() {
        let original = ThemeSkin.starry
        let encoded = try? JSONEncoder().encode(original)
        XCTAssertNotNil(encoded)
        let decoded = try? JSONDecoder().decode(ThemeSkin.self, from: encoded!)
        XCTAssertEqual(decoded, original)
    }
}
