# T-1023-OC-01·P4·Batch 1 审查判词（Ruby）

> 审查人：Ruby（reviewer）| 日期：2026-10-21（原笔误 10-22，经丹妮节点审查更正 10-21）| 对象：m1 三 commit 43d43d2/22aa9ed/daec845（基座 1cfd109）
> 验收链：编码→**Ruby**→Tina→门禁→tag | 底稿：docs/design/t1023-remediation-plan.md §十三
> 审查方式：全程只读（git show/diff + 定点读码 + 测试证据 log 实读），未跑测试批、未改码

## 一、真实性验证与变更清单独立核对

- 三 commit 与申报完全一致：43d43d2（A1+A4，5 files +225/-42）、22aa9ed（B7+B4+B5+钉翻转，10 files +77/-59）、daec845（F2，1 file +2）
- 汇总 stat 16 files +304/-101 与申报逐字吻合；工作树净（untracked 均为 P2 审计 docs，预期内）
- **变更清单独立验证 PASS**：实际 diff 面无超出申报清单的文件；UXAdaptationTests 批内变更仅 8+/6-（:707-717 河界钉区，:534 存量失败用例零触碰——引入性排除的直接证据）

## 二、逐项审面

### A1 自然限着 120 半着（合规修正）✅
- 单源成立：DrawDetectionRules.naturalDrawHalfmoveLimit = 120（新文件，裁决链四要素齐备：dim1 立案→丹妮 10-21 裁→洪涛 10-22 07:06 拍板→竞赛规则口径，逐字在注释）
- 双消费点改引：GameViewModel:118-121 阈值属性区 alias + :796 `halfmoveClock >= naturalDrawHalfmoveLimit`（原 100）；PuzzleViewModel:562 直引 enum
- 边界语义：`>=` 语义下 119 不判和/120 判和，与测试断言一致；残查 `halfmoveClock >= 100` 零命中（"100" 仅存于注释记述）
- DEBUG 钩子：testGet/SetHalfmoveClock/testGetPositionFingerprints/testRunCheckGameState 均 `#if DEBUG` 门控，Release 零泄漏；testSetHalfmoveClock 注入用于 119/120 边界驱动真实 checkGameState 路径——方案源自 RealTests 自带 TODO，承袭合理

### A4 fingerprint 对称化 ✅
- X-碰撞根因确认：旧编码 general→K/chariot→R/其余全→X，马炮卒同符异型同指纹，三现误判真实存在
- 修正：boardFingerprint() = FENParser.generate(board:) → FENDecoder.generate（Models/FENDecoder.swift:136-163）
- **A4 生死点已验**：generate 输出 `placement + turn + "- - 0 1"`——计数器为字面占位非真实值，跨步指纹可匹配，三现检测功能保持；走子方编码在位（w/b），同局异方不同纹
- Game 侧对齐声明证实：GameViewModel:820-822 boardFingerprint() 同为 FENParser.generate——双侧指纹形态统一
- 回归钉：DrawDetectionRealTests testDifferentTurn_DifferentFEN / testFENGenerate_IncludesTurn 均 passed（log L178-181）

### B7 riverText 单源化 + B4 回放翻转闭环 + B5 OK×7 键化 ✅
- RiverTextView 组件（新 44 行）：cellSize/color/isFlipped/fontSizeFactor(默认0.45)/spacingFactor(默认2) 参数化；翻转语义单点（isFlipped→汉界左/楚河右，承 ChessBoardView 原行为）；键消费经 LocalizedStringKey board.chuRiver/hanBorder（dim6 §7.4 处方①②落地）
- 12 处接线逐视验：ChessBoardView 4 Text→1 组件调用（翻转保持）｜BoardCanvasView 补 isFlipped 透传（**B4=N-1 闭环**，回放面失翻转变体消灭）｜MiniChessBoard fontSizeFactor:0.4（视觉系数保持）｜OpeningExplorerView 改引｜TutorialBoardIntroView Canvas 面键接线 Text("board.chuRiver")（LocalizedStringKey 语义成立，教程面不接组件符合处方注记）
- 残查：`Text("楚` 全 Views **0 命中**
- B5：MasterGameBrowserView `Button("OK")` **0 残留**，:246/270/1001/1006/1114/1119/1127 七处全部 L10n.shared.t("common.ok")（与 dim3 §3.4 盘点行号一一对应）
- 测试钉翻转三处：UXAdaptationTests:707-717 断言方向翻转正确（consumesComponent + !hasHardcoded 双断言，log L477 PASS 实证）；V2215Tests:392/D5I18n:206 注记随批（守卫惰性保留，处置得当）

