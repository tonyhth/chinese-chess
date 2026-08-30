import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.4 Phase 1 B 线（Eric）：B1 定级阈值常量 + B2 Vera 极端值×2

@Suite("v6.4 B线：②b 标签/图例与极端值钳制", .serialized)
struct V64BLineTests {

    // MARK: - B1：定级阈值常量单一事实源（UI 与定级共用，行为不变回归）

    @Test("classifyMove 阈值边界与 MoveQuality 常量一致")
    func classifyMoveThresholdBoundaries() {
        let analyzer = PositionAnalyzer.shared
        // 边界值逐一验证：10→brilliant, 11→good, 50→good, 51→normal,
        // 100→normal, 101→doubtful, 300→doubtful, 301→blunder, 700→blunder, 701→losing
        let expectations: [(delta: Int, quality: MoveQuality)] = [
            (MoveQuality.brilliantMaxCp, .brilliant),
            (MoveQuality.brilliantMaxCp + 1, .good),
            (MoveQuality.goodMaxCp, .good),
            (MoveQuality.goodMaxCp + 1, .normal),
            (MoveQuality.normalMaxCp, .normal),
            (MoveQuality.normalMaxCp + 1, .doubtful),
            (MoveQuality.doubtfulMaxCp, .doubtful),
            (MoveQuality.doubtfulMaxCp + 1, .blunder),
            (MoveQuality.blunderMaxCp, .blunder),
            (MoveQuality.blunderMaxCp + 1, .losing),
        ]
        for (delta, expected) in expectations {
            // playerMove != bestMove，走 delta 分支
            let q = analyzer.classifyMove(
                playerMove: "a0a9", bestMove: "b0c2",
                bestEval: 0, playerEval: -delta
            )
            #expect(q == expected, "delta=\(delta) 应为 \(expected)，实际 \(q)")
        }
    }

    @Test("六级 i18n key 覆盖（图例六级全覆盖验收锚）")
    func qualityL10nKeysComplete() {
        #expect(MoveQuality.allCases.count == 6, "图例须覆盖六级")
        for q in MoveQuality.allCases {
            #expect(q.l10nKey.hasPrefix("move.quality."), "\(q) 应复用 move.quality.* key")
        }
    }

    // MARK: - B2-1：雷达绘制层 clamp + NaN guard

    @Test("RadarChartView 脏值清洗：NaN/±inf 归 0")
    func radarNaNGuard() {
        #expect(RadarChartView.sanitizedScore(Double.nan, max: 100) == 0)
        #expect(RadarChartView.sanitizedScore(.infinity, max: 100) == 0)
        #expect(RadarChartView.sanitizedScore(-.infinity, max: 100) == 0)
    }

    @Test("RadarChartView 越界钳制：负值归 0、超上限封顶")
    func radarClamp() {
        #expect(RadarChartView.sanitizedScore(-50, max: 100) == 0)
        #expect(RadarChartView.sanitizedScore(-0.1, max: 100) == 0)
        #expect(RadarChartView.sanitizedScore(0, max: 100) == 0)
        #expect(RadarChartView.sanitizedScore(55.5, max: 100) == 55.5)
        #expect(RadarChartView.sanitizedScore(100, max: 100) == 100)
        #expect(RadarChartView.sanitizedScore(1000, max: 100) == 100)
        #expect(RadarChartView.sanitizedScore(120, max: 80) == 80)
    }

    @Test("RadarChartView 清洗值可直接 Int 转换不崩（防 Int(NaN) trap）")
    func radarSanitizedIntConvertible() {
        for dirty in [Double.nan, .infinity, -.infinity, -1, 1e9] {
            let safe = RadarChartView.sanitizedScore(dirty, max: 100)
            #expect(safe.isFinite)
            _ = Int(safe) // NaN 时这里会 trap，清洗后不应崩
        }
    }

    // MARK: - B2-2：rankProgress 下限钳制（不为负/不穿底）

    @Test("rankProgress 脏档负进度钳到 0")
    func rankProgressLowerClamp() {
        var profile = PlayerProfile()
        profile.rank = .hanlin   // requiredWins=50, requiredPuzzles=10
        profile.totalWins = 0    // 胜场与段位不匹配（脏档/回退场景）→ 原实现为负
        profile.puzzlesCompleted = 0
        #expect(profile.rankProgress >= 0.0, "rankProgress 不应为负")
        #expect(profile.rankProgress <= 1.0, "rankProgress 不应穿底")
    }

    @Test("rankProgress 正常区间不受影响")
    func rankProgressNormalRange() {
        var profile = PlayerProfile()
        profile.rank = .student  // next=scholar(5胜)
        profile.totalWins = 3
        #expect(profile.rankProgress > 0.0 && profile.rankProgress < 1.0)
        profile.totalWins = 10
        #expect(profile.rankProgress == 1.0, "超额完成封顶 1.0")
    }
}

// MARK: - B3 A7-1：雷达 count<3 占位（不再静默空白，绘制层不崩验收锚）

extension V64BLineTests {

    @Test("sanitizedScore 对全 NaN 输入序列仍可安全整表清洗（count<3 场景前置）")
    func radarAllNaNSafe() {
        let dirty: [Double] = [.nan, .infinity, -42]
        let cleaned = dirty.map { RadarChartView.sanitizedScore($0, max: 100) }
        #expect(cleaned == [0, 0, 0], "全脏序列清洗后应全 0，不崩不越界")
    }
}
