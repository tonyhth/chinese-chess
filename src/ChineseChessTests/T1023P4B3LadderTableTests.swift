import Testing
@testable import ChineseChess

// T-1023·P3 Batch3 首项：渐升梯三轴单源表完整性门（方案 A，2026-10-24 洪涛裁定）
// 真相源：t1023-remediation-plan.md v1.1 §五首项表（注记②单源纪律+完整性单测随批）；T-1026 §三方案 A/§四链式
// 定稿表用文件级常量承载（@Suite struct 内禁 static 成员——swift-testing-suite-authoring 坑 1）
private let ladderRows: [(level: AIDifficulty, skill: Int, movetimeMs: Int, ladderElo: Int)] = [
    (.novice, 0, 1000, 1000),        // lvl1 豁免位（裁定⑥ movetime≤1000 锁值；b 形态取值）
    (.beginner, 2, 500, 1338),
    (.amateurLow, 4, 700, 1712),
    (.amateurMid, 5, 1000, 1801),
    (.amateurHigh, 7, 1400, 2056),
    (.amateurDan, 9, 2000, 2336),
    (.proApprentice, 11, 2800, 2473),
    (.proExpert, 14, 3600, 2627),    // C7 薄弱边 lvl8↔lvl9（s14→s17 微差）：高段渐进感承载，加局复核候缓裁池
    (.proMaster, 17, 4400, 2700),
    (.grandmaster, 20, 5000, 3170),
]

@Suite("T1023P4B3 LadderTable", .serialized)
struct T1023P4B3LadderTableTests {

    @Test("梯表逐档对表：十档三轴与方案 A 定稿表全等（lvl1 按豁免位 b 形态取值，测后还原）")
    func tableValues() {
        let saved = AIDifficulty.lvl1UsesPikafish
        defer { AIDifficulty.lvl1UsesPikafish = saved }
        AIDifficulty.lvl1UsesPikafish = true
        for row in ladderRows {
            let spec = row.level.s2Spec
            #expect(spec.usesPikafish, "\(row.level.rawValue) 应为 Pikafish 载体（梯表全行）")
            #expect(spec.skill == row.skill, "\(row.level.rawValue) skill \(String(describing: spec.skill)) ≠ \(row.skill)")
            #expect(spec.budgetMs == row.movetimeMs, "\(row.level.rawValue) movetime \(spec.budgetMs) ≠ \(row.movetimeMs)")
            #expect(spec.ladderElo == row.ladderElo, "\(row.level.rawValue) ladderElo \(spec.ladderElo) ≠ \(row.ladderElo)")
        }
        #expect(AIDifficulty.novice.s2Spec.ladderExempt, "s0 豁免位注记：lvl1 豁免教学档（门检排除）")
    }

    @Test("完整性门①：skill 严格递增（s0<s2<s4<s5<s7<s9<s11<s14<s17<s20）")
    func skillStrictlyIncreasing() {
        let saved = AIDifficulty.lvl1UsesPikafish
        defer { AIDifficulty.lvl1UsesPikafish = saved }
        AIDifficulty.lvl1UsesPikafish = true
        let all: [AIDifficulty] = AIDifficulty.allCases
        let skills: [Int?] = all.map { $0.s2Spec.skill }
        for i in 0..<(skills.count - 1) {
            let a = skills[i] ?? -1
            let b = skills[i + 1] ?? -1
            #expect(a < b, "\(all[i].rawValue)→\(all[i + 1].rawValue) skill \(a)!<\(b)（严格递增门）")
        }
    }

