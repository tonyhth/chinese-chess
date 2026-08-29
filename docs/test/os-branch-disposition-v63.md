# C4 `#if os()` 分支定性表（v6.3 Step 3）

> 消化底料：docs/test/platform-branch-matrix.md（Eric 08-28 快照，124 处 @ aa74fe7）
> 本表时点：HEAD e579fdc（E5 开关退场后全量重扫，产品码 96 处/38 文件（Ruby P2① 更正，原 40 为底料快照口径）：
> `grep -rn '#if os(' src/ChineseChess --include='*.swift'` 亲核）
> 定性口径：**A**=平台 API 必要（UIKit/AppKit/硬件/系统服务，无分叉即编译失败）
> **B**=平台 UI 惯例（HStack vs toolbar、navBarTitleDisplayMode 等，iOS 分支 macOS 不可编译验证）
> **C**=桌面工具链限定（CLI 入口/NSPasteboard，iOS 无对应场景）
> **D**=历史债（无理由分叉或可统一，待拍板/入 v6.4 账本）
> 测试映射：existing=已有 suite 覆盖；**L2-STn**=本次补桩（L2PlatformBranchStubTests）；XCUITest=C1 收编后升级
> 覆盖口径同 Eric 三级（✅运行时 / 🟡静态断言 / 🔴零覆盖→本表补桩后 🟡）

## 一、AI/ 引擎域（12 处）

| 分支 | os | 定性 | 理由 | 测试映射 |
|---|---|---|---|---|
| SelfPlayRunner :1238/1316/1411/1527/1645/1742 ×6 | macOS | **C** | 6 个 CLI 入口（calibrate/paired/selfplay/pfmatch），iOS 无终端场景 | existing SelfPlayRunnerTests/CalibrationV3Tests（算法层运行时）；**L2-ST12**（入口 guard 静态） |
| EmbeddedPikafishEngine :189 | iOS | **A** | NNUE bundle 诊断日志（Bundle.main iOS 路径），诊断性代码 | **L2-ST11**（静态） |
| EmbeddedPikafishEngine :363 | iOS | **A** | 物理内存<2GB 保守 TT（iOS 设备内存约束） | existing V34PhaseABCTest（macOS 侧运行时）；**L2-ST11**（iOS 侧静态） |
| TranspositionTable :43 | iOS | **A** | iOS TT capacity 保守上界 precondition（内存压力） | **L2-ST10**（静态 + macOS 侧运行时容量断言） |
| CMAESOptimizer :460 | macOS | **C** | CLI 入口 | existing Batch1P0CMAESTests |
| OpeningBookExpander :246 | macOS | **C** | CLI 入口（库扩充工具） | **L2-ST12**；消费侧 existing LazyOpeningBookTests |

## 二、App/Helpers/Services/Utils/ViewModels（16 处）

| 分支 | os | 定性 | 理由 | 测试映射 |
|---|---|---|---|---|
| ChineseChessApp :1/:17 ×2 | macOS | **A/C** | AppKit import（NSApplicationDelegate）+ --selfplay argv 路由 | existing 多 suite 引用 App 符号；**L2-ST12**（argv 路由静态） |
| ChineseChessiOSApp :1（整文件门禁） | iOS | **A** | iOS App 入口，macOS target 编译隔离 | existing Phase4IOSSheetTests/UnifiedSheetTests（静态）；XCUITest |
| PlatformExtensions :5/:17/:25 ×3 | macOS | **A** | NSColor typealias + controlBackgroundColor（AppKit 色板） | existing V62SpeedMenuPixelTests 等（基建被广泛静态消费） |
| SoundEngine :15/:37/:97/:114/:127 ×5 | iOS | **A** | AVAudioSession 生命周期 + 来电打断（iOS 独有系统服务） | **L2-ST9**（×5 静态；真运行时待 XCUITest——Eric 热点排行 #1） |
| FontRegistry :58 | macOS | **A** | CTFontManagerRegisterFontsForURL（AppKit 字形注册） | existing FontTests/V211P0Tests（运行时 ✅） |
| GameViewModel :8 | iOS | **A** | `_isIOS` 编译期标记（引擎 bestMove isIOS 参数路由） | existing 引擎测试（isIOS:false 运行时；true 静态） |
| PuzzleViewModel :15 | iOS | **A** | 同上 | 同上 |

