# T-1023-OC-01·P2·D4 — 界面/UI 维检查报告（t1023-dim4-ui）

> 主审：Vera（OC 审计线）｜日期：2026-10-20｜计划锚：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §四④/§五/§六 D4
> 代码态：working tree HEAD 1cfd109（v6.4.2 在链；git status 净，untracked 两件为本检查线计划与 dim1 报告）
> 方法：轻入场定点核验——基线文件驱动符号定点 grep+定点读段（无全库扫描/无全量通读）；T-1020-OC-01 证据帧目验 2/7（view_image 目录白名单受限，仅审 workspace 副本 2 帧，如实声明）
> 边界：只检查零码动作（不编译/不打包/不跑测试/零 commit/零台账写入）；T-1020-OC-01 证据只引用核覆盖不重开单；T-1022 校准域不介入；定稿件零触碰
> 行号口径：全部为 2026-10-20 working tree 态（HEAD 态/工作树态区分规则沿用 v6.2 HIG 审计 Addendum A4）
> 证据规范：每项结论带 文件:行；基线判词引用逐字不转述；无出处条目不予收录

---

## 一、总判词

**④维通过：P0×0 / P1×0 / P2×3 / P3×5。**

主问逐面回答：
- **视觉是否一致**——基本一致，一致性机制（LayoutSpec token、ContentUnavailableView、工具栏键帽常驻）已建成但**字号单源化半程**（F1，P2）
- **布局是否稳**——稳。debt ledger 三案全部闭环且有回归资产钉住（19 档像素锚在盘）；显式宽度契约落地（LayoutSpec/BoardSizing 上界）
- **深色模式是否齐**——**策略=全局强制深色**（App 层 preferredColorScheme(.dark) 双平台），恒深色下自洽；缺口是**策略隐性化**（F2，P2）与浅色化路径未决策
- **多分辨率是否齐**——iOS 侧经 T-1020-OC-01 验收（七帧，本维目验 2 帧无异常）；缺口在**验收证据覆盖面**（单设备/横屏 1 帧/无 iPad/无 Dynamic Type 帧，F3，P2）

基线债清偿度（D0 分片）：四层基线 26 项——**21 闭合 / 2 撤销（基线内已标注误报）/ 3 部分残留**（降级为 F1/F6/F8 跟踪），无一项回潮。

---

## 二、D0 基线核销分片（④维，26 项三态标注）

### A. v6.2 HIG 审计核销（docs/design/v6.2-hig-audit-vera.md，7 项）

| 基线项 | 态 | 现状证据（文件:行） |
|---|---|---|
| P0-1 版本号缺失+macOS plist 硬编码 | ✅已修复 | Views/AboutView.swift:14（读 Bundle CFBundleShortVersionString）/:27（settings.versionLabel 版本行）；src/ChineseChess/Resources/Info.plist:36-37（\$(MARKETING_VERSION) 机制）；ChineseChess-iOS/project.yml:15（MARKETING_VERSION "6.4.2"） |
| P0-2 关于页 iOS 零入口 | ✅已修复 | Views/AboutView.swift:1（"双平台共用关于页"）；SettingsView.swift:113-115（settings.aboutSection→AboutView NavigationLink）/:142（AboutView.appVersion 直显） |
| P1-1 引擎降级零感知 | ⛔已过时（撤销） | 基线 Addendum A1 自撤（误报，2026-08-16）；本次不复查（基线已定谳） |
| P1-2 空状态不统一 | 🔶部分修复 | ContentUnavailableView 现 15 处/7 文件（OpeningExplorer/PuzzleSelect/MasterGameBrowser/DailyChallenge/Achievement/ReplayWindow/GameHistory，基线时仅 MasterGameBrowserView:484 一处）；残留面→**F6**（ChapterSelectView 缺空态分支） |
| P2-1 双平台 #if os() 无对照文档 | ✅已修复 | docs/design/v6.2-platform-parity-table.md 在盘（16,440B，2026-08-25 23:07） |
| P2-2 NSHumanReadableCopyright 缺失 | ✅已修复 | Info.plist:28-29（"© 2026 中国象棋"） |
| P2-3 首启弹窗微差 | ⛔已过时（撤销） | 基线 Addendum A2 自撤（双平台遮罩逐字同构）；本次抽验 iOS ChineseChessiOSApp.swift:100-113 / macOS ChineseChessApp.swift:457-464 双在位一致 |

### B. ui-bugs v5.5.3 彻底修复方案核销（docs/audits/ui-bugs-thorough-fix.md，5 项）

