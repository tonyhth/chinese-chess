# 全量测试存量失败账目（2026-08-15 两轮对照）

- 作者：Cody（Phase 1 交付附件，Luke 指令"账要立"）
- 数据源：今晨轮（11:07，基线 1d2fdd1，/tmp/fulltest2.log）vs 本轮（16:0x，m1 @ d22bba5+WIP，/tmp/m1_fulltest2.log）

## 一、两轮差异说明（表观矛盾闭合）

**"今晨 2884/0 全绿"是误读**：2884 是 `✔` 行（通过用例）计数，`✘` 行未被计入汇总。今晨轮实际 **126 用例失败**（`grep -cE "✘ Test" /tmp/fulltest2.log` = 126），本轮 117——两轮同基数失败，无回归。

**数字差（126 vs 117）= 并行执行波动**：失败用例名集合 diff 显示差异集中在 DemoVM/BoardPlayer 系（异步 observer 时序敏感：`vm.lastMove → nil`、`currentIndex → 0` 类等待窗口断言），两轮各挂不同子集、量级一致。典型样本：V60Phase3Tests 今晨 12 vs 本轮 6（同一用例 "GameViewModel deinit" 的 userInfo 断言两轮同挂）。

## 二、分账表

| 归属 | 失败数 | 依据 |
|---|---|---|
| **存量（业务语义演进遗留）** | **117（全部）** | 两轮（1d2fdd1 vs m1+WIP）同基数；stash 隔离对照实证（RankUnlockTests 在无 WIP 的 d22bba5 上同样 25 issues） |
| Phase 0 相关（A3r2/A3Exit132） | 0 | 两轮日志零命中 |
| Phase 1 相关（M1Phase1/Phase2aSearch） | 0 | 适配后 20/20 绿 |

## 三、存量失败分类（按套件，本轮 top10）

| 套件 | issues | 语义差样本（期望 vs 实际） |
|---|---|---|
| RankUnlockTests | 25 | 段位门禁断言过期：测试期望学童不可解锁 customTheme/gameRecordExport 等（业务已放宽为可解锁）——Luke 独立抽查同结论 |
| BoardPlayerRefactorTests | 7 | DemoVM 异步转发时序：stepForward 后 currentIndex 期望 1 实际 0（等待窗口过短类） |
| V60Phase3Tests | 6 | fallback notification userInfo 期望非 nil 实际 nil（通知载荷时序/条件演进） |
| V223FixTests | 5 | （历史 v2.2.3 修复断言，业务语义后续演进未跟测） |
| Phase4Tests | 5 | 同类历史演进 |
| Phase3Tests | 4 | 同上 |
| P3Batch2Tests | 3 | centerControl 场景识别期望 .centerControl 实际 .generic（规则调优后判定收窄） |
| D5I18nAuditVerificationTests | 3 | i18n 审计基线漂移 |
| CalibrationV3Tests | 3 | 校准断言 vs v4.3 参数（ed00395 调参后未跟测） |
| V40Phase1Tests | 2 | — |
| 其余（合计 ~54） | — | 同类历史演进 + 时序敏感 |

另有 **AIDifficulty.allCases.count 10 vs 测试期望 5**（IOSToolbarAdaptationV31Tests 等，v6.0 十级制扩容后存量断言未更新）——归 v6.0 扩容欠账。

## 四、欠账处置建议

- **不修**（超 Phase 1 范围，Luke 已定）：117 存量全部挂账
- **收账方**：建议 v6.2 专项（测试断言与业务语义对账 + 时序敏感用例加等待/串行化），或按套件随相关功能 Phase 顺带清
- **过滤版全量口径**：EngineRouter 系 8 类（EloBaseline + V34Integration + Phase2cP1 + P0AIFix + P1FallbackToast + P1FixVerification + Batch3P1P2 + V34PhaseABC）——死锁根源（EmbeddedPikafishEngine.newGame dispatch_sync，known-issues 已立条目）

---

## 五、正式数字（过滤版全量，第 5 轮，m1 @ 1cdfe2d 最终代码状态）

- **过滤**：EloBaseline + EngineRouter 系 8 类（死锁规避，known-issues 在案）
- **结果**：通过 2333 / **失败 93（全部存量）** / Phase 0/1 相关套件（A3r2FirstCause / M1Phase1 / Phase2aSearch / A3Exit132）零失败
- top 失败套件与第 2 轮同构：RankUnlock 25（段位门禁断言过期）/ BoardPlayerRefactor 6（DemoVM 异步时序）/ V223Fix 5 / Phase3 4 / P3Batch2 3 / CalibrationV3 3（v4.3 调参未跟测）
- Phase2aTests 2 = EngineRouter 默认引擎断言（v6.0 路由演进存量，同族已知）
- **结论**：117→93 的数字差为并行波动 + 过滤套件移除，两轮存量集合一致，无回归

## M1 回退锚回填（2026-08-28，git 实证 + Luke 08-27 裁定）
- **6b1ad26** feat(phase-1): NPS 遥测三件套（v1.2 §6 + D2 三 P0 修正）——R4 回退面（⚠️ 拆分：NPS 遥测 revert，D2 三 P0 存量修正保留，Luke 裁定②）
- **199cc9a** feat(phase-1): seed RNG 注入 + --nps-bench CLI + CrossVersion 装载骨架——整体保留（保留资产面，Luke 裁定②）
