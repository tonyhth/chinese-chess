# T-1016-OC-01 数据盘点：GameRecord/RecordSummary 存量字段 vs Q4 复审触发需求映射

- **作者/日期**：Cody 2026-10-16 ｜ 派单：Luke（洪涛 10-16 14:37 批，丹妮转）｜ DDL 10-17 12:00
- **性质**：零代码纯盘点（红线遵守：唯一产出=本 memo）
- **结论先行**：步数/胜负/档位三要素存量字段**已在**，时长无字段但有可信推导通道 → **主判「字段已在」，聚合导出微批方案候裁**（§4）；时长一等字段/摘要级归账字段两项为可选 schema 增补，若裁采纳随 v3.0 实施批（§5）

---

## 1. 需求源与盘点对象

**需求源（Q4 复审触发条款）**：
- v2.2 v1.2 §五.6（docs/design/difficulty-system-v2.2-draft.md L138，裁定⑥ Q4 落位）
- T-1015-OC-01 决策包 §5.2（docs/design/T-1015-OC-01-l1-carrier-decision-pack.md）
- 触发线初值：**人均对局步数 P50 < 40 步** 或 **新手胜率 < 80%** → 触发机型复审
- 数据域 = **产品域（真人对局）**，非 Tina 校准域；前置 = 统计机制立项（本地对局统计随 v3.0：步数/胜负记录+导出，无账号体系）；新手定义 = 本地对局数 ≤M 场近似（M 候产品面）
- 四要素：**步数 / 胜负 / 档位 / 时长**（§5.2 原文锚定数据 =「对人局长/胜率」）

**盘点对象（存量载体）**：
| 载体 | 位置 | 说明 |
|---|---|---|
| GameRecord | src/ChineseChess/Models/GameRecord.swift:29 | 全量记录，逐条 {uuid}.json 持久化 |
| RecordSummary | src/ChineseChess/Services/GameRecordStore.swift:5 | 列表摘要，index.json 常驻内存缓存 |
| GameRecordStore | 同上 :71 起 | 存储 = Documents/GameRecords/index.json + {uuid}.json；串行队列+原子写；孤儿回收 |
| GameMove | src/ChineseChess/Models/GameMove.swift | **每手带 timestamp: Date**（v2.0 起）+ halfmoveClock 快照 |
| StatsManager | src/ChineseChess/Services/StatsManager.swift:24 | 分档 win/loss/draw 计数桶（UserDefaults 域，无导出面，与记录域双轨） |

## 2. 字段映射表（四要素逐项）

| 要素 | Q4 需求 | GameRecord（全量） | RecordSummary（摘要/index.json） | 判定 |
|---|---|---|---|---|
| 步数 | 人均对局步数 P50（<40 触发） | `totalMoves: Int` | `totalMoves: Int` | ✅ **已在**，摘要级即可聚合，O(n) 内存 |
| 胜负 | 新手胜率（<80% 触发） | `result: GameState`（redWon/blackWon/draw，Enums.swift:21）+ `redPlayer/blackPlayer: PlayerInfo(isAI:)` | `result: GameState`（⚠️ **无执方归属维度**，见 G2） | ⚠️ **字段已在，人类视角归账维度摘要级缺** |
| 档位 | 新手域切片（L1/≤M 场）+ 分档统计 | `difficulty: AIDifficulty?`（导入记录可 nil）+ 双 PlayerInfo.difficulty | `difficulty: AIDifficulty?` | ✅ **已在**；S2 迁移已在加载边界单次应用（s2Migrated，7a19a2c/c4e92e0），聚合面所见即新体系语义 |
| 时长 | 对人局长（§5.2 锚定） | ❌ 无 duration/startedAt/endedAt | ❌ 无 | ⚠️ **未落一等字段，有推导通道**：`moves.first.timestamp → moves.last.timestamp`（见 G1） |

**域过滤依据**（两处均已在）：
- `source: RecordSource`（versusAI/puzzle/imported/freePlay）——产品域过滤 = `source == .versusAI`，摘要级即可
- 悔棋实证：GameViewModel.swift:369/379 `gameMoves.removeLast()`——悔棋回删 moves，余量 timestamp 仍单调有效，时长推导不受损

## 3. 缺口清单

