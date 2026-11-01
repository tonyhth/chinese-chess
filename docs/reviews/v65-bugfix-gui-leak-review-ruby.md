# v6.5 Bug 修复三修批 审查判词（Ruby）——校准 runner GUI 泄漏+对局冻结

- **对象**：commit 1735d39（2 files +12/-0：ChineseChessApp.swift +7 / SelfPlayRunner.swift +5），HEAD=origin/m1 亲证一致
- **日期**：2026-10-29 ｜ **审查者**：Ruby ｜ **模式**：只读审查（零 commit）
- **背景**：洪涛 10-29 23:47 实测——C7 校准批 runner 拉起的 GUI 实例滞留桌面，用户窗口对局 AI 永久卡死
- **结论**：**代码面通过，不阻塞合入。无方案级问题。**三修组合逻辑自洽：③消除可见性面（headless）+④消除进程面（既有 exit(0)）+⑤消除污染源（引擎态清场）——滞留现象三层结构性覆盖

## 变更清单独立验证

git numstat 亲证：SelfPlayRunner.swift 5/0 + ChineseChessApp.swift 7/0 = +12，2 files 与申报一致。worktree 纪律件（privacy+探针）不在本批 commit 面（Cody 已申报，与 69b5004 判词入库批注一致）。

## 逐审查点核验

### ① .accessory 影响面 — 全部非用户路径 ✅
init 分派区（:44-126，#if os(macOS)）亲证 9 个 CLI 分支：--selfplay / --calibrate / --paired / --paired-qs-full / --engine-server / --pfmatch / --calibrate-native / --calibrate-pf / --cmaes——全部 `args[1] == "--xxx"` 精确匹配且均为批跑模式（Task.detached+RunLoop.main.run()+批末 exit(0) 形态）。.accessory 门（:44-46）位于全部分支之前，hasPrefix("--") 为精确匹配的超集——**门覆盖完整无漏**。注：申报"十个"与实态 9 分支差一（或含子模式计数口径），覆盖面不受影响，申报口径随批核对即可。

### ② setActivationPolicy 时机合法性 — 合法且为优位做法 ✅
NSApplication.shared 为惰性单例，App.init 内首次访问合法（SwiftUI macOS 生命周期 init 先于激活完成）；在 NSApplication 完成启动前设置 .accessory 是文档推荐时机（晚设会有一瞬 Dock 图标闪现，init 内设无此问题）。门内调用（args[1] 前缀 -- 才设），用户路径零触碰。

### ③ shutdown() 清场完备性 — 清场链完整 ✅
- EngineRouter.shutdown()（:167）：await embeddedEngine.shutdown() + 引用置 nil
- EmbeddedPikafishEngine.shutdown()（:230）三步协议亲证：①pikafish_stop()（volatile flag 线程安全 non-blocking）②activeSearchCount 轮询归零（50ms×2s 超时）③pikafish_quit()
- **超时守卫方向安全**：2s 内搜索未完则不 quit（防 UAF），isReady=false 交由 OS 进程退出回收——批末 exit(0) 场景下无泄漏路径
- deinit 防御兜底在案（stop+quit，注释明示权衡）
- 搜索线程/引擎实例/全局态三层清场齐；自研 hard-d1 路径（novice）不经 Pikafish 无需清理

### ④ 用户 GUI 路径回归 — 零影响 ✅
GUI 启动（Finder/Dock/LaunchServices）args.count==1 不触发门；旧 macOS 系统注入参数 -psn_*（单横线）不匹配 hasPrefix("--")；分派区后用户路径初始化（PreferencesMigration/FontRegistry/bonus 清理）不受影响；用户实例保持 .regular 激活策略。

## 同场景验证申报核验
BUILD_RC=0 + 微型批（--calibrate-pf 0 0 2 30 30）rc=0 5s 自动退出 + pgrep 空——批末 exit(0) 有效性实证（滞留消除），与三修逻辑面互证。只读纪律未重跑。

## 问题清单

### 🟡 P3-1（申报口径）：CLI 分支数申报"十个"实数九个
init 分派区亲证 9 分支，第十分支未寻获（或系 engine-server 子模式计数）。门为前缀超集覆盖故功能面无损，但申报口径与实态差一——申报精确性随批核对（FP 批 P3-2 同族教训：申报完整性欠一格）。

### 🟡 P3-2（一致性面，备注级）：显式 shutdown 仅覆盖校准批
其余 8 个批模式批末无显式清场（靠 exit(0) 进程消亡 OS 回收兜底，当前无泄漏路径）。若未来任一批改为批后留驻交互模式，需同样补 shutdown——登记备忘即可，非本批缺陷。

### 观察项：.accessory 下 WindowGroup 窗口仍创建但不前置
滞留场景（若 exit 失败）视觉面已消除（不进 Dock/不激活/窗口不前置）；微型批 pgrep 空实证进程级退出有效，双防线冗余合理。

## 证据
- 通知：依 2026-10-18 丹妮协议，判词落盘即完成，三方通知由 lead sweep 代行
