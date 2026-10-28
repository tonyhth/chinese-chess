# T-1023-OC-01·Batch3 ②测试面三项 验收判词（Tina）— EvalConfigManager 竞态治理 + P3-N2 残面 + FINAL-011 落盘（d4205f2 + 606067b）

- **验收人**：Tina｜**日期**：2026-10-28 00:13-17:50｜**链**：编码（Cody）→ Ruby 审（B3TF-review 通过，附 P2×2/P3×2）→ **Tina 验（本件）** → 门禁
- **对象**：d4205f2（fix，5 files +173/-48）+ 606067b（docs，FINAL-011 记录 +105）
- **前置判词**：docs/reviews/T-1023-OC-01-B3TF-review-ruby.md（①NSLock 锁面通过 ②devMode 语义保留通过 ③P2-1 fd 泄漏窗口非阻塞发现——本件按派单要求覆盖其行为面旁证，见 §四）
- **结论**：**验收通过（PASS，附登记项 4 条）**——四项验收点全过；五套件最终锚 3+4+14+4+21 与证据 log 一致；testPerpetualCheck_RealDriven 环境敏感挂起在脱离上下文 2/2 复现（P4B1 §三.1 同判，非阻塞）；随批勘误四件在盘未提交（登记项①）

---

## 一、锚定与产物真实性

- HEAD=606067b=origin/m1（与 Ruby 锚定一致）；Ruby 判词件在盘未入库（untracked，随批入库面）
- **⚠️ 工作区含未提交勘误四件**（Ruby 判词随批处置响应，本验收复跑基线 = d4205f2+606067b+此四件）：
  1. src/ChineseChess/AI/EvalConfigManager.swift —— P2-1 修复（startMonitoring 丢跑分支 resume-then-cancel，源 mtime 10-27 19:36:37）
  2. src/ChineseChessTests/PuzzleDrawDetectionP4Tests.swift —— P3-2 失败迭代实录补录（注释面）
  3. docs/reviews/T-1023-OC-01-FINAL-011-execution-record.md —— P2-2 计数勘误（22/21→16/15）+ P3-1 L2-8 行号勘误（:987-995→:150/:352/:355/:1006-1009）
- **产物真实性（P4B3 同标准）**：测试代码载体 ChineseChess.debug.dylib mtime **10-27 20:26 ≥ 最新源编辑 19:36:37** ✅ 构建含最新源；旁证：verify2 增量构建 SwiftCompile 零行（dylib 已现态）+ 测试主二进制 stub 10-28 16:44 重建

## 二、四项验收点逐项

### ① EvalConfigManagerConcurrencyTests 8×300 零撕裂复跑 ✅
- **源码面**（EvalConfigManagerConcurrencyTests.swift 全读）：concurrentSetReadConsistency = `DispatchQueue.concurrentPerform(iterations: 8)` × 内层 0..<300 交替写读，快照必须 ∈{变体a,变体b}（violations==0 断言=零撕裂）+ 终值收敛断言；setWeightsReadback 逐字段相等；devModeToggleIdempotent true/true/false/false ×50 钉幂等门。全程测试专用实例（configURL=/dev/null）零触碰 shared
- **复跑**：verify2 首套件 ✔ Test run with 3 tests passed after 0.008s（h1/EvalConfigManagerConcurrencyTests-164404.log）；与证据链 tests4（10-27 19:38，3/3 绿）一致

### ② isCheck 真驱动双断言 + 无进攻子力分支正负对照 ✅
- **源码面**：DrawDetectionRealTests testGameMove_IsCheck_Recorded——①安静着法（炮二平五）isCheck==false ②红车 (3,3)→(3,4) 直将黑将 (0,4) isCheck==true；真实走子驱动（makeCoachMove 后读 gameMoves.last?.isCheck），占位断言已清偿
- 无进攻子力（PuzzleDrawDetectionP4Tests insufficientOffensiveMaterialDraw）：正对照 FEN 3a1k3/9/…/3K1A3（双侧仅将士）checkDraw==**true**；负对照行7补马 4N4 → checkDraw==**false**；三次重复真驱动 + 120 半着单源钉在位
- **复跑**：PuzzleDrawDetectionP4Tests ✔ 4/4（verify2 17:14:28，与 tests3 一致）；testGameMove_IsCheck_Recorded 在 verify2 过清单（10 passed 内）✅