    @Test("完整性门②：movetime lvl2 起非降；lvl1 豁免位不参与门（缺省 a=自研帽 2000，b=s0@1000 裁定⑥锁值）")
    func movetimeNonDecreasingFromLvl2() {
        let all: [AIDifficulty] = AIDifficulty.allCases
        let rest: [Int] = all.dropFirst().map { $0.s2Spec.budgetMs }  // lvl2-10
        for i in 0..<(rest.count - 1) {
            #expect(rest[i + 1] >= rest[i], "lvl\(i + 2)→lvl\(i + 3) movetime \(rest[i])→\(rest[i + 1]) 递减（非降门）")
        }
        // 豁免位注记：lvl1 不参与非降门
        #expect(AIDifficulty.novice.s2Spec.budgetMs == 2000, "缺省 a 形态=自研预算帽 2000")
        let saved = AIDifficulty.lvl1UsesPikafish
        defer { AIDifficulty.lvl1UsesPikafish = saved }
        AIDifficulty.lvl1UsesPikafish = true
        #expect(AIDifficulty.novice.s2Spec.budgetMs == 1000, "b 形态=s0@1000 豁免位（≤1000 裁定⑥；丹妮 10-24 确认定稿非 500）")
    }

    @Test("完整性门③：ladderElo 全梯非降（s0=1000 基→s20≈3170；C7 lvl8↔lvl9 微差=方案 A 门放宽承载）")
    func ladderEloNonDecreasing() {
        let all: [AIDifficulty] = AIDifficulty.allCases
        let ladders: [Int] = all.map { $0.s2Spec.ladderElo }
        for i in 0..<(ladders.count - 1) {
            #expect(ladders[i + 1] >= ladders[i], "\(all[i].rawValue)→\(all[i + 1].rawValue) ladderElo \(ladders[i])→\(ladders[i + 1]) 倒挂（非降门）")
        }
        #expect(ladders.first == 1000 && ladders.last == 3170, "T-1026 §四链式基/尾锚")
    }

    @Test("完整性门④：ladderExempt 仅 lvl1（s0 豁免位）；单源转正 skillLevel≡s2Spec.skill 双形态复核")
    func exemptionAndSingleSourceWiring() {
        for d in AIDifficulty.allCases {
            #expect(d.s2Spec.ladderExempt == (d == .novice), "\(d.rawValue) ladderExempt 应仅 lvl1 豁免位")
        }
        let saved = AIDifficulty.lvl1UsesPikafish
        defer { AIDifficulty.lvl1UsesPikafish = saved }
        for flip in [false, true] {
            AIDifficulty.lvl1UsesPikafish = flip
            for d in AIDifficulty.allCases {
                #expect(d.skillLevel == d.s2Spec.skill, "\(d.rawValue) skillLevel 与梯表脱钩（单源纪律违约）")
                #expect(d.usesPikafishEngine == d.s2Spec.usesPikafish, "\(d.rawValue) 载体路由与梯表脱钩")
            }
        }
    }

    @Test("skillToDifficulty 就近映射（梯表派生运行时证据；CalibrationV3Tests 同口径——其 runner 通道被 KI-2026-0922-01 skip/only 撞车阻断）")
    func skillToDifficultyNearestMapping() {
        let saved = AIDifficulty.lvl1UsesPikafish
        defer { AIDifficulty.lvl1UsesPikafish = saved }
        // 缺省 a 形态：候选集=梯表 skill 非 nil 档（不含 novice），min(by: <) 并列取 allCases 序先
        let expected: [(skill: Int, level: AIDifficulty)] = [
            (0, .beginner),      // 距 s2=2 最近
            (4, .amateurLow),    // s4 精确
            (5, .amateurMid),    // s5 精确
            (6, .amateurMid),    // 距 s5=s7=1 并列，序先者
            (7, .amateurHigh),   // s7 精确
            (10, .amateurDan),   // 距 s9=1（并列序先）
            (13, .proExpert),    // 距 s14=1
            (20, .grandmaster),  // s20 精确
        ]
        for row in expected {
            #expect(SelfPlayRunner.skillToDifficulty(row.skill) == row.level,
                    "Skill \(row.skill) 应就近映射到 \(row.level.rawValue)")
        }
    }
}