| 基线项 | 态 | 现状证据 |
|---|---|---|
| 问题A sidebar 数字不显示（P0） | ✅已修复（结构性） | 根因结构（.sidebar listStyle 固定宽，debt ledger 案①同源）已消除：listStyle(.sidebar) 全 Views 计数 **0 处**（grep 实证）；sidebar 改 ScrollView+Button 形态（debt ledger 案① 0553daf 正解线） |
| VB-1 EventStat.nameCN 全英文（P0 数据质量） | ↗边界转呈 | 数据面非 UI 面，归①维文档/数据矩阵核销（本维只登记不裁决） |
| 问题B 残局演示点不进去（P0，value-based 导航失效） | ✅已修复 | StudyHubView.swift:146（NavigationLink {} destination 形态）/:193（NavigationLink(destination:)）——全 destination-based，value-based 链路 0 残留 |
| 问题C 教程入口藏太深（P1） | ✅已修复 | 三路径可达：StudyHubView.swift:147（TutorialView 入口）+ SettingsView.swift:148（settings.tutorialSection）+ 首启链（ChineseChessiOSApp.swift:330 / ChineseChessApp.swift:688） |
| 问题D 三棋盘布局复用（P2） | ✅已修复（按评估执行） | Views/BoardSizing.swift:3-9（"ChessBoardView 和 ReplayBoardView 使用同一套计算方法，确保…渲染大小完全一致"）；OpeningExplorer 保持独立——与基线评估"强行统一会增加复杂度"结论一致 |

### C. v39 Phase1-4 修复计划 UI 相关项核销（docs/audits/v39-phaseb-summary.md §四，8 项）

| 基线项（Phase#） | 态 | 现状证据 |
|---|---|---|
| #3 FirstLaunchDialog 集成 App 入口（P0-3） | ✅已修复 | ChineseChessiOSApp.swift:100-113；ChineseChessApp.swift:457-464 |
| #9a ThemePickerView 加 ScrollView | ✅已修复 | ThemePickerView.swift:10（ScrollView(.horizontal, showsIndicators: false)） |
| #9b ReplayBoardView 翻转一致性 | ✅已修复 | ReplayBoardView.swift:9（"薄壳：渲染委托给 BoardCanvasView…翻转动画"）+ BoardSizing.swift 共享计算 |
| #10 PuzzleSelectView UIScreen.main→GeometryReader | 🔶部分修复 | 布局改造完成，但 UIScreen.main 残留 1 处（全工程唯一）：PuzzleSelectView.swift:722（#if os(iOS) 底部高度百分比计算）→**F8** |
| #12 棋盘 AI 思考视觉指示 | ✅已修复 | StatusBarView.swift:24-26（isThinking→status.aiThinking）/:39（onChange） |
| #13 每日挑战占位缩减 | ✅已修复 | DailyChallengeView.swift:42（"v4.0: 敬请期待 — 单行文案"） |
| #14 SettingsView 主题行色块预览 | ✅已修复 | SettingsView.swift:67-69（settings.themeSection+themeRow(for:)） |
| #16 CoachSessionView 上一步按钮 | ✅已修复 | CoachSessionView.swift:169（backward.end.fill 控件） |

### D. v6.4 UI 病灶档案三案+三总约束核销（docs/design/v6.4-ui-debt-ledger.md，6 项）

| 基线项 | 态 | 现状证据 |
|---|---|---|
| 案① sidebar 文字挤压（sheet 内 .sidebar 固定宽） | ✅已修复 | listStyle(.sidebar) 全 Views 计数 0；约束"sheet 内禁用"已沉淀为约束1 执行 |
| 案② 工具栏拥挤（无分组语义） | ✅已修复 | A+B 实施态：内联四钮（新局/悔棋/提示+学棋提权 ToolbarView.swift:283-294，注释"T-1020-OC-02 随批修 B"）；溢出菜单四功能域分组（ChineseChessApp.swift:316 注释"T-1020-OC-02 随批修 A：四功能域分组（学棋/对局/数据/外观与设置）；studyHub 已提权内联（裁 B）"/:324 dailyChallenge 项构造）；分组渲染 ToolbarView.swift:341-345（isDivider→Divider）；宽度诊断结论"内联 ~430-500pt << 主窗最小 900pt"仍成立（LayoutSpec.swift:73 compactWindowMin=900） |
| 案③ VTF 红框死区（364-388pt 零渲染） | ✅已修复（回归资产在位） | DemoControlBar.swift:146-151（ViewThatFits+wide 变体 .frame(minWidth: 400)，注释引 Ruby P1 死区数据）；ManagedSplitView.swift:14（"380 仍落死区；400 = 恢复点 392 + 余量"）；src/ChineseChessTests/V62SpeedMenuPixelTests.swift 在盘（5,573B，19 档像素差分锚）——**可回归资产未随时间流失** |
| 总约束1 禁隐式布局兜底（显式契约） | ✅已落地 | BoardSizing.swift:14-24（maxCellSize macOS 200/iOS 80；iOS maxBoardWidth 600/maxBoardHeight 675 显式上界）；LayoutSpec.swift 显式常量族 |
| 总约束2 单源布局常量（LayoutSpec） | 🔶部分落地 | 宽度/窗口常量已收编（LayoutSpec.swift:28 panelWidthMedium=400 注释"对齐 v6.2 rightMin=400 经验值"/:73 compactWindowMin=900）；字号收编半程→**F1** |
| 总约束3 双平台对照表前置 | ✅在盘 | v6.2-platform-parity-table.md（同 A-P2-1） |