### ③ FINAL-011 记录 47 项与在盘证据一致性 ✅
- **计数自洽**：47 = L1×12 + L2×13 + L3×8 + S×8 + L5×6；P0 明细 31（L1★5+L2×13+L3×8+S★3+L5★2）全 Pass；P2 面 = **16 = 15 未执行 + 1 部分核对（L5-5）**——P2-2 勘误后与逐表明细严格一致（原 22/21 系已声明弃用的汇总口径残差，勘误正确）
- **A 级锚点独立抽查 6 处全中**：BoardSizing:58 max(basePadding, cellSizeEst*0.45)；ImportViewModel:9 failure(String)/:15 fail()；GameViewModel challengeResult :150 声明/:352-355 success·failure/:1006-1009 Phase2 补全块（P3-1 勘误后锚正确，原 :987-995 现为成就代码属实）；undoMove:379 精确匹配；销账方法 :833-839（testGetHalfmoveClock 等四件 DEBUG 辅助在位）；BoardView:25-27 challengeResult alert 绑定
- 8 Bug 反向追踪矩阵 8/8 ✅；「不重开检查单」边界纪律：v5.0-cross-quality-check.md 原文零触碰 ✅

### ④ 五套件计数行（证据 logs/t1023-tf-tests-1027.log 系列）✅
| 套件 | 申报 | 主日志 | tests2 | tests3 | tests4 | 最终锚 |
|---|---|---|---|---|---|---|
| EvalConfigManagerConcurrencyTests | 3 | ✔3 (:6528) | — | — | ✔3 (:284) | ✅ |
| PuzzleDrawDetectionP4Tests | 4 | ✘ :88:9 (:6741) | ✘ :89:9 (:190) | ✔4 (:1016) | — | ✅ |
| DrawDetectionRealTests | 14 | Executed 14, 0 fail (:7097) | — | — | — | ✅ |
| CMAESWeightInjectionTests | 4 | ✘ :24:9 (:7284) positionWeight 1.0≠3.0 | ✔4 (:592) | — | — | ✅ |
| EvalWeightsTests | 21 | ✔21 7.061s (:7734) | — | — | — | ✅ |

- 五套件最终锚 **3+4+14+4+21 全绿**与 commit message 申报一致；踩坑链完整可溯（PuzzleDraw 两次失败迭代 :88:9→:89:9 与测试注释失败迭代实录逐条吻合=P3-2 补录后申报完整；CMAES 并行竞态 :24:9→.serialized 后 tests2 绿）

## 三、独立复跑链（Tina，owner=tina 互斥通道）

| 批 | 时间 | 结果 |
|---|---|---|
| ~~001549~~ | 00:15 | **作废销案**（cell 退场连坐整树被杀，Luke 裁定；根因吸取=脱离通道升级 exec background） |
| verify2 五套件 | 16:44:04-17:15:00 | **4/5 绿零 issue**（3✔ / timeout / 4✔ / 4✔ / 21✔6.746s）；DrawDetectionRealTests 10/14 过，挂 testPerpetualCheck_RealDriven，1800s kill |
| verify3 单套重试 | 17:18:04-17:48:04 | 10/14 过，**同挂同点**，1800s kill——脱离上下文 **2/2 复现** |

**RealDriven 挂起定谳（非阻塞）**：环境敏感挂起，P4B1 §三.1 同判同签名（started 后零输出→kill）。对照面：Cody 本批证据跑 2.584s 过、P4B1 空闲复跑 14/14 绿 0.223s、本验收脱离上下文 2/2 挂——与 KI-2026-0913-01 家族「hung before establishing connection」争用窗口表现一致，**非产品码缺陷、非本批引入**。验收重点用例全部在过清单；未达 3 用例由证据 log 14/14 完整绿锚（主日志 :7097，2.793s）覆盖。

