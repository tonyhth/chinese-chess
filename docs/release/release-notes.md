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
