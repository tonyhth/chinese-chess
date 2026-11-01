# T-1101-1 v6.5 FP P3 三件批 测试判词（Tina）

> **主审**：Tina（tester）｜**日期**：2026-11-01｜**派单**：Cody coder:main（测试面两套件）
> **对象锚定**：工作树态 @ m1 528b3ab6（HEAD 批内未动，点火/收割两次 rev-parse 一致）+ 8 files +378/-7（Phase2bTests.swift 工作树保留禁 commit）
> **漂移核查**：Phase2bTests.swift mtime 18:06 早于点火 18:09:36——构建态=判词时工作树态，无批内漂移（首枚举快照 341 行系 18:06 门禁落码前所摄，+3 行=Luke 裁③ env 门禁）
> **上游**：Ruby 审查 docs/reviews/v65-t1101-fp-p3-review-ruby.md（代码面通过）；本批判词对象=其审查后随批落码的 P3×4 修复面

---

## 一、批结果总览

| 批 | 形态 | 结果 | 计数对账 | 关键证据 |
|----|------|------|----------|----------|
| ① DrawDetectionRealTests | XCTest，runner P3-2 默认注入形态（**未手动设 env**） | ✅ 14/14 绿 | Executed 14 tests, 0 failures（锚=14 命中） | /tmp/t1101-tina/suite1.log:157,170 |
| ② FPAnchorProbeTests 首跑（无 env） | 门禁默认关（Luke 裁③） | ⚠️ skip-但-计数绿（预期门行为，非缺陷） | Test run with 2 tests passed after 0.001s + Suite skipped 行 | /tmp/t1101-tina/suite2.log:60-62 |
| ② FPAnchorProbeTests 复跑（TEST_RUNNER_FP_ANCHOR_PROBE=1） | Swift Testing，FAST cap=2000 | ✅ 2/2 真跑绿 | Test run with 2 tests in 1 suite passed after 37.240s（锚=2，无 skipped 行） | /tmp/t1101-tina/suite2b.log:246-264 |

## 二、分件判词

### 件3 核心（TCC 根修）✅ PASS
- 14/14 绿（Executed 14 tests, 0 failures, 0.175s 实跑），testPerpetualCheck_RealDriven passed 0.012s（suite1.log:148-149）——TCC 挂起根修实证成立
- **P3-2 默认注入路径本身得到验证**：本批未手动设 GAMERECORDSTORE_BASEURL，runner 顶层 :- 默认值生效（run-tests-mutex.sh:41-42），套件零挂起跑完——「无需手动 env，脱离上下文免疫」申报成立
- 通道 provenance：[sandbox-guard] 白名单放行横幅在 suite1.log:1 / suite2b.log:1；RUNNER_OWNER=tina

### 件1 探针（判别锚 FAST 形态）✅ PASS（附食谱勘误注记）
- 真跑签名全命中：PROBEB-SPACE mode=FAST subsets=14443 stride=25 sampled=578 combos=5780 cap=2000（suite2b.log:248）
- PROBEB-SUMMARY scanned=2003 **hits=0**（suite2b.log:249）——与申报四扫 0 命中口径一致；reasons 分布自洽（root-mate 248 / no-check 214 / pos-collision 77 / count-8 303 等，2003 全消解）
- 用例实耗：PROBE-A1 1.181s（:246）/ PROBE-B 36.055s（:262）——对照 Cody 实证 2.179s/34.474s 同量级
- ⚠️ **注记（非缺陷，随单呈报）**：派单原文「PROBE-B 默认快扫形态 2 绿 ~71s」已过时——Luke 裁③ env 门禁落码后套件默认关，无 env 跑为 skip-但-计数绿（0.001s+skipped 行，极易误读为通过，lead sweep 警告面本批独立实证命中）。Cody 食谱增补（TEST_RUNNER_FP_ANCHOR_PROBE=1）为现行正确命令，本判词以复跑真跑证据为准；首跑 skip 形态留档 suite2.log 作误读面活体对照

### P3×4 随批修复验证面
- **P3-2** runner 默认双通道注入：脚本 :41-42 在位 + ①批免 env 全绿实证 ✅
- **P3-3** 双形态门：源码 :334 套件级 .enabled(if:) + :532-535 FAST/FULL 组合数门；本批 skip/真跑两形态行为均与门设计一致 ✅
- **P3-1 / P3-4**：注记/口径勘误类，无独立断言面，随 commit 入库由 Luke 验收核对

## 三、计数对账门（静默零跑门规）
- runner 汇总对账行：①批「XCTest Executed 行=3」全=14 无缺口；②复跑批「XCTest Executed 行=2 / Swift Testing run 行=1」（✔ Test run with 2 tests）——无 0 tests 行，门通过
- 锚对账：14=派单锚 ✅；2=派单锚 ✅（以真跑形态计）

## 四、用户路径覆盖审查
本批变更面：project.yml ×2、scripts/build-release.sh、scripts/run-tests-mutex.sh、src/ChineseChess/AI/PositionAnalyzer.swift（纯注记 privacy）、src/ChineseChess/Services/GameRecordStore.swift（#if DEBUG 缝）、DrawDetectionRealTests.swift、Phase2bTests.swift（均为测试面）——**零 View 文件、零用户操作入口变更**。

| # | 用户操作 | 入口位置 | 数据查询 | 空数据保护 | 错误处理 | 用户反馈 |
|---|----------|----------|----------|------------|----------|----------|
| — | N/A（无 View/入口变更） | — | — | — | — | — |

GameRecordStore 缝经 Ruby 独立裁定 Release 编译恒等（#if DEBUG 剔除后 shared ≡ 原实现，生产直构造点唯一），用户路径行为零变化。缺失项：**无**。

## 五、锚定与纪律
- HEAD 528b3ab6 批内未动；工作树 8 files +378/-7 与构建态一致；全程**零 commit**（探针工作树态纪律维持）
- 全部批经 run-tests-mutex.sh 唯一入口（flock 全局互斥 + 语言锁，锁释放/恢复横幅在案）
- Cody「P3-1 勘误 + 件4 commit 在途」：commit 落地后内容即本判词所测工作树态，Luke 验收时按本指纹（8 files +378/-7 @ 528b3ab6+dirty）核对

## 六、结论
**①件3 14/14 绿 ✅；②件1 探针 2/2 真跑绿（FAST，scanned=2003 hits=0）✅；无 FAIL 项。**
门禁 skip 形态与派单食谱勘误已注记在案。**T-1101-1 测试面通过，候 Luke 验收。**

*主审 Tina｜2026-11-01｜只验不改零 commit｜证据链 /tmp/t1101-tina/{chain.log,chain2.log,build.log,suite1.log,suite2.log,suite2b.log,verify.done,verify2b.done}*
