# T-1017-OC-01 统计机制聚合导出 Vera 全审单（v3.0 实施批首单代码）

> **审查人**：Vera（inspector；Luke 指派代行代码面全审，设计规格忠实性为本审主轴）｜**日期**：2026-10-17 深夜
> **对象**：commit 75f06e0（m1 @033277b，未合入候判词）——src/ChineseChess/Services/GameRecordStatsAggregator.swift（573L 新）+ src/ChineseChessTests/T1017OC01GameRecordStatsTests.swift（375L 新，15 测试）
> **规格锚**：docs/plans/T-1016-OC-01-q4-review-data-inventory.md §2/§4/§6（G1-G4）+ Luke 双域统计口径四裁定（校准域 <20 剔除单列异常/产品域全计含超短局/0 步类完整性告警不计入/阈值可调）
> **取证基线**：git show 75f06e0（stat/name-only/diff 实证）+ 双源码全文 + 测试 log（workdirs/logs/h1/T1017OC01GameRecordStatsTests-230431.log，"Test run with 15 tests passed"+TEST SUCCEEDED，xcresult /tmp/xc-mutex-dd）+ 导出样例（~/DevTeam/logs/t1017-oc01-export-sample.json，**全量数值手工逐格复算**）+ Enums.swift:29 枚举实证 + T-1016-OC-01 memo 全文
> ⚠️ **派单撤销注（2026-10-17，Luke main）**：本单系 feishu 通道重复派发产出（6276e6fc 已撤销；代码审查线按交付 DoD 归 Ruby，T-1017-OC-01-R 为准）——本审查单降级为**交叉验证参考留档**，不作合入授权依据；判词/P3×6/裁量裁语供 Ruby 线互证

---

## 判词：**通过**（P0×0 / P1×0 / P2×0；P3×6 全部非阻塞登记随下触）

四项裁量全部裁「**留**」。通过→可合入 main（Luke 面）→汇编呈洪涛收口 v3.0 实施批。

## 七审面裁定

### ① 双域口径忠实性 ✓

四裁定逐条落位：**裁定①** 校准域 totalMoves < 阈值剔除主判据、单列 ultraShortAnomalies（含 recordId+步数明细）；**裁定②** 产品域全计含超短局（ultraShortCount 系观测面，注释明示"主判据仍全计，供阈值校准"）；**裁定③** 0 步类走完整性告警不计入统计——且与裁定①正确分层：0 步不入超短异常列表（0 步≠超短局），两域一致；**裁定④** 阈值 GameRecordStatsConfig.ultraShortMoveThreshold=20 可调+max(1,·) 防呆。memo §4 四通道全落位（域过滤摘要级 source==.versusAI／人类归账 loadRecord 读 isAI 零 schema／时长推导 moves 首尾 timestamp 仅 versusAI／导出文件级无 UI）；§6 待裁点全响应（新手双报并存／推导先行零 schema／无 UI 形态）。

### ② 统计计算正确性 ✓（导出样例全量手工复算逐格吻合）

P50 标准定义（奇取中/偶取均/空 nil，四形态测试在）；均值/min/max ✓；档位切片按 rawValue 分组升序、unspecified 殿后 ✓；新手双报 ✓（口径 a=.novice 切片；口径 b=设备级 counted 总数 ≤M——M nil→isNovicePhase nil+显式 note，M 设→bool）；人类归账镜像（不假设人执红，humanOutcome 按执方镜像，winRate 分母=已终局单人类局）；时长推导 last−first（倒序→nil 剔除+告警，步数胜负不受累）。**样例 9 局复算**：product p50=45/mean=43.6 ✓；novice 切片 [12,31,45]→p50=31/winRate=1/3 ✓；归账 win2 loss2 draw1=0.4 ✓；时长 min330/p50 1320/max 2310/mean 1278 ✓；校准 primary [118]+anomalies [15] ✓；q4 对照 45≥40 false、1/3<0.8 true ✓。

### ③ GameRecordStore 只读 + StatsManager 零依赖 ✓

聚合器仅触 store.loadSummaries()/loadRecord(id:)（生产入口+可注入入口分离，单测经 recordProvider 闭包零 store 直依——测试架构面加分项）；**StatsManager 零符号引用**（memo G4：双桶不作触发依据）——q4TriggerCheck 纯信息面零动作（note 明示"判定与复审决策归产品面"），与 G4 同构自洽。

### ④ imported 域时间戳不可信过滤完备 ✓（无泄漏通道）

