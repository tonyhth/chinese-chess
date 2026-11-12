# T-1104-1 教练增强批审查判词（Ruby）

> **主审**：Ruby（审查者）｜**日期**：2026-11-11
> **派单**：Luke lead:main（台账 T-1104-1；链位 Cody→Ruby→Tina→门禁→Luke；DDL 11-11 18:00）
> **spec**：docs/proposals/coach-explainer-enhancement.md v1.1（Vera 已审）
> **对象**：commit d9d01852（已入库推远端——按"commit 后审查"口径，问题项走后续修复 commit，不回退本批）；批面 3 files +649/-32（CoachExplainer.swift +187 / CoachModeOverlay.swift +16 / CoachExplainerPhase3Tests.swift +478），与派单一致 ✅；工作树仅剩探针 Phase2bTests +345（禁 commit 纪律持续）
> **纪律**：只读零 commit；判词落盘即完成，三方通知 lead sweep 代行
> **披露**：审查中发现本机 pbxproj stale 引用阻塞构建，Ruby 执行 `xcodegen generate` 再生（从已入库 project.yml 确定性再生，零 tracked 变更）后完成动态复跑——详见 §八

---

## 一、① 场景计数归因（重点）

**实态权威枚举：34 case = 旧 8 + 26 新**（git show d9d01852 逐 case 枚举亲证）。

- **申报口径错位**：commit message"26 种（8旧+18新）"是 6b1ff567（Phase3 基座批，11 月前）时点状态；本批 +8 case 后实态 34。测试件自身断言 34（`scenarioCount26` 测试名旧、断言体 `count == 34` 与 26 新 rawValue 清单——**测试对、申报错**）
- **spec 对账：24 有效场景全部在库** ✅——26 新 = spec §1 四表 24 + 清单外 2，无遗漏
- **+2 定性：`advantageEstablished`/`suddenChange` = spec §5 趋势文案的场景化残留，判定越面且冗余（死 case）**
  - 证据：全文件 grep 无 classify return 位（仅 :53 枚举 / :303 标题 / :477 变体三处自引用）
  - 而 spec §5 趋势机制**已按 spec 原设计落地**：DemoViewModel :117 `trendAnalyzer` + :317-321 record/trend/commentary 通道亲证在位（6b1ff567 交付）
  - 两 case 是与 spec 通道平行的未接线重复品，占枚举+变体文案+Overlay 穷举位
- **处置建议**：删除两死 case（titleFor/detailFor/Overlay 图标颜色/测试清单四处同步，34→32 = 8旧+24spec 与 spec 完全对齐）——归修复批；若主张场景化趋势通道，须先裁掉与 DemoViewModel 通道的双轨冲突，不推荐
- **附带发现（6b1ff567 遗留，非本批回归）**：6 个 spec 场景枚举在库但 classify 从未返回——openingZhongPao / sacrificeAttack / mutualAttack / tacticFork / tacticPin / tacticSkewer（跨文件 grep 亲证仅 title/detail/Overlay 引用）。**spec 触发面实为 18/24**；commit 申报"34 场景全覆盖"在触发层不成立（枚举覆盖 34/34 ✓、触发覆盖 26/34）。登记补接线批次，不阻塞本批

## 二、② 向后兼容硬门

- **P1 V2 签名 ✅**：旧 4 参数 explain 在位（:81），转发 6 参数（moveNumber: 0 + Board(fen:)），与 spec P1 V2 sketch 一致；现有调用方零改动
- **旧 8 全部可达 ✅**：return-site 映射亲证 8/8 有 classify return 位
- **门义裁定（交 Luke 终裁）**：字面"任意输入行为不变"与 spec §1.2/§1.3 场景条件**内在不相容**——middleBlunder（delta 200-299∩步数15-35）、endgameBlunder（delta>150）、winMaterial/recoverMaterial（delta>100 吃子）若不截流旧带则永不可达。实态四个旧 case 域收缩点：
  1. `.blunder`：endgame 相位 delta>150 域 → endgameBlunder（middle ≥300 兼容带不动）
  2. `.missedCapture`：delta>100 吃子域 → winMaterial/recoverMaterial（50-100 复盘带不动）
  3. `.missedCheck`：200-299∩15-35 域 → middleBlunder
  4. `.developPiece`/`.centerControl`：劣势吃子（bestEval<0∧安全吃子）→ defensiveCounter 拦截
- **裁定：Cody 的「语义锚点保留」读法可接受**（delta≥300 blunder/missedMate 带 + 50-100 missedCapture 带不动，注释明示兼容意图），四收缩点逐条列明备 Luke 终裁；建议把锚点保留固化为回归断言（现 compat 测试仅断言非空=弱，🟡 P3）

## 三、③ 四验收断言在位性

- 场景覆盖 ✅：34 count 断言 + 26 rawValue 清单 + ~15 个触发测试（open/middle/endgame 分流）
- 变体数 △：variantNoRepeat 断言 ≥2 种（smoke 级，弱于 spec 每场景 3-5 口径，🟡 P3 登记）
- 棋谚 ~15% ✅：100 采样统计断言（3-35 带）
- 阶段感知 ✅：PhaseDetector 10 测（含 14/15/35 边界、大子≤4、负数/超大 moveNumber）+ TrendAnalyzer 13 测（滑窗 5、200/201 边界、suddenTension 防误报、reset）；DemoViewModel 集成生产接线亲证在位，但测试 §11 为 stub（只测 TrendAnalyzer 本体不测 VM 接线，🟡 P3）
- **动态验证 ✅ 双证**：Cody 00:27:21 pre-commit runner 日志 73 tests 全绿 + **Ruby 独立复跑 73 tests 全绿 TEST SUCCEEDED**（RUNNER_OWNER=ruby，本机）

