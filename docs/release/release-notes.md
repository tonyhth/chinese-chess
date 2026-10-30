# Release Notes 标记（v6.3 系）

## v6.3.0 —— ⚠️ 已知缺陷中间态，非正式发布锚
- tag v6.3.0（232036e）保留于 origin 作历史标记，**携带已知缺陷**：
  复盘分析/智能点评/棋力评估第 2 着起静默 nil（双写历史根因，
  ca8d91f..0d343f1 修复链在案）
- **正式锚 = v6.3.1**（热修 commit，首个通过复测的 6.3 系形态）
- 用户侧：请直接安装 v6.3.1 覆盖；勿分发 v6.3.0 包

---

# Release Notes 标记（v6.4 系）

## v6.4.0 —— v6.4 大版本首个正式锚（2026-10-18 收口）
- tag v6.4.0（cut c45d423；T-1018-OC-01 打包收口：Release 构建+releases/ 归档，版本 6.4.0-alpha.3→6.4.0 递增，零功能代码）
- 内容=T-1017 全批（含统计聚合导出 75f06e0）及 v6.4 开发批累积（P9 真芯接入/C4a·C4b UI 域/L10n 基建/方案 C 双层诚实刻度等）
- 门禁：verify_delivery.sh 6/6 exit 0（含 Release 重构建独立验证）

## v6.4.1 —— patch 批：P3 消解+L10n 段位制全量换轨（2026-10-18/19）
- tag v6.4.1（定版 8f9df43，镜像 c45d423 形态；tag 序 v6.4.0→v6.4.1 无跳号）
- T-1019-OC-01：P3×6 消解（zeroMoves 文案分流/未终局时长门控/文件名秒级碰撞原子覆盖/测试边界补齐/documentsDirectory 防御/AlertReason enum 化）+L10n 段位制全量换轨 zh/en+短名+分组标签（终表更正 08253b6：lvl7=棋协大师 Association Master/lvl9=特级大师 Grandmaster/lvl10=棋圣 Sage）
- T-1020-OC-01 移动端适配（开局选择页 size-class 竖排分支+教练页导航栏压缩）+T-1020-OC-02 工具栏四功能域分组收纳+studyHub 提权（A+B 组合）
- 门禁：6/6 exit 0 + Tina 复验 PASS（复验单在案）

## v6.4.2 —— patch 批：教练执方门修复（2026-10-18/19）
- tag v6.4.2（定版 a26d902，镜像 8f9df43 形态；iOS 子工程版本同步 1cfd109）
- T-1021-OC-01：教练应答走人类走子通道被双执方门拒——applyMove 核心段剥离+makeCoachMove 专用通道（5ce0fa2，含 T1021CoachSideGateTests 回归钉 119L）
- 门禁：6/6 exit 0 + Tina 复验 PASS（60 线归属勘误底实证）→done 终销

## v6.4.3 —— patch 批：P4 Batch 1/2/2.5 修复+校准 harness（2026-10-24）
- tag v6.4.3（定版 b172bc3，双 yml 同原子；pbxproj xcodegen 再生 ×4）
- T-1023-OC-01·P4：A2 UIScreen.main→GeometryReader 容器实测（cf37777）；B6 LayoutSpec 字阶 10 token 收编 27 站点零视觉变化（a0dbbcb）；B10 OpeningBook 索引层解耦（9754a84）；humanSide 环境依赖隔离（694a68a，KI 锚）；B1/B2/B3 文档修批（496d67a）；calibrate-pf 双侧独立 movetime harness（a24eb91）；V2215 语义豁免+D5I18n 换轨清偿（a76a1e9）
- 门禁：BUILD_RC=0 + 七套件 7/7 PASS（零豁免触发）

---

# Release Notes 标记（v6.5 系）

## v6.5.0 —— 弱化链 S2 定稿+B1 裁定执行+T-1023-OC-01 P4 整改叙事完整落版（2026-10-29 收口）
- tag v6.5.0（annotated 收口锚；验收件直引——Ruby P3-1 建议消费：v6.5 评估 v1.2 §3（R3/R4 裁点落档）+ difficulty-system-v2.2-draft v1.7 §四（ladderElo 正式锚定落档））
- v6.5 弱化链 S2 定稿落地：§Y 噪声表全零 N-out（96af46d）+ T-0926-OC-04 noisyEvaluate 等价性测试与夹具勘误（15ccd62/96af46d/本收口）+ B1-R3 选择器 lvl6-9 回全表（599ccab——过渡期结束双前提达成：方案 A 重锚落码+ladderElo 正式锚定落档 v1.7）
- 基线件对齐：B0=difficulty-system-v2.2-draft v1.6 基线对齐批（吸收方案 A 重锚+基线代际差清偿，Alex）+B1=v1.7 Q1 锚定落档（洪涛五点裁语 Q1=A，vera 快审通过）
- T-1023-OC-01 P4 收口：首项 Enums 渐升梯参数表（43d43d2 方案 A 落码）+文档修批六子批+② 测试面+① 功能打磨（e93ccc1）+随批勘误四件（7afdb2a）+C 案收口（27f1d43）
- 校准 runner GUI 泄漏三修（1735d39——洪涛 10-29 实测滞留+对局卡死根因消除：③CLI 模式统一 headless/④批末自动退出/⑤批末引擎清场）+ iOS 子工程 xcodegen 重生成收编 Oct 19 后源漂移面
- C7 加局批判读：T1 s14↔s17 亚阈值均势登记（预承诺回流档，Δ=-17.4 CI 跨零，-73 旧异常未复现）+T2 s4↔s7 定值 -255 消 B3 双值（judgment-report-cody + C7-VERIFY-JUDGMENT 双算互证，随批入库）
- 门禁：全量批 838 tests 首度全量对账（2 失败→双修定向回归绿：MasterGameFixTests 陈旧断言勘误+T0926OC04 夹具勘误）+iOS 编译门禁 RC=0（子工程重生成后）+T1013OC03S2RelevelTests 15/15+CheckmateSearchTests 5/5+A3r2FirstCauseTests 5/5
- KI：known-red/未验证测试禁上 m1（7afdb2a 案例立规）+ s14↔s17 邻接面未来校准观察清单
