import Testing
import Foundation
@testable import ChineseChess

// MARK: - Phase Q2 段位门禁系统测试

@Suite("UnlockedFeature 段位门禁")
struct RankUnlockTests {

    /// 辅助：创建指定段位的 profile
    private func makeProfile(_ rank: Rank) -> PlayerProfile {
        var p = PlayerProfile()
        p.rank = rank
        return p
    }

    // MARK: - 段位 → 功能解锁

    @Test("学童：仅解锁无段位限制的功能")
    func studentUnlocks() {
        let profile = makeProfile(.student)
        for feature in UnlockedFeature.allCases {
            if feature.requiredRank == .student {
                #expect(profile.isFeatureUnlocked(feature), "学童应解锁无段位限制功能 \(feature.rawValue)")
            } else {
                #expect(!profile.isFeatureUnlocked(feature), "学童不应解锁 \(feature.rawValue)")
            }
        }
    }

    @Test("秀才：解锁 chapter2Early + openingTreeBrowse")
    func scholarUnlocks() {
        let profile = makeProfile(.scholar)
        #expect(profile.isFeatureUnlocked(.chapter2Early))
        #expect(profile.isFeatureUnlocked(.openingTreeBrowse))
        #expect(!profile.isFeatureUnlocked(.chapter3Early))
        #expect(!profile.isFeatureUnlocked(.engineAnalysis))
    }

    @Test("举人：解锁 chapter3Early")
    func jurenUnlocks() {
        let profile = makeProfile(.juren)
        #expect(profile.isFeatureUnlocked(.chapter2Early))
        #expect(profile.isFeatureUnlocked(.chapter3Early))
        #expect(profile.isFeatureUnlocked(.openingTreeBrowse))
        #expect(!profile.isFeatureUnlocked(.freePlayPuzzles))
    }

    @Test("翰林：解锁 freePlayPuzzles + engineAnalysis")
    func hanlinUnlocks() {
        let profile = makeProfile(.hanlin)
        #expect(profile.isFeatureUnlocked(.freePlayPuzzles))
        #expect(profile.isFeatureUnlocked(.engineAnalysis))
        #expect(!profile.isFeatureUnlocked(.aiCoach))
    }

    @Test("国手：解锁 aiCoach + gameRecordExport")
    func masterUnlocks() {
        let profile = makeProfile(.master)
        #expect(profile.isFeatureUnlocked(.aiCoach))
        #expect(profile.isFeatureUnlocked(.gameRecordExport))  // 翰林+均可导出
        #expect(!profile.isFeatureUnlocked(.openingTreeFavorite))
    }

    @Test("棋圣：解锁全部功能")
    func sageUnlocksAll() {
        let profile = makeProfile(.sage)
        for feature in UnlockedFeature.allCases {
            #expect(profile.isFeatureUnlocked(feature), "棋圣应解锁全部功能，但 \(feature.rawValue) 未解锁")
        }
    }

    // MARK: - requiredRank 一致性

    @Test("requiredRank 与 isFeatureUnlocked 一致")
    func rankConsistency() {
        for feature in UnlockedFeature.allCases {
            let profile = makeProfile(feature.requiredRank)
            #expect(profile.isFeatureUnlocked(feature), "\(feature.rawValue) 在 requiredRank 应解锁")

            if feature.requiredRank > .student {
                let belowRank = Rank.allCases[feature.requiredRank.order - 1]
                let belowProfile = makeProfile(belowRank)
                #expect(!belowProfile.isFeatureUnlocked(feature), "\(feature.rawValue) 在低于 requiredRank 不应解锁")
            }
        }
    }

    // MARK: - isImplemented 标记

    @Test("已实现功能标记正确")
    func implementedFlags() {
        #expect(UnlockedFeature.chapter2Early.isImplemented)
        #expect(UnlockedFeature.chapter3Early.isImplemented)
        #expect(UnlockedFeature.freePlayPuzzles.isImplemented)
        #expect(UnlockedFeature.engineAnalysis.isImplemented)
        #expect(UnlockedFeature.gameRecordExport.isImplemented)
        #expect(UnlockedFeature.gameRecordImport.isImplemented)

        // v3.7.2+: 以下功能已实现
        #expect(UnlockedFeature.aiCoach.isImplemented)
        #expect(UnlockedFeature.openingTreeFavorite.isImplemented)
        #expect(UnlockedFeature.customTheme.isImplemented)
        #expect(UnlockedFeature.openingTreeBrowse.isImplemented)
    }
}
