# skip 集中清单（v6.3 H-1，Tina 落档 2026-08-29）

> **单源声明**：本文件是 chinese-chess 测试常规 skip 名单的唯一权威源。
> `scripts/run-tests-mutex.sh` 自动消费本表（状态列 = skip 的行生成 `-skip-testing` 参数）。
> 修复落地时**同 commit** 更新本表（状态 skip→active），不靠记忆（守门原则：基线成员必须确定性，绿或 skip，不掷硬币）。
> 全绿口径（v6.3-plan §4-2）= 绿，或登记 skip（带 reason）。

| Suite | 状态 | reason | 证据/裁定 |
|-------|------|--------|-----------|
| EloBaselineTests | skip | 自对弈 5 局 × 30+ 分钟，锁死构建目录，全量批铁律排除 | DEVTEAM.md 测试铁律（历史） |
| V370Phase1Tests | skip | GameRecordStore_* dispatch_sync 死锁族（testGameRecordStore_AddAndLoad 实测挂点） | 08-28 §4.3 r1 卡死实证（LAUNCH-REGISTRY） |
| V370Phase2SupplementTests | skip | 同族（testGameRecordStore_AddRecord_DeduplicatesById 实测挂点，r2 二次卡死） | 08-28 §4.3 r2 |
| V370Phase3Tests | skip | GameRecordStore_* 死锁族预防性排除（r3 起跑口径五类之一） | 08-28 §4.3 r3 |
| V370Phase4Tests | skip | 同上 | 08-28 §4.3 r3 |
| V371Tests | skip | 同上 | 08-28 §4.3 r3 |
| UILayoutOptTests | skip | 大师级 AI 用例构造第二 Pikafish 实例 init 死锁（r3d/r3e 同点定位） | 08-28 r3f 定位；TOOLS.md 历史口径"常规 skip 六件之一"，r3 系曾漏配 |
| CalibrationV3Tests | skip（全量批） | 全量批内 180s×2 超时挂点（08-29 r3 #2 实测：newGame 清除 lastSkillOverride 180s 超时 → 引擎楔死 → 下游 10 红连坐；隔离复跑全绿 23/23）——单跑/定向批不受限，全量批 skip | r3 #2 line 2743 首崩点 + Step 2 隔离绿 |
| PikafishCAPITests | skip | r3f 挂点嫌疑 + 08-28 selcons 并行批 2 红（result=-1 启动失败形态，并行干扰） | 08-29 Luke 裁定 skip，2 红不采信 |

<!-- 表格仅收整 suite 级 skip（供脚本 awk 消费）；用例级 skip 记在下方，不入机器可读表 -->

### 用例级（代码内 skip，不参与脚本生成）

- BoardPlayerRefactorTests「ReplayVM 中途暂停后再播放可以继续」：isAutoPlaying 时序竞态 flaky（3 跑 2 红 1 绿），无条件 skip + reason（dc4653d §三）；修复落地同 commit 移除。

## 注记（非 skip 但影响对账）

- **MovegenCrosscheck 休眠 → Test run 计数漂移**：基线登记行须注记"MovegenCrosscheck 休眠，run 计数口径以用例级为准"（Ruby 复核口径，08-28）。
- **锁屏挂死 ×2**（r3/r3b，9.5h 0% CPU）：环境案非 suite 案，处置 = 起跑带 `caffeinate` + 长跑 nohup 规约，不入 skip 表。
- **正式批与 r 系长跑基线互斥起跑**：经 `run-tests-mutex.sh` 的 flock 全局锁强制（08-29 Luke 口径），规约同时固化在工单模板 docs/general/ticket-template.md。
| AIEngineTimingContractTests | active | suite 不整 skip（Luke 08-29 二裁）：lvl1-3 硬断言 + lvl4/5 登记观察档（测试内确定性豁免，实测照常入表带 VIOLATION-REGISTERED 标记）。lvl4 max 13.5s / lvl5 max 45.4s（预算 5.7 倍）违约实锤，违约集中第 8-10 着连续深局段（丹妮复核定位锚：迭代加深深局段 TimeManager 失效，lvl5 末两着 40s+ 连坐）；初判根因 TimeManager 层间检查、层内无 deadline 截断（28s 案同族）；lvl3 秒回=浅层档设计行为，测试已加返回着非空且合法断言排除假快 | v6.4 难度重设计工作包（P1，issue=difficulty-redesign，与 depth 阶梯校准/V2 前史锚点合并同域），证据 evidence/engine-timing-0829/（丹妮复核三点 08-29 入注） |