## 三、Views/（68 处，按文件分组）

| 文件（分支数） | 定性 | 理由 | 测试映射 |
|---|---|---|---|
| ToolbarView :96（iOS 工具栏 HStack）+ :227/240/253/266/280（macOS 快捷键 ×5） | **B** | 逃逸史在案（1189989 难度标签案）：iOS HStack vs macOS keyboardShortcut/controlSize 双惯例 | **L2-ST1**（iOS HStack 结构+按钮集合静态；macOS 快捷键集合静态）；XCUITest |
| StatusBarView :81/:111（iOS 被吃棋子精简段） | **B** | 逃逸史在案（b19a4ef 徽章案）：iOS 精简行 vs macOS 双列全量 | **L2-ST2**（iOSCapturedPiecesSection/capturedRowHeight=24 静态） |
| SettingsView :172/:175 | **B** | 残余分叉 = 关于页导航形态（原 :37 引擎开关 iOS 入口已随 E5 退场删除——⭐参照案 2 假切换案现场清账） | existing V62LayoutTests；**L2-ST3**（E5 后无引擎开关残留再锢定，静态） |
| GameHistoryView :67/363/410/437（macOS contextMenu+NSPasteboard ×4）+ :152/155/177/375（iOS navBar/searchable/底栏/UIPasteboard ×4）+ **:158（macOS searchable→toolbar 规避）** | **B/C/A** | 剪贴板 API 平台各自必要（C/A 混合）；**:158 为渲染卡死规避分支——回归即卡死，Eric 热点 #3** | **L2-ST4**（:158 规避钉住：macOS 段禁 searchable、iOS 段含 searchable）+ **L2-ST5**（剪贴板调用点计数 ×N 静态）；真数据面 XCUITest |
| DemoControlBar :16/:33/:358（iOS）+ :135/:312（macOS） | **B** | sheet vs popover 配置入口（速度菜单红框案现场在 v6.4 账本） | existing SmartCommentaryPhase1Tests/MacPlayLayoutPolishTests（🟡） |
| DemoInfoBar :13/:22（iOS iosInfoBar）+ :78（macOS） | **B** | 双平台信息栏布局 | **L2-ST6**（iosInfoBar 静态——原零命中） |
| MasterGameBrowserView ×11（:109/:448/:585/:961? iOS；:130/:192/:903/:1019/:1088/:1354/:1423 macOS） | **B** | 文件最重双布局：iosPlayLayout/iosSearchSheet vs HSplit/focused/搜索模式 | existing CommentaryOverlayPositionTests 等（部分 🟡）；**L2-ST7**（iosSearchSheet/:1019 搜索模式/:1088 loadIndex/:1423 focused 四零覆盖点静态） |
| PuzzleDemoView ×8（:39/:164/:234 iOS；:81/:124/:291/:443/:570 macOS） | **B** | 双布局 + tacticalGroupFilterBar（:291 零覆盖）+ focused | existing 部分 🟡；**L2-ST8**（:291/:570 静态） |
| PuzzleSelectView :239/:509（iOS）+ :691（macOS） | **B** | iPad 多列/按钮形态 vs macOS 布局 | **L2-ST8**（:509 iPad 分支静态） |
| ReplayControlView :38 | **B** | iOS 控件宽度 | **L2-ST8** |
| ChessBoardView :414 | **A** | UIImpactFeedbackGenerator 触感（iOS 硬件） | **L2-ST8** |
| ReplayView :108/:122（iOS）+ :200（macOS） | **B** | 回放控件双布局 | existing 部分；**L2-ST8**（补静态） |
| PrivacyPolicyView :27 | **B** | navBar inline | **L2-ST8** |
| AboutView :51 | **B** | navBar inline | **L2-ST8** |
| RankPrivilegeView :29 | **B** | navBar inline | **L2-ST8** |
| OpeningExplorerView :44 | **B** | iOS sheet 入口 | existing V34 系列（🟡） |
| Tutorial/TutorialView :52 | **B** | navBar | **L2-ST8** |
| StudyHubView :13 | **B** | iOSLayout 演示导航链入口 | **L2-ST8**；XCUITest 收编后升 🟡→✅ |
| MasterGameBrowserView 外其余 navBarTitleDisplayMode 系（含 :184 引用） | **B** | iOS 导航惯例族 | **L2-ST8**（族级静态断言：iOS 段含 navBarTitleDisplayMode 的文件清单钉住） |
| ManagedSplitView :23 | **B** | macOS HSplitView vs iOS 降级布局 | existing V62LayoutTests T1/T2 |
| AnalysisView :356 | **A** | NSPasteboard 导出 | **L2-ST5**；数据面 XCUITest |
| AssessmentView :209 | **A** | controlBackgroundColor（AppKit 色板） | **L2-ST8** |
| MoveRecordPanel :14 / DemoSidePanel :13 / CommentaryPanel :10 | **B/C** | macOS 侧栏族（iOS 无侧栏场景） | existing V62LayoutTests（🟡） |
| BoardSizing :14/:20/:40 | **B** | 布局常量双平台值 | existing 布局套件消费 |
| PuzzleDemoView 等 `#if os(macOS)` `tacticalGroupFilterBar` 同上归并 | — | — | — |

