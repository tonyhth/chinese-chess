# T-1023-OC-01·P4·Batch 1 验收判词（Tina）

> 验收人：Tina（tester）| 日期：2026-10-21 | 对象：43d43d2 / 22aa9ed / daec845（基座 1cfd109）+ 前置隔离修法笔 694a68a（丹妮裁准方案 a）
> 验收基线：694a68a（daec845+隔离修法一笔，产品码零增量）| Ruby 审查：docs/reviews/T-1023-OC-01-P4B1-review-ruby.md（零返工）
> 验收方式：隔离检出 worktree ~/DevTeam/worktrees/t1023p4b1-verify-694a68a（不触碰主仓 Cody Batch 2 WIP）+ run-tests-mutex 单通道 RUNNER_OWNER=tina（前台豁免通道，KI-2026-0913-01 四象限口径）

## 一、静态面核验 ✅

- 三 commit diffstat 与 Ruby §一逐字合：43d43d2=5 files +225/-42（DrawDetectionRules 新 22L/GameViewModel 21/PuzzleViewModel 34/DrawDetectionRealTests 108/PuzzleDrawDetectionP4Tests 新 82）、22aa9ed=10 files +77/-59（RiverTextView 新 44L+5 视图接线+三测试钉）、daec845=1 file +2（Info.plist）
- 694a68a tests-only 实证：仅 UXAdaptationTests.swift +13，产品码零增量 ✓
- 静态残查三零：Text("楚 河汉界=0 / Button("OK")=0 / halfmoveClock >= 100=0
- naturalDrawHalfmoveLimit 单源：DrawDetectionRules.swift:21=120；消费 GameViewModel:125(alias)/:800 + PuzzleViewModel:563(直引)——Ruby P3-1 风格注记如实（alias vs 直引并存，功能等价）

## 二、测试批结果（七套件）

| 套件 | 结果 | 备注 |
|------|------|------|
| DrawDetectionRealTests | **PASS（复跑定谳）** | 首跑 timeout 1800s（见 §三）；空闲复跑 14/14 全绿 0.223s，含 A1 边界新用例 testNaturalDraw_Boundary119NoDraw_120Draw passed 与 A4 回归钉 |
| DrawDetectionTests | PASS | |
| UXAdaptationTests | **PASS（:534 转绿实证）** | Test "走棋 + 悔棋 回归" passed 0.012s（694a68a 隔离修法生效）；翻转钉 passed（consumesComponent+!hasHardcoded 双断言）；42 passed |
| V2215Tests | FAIL(65) | **存量守卫断言过时**（§三.2，非本批引入） |
| D5I18nAuditVerificationTests | FAIL(65) | **存量期望值过时**（§三.3，非本批引入） |
| GameViewModelTests | PASS | |
| Phase1P0Tests | PASS | |

出处：~/DevTeam/workdirs/logs/h1/（121132/124132/124145/124159/124238/124301/124308 七 log）+ 复跑 h1/DrawDetectionRealTests-124704.log

## 三、三异常定谳

### 3.1 DrawDetectionRealTests 首跑 timeout → 环境敏感，复跑定谳非本批问题 ✅
- 现象：首跑（12:11:32 起）挂起于 testPerpetualCheck_RealDriven started 后 30 分钟零输出，runner 1800s kill
- 双证据链：①Cody 同 commit 同 runner 通道批跑全套 14 tests 0 failures（Ruby §三，t1023p4b1-tests-final-1022.log L205-209）；②本验收空闲复跑（12:47，校准批清场后）同套件 14/14 全绿 0.223s
- 定谳：**环境敏感挂起**（测试宿主内引擎建连链路在资源争用窗口偶发挂起，KI-2026-0913-01 "hung before establishing connection" 同族表现）——首跑起跑时 T-1022 S1 校准批并存（12:11 vs S1 12:12 kill）。非产品码缺陷（detectPerpetualCheck/applyMove 逻辑经 Cody 批+本批复跑+120 边界用例三重验证）、非 Batch 1 引入
- 测试体审读附注：testPerpetualCheck_RealDriven 走 makeCoachMove+coachConfig(aiDifficulty:) 路径——测试环境内 coachConfig 场景是否应触发引擎链路，建议 Cody 随批评估（如可 mock 断开则彻底免疫环境敏感；tests-only 不阻断）

### 3.2 V2215Tests FAIL(65) → 存量守卫断言过时（豁免呈请）⚠️
- 失败体："Views 中硬编码 .system(size:) 数量跟踪" Expectation failed: (hardcodedCount → 96) <= 30
- 定谳：①96 处清单内大量为 .font(.system(size: LayoutSpec.fontSizeXxx)) **语义常量形态**（非字面魔法数），计数器把语义常量误计入=守卫正则过宽；②阈值 30 与现状 96 的差距系累积性（非本批新增——Ruby §二已注记 V2215Tests:392 本批仅改注记"守卫惰性保留"；Batch 1 diff 零触碰该断言逻辑）
- 处置呈请：存量豁免（同 fallback 口径）+ 守卫计数器修正（排除 LayoutSpec 形态）登记 Batch 2 tests-only 项

### 3.3 D5I18nAuditVerificationTests FAIL(65) → 存量期望值过时（豁免呈请）⚠️
- 失败体（2 issues 同型）：en[difficulty.lvl3] 期望 'Intermediate' 实际 'Amateur 3D'（:122）；zh-Hans[difficulty.lvl3] 期望 '中级' 实际 '业余三段'（:142）
- 定谳：测试期望值停留在**难度体系换轨前命名**（v6.4.1 L10n 段位制全量换轨的漏网测试面——现行 S2 锁表 lvl3=amateurLow=业余三段/Amateur 3D 为正）；Batch 1 对 D5I18n 仅 +1 行注记，断言零触碰，非本批引入
- 处置呈请：存量豁免 + 期望值随 S2 锁表更新登记 Batch 2 tests-only 项（六维 i18n 域 Eric 交叉知悉）

## 四、逐项验收结论

| 项 | 验证标准（§十三） | 实证 | 判定 |
|----|------------------|------|------|
| A1 60 步规则合规 | DrawDetection 系改断言+120 边界用例 | testNaturalDraw_Boundary119NoDraw_120Draw passed；119 不判和/120 判和边界语义断言在位；残查 >=100 零命中 | ✅ |
| A4 fingerprint 对称化 | dim2 P1-N1 四件标准 | Puzzle 侧换完整 FEN（Ruby 验生死点）+双侧形态统一+回归钉 passed+PuzzleDrawDetectionP4Tests 新 82L 在位；dim2 报告 P1-N1 随本批落地核销 | ✅ |
| B7 riverText 单源化 | 共享组件+键接线+钉翻转 | RiverTextView 44L+12 处接线+翻转钉双断言 passed+残查 0 | ✅ |
| B4 回放翻转闭环 | 并入 B7 | BoardCanvasView isFlipped 透传（N-1 变体消灭） | ✅ |
| B5 OK×7 键化 | l10n.t(common.ok)×7 | :246/270/1001/1006/1114/1119/1127 全部改引，残查 0 | ✅ |
| F2 恒深色显式化 | Info.plist 显式声明 | UIUserInterfaceStyle=Dark +2 在位 | ✅ |
| （前置）:534 转绿 | 隔离修法生效 | "走棋 + 悔棋 回归" passed 0.012s | ✅ |

## 五、结论

**Batch 1（A1/A4/B7+B4/B5/F2）五件交付验收 PASS**——实现面、证据链、红线全部通过；:534 转绿实证；A1/A4 验证标准（含 dim2 P1-N1 四件）逐项落位。

**两存量守卫失败（V2215/D5I18n）豁免呈请**：证据链完整（diff 零触碰+失败体均系换轨前/守卫过时的既有状态），不在丹妮预登记 fallback 清单内（清单仅 1 项 :534 系），故**不自行豁免**，呈丹妮裁定：a) 扩围豁免（两件登记 KI+Batch 2 tests-only 修正）不阻塞 tag；b) 或维持严格门待守卫修正。Tina 建议 a（两件均 tests-only 量级、产品码零关联）。

**随件移交**：①testPerpetualCheck_RealDriven 环境敏感挂起——建议 Cody 评估 coachConfig 场景测试的引擎链路 mock 断开（tests-only）；②preflight 五检查点未覆盖 data/pgn-extracted+opening-categories.json（本验收踩坑补齐，建议 KI 登记+preflight 扩点）；③V2215 计数器排除 LayoutSpec 形态修正。

> 判词落盘即验收完成。完成回执丹妮终记台账。
> Tina 2026-10-21
