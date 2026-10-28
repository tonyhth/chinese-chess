# T-1023-OC-01 · Batch3 ②测试面三项 · Ruby 审查判词

- 日期：2026-10-27
- 审查者：Ruby（reviewer）
- 对象：d4205f2（代码批，5 files +173/-48）+ 606067b（docs 批 FINAL-011 记录 +105）
- 锚点：HEAD=606067b=origin/m1（远端推送亲证）；父 5819cc7
- 审查方式：只读；git 实况独立验证 + 全文件锁面审计 + 日志取证 + FINAL-011 锚点抽查

## 一、变更清单独立验证（防漏报）

git show d4205f2 --stat 与 Cody 申报逐行一致：EvalConfigManager.swift 79±、Batch1P0CMAESTests 5±、DrawDetectionRealTests 54±、PuzzleDrawDetectionP4Tests +15、EvalConfigManagerConcurrencyTests +68（新增）；606067b 仅 docs/reviews/T-1023-OC-01-FINAL-011-execution-record.md +105。**无漏报文件，无未申报 diff。**

## 二、五个审查点逐项判定

### ① NSLock 锁面 —— 通过（附 1 处 P2）

- **无嵌套无死锁**：stateLock 为全文件唯一锁；weights getter/setter 锁内纯赋值/拷贝；isMonitoringActive 纯读；startMonitoring 两段锁（首检段/装源复核段）之间不持锁，open() 与 makeFileSystemObjectSource 均在锁外；handleFileChange 锁外调 reload()（reload→weights setter 二次拿锁非嵌套）。锁内无任何可能再触锁的调用路径，死锁面为零。
- **deinit 锁面**：deinit→stopMonitoring 拿锁；deinit 时引用计数归零，不可能有他线程持本实例锁。event handler [weak self] 不阻止 deinit；cancel handler 值捕获 fileDescriptor 不捕获 self——无环、无 deinit 阻塞。
- **init 直赋 _weights 不走锁**：正确。对象未发布前无并发可达（Swift 内存模型），stateLock 为 let 声明处初始化先于 init body。测试初始化器 configURL=/dev/null 与原行为一致。
- 🟡 **P2-1（代码面，不阻塞）**：startMonitoring 丢跑分支（d4205f2 后 :122-125）对**从未 resume 的 suspended source** 调 cancel()。dispatch_source_set_cancel_handler(3) man page 亲证："Newly created sources are created in a suspended state...must be activated by a call to dispatch_resume() before any events will be delivered"——suspended 态下未 resume，cancel handler（close(fd)）交付无保证 → **fd 泄漏窗口 + 注释「fd 由 cancel handler 关闭」在该分支前提失真**。触发面：双线程同时通过 :96 首检（devMode 多线程写场景，纵深防御分支）。建议修复（一行）：该分支 resume() 后再 cancel()，或直接 close(fileDescriptor) + source.cancel()。对照：stopMonitoring 路径 cancel 的是已 resume 的 source，handler 确定执行，无此问题；unlock→resume 窗口被 stopMonitoring 插入时序为 resume-then-cancel，安全。

### ② devMode didSet 语义保留 —— 通过

判定逻辑逐字等价：devMode && !isMonitoring → devMode && !isMonitoringActive()（仅读取方式加锁，判定结构/分支顺序/重试语义全保留）；didSet 每次赋值必触发（Swift 语义，含同值赋值）不变，重复赋值重试起监控语义由 ConcurrencyTests devModeToggleIdempotent（true/true/false/false × 50）钉住。**语义保留完整。**

### ③ CMAESWeightInjectionTests .serialized —— 认可

- 批注准确性核实：套件 4 测试中 3 个动 shared（weightInjectionViaSetWeights / evaluateFitnessInjectionPattern / evaluateFitnessRestoreBestWeights 逐一确认），individualEncodeDecodeRoundTrip 不动——批注「3 个改 shared」准确。
- 先例对齐：EvalWeightsTests.swift:7 @Suite(.serialized) 在案。
- 竞态实锤在案：主日志 :24:9 positionWeight → 1.0 == 3.0 failed（19:02），加 .serialized 后 tests2（19:10）4/4 pass——修复闭环有日志证据。
- **定性认可：既有测试基础设施修复（Swift Testing 套件内默认并行 vs 动 shared 的写写/写读踩踏），非本批引入缺陷。**新增 ConcurrencyTests 全程专用实例零触碰 shared，与 Batch1P0 双套件并行隔离，设计一致性好。

### ④ FINAL-011 记录证据分级 —— 基本诚实，附 1 P2 + 1 P3