## 四、④ 三夹具 TODO 根因裁（Cody 候裁项——本判词定谳）

**总判：三案皆夹具构造错，启发式与 classify 逻辑无罪——按夹具修复路径解除，无需启发式精化。**

| 案 | 根因（实证） | 处置 |
|---|---|---|
| winMaterial | 初版夹具 f7 放的是**卒**（probeFixtures 实证 `piece=soldier`）→ 非吃子走法 → isSafeCapture guard false → .generic。**Cody 00:20→00:24 间已修正夹具（f7=车）且 76-test 跑已过（00:24 失败清单无此件）** | **TODO 已过时：直接解除注释即绿**（00:24 跑 + Ruby 73 绿复跑双证） |
| defensiveCounter | 夹具红车在 **c7**（"2R6"）而 bestMove=f7f6 → from 无子 → isSafeCapture false → .centerControl（00:20/00:24 双证，与静态追踪一致） | FEN 改 "2R6"→"5R3"（R 挪 f7），保留 bestEval<0 语义，解除注释 |
| openingTrap | 夹具 FEN **缺炮 → 大子 8<10 → phase=middle → classifyOpening 不可达**（probe6 自证 majors=8 phase=middle）；PROBE2 另证该 FEN `FENDecoder.parse=false`（解析层再添一道雷） | 重造 FEN：补双炮（大子 12≥10→opening）+ from 方位与 bestMove 核对 + `FENDecoder.parse` 先行断言必须通过 |

- **元根因（"actor 路径与独立复刻不一致"的真解）**：复刻面不完整——probe 只复刻启发式谓词本体，未复刻 classify 的完整前置链（FEN 解析 → piece-at-from → phase 判定 → 分支序）；且复刻用 `FENDecoder.parse + Board(pieces:)` 而 actor 用 `Board(fen:)`（构造路径不同源）。「已排除 FEN 解析/缓存/并行」的排除清单漏了第四项：**夹具-谓词前置链错位**
- 门禁目标：三案修复后 76 全绿（73+3 解除注释）

## 五、⑤ lastTextHash 与 ProverbLibrary

- pickVariant ✅：filter lastTextHash + fallback variants[0] + 回写——spec §2（P2 V7 防重复优先、去 seed）忠实实现；actor 隔离线程安全；lastTextHash 跨场景共享 = 更严格（连场景切换也不重复，无害）
- ProverbLibrary ✅：**20 条逐字对齐 spec §3**（text/phase/category 三字段逐条比对一致）；randomProverb 阶段匹配（==phase ∨ ==all）✓
- 🟡 P3：缺 spec 选取规则「不连续两步不出现棋谚」——maybeAppendProverb 仅 15% roll 无连续性 guard（连续概率 ~2.25%，影响小，登记随修复批）

## 六、⑥ CoachModeOverlay 穷举补全

- 图标/颜色两 switch **均无 default → 编译器强制穷举**，完整性有构造保证 ✅
- +16 = 8 新 case × (icon+color) 精确对账 ✅（openingTrap eye.fill / orange 亲证）

## 七、🔴 P1 构建破窗（本机态，已由 Ruby 修复）与申报勘误

- **本机 pbxproj stale 引用**：ProbeT1104.swift（untracked 临时件）删除后未重跑 xcodegen generate → 本机增量构建 BUILD FAILED（Ruby 首次复跑实证 "Build input file cannot be found"）。pbxproj 为 untracked 生成物，**非入库破窗**，但 Tina 门禁若在本机跑会直接撞墙
- **Ruby 已修复**：`xcodegen generate` 再生（stale 引用清零）→ 复跑 73 绿 ✅
- 根因链：run-tests-mutex.sh 无 xcodegen 步骤（build-release.sh 有）——🟡 P2 建议 runner 起跑前补 `xcodegen generate`，防再犯
- 遗留清理：Phase3Tests 内 **7 个 PROBE 临时测试已入库**（注释自标"判词交付前删除"）——随修复批删除（73→66），PROBE4 的 `#expect(parsed != nil)` 是真实断言，勿留
- 申报勘误（🟡）："26 种（8旧+18新）"口径错位（§一）；"34 场景全覆盖"触发层不成立（§一）
- 🟡 P3：缝内注释 task ID 错位（MARK 引 T-1102-1、残局段引 T-1101-5，均应为本批 T-1104-1）——台账可溯性随手勘

## 八、结论

**代码面：通过（有条件）——场景/变体/棋谚/阶段感知/防重复/穷举六面实现合格，73 绿动态双证（Cody 00:27 + Ruby 复跑），无方案级问题。**

**放行与修复路径（交 Luke）：**
1. **不阻塞 Tina 门禁**（本机破窗已修 + 73 绿双证；死 case/PROBE 均为惰性噪声）
2. **修复批（小，≤1h，与 Tina 并行）**：删 2 死 case（§一处置）或 Luke 明示保留；删 7 个 PROBE 测试；解除 winMaterial TODO（已绿）；修 defCounter/trap 夹具（§四处方）→ 目标 76 全绿
3. **Luke 终裁两项**：②门义四收缩点清单（推荐采纳 Cody 读法）；①死 case 处置方向（推荐删除）
4. 🟡 随手项：棋谚连续性 guard、compat 锚点断言、变体数断言加严、VM 集成测试去 stub、task ID 注记、runner 补 xcodegen

*主审 Ruby｜2026-11-11｜只审不落码零 commit（xcodegen 生成物再生已披露）｜通知由 lead sweep 代行（2026-10-18 丹妮协议）*
