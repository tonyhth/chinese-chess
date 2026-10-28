# T-1023-OC-01·①功能打磨批 验收判词（Tina）— 功能打磨全量 + CheckmateSearch P3-N1 + os_log 面（e93ccc1）

- **验收人**：Tina｜**日期**：2026-10-28 21:20-21:50｜**链**：编码（Cody）→ Ruby 审（FP-review 通过）→ **Tina 验（本件）** → 门禁
- **对象**：commit e93ccc1（10 files +22/-17），HEAD=origin/m1
- **前置判词**：docs/reviews/T-1023-OC-01-FP-review-ruby.md（代码面通过不阻塞合入；P2-1=CheckmateSearch 回归锚缺——本件按派单要求覆盖回归面旁证，**结论：旁证未闭合**，见 §三）
- **结论**：**e93ccc1 验收通过（PASS，不阻塞合入）**——六项验收点中五项过、⑤ 产品修复面过但**回归锚测试红**（P1 登记项退 Cody 夹具重设计）；P3 残面 1 条

---

## 一、锚定与工作区状态

- e93ccc1 亲证在库，HEAD=origin/m1；82d01de 收口 commit 已落（**上单 B3TF 登记项①闭环 ✅**——勘误四件+判词两件入库亲证）
- **工作区未提交 src 三件 = Ruby 随批处置响应**（P3-1 fenPrefix privacy 勘误 / P3-2 GameRailView 宽度勘误 / P2-1 回归锚测试新增），本验收复跑基线 = e93ccc1 + 此三件，判词按此口径
- ⚠️ 锚测试文件**实时迭代中**：Phase2bTests.swift 三版（21:26 无象版 → 21:33 探针版 → 21:35 +be2 版），本判词锚定两次实测快照 + 结构分析，不追滚动版

## 二、六项验收点逐项

### ① 回放步进 ←/→ 键盘快捷键 ✅（代码面）
- ReplayControlView.swift：`keyboardShortcut(.leftArrow/.rightArrow, modifiers: [])` 挂 prev/next 按钮，`disabled(!canGoBack/!canGoForward)` 门在位（disabled 态快捷键不触发）；回放域独占消费（ReplayView:91），无 TextField 冲突（Ruby ④核一致）
- **交互实测改道**：KI-2026-0913-01 家族机械定谳（代理树零 GUI 场景，headless 已证伪四通道，禁盲试）——键盘交互实证候真机/Aqua 轮（gui-evidence-channels 逃生通道），呈报登记

### ② macOS 搜索框 ESC 清除 ✅（代码面）
- GameHistoryView.swift：`onExitCommand { searchText = "" }` 挂搜索 TextField——macOS-only API 与派单对象（macOS 搜索框）精确对应
- 交互实测同①改道真机轮

### ③ legalMove a11y trait ✅（代码面）
- ChessBoardView.swift：走法目标点 `.accessibilityAddTraits(.isButton)`，复用既有 board.legalMove* L10n key（label+hint 在位）——零新增字符串，红线零触碰

### ④ F5 极小字号 ✅（代码面）
- AnalysisView 9→11pt（估值 cp 文本，monospaced caption 语境）；GameRailView 12.5→13pt ×3（回合号/红/黑着法）——Ruby HIG 裁量认可（11pt 辅助语境可读、13pt 达常规辅助文本水位）
- 渲染实测同①②改道真机轮

### ⑤ CheckmateSearch 全量校验行为面 —— **产品修复面 ✅ / 回归面旁证 ❌ 未闭合**
- **产品修复（committed）**：prefix(8) 排序剪枝撤除，改全量应将校验（moveScore 排序保留效率语义、判定完备性不变）；超时守卫 dfs :39-41 + killTimeLimit=750 双端显式常量（AIEngine :363/:593）+ maxDepth=12；最坏路径超时返回 nil 失败方向安全。committed CheckmateSearchTests 4/4 绿（Cody 证据 tests-1028 21:05 + verify4 独立复跑 4 过一致）
- **回归锚（P2-1 随批响应，未提交）：红**——详见 §三，退回 Cody

