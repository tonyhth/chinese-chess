# v6.5 B1-R3 验证判词（Tina）— UI 选择器 lvl6-9 回全表（599ccab）

- **验证人**：Tina｜**日期**：2026-10-29 00:15-00:25｜**链**：编码（Cody）→ Ruby 审（B1-R3-review 通过，六点全 ✅）→ **Tina 验（本件）** → 门禁
- **对象**：commit 599ccab（2 files +9/−8：Enums.swift 翻转+注释 / T1013OC03S2RelevelTests.swift 断言锚改向），HEAD=origin/m1 亲证一致
- **基座披露**：复跑基线 = 599ccab + worktree 两件 FP 残面留树件（PositionAnalyzer privacy 日志串面 + Phase2bTests 探针件）——与本批 S2Relevel 面零重叠（前者仅日志串、后者他套件），构建编译通过无扰
- **结论**：**验证通过（PASS）**——三验证点全过，15/15 独立复跑绿

## 一、① 翻转行为 ✅

- Enums.swift：`transitionProfessionalPickerHidden = true → false`，注释随裁点更新（B1-R3 裁定执行 2026-10-28，v6.5 评估 v1.2 R3：过渡期结束=方案 A 重锚落码+ladderElo 正式锚定落档 v1.7；底层数据源全程未动仅可见集过滤解除）
- visibleProfessionalLevels false 支回 `professionalLevels` 全表五档（lvl6-10：amateurDan/proApprentice/proExpert/proMaster/grandmaster）
- 消费点恰三处亲证（全仓 grep 排除 Enums 后零多余消费）：**SettingsView:25 / ToolbarView:196 / ToolbarView:314** 全为 `ForEach(AIDifficulty.visibleProfessionalLevels)` 属性消费——零改码自动回全表成立

## 二、② 断言锚改向 ✅

transitionPicker 三断言改向亲证（diff 面逐行）：
1. `#expect(!transitionProfessionalPickerHidden)`（原 true 断言反向）
2. `#expect(visibleProfessionalLevels == professionalLevels)`（原 == [.grandmaster]）
3. 数据源锢定保留：`amateurLevels + professionalLevels == allCases`（①-4b 同款防线未松）
- 用例名随语义更新（「回全表：…B1-R3 裁定执行」）

## 三、③ 残锚扫描 ✅（独立复核）

- 全测试面 grandmaster 引用逐套件扫描（V60Phase2/SelectionConsistency/DifficultyV42/EngineTimeContract/EngineReliabilityFingerprint/CalibrationV3/V60Phase6/Phase1/V60Phase3）：**全部为档位枚举直引**（skillLevel/budgetMs/EngineTime 契约/映射锚等既有语义）
- 过渡态锚残留（`[.grandmaster]` 可见集 / `hidden==true`）：**全仓零命中**——与 Ruby ③核一致
- S2Relevel 内 grandmaster 引用均为 s2Spec 属性断言（ladderElo 递增/s20@5000 官方锚/usesPikafishEngine），合法语义

## 四、独立复跑（verify6，owner=tina）

| 项 | Cody 申报 | verify6 独立复跑 | 判定 |
|---|---|---|---|
| T1013OC03S2RelevelTests | 15/15（t1023-b1-tests-1028.log） | ✔ **Test run with 15 tests passed**（0.043s，RC=0 零 issue） | ✅ |

## 五、观察（不阻塞）

- Ruby P3-1（R3 裁点文档链间接跳转）登记知悉，随 B1 验收件引用直达路径（v1.2 §3）时顺带清偿
- 批余面交接：PositionAnalyzer privacy（f02c026 回退留树件）候下批验证流转——本件仅披露基座，不做处置

## 六、判定

**验证通过（PASS）**——①②③ 全过+15/15 独立复跑绿；红线零触碰（s2Spec 引擎参数/L10n/单源纪律三面 Ruby 亲证+本件 diff 面复核一致）；随批无新增问题。

> 判词落盘即验证完成，回报 Cody+同步 Luke。
> Tina 2026-10-29

---
*验证人：Tina｜599ccab+残面披露口径｜2026-10-29｜复跑证据：/tmp/v65-b1r3-verify6/ + h1/T1013OC03S2RelevelTests-002413.log*
