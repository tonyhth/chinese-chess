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

    // MARK: - 单调性硬门（v2.2 §2.2 门 1：锁表段严格递增无并列；过渡位/豁免位按 §2.3 分层排除）

    @Test("单调硬门：锁表段 lvl2-5 严格递增（1280<1777<2268<2568）")
    func monotonicLockedSegment() {
        let locked: [AIDifficulty] = [.beginner, .amateurLow, .amateurMid, .amateurHigh]
        let ladders = locked.map { $0.s2Spec.ladderElo }
        for i in 0..<(ladders.count - 1) {
            #expect(ladders[i] < ladders[i + 1],
                    "\(locked[i].rawValue)(\(ladders[i])) 必须 < \(locked[i + 1].rawValue)(\(ladders[i + 1]))——倒挂/并列即重排表退回")
        }
    }

    @Test("单调硬门：过渡位分层排除后 lvl10 尾锚仍须高于锁表顶（lvl5=2568 < lvl10=3300）")
    func tailSegmentAboveLockedTop() {
        #expect(AIDifficulty.grandmaster.s2Spec.ladderElo > AIDifficulty.amateurHigh.s2Spec.ladderElo,
                "过渡位 lvl6-9 分层排除后，lvl10 官方锚延续仍须高于锁表顶（结构衔接）")
    }

    @Test("段距下限门：锁表段相邻天梯差 ≥100（v2.2 §2.2 门 2 锁值，T-1013-OC-02）")
    func segmentDistanceFloor() {
        let locked: [AIDifficulty] = [.beginner, .amateurLow, .amateurMid, .amateurHigh]
        let ladders = locked.map { $0.s2Spec.ladderElo }
        for i in 0..<(ladders.count - 1) {
            #expect(ladders[i + 1] - ladders[i] >= 100,
                    "\(locked[i].rawValue)→\(locked[i + 1].rawValue) 天梯差 \(ladders[i + 1] - ladders[i]) < 100（防小档距体感反模式）")
        }
    }

    // MARK: - 锁表参数（v0.3.1 §2.1 锁数）

    @Test("锁表参数：lvl2-5 载体/skill/预算逐档对表（R2-P1/P2 锚 + lvl5 现行 10000ms）")
    func lockedTableParams() {
        let b = AIDifficulty.beginner.s2Spec
        #expect(b.usesPikafish && b.skill == 0 && b.budgetMs == 5000, "lvl2=skill0@5000ms（R2-P1 锚）")
        let l = AIDifficulty.amateurLow.s2Spec
        #expect(l.usesPikafish && l.skill == 4 && l.budgetMs == 5000, "lvl3=skill4@5000ms（R2-P1/G-M1 段距 798）")
        let m = AIDifficulty.amateurMid.s2Spec
        #expect(m.usesPikafish && m.skill == 7 && m.budgetMs == 5000, "lvl4=skill7@5000ms（R2-P2/G-M2 段距 301）")
        let h = AIDifficulty.amateurHigh.s2Spec
        #expect(h.usesPikafish && h.skill == 10 && h.budgetMs == 10000, "lvl5=skill10@10000ms（现行标定沿用，保质期注记）")
    }

    @Test("过渡位维持现行：lvl6-9 skill/预算与 v4.2 现值一致（§2.3 维持现状）+ lvl10 官方锚延续")
    func transitionSlotsUnchanged() {
        #expect(AIDifficulty.amateurDan.s2Spec.skill == 0 && AIDifficulty.amateurDan.s2Spec.budgetMs == 5000
                && AIDifficulty.amateurDan.s2Spec.transitionSlot, "lvl6 过渡位维持现行 s0@5000")
        #expect(AIDifficulty.proApprentice.s2Spec.skill == 4 && AIDifficulty.proApprentice.s2Spec.budgetMs == 6000
                && AIDifficulty.proApprentice.s2Spec.transitionSlot, "lvl7 过渡位维持现行 s4@6000")
        #expect(AIDifficulty.proExpert.s2Spec.skill == 7 && AIDifficulty.proExpert.s2Spec.budgetMs == 7000
                && AIDifficulty.proExpert.s2Spec.transitionSlot, "lvl8 过渡位维持现行 s7@7000")
        #expect(AIDifficulty.proMaster.s2Spec.skill == 10 && AIDifficulty.proMaster.s2Spec.budgetMs == 8000
                && AIDifficulty.proMaster.s2Spec.transitionSlot, "lvl9 过渡位维持现行 s10@8000")
        #expect(AIDifficulty.grandmaster.s2Spec.skill == 20 && AIDifficulty.grandmaster.s2Spec.budgetMs == 10000
                && !AIDifficulty.grandmaster.s2Spec.transitionSlot, "lvl10 官方锚延续非过渡位")
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

    @Test("迁移映射：Codable 解码路径消费（持久化键迁移），实码锚版候裁")
    func migrationDecodedPath() {
        func decode(_ raw: String) -> AIDifficulty? {
            let data = try! JSONEncoder().encode(raw)
            return try? JSONDecoder().decode(AIDifficulty.self, from: data)
        }
        // 实码锚版（候裁提案①）：lvl6=s0→新 lvl2 / lvl7=s4→新 lvl3 / lvl8=s7→新 lvl4 / lvl9=s10→新 lvl5（全同锚零漂移）
        #expect(decode("lvl6") == .beginner, "old lvl6（实码 s0）→新 lvl2 同锚零漂移")
        #expect(decode("lvl7") == .amateurLow, "old lvl7（实码 s4）→新 lvl3 同锚零漂移")
        #expect(decode("lvl8") == .amateurMid, "old lvl8（实码 s7）→新 lvl4 同锚零漂移")
        #expect(decode("lvl9") == .amateurHigh, "old lvl9（实码 s10）→新 lvl5 同锚零漂移（免挂起）")
        #expect(decode("lvl10") == .grandmaster, "old lvl10（s20）→新 lvl10 同锚零漂移")
        // 自研 old1-5 就近（实测锚）：old3/4/5≈1777→新 lvl3；old1 同槽豁免档；old2 锚残缺→过渡定位注记
        #expect(decode("lvl3") == .amateurLow, "old lvl3（硬 d2，>1777 带）→新 lvl3 就近（偏差≤1 档合规）")
        #expect(decode("lvl4") == .amateurLow, "old lvl4≈old5（B5）≈1777 →新 lvl3 就近")
        #expect(decode("lvl5") == .amateurLow, "old lvl5 下限 1777（plan-b §1.3）→新 lvl3 同锚零漂移")
        #expect(decode("lvl1") == .novice, "old lvl1→新 lvl1 豁免档同槽")
        #expect(decode("lvl2") == .beginner, "old lvl2 锚残缺→lvl2 过渡定位（文案面注记随行）")
        // 旧版兼容键（v2.0-v5.x）不受迁移影响
        #expect(decode("master") == .amateurHigh)
        #expect(decode("beginner") == .novice)
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

    @Test("过渡期选择器：visibleProfessionalLevels=[lvl10]，底层数据源锢定不破（候裁提案②）")
    func transitionPicker() {
        #expect(AIDifficulty.transitionProfessionalPickerHidden, "候裁默认=过渡期隐藏 lvl6-9")
        #expect(AIDifficulty.visibleProfessionalLevels == [.grandmaster])
        // 数据源锢定（①-4b 同款）：底层数组未动，隐藏仅为过渡期可见集过滤
        #expect(AIDifficulty.amateurLevels + AIDifficulty.professionalLevels == AIDifficulty.allCases)
    }
}