## 四、定性汇总与结论

- **A（平台 API 必要）**：15 处 —— 无分叉即不可编译/无对应 API，全部合理
- **B（平台 UI 惯例）**：61 处 —— 双布局/导航/控件惯例；macOS test target 编译隔离 iOS 分支，上限 🟡，真运行时依赖 C1 UITests 收编扩容
- **C（桌面工具链限定）**：11 处 —— CLI/NSPasteboard 等桌面场景，iOS 缺失合理
- **D（历史债）**：0 处待拍板 —— 唯一候选（SettingsView:37 iOS 引擎开关入口）已随 v6.3 E5 开关全清退场删除；DemoControlBar 速度菜单形态差异已入 v6.4-ui-debt-ledger 不在 v6.3 scope
- **账目对账（Ruby P2①）**：96 = 87 处独立定性行（A15+B61+C11）+ 9 处组内归并行（如 ToolbarView macOS ×5 计 1 行、SelfPlayRunner ×6 计 1 行等——归并行各分量已在行内 ×N 标注，分类随组行）；38 文件（表头原 40 系底料快照时点口径，E5 删 SettingsView 开关等已漂移）
- ⭐ 三个逃逸史现场（ToolbarView/StatusBarView/SettingsView）全部落 L2 补桩锢定（ST1/ST2/ST3）
- 🔴→🟡 提升：Eric 热点排行 #2-#10 全部落桩（#1 SoundEngine 静态桩 + XCUITest 遗留）

## 五、补桩映射索引（L2PlatformBranchStubTests）

ST1 ToolbarView / ST2 StatusBarView / ST3 SettingsView E5 清账 / ST4 GameHistoryView:158 规避 / ST5 剪贴板调用点 / ST6 DemoInfoBar / ST7 MasterGameBrowserView 四点 / ST8 navBar 族+杂项（ChessBoardView 触感/ReplayControl/PrivacyPolicy/About/RankPrivilege/Tutorial/StudyHub/Assessment/PuzzleSelect iPad/ReplayView/PuzzleDemo:291:570）/ ST9 SoundEngine ×5 / ST10 TranspositionTable / ST11 EmbeddedPikafishEngine iOS 诊断+TT / ST12 CLI 入口族 guard