**D0 分片小结**：26 项 = 21 闭合 + 2 撤销（基线已自谳）+ 3 部分残留（F1/F6/F8 承接）。无回潮项。

---

## 三、主审四面新发现（本维增量）

### F1（P2）字号魔法数收编半程——~41/98 处散落
- **现状**：Views 全目录 .system(size:) 共 98 处；LayoutSpec.fontSizeCaption 40 处 + fontSizeBody 17 处已 token 化（57/98），**raw 魔法数 ~41 处**（40pt×9、48pt×5、9pt×3、12.5pt×3、10pt×3、cellSize*0.3×2 及长尾）
- **证据**：grep 统计 src/ChineseChess/Views/ .system(size:) 分布（2026-10-20 实测）；token 定义 Views/Layout/LayoutSpec.swift
- **影响**：跨页面字号层级不一致的温床；debt ledger 总约束2"单源常量"在字号轴未收敛
- **P3 整改映射**：视觉一致性包——LayoutSpec.fontSize 全量收编（纯机械替换，低风险，建议随 P4 任一批顺手携带）

### F2（P2）深色模式策略隐性化——全局强制 .dark 无声明，浅色化路径未决策
- **现状**：App 层双平台强制深色——ChineseChessApp.swift:512 与 ChineseChessiOSApp.swift:413 均 .preferredColorScheme(.dark)；**全 App 不跟随系统深浅色**，且该策略无任何设计文档声明
- **耦合面**：Views 下固定木色 Color(red:) 27 处（AnalysisView/CoachModeOverlay/OpeningExplorerView 等）与系统语义前景色（.secondary/.gray）混用（例：AnalysisView.swift:55 固定深木背景 × :298 .secondary 前景）——恒深色下语义色恒为白系，自洽；**一旦开放浅色模式即全面失配**
- **影响**：策略与代码耦合隐性化=未来浅色化的隐形地雷；"深色模式是否齐"的答案依赖一个未成文的决策
- **P3 整改映射**：呈决策项——①策略显性化（设计文档一行声明"恒深色为产品决策"，零码动作）②浅色化成本评估（27 处固定色+语义色混用面盘点，随本报告 F4 证据可直接引用）

### F3（P2）T-1020-OC-01 验收证据覆盖缺口（只引用评估，不重跑）
- **现状**：evidence/t1020-mobile/ 七帧全为 **iPhone 16 Pro 单设备**（manifest.json：01-main-portrait/02-studyhub/03-select-top-row-selected/04-select-settingsbar-compact/05-game-portrait/06-game-landscape/07-back-portrait）
- **覆盖缺口**：①无 iPad/SE 小屏帧 ②横屏仅对局页 1 帧 ③无 Dynamic Type 大字号帧 ④深色未在帧名标注
- **目验（2/7 帧）**：03/07 两帧均为深色模式、布局无挤压/溢出/裁切；frame03"起马—暂不支持教练模式"优雅降级提示可见（正面）；与 F2 强深色策略推断一致
- **影响**：T-1020 验收态本身无问题（计划 §7.1 done 口径），但作为④维多分辨率"只核覆盖"的证据基座，覆盖维度不足以支撑 P4 多分辨率回归
- **P3 整改映射**：P4 验证批补帧（iPad/横屏全页/Dynamic Type XXL/深色标注），随批走不单开

