# v6.5 Bug 修复三修 验证判词（Tina）— 校准 runner GUI 泄漏+对局冻结（1735d39）

- **验证人**：Tina｜**日期**：2026-10-29 23:05-23:20｜**链**：编码（Cody）→ Ruby 审（gui-leak-review 通过，四点全 ✅）→ **Tina 验（本件）** → 门禁
- **对象**：commit 1735d39（2 files +12/-0：ChineseChessApp.swift +7 headless 门 / SelfPlayRunner.swift +5 批末清场），HEAD=origin/m1
- **基座披露**：验证构建 = 工作树（1735d39+两件 FP 残面留树件）独立 dd（/tmp/v65-bugfix-dd，构建 RC=0 零 error，binary mtime 10-29 23:14:40）；残面与本批 GUI/shutdown 面零重叠
- **结论**：**验证通过（PASS）**——三验证点全过，微型批 4s 自动退出 rc=0 零滞留实证

## 一、① headless 行为 ✅

- **门位**（ChineseChessApp.swift init 分派区前）：`args.count >= 2 && args[1].hasPrefix("--")` → `NSApplication.shared.setActivationPolicy(.accessory)`——前缀超集覆盖全部 CLI 批模式（分派区 9 分支计数与 Ruby P3-1 勘误口径一致：本件 grep 亲数 9）；init 内设置=文档优位时机（无 Dock 闪现窗）
- **微型批实证**（--calibrate-pf 0 0 2 30 30，独立构建二进制）：**WALL=4s 自动退出 / BATCH_RC=0 / pgrep 零滞留 / 报告落盘正常**——批头横幅 per-side 文案显式（引擎A(Skill0)=30ms 引擎B(Skill0)=30ms，T-1026 时代「缺省位文案滞后」已随本批横幅更新顺带消除）
- **Dock-face 可观测性注记**：daemon 树 LaunchServices policy 字段 NULL（headless 环境无激活面，预期内不可观测）——用户 Aqua 会话 Dock 面终验候洪涛日常校准使用自然确认（逃生通道口径；原报现象即用户侧实测发现，修复后同路径回归）

## 二、② 批末引擎清场 ✅

- 链路亲证：runCalibratePfFromCLI 批尾 `await EngineRouter.shared.shutdown()`（SelfPlayRunner :1958 区）→ EngineRouter.shutdown（:167 await+引用置 nil）→ EmbeddedPikafishEngine.shutdown（:230）三步协议：
  1. `pikafish_stop()`（volatile 旗标，线程安全 non-blocking）
  2. `activeSearchCount` 50ms 轮询、2s 死线
  3. 归零方 `pikafish_quit()`；**超时路 skip-quit 防 UAF**（isReady=false 交 OS 进程退出回收）——方向安全与 Ruby 判词一致
- deinit 防御兜底在位（注释明示权衡）
- 微型批 4s 全程无挂起——清场路径实践无阻（批末引擎闲态 stop→归零即 quit，秒级）

## 三、③ 用户 GUI 路径回归 ✅

- `args.count == 1`（Finder/Dock/LaunchServices 常规启动）不触发门，激活策略保持 .regular
- 旧 macOS `-psn_*` 单横线参数不匹配 `hasPrefix("--")`
- 门位于全部分支之前=用户路径初始化（PreferencesMigration/FontRegistry 等）零触碰

## 四、独立复跑记录

| 项 | Cody 申报 | verify（本件） | 判定 |
|---|---|---|---|
| BUILD | RC=0（t1023-bugfix-build-1029.log） | 独立 dd 构建 RC=0 零 error | ✅ |
| 微型批 rc/退出 | rc=0 5s 自动退出零滞留 | **4s / rc=0 / ZERO-RESIDUE / 报告落盘** | ✅ |
| 首跑探针缺陷 | — | wait 跨子 shell 127 伪值+过早残留读（探针自勘误，非产品面） | 注记 |

## 五、观察（不阻塞）

- Ruby P3-1：CLI 分支数九个（本件 grep 计数一致，Cody 申报勘误已自我更正）——闭环
- Ruby P3-2（备注级）：显式 shutdown 现仅覆盖校准批，其余 8 批模式 exit(0) OS 兜底——若未来批后留驻交互化需同补，登记备忘
- 残面两件（privacy/探针）继续留树随下批流转（f02c026 同口径）

## 六、判定

**验证通过（PASS）**——三验证点全过+微型批实证闭环；红线零触碰（无 s2Spec/L10n/单源面）；随批无新增问题。三修组合（headless 可见性+exit 进程面+shutdown 污染源）对「滞留桌面+对局 AI 卡死」现象三层结构性覆盖成立。

> 判词落盘即验证完成，回报 Cody+同步 Luke。
> Tina 2026-10-29 23:20

---
*验证人：Tina｜1735d39+残面披露口径｜2026-10-29｜复跑证据：/tmp/v65-bugfix-dd/ + /tmp/v65-bugfix-build.log + /tmp/v65-mb2.log（微型批净版）*
