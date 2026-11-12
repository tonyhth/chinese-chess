# T-1104-1 教练增强批 门禁判词（Tina）

> **主审**：Tina（tester）｜**日期**：2026-11-12/13｜**派单**：Luke lead:main（链位 Ruby→Tina→Luke；DDL 11-12 12:00，逾期根因与本判词 §五一并呈报）
> **对象锚定**：m1 **d9d01852**（隔离 worktree `~/DevTeam/worktrees/T-1104-1-verify-d9d01852`——主仓现挂 Cody 修复批 WIP/已落定 7eb8e528，按技能 §1.5 隔离检出保验证态纯净）
> **上游**：Ruby 判词 docs/reviews/v65-t1104-1-coach-review-ruby.md（通过有条件）；Cody 修复批 7eb8e528 已落定（Phase3Tests 65 绿自跑）
> **方法**：点名套件独立复跑 + 四断言源码核验 + **父提交 9c5dd4c7 同参 --full 对照**（失败集 diff 归因）

---

## 一、验证面结果

| 项 | 结果 | 关键证据 |
|----|------|----------|
| ① CoachExplainerPhase3Tests 73 绿独立复跑（第三通道） | ✅ | `✔ Test run with 73 tests in 1 suite passed after 0.243 seconds`，rc=0，runner-011416-20333.log:6144（Cody 00:27 + Ruby 01:0x 双证之外第三通道） |
| ② 四验收断言在位 | ✅ | 34 count（:27/:35）｜variantNoRepeat lastTextHash（:768）｜棋谚 100 采样 3-35 带（:733-760）｜PhaseDetector 10 测（:77-151）+ TrendAnalyzer 13 测 |
| ③ 全量回归绿 | ❌ as-is → **归因后批因仅 3 项**（§二） | runner-231359-73318.log（2904 tests/70 issues/31 failed）+ 父对照 runner-235046-81579.log（2891/31） |

## 二、全量回归归因（父子对照定谳）

**方法**：父提交 9c5dd4c7（coach 批之前）同参 --full 对照跑，失败集逐项 diff。

### 批因 = 3 项（父绿子红，全部为批变更未同步老套件）

| # | 失败测试 | 位置 | 机理 |
|---|----------|------|------|
| 1 | CoachScenario: 26 种场景完整（Phase 3 扩展） | CoachModeOverlayTests.swift:14 | 断言 count==26，批将枚举 26→34 未同步此 v3.8 时代老套件（父批 26==26 ✅） |
| 2 | CoachScenario 有 26 个 case | T1T4GapTests.swift:357 | 同类陈旧计数断言（父批 ✅） |
| 3 | testIsSafeCapture_RookCapturingUnprotectedPawn | CoachExplainerSafeCaptureTests.swift:223 | classify 域收缩（Ruby §二 门义裁定收紧点 2：delta>100 吃子域→winMaterial）行为变更 vs 老测试预期 missedCapture（父批 passed 0.002s ✅） |

### 非批因 = 28 项既有失败（两边皆红）+ 1 项波动（父红子绿）

- **v4.2 重映射族**（DifficultyV21Tests/l10n displayName/AIDifficulty 枚举完整性等 ~20 issues）：断言 v4.2 旧值（0/4/7/10）vs 现行方案 A 梯表（9/11/14/17，2026-10-24 重锚）——陈旧套件债务
- **Pikafish 前时代断言族**（Phase2a EngineRouter「默认内置引擎」/evaluate/analyzeMove/回归指纹/复盘管道指纹等）：断言内嵌化之前引擎形态
- **天梯梯度/SelfPlayRunner/PositionAnalyzer 分级/P1-a/L2 补桩/v4.0 Beginner** 等
- **打包 ×2**：依赖 releases/ 打包产物，fresh worktree 无——环境敏感
- **波动**：PVS 结果一致性（父红子绿）——非确定性搜索或负载序差，单列不采信
- 注：两边皆红清单共 29 项（含 1 条汇总行伪计数），实际失败测试 28

## 三、批因 3 项修复处方（交 Cody 修复批收编）

1. CoachModeOverlayTests.swift:14 —— 计数断言更新至终态值（**注意：终态 7eb8e528=32，非 34**）
2. T1T4GapTests.swift:357 —— 同上
3. CoachExplainerSafeCaptureTests.swift:223 —— 预期按门义裁定同步（winMaterial 为已审行为变更），或 Luke 终裁回滚域收缩

⚠️ **两态对账警示**：7eb8e528 仅触及 3 文件（CoachExplainer/CoachModeOverlay/Phase3Tests），**未同步上述三个老套件**——终态锚（32 场景）下 26-计数断言依然红。两态对账时此项必须入账。

## 四、基建附报三项（候审，与本次逾期直接相关）

1. **runner 预算窗**：外层 timeout 默认 1800s（:91，env 可覆盖）击杀首次 --full（rc=124，01:47:39）——--full 全量面实测需 ~31-35min，1800s 边界不足；建议 --full 模式默认预算提升或文档化 RUNNER_TIMEOUT
2. **runner-wake 投递链缺陷**：rc=124 批两次入队回执在案（runner-011736-21331.log:8653）但我侧 45h+ 未收到唤醒——accepted/queued≠delivered 假阳性家族新证；本次改用自挂唤醒器收割（可行，但会话清理 ~30min 收割监控器，需 process 轮询兜底）
3. **全量面发现差 838→2904**：v6.5.0 门禁口径 838/0，本次 fresh xcodegen 全量 2904 tests/335 suites——pbxproj stale 假设（runner 无 xcodegen 步=Ruby P2 同根）；真实全量面疑似从未被近期完整跑绿，建议基线重锚（全量债务 28 项专项批处置）

## 五、用户路径覆盖审查

变更面含 **CoachModeOverlay.swift（View，+16）**：8 新 case × (icon+color) switch 穷举补全——**无新增用户操作入口、无数据查询/空数据保护/错误反馈链路变化**（纯展示枚举补全，编译器强制穷举完整性=Ruby §六 已审）。覆盖审查表 N/A（无入口/数据/反馈链路变更），缺失项：无。

## 六、结论

- **批面（①②）PASS**：73 绿第三通道达成、四验收断言逐条在位
- **门禁 ③ 按字面未过、按归因收敛**：本批引入回归面=3 项陈旧断言（修复成本低，处方明确）；28+1 项失败非本批引入（父提交同样红），属存量债务+环境面，开专项批处置
- **建议收口路径**：修复批补 3 项老套件同步 → 门禁复核以「点名套件 + 3 老套件定向批」即可（无需再全量）；两态对账按 §三警示入账
- 候 Luke 裁量：③门义（SafeCapture 域收缩方向）+ 存量债务批立项 + 基建三项

*主审 Tina｜2026-11-13 00:3x｜只验不改零 commit｜证据链 runner-011416-20333.log / runner-231359-73318.log / runner-235046-81579.log（均在 ~/DevTeam/workdirs/logs/h1/）*