好面（亲证）：
- 口径注记主动登记 §5.4 汇总 25 vs 明细 31 不一致，声明按明细口径落盘——诚实
- 47 项 = L1×12+L2×13+L3×8+S×8+L5×6，逐表 Pass/未执行计数自洽；P0 明细 31（5+13+8+3+2）自洽
- A 级锚点抽查 5 处 4 中：BoardSizing:58 ✅ 精确命中；AnalysisViewModel:139/:227 ✅ 引擎不可用兜底在位；chineseNotation 6 处 ✅（AnalysisViewModel:246/PositionAnalyzer:387/OpeningExplorerService:122,170,209/PGNImporter:331 逐一命中）；SheetDestination 17 case ✅（:155-190 逐 case 清点=17，id 映射在位）
- L5-5 部分核对诚实（macOS 亲证 + iOS 候验证轮不冒进）；21 未执行如实登记候真机轮

🟡 **P2-2（记录面）**：**汇总节 P2 计数口径回摆**——「P2 面（22 项）：1 部分核对+21 未执行」与自身逐表明细不符：逐表实数未执行 15 项（L1×7+S×5+L5×3）+ L5-5 部分核对 1 项 = **16 项**。22 = 47−25 系用口径注记中**明确声明弃用**的「彼时汇总口径」残差推出——前文弃用汇总数，汇总节复用，自相矛盾。多出的 6 项即汇总口径 25 与明细口径 31 之差（实为 P0 明细项）。后果：真机验证轮按 21 项销账将出现 6 个幽灵项。建议勘误为 16（1+15）。
🟡 **P3-1（记录面）**：L2-8 行号锚点漂移——声称 challengeResult 在 GameViewModel:987-995，现态该区间为成就解锁代码；challengeResult 赋值链实际 :150/:352/:355/:1006。功能在位、判定不受影响，但 A 级证据可审计性受损，建议随批勘误行号。

### ⑤ 红线五项 —— 零触碰

本批 6 文件（5 代码/测试 + 1 docs）全清单在案：零 L10n 锁表、零 xcstrings、零 s2MigrationMap、零定稿件、零 Enums/单源表面。**红线全绿。**

## 三、测试结果独立验证（日志取证）

| 套件 | 申报 | 日志实况 | 判定 |
|---|---|---|---|
| EvalConfigManagerConcurrencyTests | 3 | 主日志 ✔ Test run 3 passed | ✅ |
| PuzzleDrawDetectionP4Tests | 4 | 主日志 ✘(:88:9) → tests2 ✘(:89:9) → **tests3 ✔ 4 passed (19:14)** | ✅ 最终锚成立 |
| DrawDetectionRealTests | 14 | 主日志 Executed 14 tests, 0 failures | ✅ |
| CMAESWeightInjectionTests | 4 | 主日志 ✘(:24:9) → **tests2 ✔ 4 passed (19:10)** | ✅ 最终锚成立 |
| EvalWeightsTests | 21 | 主日志 ✔ Test run 21 passed (7.061s) | ✅ |

申报的两次踩坑与日志吻合：FEN 10 列被拒（:88:9 testCheckDrawNow→false，FENDecoder:66 col==9 guard 亲证）+ CMAES 并行竞态（:24:9 positionWeight 1.0≠3.0）。测试注释已录摆位纪律①行宽 9 列、②双将异列避对脸。

🟡 **P3-2（申报面）**：PuzzleDraw 实际经历**两次**失败迭代——tests2（19:10）:89:9 的第二次失败（FEN 已 9 列仍 testCheckDrawNow→false，对应摆位纪律②对脸踩坑）未在交审申报中点名，申报文案仅录「行宽 9 列纪律踩坑一次」。注释与日志均在案不属隐瞒，但申报完整性欠一格：后续踩坑申报请按失败次数逐次列明。

## 四、判词

**代码面：通过。**竞态治理锁形制正确（唯一锁、零嵌套、init/deinit 域安全）、行为零变更主张成立（didSet 逐字等价+纯同步化）、.serialized 处置认可、P3-N2 残面清偿真实落地（占位断言转真驱动双断言 + 无进攻子力正负对照 + 销账方法 GameViewModel:833-839/PuzzleViewModel:591 亲证在位）、红线零触碰、五套件最终全绿锚逐一套件在案。

**不阻塞合入。随批处置面（均一行级/文案级）：**
- P2-1：startMonitoring 丢跑分支 suspended-cancel fd 泄漏 + 注释前提失真——建议 resume-then-cancel 修正
- P2-2：FINAL-011 汇总 P2 计数 22/21 → 勘误 16/15（弃用汇总口径残差）
- P3-1：FINAL-011 L2-8 行号 :987-995 → 勘误 :150/:352/:355/:1006
- P3-2：踩坑申报按失败次数逐次列明（本次 tests2 :89:9 第二次失败补录知悉即可）

证据等级说明：本判词全部结论有命令输出/日志行/文件行号锚点，审查过程零写代码、零 commit。

---
*审查者：Ruby｜d4205f2+606067b｜2026-10-27｜判词落盘即完成（2026-10-18 丹妮协议：三方通知由 lead sweep 代行）*