域过滤摘要级先行（仅 versusAI 摘要深读）→ imported 永不入 product/calibration 深读面；时长推导仅在产品域 counted 内发生；校准域无时长面；otherSources 仅计数+理由披露。imported 记录的时间戳无任何消费路径。边界自洽：单步局 first==last→duration 0 计入（产品域全计语义一致）；倒序→剔除+告警+计数（durationInvalidCount）。

### ⑤ 测试套件质量 ✓（15 测试对七审面覆盖充分；漏测 2 项见 P3-4）

口径四规则（双域拆分/校准单列/零步双域/产品全计+阈值观测）、P50 四形态、归账双向镜像+bothHuman 排除、unfinished 剔除分母但保留步数、时长正反例、双报 M 三态（nil/M=4 ✓/M=3 ✗）、q4 对照、孤儿摘要 loadFailures、导出往返（**iso8601 解码策略显式设置+全 report 等值断言**——编码解码策略匹配，往返真闭环）、样例收割测试（合成 9 局=交付样例同源，provenance 干净）。

### ⑥ 四项裁量：全部「留」

| 裁量 | 裁定 | 理由 |
|---|---|---|
| q4TriggerCheck 信息面对照节 | **留** | Q4 判定权归产品面（G4 同构）；零动作+note 显式，无触发机制化越界 |
| 4 类防御性告警扩展（moveCountMismatch 观测面仍计入/timestampOrderInvalid 仅剔时长/unfinishedResult 不入胜率分母/recordFileMissing 域不可定挂总面） | **留** | 语义各自正确且相互正交（步数/时长/胜率/全域四层互不误伤），均有测试锚，零静默 |
| bothHuman 单列计数 | **留** | 双人类局不入单视角胜率正确（本地双人无"新手 vs AI"语义），单列披露零丢弃 |
| otherSources 零静默丢弃 | **留** | 计数+逐源理由（imported 时间戳不可信/puzzle 非完整局/freePlay 非目标源），审计面完整 |

### ⑦ 导出 JSON 结构与原子写 ✓

结构与样例逐字段吻合（schemaVersion/task/generatedAt/config/双域报告/otherSources/loadFailures 全嵌套面）；`.atomic` 写+文件名戳固定 en_US_POSIX+Asia/Shanghai（跨机确定性）✓；prettyPrinted+sortedKeys 利 diff/审计 ✓。

## 生产零触碰实证

033277b→75f06e0 diff 在 EngineRouter/Enums/engine 面**空输出**（dispatch 声称亲证吻合）；commit 仅二文件 948 行新增；谱系干净（033277b=T-1016-OC-03 裁量⑥注记行，c4e92e0=迁移主体）。

## P3×6（非阻塞，登记随下触）

1. **q4TriggerCheck 口径披露**：noviceWinRate 取口径 a（.novice 切片）——M 未定口径 b 不可算，选择被迫但字段 note 未显式口径来源；一行 note（"新手胜率取口径 a 切片；口径 b 候 M 定"）随下触。
2. **校准域缺 moveCountMismatch 检查**（产品域有）：机对机 totalMoves≠moves.count 会进主判据样本——防御对等性候补（低风险：harness 受控源）。
3. **record.source 与 summary.source 一致性未抽验**：index/record 深读错配（极低概率）无防御——与 moveCountMismatch 同族，随下触。
4. **漏测 2 项**：①校准域边界 totalMoves == threshold（=20 应入主判据——现仅 15/45 两点，边界未钉）②moveCountMismatch 告警路径未触发过（totalMovesOverride≠moveCount 组合未测）。
5. **裁定卡证据链**：harness 卡 7328c9fc workboard_read 直达失败（card not found；docs/plans/T-1011-luke-holistic-re-review.md:51 在案其存在）——裁定原文以派单权威引文+聚合器头部引文**双源一致**承证，本审判定不受影响；建议台账行补卡全 id/链接。
6. **tierKey 对 rawValue 格式隐式耦合**：AIDifficulty.rawValue 系自定义 "lvlN" 字符串（Enums.swift:29 声明无原生 Raw type，实证 sample tierKey lvl1/lvl2/lvl4）；tierOrder 硬解析 "lvl" 前缀——rawValue 格式漂移会静默降级排序，而符号化测试（.rawValue）不捕获格式变更。一行注释或字面值锚测试随下触。

## 交付记录

- 完整判词→Cody（sessions_send agent:coder:main）＋群消息完整件；摘要→Luke（lead:main 若 restart recovery 由群承载）＋群消息摘要件
- （runId/om id 见 CURRENT_TASK.md 本任务条目）
