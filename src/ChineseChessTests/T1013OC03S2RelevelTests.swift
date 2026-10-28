//
//  T1013OC03S2RelevelTests.swift
//  ChineseChessTests
//
//  T-1013-OC-03 S2 实施——10 级重排（锁定 portion）单测
//  规格：difficulty-system-v2.2-draft.md v0.3.1（锁表/硬门/M-C′ 迁移）+ v65-weakening-chain-v3-draft.md v0.2.1 §8①
//  覆盖：①单调性硬门（锁表段）②段距下限门 ③锁表参数逐档 ④过渡位维持现行 ⑤L1 载体双形态
//        ⑥迁移映射（Codable 解码路径消费 / init(rawValue:) 不污染）⑦载体路由面 ⑧过渡期选择器（候裁提案②）
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("T1013OC03 S2 Relevel", .serialized)
struct T1013OC03S2RelevelTests {

    // MARK: - 单调性硬门（v2.2 门 1 锁表段严格递增无并列；段距 ≥100 门经 2026-10-24 方案 A 裁定放宽为全梯非降）

    @Test("单调硬门：锁表段 lvl2-5 严格递增（方案 A：1338<1712<1801<2056）")
    func monotonicLockedSegment() {
        let locked: [AIDifficulty] = [.beginner, .amateurLow, .amateurMid, .amateurHigh]
        let ladders = locked.map { $0.s2Spec.ladderElo }
        for i in 0..<(ladders.count - 1) {
            #expect(ladders[i] < ladders[i + 1],
                    "\(locked[i].rawValue)(\(ladders[i])) 必须 < \(locked[i + 1].rawValue)(\(ladders[i + 1]))——倒挂/并列即重排表退回")
        }
    }

    @Test("单调硬门：lvl10 尾锚仍须高于 lvl5（方案 A：lvl5=2056 < lvl10=3170）")
    func tailSegmentAboveLockedTop() {
        #expect(AIDifficulty.grandmaster.s2Spec.ladderElo > AIDifficulty.amateurHigh.s2Spec.ladderElo,
                "过渡位 lvl6-9 分层排除后，lvl10 官方锚延续仍须高于锁表顶（结构衔接）")
    }

    @Test("梯距门（方案 A 放宽）：全梯 ladderElo 非降（10-24 裁定：≥100 段距门放宽为非降，C7 高段渐进感承载）")
    func segmentDistanceFloor() {
        let all: [AIDifficulty] = AIDifficulty.allCases
        let ladders: [Int] = all.map { $0.s2Spec.ladderElo }
        for i in 0..<(ladders.count - 1) {
            #expect(ladders[i + 1] >= ladders[i],
                    "\(all[i].rawValue)→\(all[i + 1].rawValue) 天梯 \(ladders[i])→\(ladders[i + 1]) 倒挂（方案 A 门=非降）")
        }
        #expect(ladders.first == 1000 && ladders.last == 3170, "s0=1000 基→s20≈3170 尾锚（T-1026 §四链式）")
    }

    // MARK: - 锁表参数（v0.3.1 §2.1 锁数）

    @Test("锁表参数：lvl2-5 载体/skill/预算逐档对表（方案 A 梯表，2026-10-24 重锚）")
    func lockedTableParams() {
        let b = AIDifficulty.beginner.s2Spec
        #expect(b.usesPikafish && b.skill == 2 && b.budgetMs == 500, "lvl2=s2@500ms（方案 A 梯表）")
        let l = AIDifficulty.amateurLow.s2Spec
        #expect(l.usesPikafish && l.skill == 4 && l.budgetMs == 700, "lvl3=s4@700ms（方案 A 梯表）")
        let m = AIDifficulty.amateurMid.s2Spec
        #expect(m.usesPikafish && m.skill == 5 && m.budgetMs == 1000, "lvl4=s5@1000ms（方案 A 梯表）")
        let h = AIDifficulty.amateurHigh.s2Spec
        #expect(h.usesPikafish && h.skill == 7 && h.budgetMs == 1400, "lvl5=s7@1400ms（方案 A 梯表）")
    }

    @Test("过渡位转正：lvl6-9 三轴已入方案 A 梯表（消费单源转正）+ 过渡位标志保留 + lvl10 官方锚 s20 延续")
    func transitionSlotsReladder() {
        #expect(AIDifficulty.amateurDan.s2Spec.skill == 9 && AIDifficulty.amateurDan.s2Spec.budgetMs == 2000
                && AIDifficulty.amateurDan.s2Spec.transitionSlot, "lvl6=s9@2000（过渡位标志保留，消费已转正单源）")
        #expect(AIDifficulty.proApprentice.s2Spec.skill == 11 && AIDifficulty.proApprentice.s2Spec.budgetMs == 2800
                && AIDifficulty.proApprentice.s2Spec.transitionSlot, "lvl7=s11@2800")
        #expect(AIDifficulty.proExpert.s2Spec.skill == 14 && AIDifficulty.proExpert.s2Spec.budgetMs == 3600
                && AIDifficulty.proExpert.s2Spec.transitionSlot, "lvl8=s14@3600（C7 薄弱边起点：高段渐进感承载）")
        #expect(AIDifficulty.proMaster.s2Spec.skill == 17 && AIDifficulty.proMaster.s2Spec.budgetMs == 4400
                && AIDifficulty.proMaster.s2Spec.transitionSlot, "lvl9=s17@4400")
        #expect(AIDifficulty.grandmaster.s2Spec.skill == 20 && AIDifficulty.grandmaster.s2Spec.budgetMs == 5000
                && !AIDifficulty.grandmaster.s2Spec.transitionSlot, "lvl10=s20@5000 官方锚延续非过渡位")
    }

    // MARK: - L1 载体双形态（v2.2 §2.1 五缺口④：默认 a，b 隔离可换）

    @Test("L1 默认选项 a：自研 hard-d1 维持（usesPikafish=false），豁免教学档")
    func lvl1DefaultOptionA() {
        #expect(!AIDifficulty.lvl1UsesPikafish, "默认应为选项 a（自研 hard-d1 维持基线，洪涛裁量未落）")
        #expect(!AIDifficulty.novice.s2Spec.usesPikafish, "选项 a 下 lvl1 走自研载体")
        #expect(AIDifficulty.novice.s2Spec.ladderExempt, "lvl1 豁免教学档（L1→L2 不计档距门）")
    }

    @Test("L1 选项 b 一键切：Pikafish skill0 + movetime≤1000ms（隔离可换，测后还原）")
    func lvl1OptionBSwitch() {
        let saved = AIDifficulty.lvl1UsesPikafish
        defer { AIDifficulty.lvl1UsesPikafish = saved }
        AIDifficulty.lvl1UsesPikafish = true
        let spec = AIDifficulty.novice.s2Spec
        #expect(spec.usesPikafish && spec.skill == 0, "选项 b=Pikafish skill0")
        #expect(spec.budgetMs <= 1000, "选项 b movetime≤1000ms（强度弱于 lvl2 由预算差承载，R2-P1 双预算观察）")
    }

    // MARK: - 迁移映射（v2.2 §3.2 M-C′ 全表强度就近；实码锚版=候裁提案①，Checkpoint 1 08:53）

    // MARK: - P1-2 边界迁移（Luke 裁定选项 a：挂点收窄至 GameRecord 用户数据边界）

    /// 旧档夹具：s2Migrated=false + S2 前旧语义档位键
    private func makeOldRecord(difficulty: AIDifficulty, playerDifficulty: AIDifficulty) -> GameRecord {
        GameRecord(
            title: "旧档",
            redPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: playerDifficulty),
            blackPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: .novice),
            difficulty: difficulty,
            result: .draw, totalMoves: 1, moves: [],
            s2Migrated: false
        )
    }

    @Test("P1-2 边界迁移：旧档（无标记）record+players 经映射单次应用（实码锚全同锚零漂移）")
    func boundaryMigrationOldRecords() {
        let decoder = JSONDecoder()
        // 实码锚映射：lvl6(s0)→新 lvl2 / lvl5(≈1777)→新 lvl3 / lvl8(s7)→新 lvl4 / lvl9(s10)→新 lvl5
        let cases: [(old: AIDifficulty, expected: AIDifficulty)] = [
            (.amateurDan, .beginner), (.amateurHigh, .amateurLow),
            (.proExpert, .amateurMid), (.proMaster, .amateurHigh)
        ]
        for testCase in cases {
            let data = try! JSONEncoder().encode(makeOldRecord(difficulty: testCase.old, playerDifficulty: testCase.old))
            let loaded = try! JSONDecoder().decode(GameRecord.self, from: data)
            #expect(loaded.difficulty == testCase.expected, "\(testCase.old.rawValue) 应迁移为 \(testCase.expected.rawValue)")
            #expect(loaded.redPlayer.difficulty == testCase.expected, "redPlayer 应同步迁移")
            #expect(loaded.blackPlayer.difficulty == .novice, "novice 不在映射表=键不变零漂移")
            #expect(loaded.s2Migrated, "应用后标记置位")
        }
    }

    @Test("P1-2 新值零腐蚀：S2 后新档（标记在位）difficulty 直读不迁移")
    func boundaryZeroCorrosion() {
        let decoder = JSONDecoder()
        // S2 后新档：s2Migrated=true + 新语义键（lvl4=s7）——若误迁移会降为 lvl3（腐蚀实锤位回归）
        for d in [AIDifficulty.beginner, .amateurLow, .amateurMid, .amateurHigh, .grandmaster] {
            let record = GameRecord(
                title: "新档",
                redPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: d),
                blackPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: d),
                difficulty: d,
                result: .draw, totalMoves: 1, moves: [],
                s2Migrated: true
            )
            let data = try! JSONEncoder().encode(record)
            let loaded = try! JSONDecoder().decode(GameRecord.self, from: data)
            #expect(loaded.difficulty == d, "\(d.rawValue) 标记在位应零腐蚀直读")
            #expect(loaded.redPlayer.difficulty == d)
        }
    }

    @Test("P1-2 非设置解码不触迁移：AIDifficulty Codable 纯解码恒等（类型级钩子已撤）")
    func plainDecodableIdentity() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for d in AIDifficulty.allCases {
            let data = try! encoder.encode(d)
            #expect(try! decoder.decode(AIDifficulty.self, from: data) == d,
                    "\(d.rawValue) 纯解码应恒等（迁移只在 GameRecord 边界）")
        }
        // 锚定：lvl6 纯解码 = .amateurDan（不迁移到 lvl2）
        let data = try! encoder.encode(AIDifficulty.amateurDan)
        #expect(try! decoder.decode(AIDifficulty.self, from: data) == .amateurDan)
    }

    @Test("迁移不污染 init(rawValue:)：CLI lvlN 直构语义保持（--calibrate/--calibrate-native 依赖）")
    func rawValuePathNotMigrated() {
        #expect(AIDifficulty(rawValue: "lvl6") == .amateurDan, "rawValue 直构不走迁移（CLI 语义保持）")
        #expect(AIDifficulty(rawValue: "lvl9") == .proMaster, "rawValue 直构不走迁移（CLI 语义保持）")
        #expect(AIDifficulty(rawValue: "lvl4") == .amateurMid, "rawValue 直构不走迁移（CLI 语义保持）")
        #expect(AIDifficulty(rawValue: "lvl2") == .beginner)
    }

    // MARK: - 载体路由面 + 过渡期选择器（候裁提案②）

    @Test("载体路由面：lvl2-5 与 lvl6-10 usesPikafishEngine=true；lvl1-a=false；与 isProfessional 有意分离")
    func carrierRouting() {
        #expect(AIDifficulty.beginner.usesPikafishEngine)
        #expect(AIDifficulty.amateurLow.usesPikafishEngine)
        #expect(AIDifficulty.amateurMid.usesPikafishEngine)
        #expect(AIDifficulty.amateurHigh.usesPikafishEngine)
        #expect(AIDifficulty.amateurDan.usesPikafishEngine)
        #expect(AIDifficulty.grandmaster.usesPikafishEngine)
        #expect(!AIDifficulty.novice.usesPikafishEngine, "lvl1 默认 a=自研 hard-d1")
        #expect(!AIDifficulty.beginner.isProfessional, "isProfessional=UI 分组/进度旧语义，lvl2-5 有意保持 false（语义分离注记）")
    }

    @Test("回全表：visibleProfessionalLevels=professionalLevels 全表，数据源锢定不破（B1-R3 裁定执行）")
    func transitionPicker() {
        #expect(!AIDifficulty.transitionProfessionalPickerHidden, "B1-R3：过渡期结束，lvl6-9 回全表")
        #expect(AIDifficulty.visibleProfessionalLevels == AIDifficulty.professionalLevels)
        // 数据源锢定（①-4b 同款）：底层数组未动，回全表=可见集过滤解除
        #expect(AIDifficulty.amateurLevels + AIDifficulty.professionalLevels == AIDifficulty.allCases)
    }

    // MARK: - P1-1 局中切档 skill 滞留回归（Ruby 全审修后重走）

    @Test("P1-1 局中切档：切档→期望 skill 随切刷新（旧 lastSkillOverride 守卫滞留实锤位回归；Batch3 后单源梯表值）")
    func midGameSwitchResolution() {
        // 局首首手：lvl4（梯表 s5）→ 推 5
        #expect(AIDifficulty.s2SkillToApply(difficulty: .amateurMid, externalOverride: nil, lastApplied: nil) == 5)
        // 第二手同档：脏检查跳过（不重复推）
        #expect(AIDifficulty.s2SkillToApply(difficulty: .amateurMid, externalOverride: nil, lastApplied: 5) == nil)
        // 局中切 lvl2：期望 2（旧守卫在此滞留 5 = P1-1 实锤场景）
        #expect(AIDifficulty.s2SkillToApply(difficulty: .beginner, externalOverride: nil, lastApplied: 5) == 2)
        // 低→高对称：lvl2 局中切回 lvl4 → 期望 5
        #expect(AIDifficulty.s2SkillToApply(difficulty: .amateurMid, externalOverride: nil, lastApplied: 2) == 5)
        // lvl6-10 局中互切：Batch3 后同走单源梯表（旧 skillLevel 双通道已退役）
        #expect(AIDifficulty.s2SkillToApply(difficulty: .proApprentice, externalOverride: nil, lastApplied: 9) == 11)
        #expect(AIDifficulty.s2SkillToApply(difficulty: .proMaster, externalOverride: nil, lastApplied: 11) == 17)
        // 外部 override 存活（--calibrate 通道）：难度应用不插手（nil=不推）
        #expect(AIDifficulty.s2SkillToApply(difficulty: .beginner, externalOverride: 7, lastApplied: 7) == nil)
        #expect(AIDifficulty.s2SkillToApply(difficulty: .amateurLow, externalOverride: 0, lastApplied: 4) == nil)
        // 过渡位 lvl6（无外部 override）：直接走单源梯表 s9（镜像双推面已随转正退役）
        #expect(AIDifficulty.s2SkillToApply(difficulty: .amateurDan, externalOverride: nil, lastApplied: 4) == 9)
    }

    @Test("P1-1 外部 override 廊角申报：override≠nil 时 difficulty.skillLevel 不再反覆盖（行为增强已申报）")
    func externalOverrideCorner() {
        // 廓角（override≠nil, skillLevel≠nil，如 lvl7 局中 --calibrate 混入）：旧码被 difficulty.skillLevel 反覆盖，
        // 新码 override 存活——Ruby 全审申报的行为增强，回归钉住
        #expect(AIDifficulty.s2SkillToApply(difficulty: .proApprentice, externalOverride: 9, lastApplied: 9) == nil,
                "外部 override 存活期，难度应用不插手（即使 skillLevel≠nil）")
    }
}