### ⑥ os_log 失败面输出 ✅（代码面）
- 三处失败路径统一：bestMove/evaluate isReady 守卫 NSLog→AppLog.engine.error；pikafish_eval 失败码上抛新增（r/depth/timeMs/fenPrefix）；PositionAnalyzer 撤 #if DEBUG 改常开+冗余 NSLog 撤除
- 随批勘误验证：fenPrefix `privacy: .public` 在盘 ✅（Release 诊断价值保全）
- **残面登记**：PositionAnalyzer `engineType`（String 插值）未随 P3-1 勘 privacy——Release 仍 `<private>`，Ruby P3-1 后半句未清偿（P3）

## 三、🛑 P1 登记项：P2-1 回归锚测试红（夹具前提错误，退回重设计，勿以现态 commit）

**双复现实测**：
| 快照 | 版本 | 失败点 | 实测 |
|---|---|---|---|
| Cody tests5 21:27 | 21:26 版（无象） | Phase2bTests.swift:86:9 | responses.count = **7** >= 9 ✘ |
| Tina verify4 21:33 | 21:33 探针版 | :89:9 | responses.count = **7** >= 9 ✘ |

前置自检断言死，核心断言（search→nil）未到达。

**夹具分析三处误**（21:26 版注释声称「应将恰 10 手」）：
1. **马蹩腿 ×4 误计**：马 (2,2) 插 (1,4)/捕 (3,4) 腿=(2,3) 被 ba1 占；马 (2,6) 同理腿=(2,5) 被 ba2 占——4 手全部不存在
2. **(0,3) 逃将误判**：注释称「对脸非法」——ba1 在 (2,3) 遮挡 (0,3)-(9,3) 对脸线，**实合法**
3. 实测 7 = 逃×2 ((0,3)+(0,5)) + 士插×2 ((2,3)/(2,5)→(1,4)) + 相插×1 ((4,2)→(2,4) 象眼 (3,3) 空) + 捕车×2 ((3,1)/(3,8)→(3,4))——**Tina 独立推演与实测逐手吻合**

**结构性无效（关键）**：7 < 8 → 旧 prefix(8) 剪枝下同样全量校验 7 手、行为与全量校验无差别——**此夹具即使删掉前置断言让核心断言通过，也无法区分新旧代码 = 锚不锚定 P3-N1**。

**21:35 版（+be2(4,6) 第二象）预测**：象插 (2,4) 再 +1（象眼 (3,5) 空、(2,4) 合法象位）= **8 手，仍 <9**——当前子力集结构上限不足。

**重设计约束（交 Cody）**：
1. 真凑 ≥9 应将：建议撤士离马腿（如 ba1 (2,3)→(1,3)? 不行，士限宫——改马位或撤一士换炮/卒护子面），或增黑护子让应将面自然 ≥9
2. **破杀手必须排 moveScore 序 ≥9 位**：moveScore 语义=吃子加分+近宫加分——破杀响应须为低分形态（非吃子+远离己宫），否则旧 prefix(8) 也校验得到它，锚照样无效
3. 达成后绿跑连同本判词归档，Ruby P2-1 方闭

## 四、独立复跑汇总（verify4，owner=tina，/tmp/t1023-fp-verify4/）

| 套件 | Cody 申报/证据 | verify4 独立复跑 | 判定 |
|---|---|---|---|
| CheckmateSearchTests | 4/4（tests-1028 :21:05）+锚红（tests5 21:27） | 4/5 过+锚红（21:33，同点复现） | committed 面 ✅｜锚 ❌ |
| A3r2FirstCauseTests | 5/5 | ✔ 5/5（0.201s） | ✅ |
| BUILD | BUILD_RC=0（build-1028，0 error 行亲证） | verify4 增量构建 0 error | ✅ |

## 五、随批处置面登记

| Ruby 项 | 处置现态 | Tina 核验 |
|---|---|---|
| P2-1 回归锚 | 已写但红（§三） | ❌ 退回重设计 |
| P3-1 os_log privacy | fenPrefix 已勘在盘；**PositionAnalyzer engineType 未随勘** | 半清偿，P3 残面 |
| P3-2 GameRailView 宽度 28→32 | 已勘在盘 | ✅ |
| P3-3 KI 仓外登记路径指针 | 未落 docs 指针（Ruby 语「可接受」） | 登记，不阻塞 |
| dim3 P3-1（登记不迁移）/F6 豁免/F7 撤深色/F8 销项/s2Spec 注记 | Enums 纯注释/ChineseChessApp :280-281/audits 口径 | Ruby 亲证面，本件抽查 Enums diff 纯注释 ✅ |

