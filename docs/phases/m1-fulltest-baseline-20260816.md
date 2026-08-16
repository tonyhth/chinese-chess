# m1 全量测试存量基线（2026-08-16 版，93→50 更新）

> 作者：Cody（Luke 小单，收割报告存档）
> **本文件是 m1 分支后续全量对账的权威基线**（前版：m1-phase1-fulltest-ledger.md 93 账，c4b0a58）
> 口径：过滤 EloBaselineTests 全量（未过滤 EngineRouter 系 8 类——与 93 账的过滤差异见注⑤）

## 一、正式数字

- **双轮全同铁证**：clean HEAD（54752ed）vs 切换 WIP（beeadbe 前身）失败清单**逐条全同**——39 Swift Testing + 11 XCTest = **50 用例 / 37 issues**，唯一差异 2 行耗时数字
- 双框架口径：Swift Testing `✘ Test` + XCTest `error: -[Suite test]` 两种格式都计（"40"为只计 ST 的旧口径，已废）
- 判定（Luke 裁定 2026-08-16）：50/50 全落 93 账已知族，**零新面孔 → 不立污染专项，基线记录更新**

## 二、50 用例语义族映射表（族 ↔ c4b0a58 账目锚）

| 族 | 数量 | 用例群 | 93 账目锚 |
|---|---|---|---|
| i18n/L10n 泄漏族 | 14 | L10n 中英 key×2 / 英文 UI×2 / 翻译值长度 / SmartCommentary×1(ST)+1(XCT) / UIBugFixI18n×4(XCT) / D5 审计×3 | "D5I18nAuditVerificationTests 3 i18n 审计基线漂移" + 同类演进区 |
| 断言过期族（业务演进未跟测） | 18 | AIDifficulty 十级制×7 / MasterSearchResult displayName×2 / centerControl d/e/f×3 / CoachScenario 8 case / GameMove halfmoveClock / TutorialFEN / V371 PGN / PhaseB2Step2×2(XCT) / MasterGameFix×2(XCT) / SolutionMode | "v6.0 十级制扩容欠账（IOSToolbarAdaptationV31Tests 等）"/ "P3Batch2Tests 3" / "其余合计 ~54" / 特注⑦ |
| 单例状态泄漏族 | 5 | 语言切换 translations / 新对局重置 / 记录人机胜利 / 记录多局 / 困毙判负 | 同类演进区（PlayerProfile/StatsManager 全局态） |
| 异步时序族 | 9 | DemoVM currentIndex/lastMove/canGoForward/stepForward/stepBackward/validStepCount/progressText/showingResult（BoardPlayerRefactorTests 文件，套件名"DemoViewModel Delegation"） | "BoardPlayerRefactorTests 7 DemoVM 异步转发时序（波动子集）" |
| 引擎族 | 4 | EngineRouter 默认 native（Phase2aTests 文件内）/ analyzeMove / topMoves MultiPV / evaluate FEN / beginner 应比 medium 快 | "v6.0 路由演进存量" / V40Phase1 计时族 |

特注：**文件名 ≠ 套件名分辨**——今早单跑绿的 EngineRouterTests 与全量挂的 `EngineRouter 默认返回 native 引擎` 是**不同文件**（后者在 Phase2aTests.swift:487）。

## 三、93→50 数量对账

| 项 | 数量 | 证据 |
|---|---|---|
| RankUnlock 段位门禁 | **−25（整套翻绿）** | 套件显示名"UnlockedFeature 段位门禁"（中文，grep RankUnlock 零命中陷阱）；两轮全量 ✔ Suite passed 0.004s 零失败行——同树同码翻绿 = 顺序依赖波动直接证据 |
| 波动族子集变化 | −18 | DemoVM/L10n/i18n 族逐轮不同子集（93 账自证 126↔117 同族波动区间） |
| 修复消化 | 0（排除） | m1 1cdfe2d..HEAD 零 tests 断言修复 commit（git log 实核，仅 A3r2 冲突标记修复 bdec77b） |

注⑤：93 账过滤了 EngineRouter 系 8 类（死锁规避）；本双轮只过滤 EloBaseline，8 类跑了未死锁零贡献——口径差已核，不影响对照。

## 四、波动性注记（对账规则）

- **族内子集逐轮可变**：i18n/异步时序族的用例组合随运行顺序漂移——后续对账按**族级对照**（数量级 ±50% 内且无新族 = 同基线），不追求逐用例复现
- 新面孔判定 = 出现本表五族之外的新失败族（Luke 裁定①：新面孔单列 → 触发专项评审）
- RankUnlock 已从基线摘除（翻绿）；若未来复挂，按断言过期族回收

## 五、证据存档

- ~/DevTeam/p2c-switch-evidence/（永久）：
  - p2c2-full.log（WIP 全量）/ p2c2-baseline-full.log（clean HEAD 全量）
  - st40.txt（39 ST 提取清单）/ xct.txt（11 XCT 提取清单）
- /tmp/p2c2-*.log（原始，易失）
- E1 串行取证（进行中）：/tmp/m1-e1-serial.log——三分类判定（绿=并行竞态 / 同 50=顺序依赖泄漏 / 部分=混合）收割后由 Danny 转 Alex

## 六、变更记录

- 2026-08-15：93 账（m1-phase1-fulltest-ledger.md，c4b0a58）
- 2026-08-16：93→50 本版（双轮全同铁证 + RankUnlock 翻绿 + 波动族对账；Luke 验收收割报告）
