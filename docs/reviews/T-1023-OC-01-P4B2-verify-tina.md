# T-1023-OC-01·P4·Batch 2 验收判词（Tina）

> 验收人：Tina（tester）| 日期：2026-10-22 | 对象：496d67a（B1-B3 docs）/ 9754a84（B10）/ cf37777（A2）/ 9553917（B9）/ a0dbbcb（B6）——基座 694a68a，区间 694a68a..a0dbbcb 实核 5 commit（Ruby 判词口径"六 commit 全审"含前置隔离笔 694a68a 或不同区间，数量差异如实注记不影响交付面结论）
> 验收基线：a0dbbcb | 隔离检出：worktree t1023p4b2-verify-a0dbbcb（主仓 Batch 3 WIP 不触碰）| preflight RC=0（五项资产含 KI 盲区预防补齐 pgn-extracted/opening-categories）
> 方式：xcodegen→build→run-tests-mutex 前台豁免通道七套件（XCODEGEN_RC=0/BUILD_RC=0/TEST_RC=1）

## 一、交付面验收 ✅ 全 PASS

| 项 | 实证 | 判定 |
|----|------|------|
| A2 UIScreen.main→GeometryReader | cf37777（PuzzleSelectView 底部高度预算，比例语义保持，首帧兜底 180）；UXAdaptationTests 32 tests 全绿 | ✅ D3 P1-5 闭环 |
| B6 LayoutSpec 字阶收编 | a0dbbcb（10 token 全量收编 27 数值站点，值=实测现存值零视觉变化）；UXAdaptationTests LayoutSpec 断言绿 | ✅ |
| B9 StatusBarView TODO 移除 | 9553917（残局走错文案属 Puzzle 域 UI 层，集成前置未发生，职能随集成重建）；UXAdaptationTests 绿——**dim2 P2-1（StatusBar 悬置 TODO）随本批核销** | ✅ |
| B10 OpeningBook 解耦 | 9754a84（标准基盘单次解析+init(pieces:) 派生工作副本，行为零变化）；全批无回归 | ✅ |
| B1/B2/B3 docs | 496d67a（test-rules 真相源改指/release-notes v6.4.x 三条目/打包 tmp.* 排除） | ✅ |

测试批 PASS 面：UXAdaptationTests（32 tests）/ GameViewModelTests / Phase1P0Tests / DrawDetectionRealTests / DrawDetectionTests 全绿。

## 二、两 FAIL 定谳与核对发现 ⚠️

### 2.1 V2215Tests FAIL —— KI 修正项未随批，B6 收编与守卫计数器方向相悖
- 失败体：与 Batch 1 同型（hardcodedCount → 96) <= 30，V2215Tests.swift:188
- 关键事实：①Batch 2 六 commit **无计数器修正**（KI-2026-1021-01 修正项缺位）；②B6 收编 27 站点系"字面数值→LayoutSpec 语义形态"——收编后 LayoutSpec 形态引用**增加**，而计数器（未修正版）恰把 LayoutSpec 形态计入 → **收编越多守卫越红**（方向性相悖）
- 定谳：存量 KI（Batch 1 已豁免裁定在案）+ KI 修正项缺位核对发现。非 Batch 2 新引入缺陷（B6 收编本身正确）

### 2.2 D5I18nAuditVerificationTests FAIL —— KI 修正项未随批
- 失败体：与 Batch 1 完全同型（lvl3 期望 'Intermediate'/'中级' vs 实际 'Amateur 3D'/'业余三段'，:122/:142，2 issues）
- 关键事实：Batch 2 六 commit **无期望值修正**（KI-2026-1021-02 修正项缺位）
- 定谳：存量 KI（Batch 1 已豁免裁定在案）+ 修正项缺位。非 Batch 2 新引入

### 2.3 核对发现呈报
丹妮裁示口径"②③登记 KI+**Batch 2 tests-only 修正**"——实测两修正项**均未随 Batch 2 交付**（六 commit 零 tests 断言修正）。非归责判定（编排口径可能系"候 Batch 3"或沟通落差），如实呈报请对齐：两 KI 修正排 Batch 3 或独立 tests-only 微批；在修正落地前，V2215/D5I18n 两套件于任何验收跑中持续红（豁免裁定在案覆盖，不阻塞 tag）。

## 三、结论

**Batch 2 交付面（A2/B6/B9/B10/B1-B3 docs）验收 PASS**——五 commit 实现与申报一致、UI/功能面测试全绿（UXAdaptationTests 32 tests 含 A2 容器替换/B6 收编/B9 移除三面验证）、无新增回归。

**随批事项**：①两 KI 修正（V2215 计数器/D5I18n 期望）未随批，转绿验证延后，排期请对齐；②V2215 守卫与 B6 收编的方向性相悖（收编越多越红）——计数器修正优先级建议提升（否则守卫永久失真）；③T-1026 八批已完成，C2-s4v5 补跑候本验收后串行执行（渐升梯定稿表候 C2 数据闭合）。

> 判词落盘即验收完成，回执丹妮终记台账。
> Tina 2026-10-22