## 六、判定

**e93ccc1 验收通过（PASS，不阻塞合入）**：①②③④⑥ 代码面全过（①②④ 交互实测按 KI-2026-0913-01 家族定谳改道真机/Aqua 轮呈报）；⑤ 产品修复行为面通过（全量校验+750ms 守卫+committed 套件绿）；**回归锚红为 P1 登记项退 Cody**（现态勿 commit，重设计绿后闭 Ruby P2-1）；P3 残面 1 条（PositionAnalyzer privacy）。红线五项零触碰（10 文件全 .swift、零 L10n 新增、Enums +2 纯注释亲证）。

> 判词落盘即验收完成。交下游：sessions_send(lead) + feishu 双写。
> Tina 2026-10-28

---
*验收人：Tina｜e93ccc1+随批勘误三件｜2026-10-28｜复跑证据：/tmp/t1023-fp-verify4/ + h1/CheckmateSearchTests-213329.log + h1/A3r2FirstCauseTests-213403.log；锚测试迭代快照：Cody tests5(21:27/:86) 与 Tina verify4(21:33/:89) 双红*

---

## 八、补充判定（7afdb2a 验证，2026-10-28 21:50 追加）

**触发**：Cody 验证请求——随批勘误清偿 commit 7afdb2a（4 files +96/-10：锚测试重设计+P3-1 privacy+P3-2 宽度+Ruby 判词入库），基线 e93ccc1+7afdb2a=origin/m1。

**独立复跑（verify5，owner=tina）**：CheckmateSearchTests ✔ 5/5（0.040s，含锚）+ A3r2FirstCauseTests ✔ 5/5（0.210s），RC=0 零 issue——与 Cody tests7 一致 ✅（h1/CheckmateSearchTests-214444.log + A3r2FirstCauseTests-214458.log）

**锚测试重设计核验**：士挪 (0,3)/(0,5) 解蹩马腿——Tina 独立推演应将恰 10 手（士插 (1,4)×2+马插 (1,4)×2+相插 (2,4)×2+捕 R1×4；逃将 0 手=双士自笼+将只能直行），与探针实证/实测吻合；马腿规则踩坑实录入注记（申报诚实 ✅）；用例 3/4 占位断言转真实断言 ✅

**判别力分析（§三 P1 焦点转移为 P3 残面登记）**：moveScore 实测排序——(1,4) 应将≈160（邻近 100+阻挡 60）> 捕 R1≈150（baseValue+邻近 60）> (2,4) 相插≈140。**旧 prefix(8) 窗口=前 8 位恰含全部必破杀响应**：捕车灭红唯一攻击子；(1,4) 应将→红车反吃→黑将 (0,4)→(1,4) 反吃红车（红方零攻击子，depth 8 内无法终杀）——旧代码首个校验即 break 返回 nil，**新旧代码同绿**。
- **P1 处置更新**：锚测试绿，作为「无假阳性行为契约钉」成立——Ruby P2-1 字面（≥9 应将+一手破杀+nil 断言）**已满足、就此关闭** ✅
- **P3 新登记（剪枝域判别缺口）**：现套件无任何用例可探测 prefix(k) 剪枝回潮（本锚新旧同绿为分析实证）。判别性夹具设计约束（已交 Cody）：黑方须**无捕将响应**（否则捕将排位必前、旧代码必绿）+ 破杀应将排 moveScore 位次 ≥9。候排期，不阻塞
- ②UX 抽验/③Release 观测：口径同判词主体（代码面过+headless 改道真机轮；os.Logger error 级 Release 常开系构造性保证）

**7afdb2a 本体验证结论**：**通过** ✅（勘误三件落地正确+判词入库+锚绿）。FP 批整体维持 **PASS**；P3-3 盘面件（remediation-plan KI 指针 gitignored）口径知悉。

*补充判定人：Tina｜7afdb2a｜2026-10-28 21:50｜证据：/tmp/t1023-fp-verify5/*