**G1（时长无一等字段）——唯一字段级缺口**
- 影响面：仅 §5.2「对人局长」锚；**两条触发线初值（步数 P50/胜率）均不依赖时长**，不阻塞 Q4 落地
- 推导通道评估：versusAI 域 `moves.last.timestamp − moves.first.timestamp` 可信（含 AI 思考时间=真实墙钟局长）；**imported 域不可信**（PGN 导入时间戳非对弈真实产生，PGNImporter.swift:214 面）→ 聚合必须域过滤，与 Q4 产品域口径天然一致
- 若需一等字段：最小增补 = GameRecord/RecordSummary 各加 `startedAt/endedAt`（或 `durationMs`），`decodeIfPresent` 兼容旧档（旧档 nil=时长不可得，仅新档起计）；时序自洽——§5.2 观察期本就挂「v3.0 发布+统计机制上线」双条件

**G2（胜负的人类视角归账维度摘要级缺）——核查中发现，非直觉缺口**
- `result` 是执方语义（redWon/blackWon），RecordSummary 不含 PlayerInfo，**人机局人类方可执黑**（GameViewModel.swift:1071 `isHumanRed = humanSide == .red`，PuzzleViewModel:1084 同构）→ 不能假设人执红
- 现有零 schema 变更通道：versusAI 域逐条 `loadRecord(id:)` 读 `redPlayer.isAI` 归账（O(n) 文件 IO，千条级秒内）
- 可选 schema 微增：RecordSummary 加 `isHumanRed: Bool?`（decodeIfPresent，旧档 fallback=loadRecord 路径）

**G3（无导出面）**
- index.json / {uuid}.json 均在沙盒 Documents/GameRecords/，无 UI/API 出口；决策包 §5.2 要求「记录+导出」的导出半边现缺

**G4（双数据桶，流程面）**
- StatsManager 分档计数桶（UserDefaults）与 GameRecordStore 记录域（JSON）双轨并存，删记录不回退计数 → **Q4 触发判据应以 GameRecordStore 为唯一真相源**，StatsManager 仅作参考面，不作触发依据

## 4. 聚合/导出成本估（微批方案草案，候裁非实施）

| 项 | 口径 | 估 |
|---|---|---|
| 聚合器（摘要级） | loadSummaries() 内存聚合：域过滤 + 步数 P50 + 档位切片（含单测，纯函数） | 0.5 人日 |
| 胜负人类视角归账 | versusAI 域 loadRecord 读 isAI（零 schema 变更） | +0.25 人日 |
| 时长推导 | 同域 loadRecord 取 moves 首尾 timestamp | +0.25 人日 |
| 导出面（无 UI） | 聚合结果 JSON 写 Documents（文件级出口，无 UI） | +0.25 人日 |
| 导出面（含 UI） | 分享面板 + 文案（候产品面，可后置） | +0.5~1 人日 |
| **合计** | 无 UI 全口径 ≈ **1~1.25 人日**；含 UI ≈ 1.5~2.25 人日 | |
| 可选：时长一等字段 | schema 增补+写入点接线+兼容注记 | +0.5~1 人日（随 v3.0 实施批） |

## 5. 结论分支（按派单要求明确）

- **主判：字段已在**（步数/胜负/档位三要素存量齐备，胜负归账走零 schema 推导通道）→ **聚合导出微批方案候裁**（§4 草案，无 UI 口径 ≈1~1.25 人日）
- **时长：字段缺但推导通道可信且不阻塞触发线初值** → 建议「推导先行（微批内含），一等字段增补随 v3.0 实施批候裁」双轨
- 若 Luke 裁「一等字段路线」：最小 schema 增补清单见 G1/G2 括注，随 v3.0 实施批，本单不实施

## 6. 待裁点

1. 微批是否含时长推导与人类视角归账通道（+0.5 人日，零 schema 变更）
2. 导出面形态：无 UI 文件级 vs 分享面板（候产品面）
3. 新手口径：`difficulty == .novice` 切片 vs 「本地对局数 ≤M 场」（决策包 §5.2 原 M 口径，M 候产品面）——可并存双报，成本≈0
4. 时长/归账一等字段是否随 v3.0 立项（若认推导通道则 G1 关闭为一等字段「不需要」）

---
**依据索引**：GameRecord.swift:29 ｜ GameRecordStore.swift:5/:71 ｜ GameMove.swift:20（timestamp）｜ GameViewModel.swift:1071-1094（buildGameRecord/isHumanRed/undo:369）｜ Enums.swift:21（GameState）｜ v2.2 v1.2 §五.6 L138 ｜ 决策包 §5.2/§2.3