### F2 恒深色显式化 ✅
- Info.plist +2：UIUserInterfaceStyle=Dark（插入位规范）；docs/design/dark-mode-policy.md 在盘；零行为声明成立（现状即深色设计，显式化仅锁语义）

## 三、测试证据核验（log 实读）

- t1023p4-b1-tests-final-1022.log（58504B）：DrawDetectionRealTests `Executed 14 tests, with 0 failures`（L205-209）✅；UXAdaptationTests 翻转钉 PASS（L477）✅；全 run 32 tests 7 suites **仅 1 issue**=存量走棋悔棋项
- 通道合规：run-tests-mutex.sh 单通道 RUNNER_OWNER=cody，skip 清单命令行在案 ✅（DEVTEAM.md 测试规约遵守）
- 过程透明：r1 批次作废（/tmp/xc-mutex-dd CodeSign 损坏，清 DD 重跑）如实申报；xcodegen 重跑收录 3 新文件——过程纪律良好

## 四、存量失败定性核验（非本批引入）✅ 同意 Cody 定性

- 失败体：UXAdaptationTests「走棋 + 悔棋 回归」（:530-545）"兵无合法走法"——selectPiece 执方门拒（humanSide=black 用户偏好污染 vs 测试假设红方）
- 三证据链：①批内 diff 零触碰该用例（§一）②全新进程嵌套路径隔离单跑同败（t1023p4-b1-fullreg-iso-1022.log L82）③MoveValidator 直调返回 1 合法步（被测逻辑面健康）
- 定性：测试隔离缺陷（UserDefaults 跨用例状态泄漏），非产品码缺陷、非本批引入。Cody 建议方案（用例显式设 humanSide + defer 还原，参照 ad65195 TestL10nSupport 范式）方向正确
- **处置上升**：该失败将同样命中 Tina 验收批——需丹妮/Alex 裁：a) 先行 P4 测试隔离微批（建议，量级 ~0.5 人日内）再走验收；或 b) Tina 验收按"1 已知存量豁免 + 本批新增断言全绿"口径。Cody 已报 Danny/Alex，Ruby 附议 a)（known-issues 无登记，建议随隔离批补登记）

## 五、发现清单（本批无 P0/P1/P2 返工面）

- P3-1（风格）：自然限着常量消费风格不一——GameViewModel 走 private alias 属性、PuzzleViewModel 直引 enum。功能等价（单源未破），建议后续统一为直引。不阻断
- P3-2（观察，批外）：FENDecoder.generate 计数器恒 "0 1" 字面占位——指纹用途无碍；但 GameViewModel:552/:623 导出场景若消费方期望真实回合计数则为既有 inaccuracies（P4 前即存在，非本批引入）。建议 P4 后续批核导出 FEN 计数器语义
- P3-3（观察）：PuzzleViewModel.checkDraw 三现计数 history 重置语义（吃子/兵动清史）本批未动，指纹形态变更不影响其重置逻辑——维持现状，Tina 验收如覆盖三现场景可顺带确认

## 六、结论

**代码面通过，零返工面。** 五件（A1/A4/B7+B4/B5/F2）实现与申报一致、证据链完整、红线零违反（P4 改码授权范围内动作；单通道测试合规）。存量失败定性成立且已上升裁决。附 P3 观察三项随件登记。

**放行路径**：Ruby 审通过 → 丹妮/Alex 裁存量失败处置口径（建议 a：先行测试隔离微批）→ Tina 验收 → 门禁 → tag。

> 判词落盘即审查完成。Luke/群通知按 10-18 协议由 lead sweep 代行。Ruby 2026-10-22