### F4（P3）固定木色×系统语义色混用清单
- AnalysisView.swift:55（bg 44,24,16）/:298（.secondary）/:299（固定金 200,160,100）/:301（.gray）；OpeningExplorerView.swift:155（同款 bg）；CoachModeOverlay.swift:244（固定深棕 40,22,16）——全 27 处清单可由 grep Color(red: 复现
- 依赖 F2 策略成立而自洽；浅色化时的整改清单，随 F2 决策一并处置

### F5（P3）极小字号与 Dynamic Type 不跟随
- .system(size: 9) 3 处（含 AnalysisView.swift:301 monospaced 9pt 评价值）、12.5pt 3 处；全部 98 处固定 pt 不随用户 Dynamic Type 缩放
- HIG 文本可读性面登记；与 F1 收编批同车处置（token 化时按 text style 换算可选）

### F6（P3）ChapterSelectView 无空态分支
- ChapterSelectView.swift（219L）无空态 UI（全文件仅 :172 unlockDescription.isEmpty 解锁描述判断）；章节列表直接 ForEach(store.chapters)（:40）
- v6.2 基线 P1-2 声称"7 个主列表视图全部有空态分支"，现状 ChapterSelect 不成立（疑 v6.4 布局重构面变化）；数据源为内置静态章节，触发概率≈0
- 处置：随空态组件收编批补齐或豁免登记（低价值，不单开）

### F7（P3）TutorialInfoView 冗余强制深色
- Views/Tutorial/TutorialInfoView.swift:49 .preferredColorScheme(.dark)——App 层（F2）已全局强制，视图层重复声明为死代码面
- 清理项，随任一批顺手

### F8（P3）UIScreen.main 废弃 API 残留 1 处
- PuzzleSelectView.swift:722（#if os(iOS) 分支，UIDevice idiom+屏高百分比计算底部区域高度）
- v39 #10 唯一残留；deprecated 但功能正常；建议换 GeometryReader 或 view autorelease windows API，随批携带

---

## 四、T-1020-OC-01 / T-1020-OC-02 边界核对（只核实施后状态）

| 单据 | 边界项 | 核对结果 |
|---|---|---|
| T-1020-OC-01 移动端适配（done，交付 40125e0） | 只核验收态覆盖 | 七帧在盘（manifest.json）；目验 2 帧无异常；覆盖缺口登记为 F3，不重开单不重跑模拟器 |
| T-1020-OC-02 工具栏 A+B（done，实施 29adeb8） | 只核实施后状态 | A 四功能域分组（ChineseChessApp.swift:316 注释锚+:324 项构造+ToolbarView.swift:341-345 渲染）；B 学棋提权内联（ToolbarView.swift:283-294+遥测 studyHubInline:"1" :375/:379）——双落地，与诊断单推荐一致 |

---

## 五、分级汇总与 P3 整改映射

| 级别 | 项 | 摘要 | 整改去向 |
|---|---|---|---|
| P0 | 无 | — | — |
| P1 | 无 | — | — |
| P2 | F1 | 字号魔法数 ~41/98 未收编 token | 视觉一致性包（机械替换） |
| P2 | F2 | 恒深色策略隐性化+浅色化未决策 | 决策呈报（策略声明+成本评估） |
| P2 | F3 | T-1020 证据覆盖缺口（单设备/横屏 1 帧/无 iPad/无 DT 帧） | P4 验证批补帧 |
| P3 | F4 | 固定木色×语义色混用 27 处清单 | 随 F2 决策处置 |
| P3 | F5 | 极小字号（9pt×3）+Dynamic Type 不跟随 | 随 F1 收编批 |
| P3 | F6 | ChapterSelectView 无空态分支 | 空态收编批或豁免 |
| P3 | F7 | TutorialInfoView 冗余强深色 | 顺手清理 |
| P3 | F8 | UIScreen.main 残留 1 处 | 随批换 GeometryReader |

**判词**：④维无阻断项。基线债 26 项核销 21 闭合无回潮，三案结构性修复均有回归资产钉住；残余面全部为一致性与证据完备性打磨项，可直接映射 P3 整改条目（F1/F3 机械可改，F2 需洪涛决策）。

---

## 六、证据可靠性声明

1. 全部结论出自 2026-10-20 working tree（HEAD 1cfd109）定点核验，grep/read 命令与行号可在同树上复现
2. 证据帧目验 2/7（03/07 帧，workspace 副本）；其余 5 帧未逐张目验，相关结论以 manifest 命名+F2 强深色策略推断为限——已如实标注，不作超出证据的断言
3. 本报告零 commit 零台账写入（OC 审计线双线身份）；报告落盘 docs/audits/t1023-dim4-ui.md 即交付物本体
4. 基线判词引用（撤销类两项）逐字沿用 v6.2-hig-audit-vera.md Addendum 原文口径，未转述再创作

— Vera，2026-10-20