## 四、Ruby 前置判词核验（派单前置项）

- ① **NSLock 锁面**：独立核对现态——唯一 stateLock、锁内纯赋值/拷贝、装源复核段不持锁 open()、handleFileChange 锁外 reload，与 Ruby 判词一致 ✅
- ② **devMode 语义保留**：didSet `devMode && !isMonitoringActive()` 判定结构/分支顺序在位，仅读取方式加锁 ✅
- ③ **P2-1 行为面旁证（派单要求）**：修复在位（:122-129 resume-then-cancel + 判词引注）；行为旁证 = devModeToggleIdempotent **200 次真实启停切换**（50 循环×4 赋值）零崩溃零权重扰动（verify2 ✔）+ 丢跑分支语义收敛（resume 使源进入已交付态再 cancel，cancel handler close(fd) 确定落地，fd 泄漏窗口关闭）

## 五、用户路径覆盖审查

本批触碰面 EvalConfigManager（AI 配置管理层，无直接 View 变更）：

| # | 用户操作 | 入口 | 链路 | 空数据保护 | 错误处理 | 用户反馈 |
|---|---|---|---|---|---|---|
| 1 | devMode 开关 | 设置项 didSet | start/stopMonitoring | isMonitoring 幂等门+装源复核 | open() 失败 guard return | 无直接 UI（后台监控行为） |
| 2 | 评测配置热替换 | 文件系统 source | handleFileChange→reload→weights | modDate nil guard | try? 静默回退 | AI 强度随权重变化 |
| 3 | 权重读写（CMAES/自弈） | setWeights/weights | NSLock 串行化 | /dev/null 读安全（load 空/坏数据回退 .default） | partial 解码回退 | 引擎对局表现 |

- **缺失项：无新增 P1**。本批为管理层竞态治理+测试面，用户可见行为零变更（didSet 语义逐字保留）；FINAL-011 P2 面 15 项未执行（主题/深色/字体/iPad/旋转/端到端场景）系既有用户路径验证欠账，候真机验证轮按件销账，非本批引入

## 六、观察项（不阻塞，登记）

1. **勘误四件未提交**：P2-1/P2-2/P3-1/P3-2 随批处置响应均在工作区——须随本验收收口 commit 入库，否则在盘判词与 HEAD 锚漂移（建议 Cody 随收口批提交）
2. **RealDriven 引擎链路 mock 断开**（P4B1 移交项①，仍未清偿）：本批脱离上下文 2/2 复现挂起强化其必要性，tests-only，建议 Cody 排期
3. **20:26 零字节 CMAES log**（h1/CMAESWeightInjectionTests-202629.log）：10-27 20:26 一次未申报起跑的构建残留（dylib 同刻落地），无测试终态；来源待 Cody 知悉登记
4. 001549 死批销案（Luke 裁定 2026-10-28）；根因已吸取（nohup-挂前台 cell → exec background 通道）

## 七、判定

**验收通过（PASS，附登记项）**：四项验收点全过 ✅；五套件最终锚与证据 log 一致 ✅；Ruby 四项随批处置全部响应且勘误正确 ✅；RealDriven 挂起为已立案环境敏感面（先例同判）非阻塞 ✅；红线五项零触碰（本批 diff 全清单复核：零 L10n 锁表/零 xcstrings/零 s2MigrationMap/零定稿件/零 Enums 单源面）✅。

> 判词落盘即验收完成。交下游：sessions_send(lead) + feishu 双写。
> Tina 2026-10-28

---
*验收人：Tina｜d4205f2+606067b+随批勘误四件｜2026-10-28｜复跑证据：/tmp/t1023-b3tf-verify2/ + /tmp/t1023-b3tf-verify3/ + h1 逐套件日志（164404/164428/171428/171439/171446/171804）*
