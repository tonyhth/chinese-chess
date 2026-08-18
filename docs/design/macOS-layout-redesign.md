# macOS 页面布局重设计方案

| 项目 | 内容 |
|---|---|
| 设计人 | Alex（架构师） |
| 日期 | 2026-08-09 |
| 版本 | **v1.2（第 3 轮评审修复：Tina 5 条 P1 验收标准必补 + HSplitView 持久化技术验证结论）** |

---

## 一、现状分析

### 1.1 主窗口（ChineseChessApp.swift）

macOS 主窗口为纯垂直布局：

```
┌─────────────────────────────┐
│ ToolbarView（顶部按钮栏）     │
│ ChessClockView（棋钟）        │
│ BoardView（棋盘）              │ ← 棋盘占满中间
│ StatusBarView（状态栏）        │
│ 底部操作栏（15+ 按钮）         │
└─────────────────────────────┘
```

- 窗口 `defaultSize(760×860)`，`minWidth: 900, minHeight: 750`
- `windowResizability(.contentSize)` — 窗口可缩放但内容不会自适应
- 宽屏下棋盘居中、左右大量留白，空间浪费

### 1.2 演示页面（MasterGameBrowserView / PuzzleDemoView）

**macOS 播放布局**（两页面一致）：

```
┌─────────────────────────────┐
│ DemoInfoBar（标题 + 进度）    │
│ DemoBoardView（棋盘）         │ ← aspectRatio fit，居中
│ DemoControlBar（控制栏）      │ ← 全宽，点评 overlay 在底部
└─────────────────────────────┘
```

- `frame(minWidth: 600, minHeight: 700)` — 固定最小尺寸
- 棋盘使用 `aspectRatio(contentMode: .fit)` — **不会被拉伸变形**，但宽屏下左右留白
- 点评 CommentaryOverlay 浮在 DemoControlBar 上方 — 宽屏下位置合理但信息密度低

**核心问题**：macOS 宽屏下，棋盘右侧的大量空间完全浪费。信息栏、点评、走法列表都挤在棋盘上下方。

### 1.3 DemoControlBar

- macOS 和 iOS 分别有独立布局
- macOS：`HStack` 水平排列（播放控制 + 速度 + 连播 + 设置 + 返回）
- DemoConfigPopover 固定 `frame(width: 280)` — 合理，popover 不需要自适应

### 1.4 DemoInfoBar

- macOS：单行 `HStack`（标题 + 分类标签 + 副标题 + 进度）
- iOS：两行布局（标题行 + 副标题行）
- 问题不大，但宽屏下信息密度低

---

## 二、设计目标

### 2.1 macOS

1. **左右布局**：棋盘左 + 信息/点评右，利用宽屏空间
2. **窗口可自由缩放**：移除固定 minWidth 约束，改用弹性约束
3. **棋盘等比自适应**：棋盘随窗口大小等比缩放，不被拉伸
4. **点评栏位置合理**：从底部 overlay 移到右侧面板

### 2.2 iOS

1. **上下布局微调**：当前布局基本合理，仅优化间距和信息密度
2. **小屏适配**：确保 iPhone SE 等小屏设备可用

### 2.3 点评差异化

| 平台 | 点评位置 |
|------|---------|
| macOS | 右侧面板内（常驻显示区） |
| iOS | 底部 overlay（当前方式，弹出气泡） |

---

## 三、macOS 布局方案

### 3.1 演示页面（MasterGameBrowserView / PuzzleDemoView）

**当前**（垂直布局）：
```
┌──────────────────────────┐
│ InfoBar                  │
│ Board（居中，左右留白）    │
│ ControlBar + 点评 overlay │
└──────────────────────────┘
```

**方案**（左右布局）：
```
┌──────────────────┬───────────────────┐
│                  │ InfoBar           │
│                  │                   │
│    Board         │ 点评区（常驻）      │
│  （等比缩放）     │                   │
│                  │ 走法记录（可折叠）   │
│                  │                   │
│                  │ ControlBar        │
└──────────────────┴───────────────────┘
```

**关键设计**：
- 使用 **HSplitView** 分割左右（选定方案，不再考虑 HStack + GeometryReader）
  - 理由：(1) 项目已有先例 OpeningCoachSelectView；(2) 演示页面是 macOS 专用（`#if os(macOS)`）；(3) 用户可拖拽调整面板宽度是体验加分
- 左侧棋盘区域：`aspectRatio(contentMode: .fit)` + `frame(maxWidth: .infinity, maxHeight: .infinity)` — 棋盘等比缩放，始终居中
- 右侧面板：`frame(minWidth: 300, idealWidth: 340, maxWidth: 500)` — idealWidth 从 320 提到 340，确保 DemoControlBar 不溢出
- 右侧面板内容垂直排列：信息栏 → 点评区 → 走法记录 → 控制栏
- HSplitView 分割比例通过 `@AppStorage("demoSplitRatio")` 持久化 —— ⚠️ **v1.2 修正：该表述在 v1.1 为未验证假设，技术验证已完成，见下方「HSplitView 持久化技术验证（v1.2）」**

**右侧面板各组件**：

```
┌───────────────────┐
│ DemoInfoBar       │  ← 标题 + 分类 + 进度
├───────────────────┤
│                   │
│ 点评区（常驻）      │  ← CommentaryOverlay 改为常驻 View
│ 当前走法点评       │     不再是底部弹出气泡
│                   │
├───────────────────┤
│ 走法记录           │  ← 可折叠列表（macOS 默认展开）
│ 1. 炮二平五        │
│ 2. 马八进七        │
│ ...               │
├───────────────────┤
│ DemoControlBar    │  ← 控制栏（全宽）
└───────────────────┘
```

**点评区改造**：
- 新增 `CommentaryPanel`（macOS 专用，替代 CommentaryOverlay）
- 不再使用 ZStack overlay，改为右侧面板中的常驻区域
- 无点评时显示「暂无点评」占位
- 有点评时显示点评内容 + 类型图标 + 背景色

**走法记录**：
- macOS 专用 MoveRecordPanel 实现（不重构 iOS 版的 iosRecordPanel）
- macOS 默认展开显示，高亮当前走法，点击可跳转
- **两个演示页面（MasterGameBrowserView + PuzzleDemoView）都加走法记录面板**

### 3.2 窗口尺寸约束

```swift
// 演示页面（MasterGameBrowserView / PuzzleDemoView）
.frame(minWidth: 800, minHeight: 600)  // 从 600×700 改为 800×600（更宽更矮）
```

> **v1.1 修正（P0-1）**：主窗口 **不做布局改造**，仅调整窗口尺寸约束：
> ```swift
> // ChineseChessApp.swift 主窗口
> .frame(minWidth: 900, minHeight: 600)  // minHeight 从 750 降低到 600
> ```
> 主窗口的布局结构（ToolbarView / BoardView / StatusBarView / 底部操作栏）完全不变。

> **v1.1 新增（P1-5）**：演示页面通过 sheet 展示，sheet 的 minWidth 必须同步调整：
> ```swift
> // ChineseChessApp.swift 中 .puzzles 和 .studyHub 的 sheet
> .frame(minWidth: 800, minHeight: 700)  // 从 600×700 改为 800×700
> ```
> 否则左右布局在 sheet 中放不下。涉及的 sheet case：`.puzzles`、`.studyHub`（演示页面入口）。

---

## 四、iOS 布局方案

### 4.1 演示页面

当前上下布局基本合理，微调：

```
┌──────────────────────┐
│ DemoInfoBar          │
│                      │
│ Board                │
│                      │
│ CommentaryOverlay    │  ← 底部弹出气泡（保持不变）
│ DemoControlBar       │
├──────────────────────┤
│ 走法记录（可折叠）     │  ← 已有，保持
└──────────────────────┘
```

**微调项**：
- iPhone SE 小屏：DemoControlBar 按钮间距从 8pt 缩到 6pt（已有 `spacing: 8`，可加 sizeClass 判断）
- DemoInfoBar 副标题在极小屏（iPhone SE）可隐藏

### 4.2 点评位置

iOS 保持当前 CommentaryOverlay 底部弹出方式——合理，不改动。

---

## 五、代码改动范围

### 5.1 新增文件

| 文件 | 内容 |
|------|------|
| `CommentaryPanel.swift` | macOS 右侧面板点评常驻视图（从 CommentaryOverlay 派生） |
| `MoveRecordPanel.swift` | macOS 专用走法记录面板（不复用 iOS iosRecordPanel，独立实现） |
| `DemoSidePanel.swift` | macOS 右侧面板容器（InfoBar + CommentaryPanel + MoveRecordPanel + ControlBar） |

### 5.2 修改文件

| 文件 | 改动 | 工作量 |
|------|------|--------|
| `MasterGameBrowserView.swift` | `macosPlayLayout` 改为 HSplitView 左右布局 + 走法记录面板；sheet minWidth 600→800 | 中 |
| `PuzzleDemoView.swift` | `macosLayout` 改为 HSplitView 左右布局 + 走法记录面板；sheet minWidth 600→800 | 中 |
| `CommentaryOverlay.swift` | 不改动。macOS 用新的 CommentaryPanel 替代 overlay | 小（仅注释说明） |
| `DemoControlBar.swift` | macOS 版本适配右侧面板宽度（从全宽改为面板宽度） | 小 |
| `DemoInfoBar.swift` | macOS 版本适配右侧面板宽度 | 小 |
| `ChineseChessApp.swift` | 主窗口 minHeight 750→600（仅尺寸，不布局）；演示 sheet minWidth 600→800 | 小 |

> **v1.1 修正（P0-1）**：主窗口仅调整 minHeight，不做布局改造。

### 5.3 不改动的文件

- `DemoBoardView.swift` — 棋盘视图本身不需要改，`aspectRatio(contentMode: .fit)` 已正确
- `DemoConfigPopover.swift` — popover 固定宽度合理
- iOS 相关布局代码 — 保持不变

### 5.4 工期估算

| 工作项 | 工时 |
|--------|------|
| CommentaryPanel + MoveRecordPanel + DemoSidePanel | 4h |
| MasterGameBrowserView macOS 左右布局改造（含走法记录） | 4h |
| PuzzleDemoView macOS 左右布局改造（含走法记录） | 4h |
| DemoControlBar / DemoInfoBar 适配 | 2h |
| Sheet 尺寸约束调整 | 1h |
| 测试 + 调试 | 3h |
| **合计** | **~18h（约 2-3 天）** |

> **v1.1 修正**：删除响应式断点（-2h），MasterGameBrowserView 新增走法记录面板（+1h），PuzzleDemoView 同（+1h），新增 sheet 尺寸调整（+1h），测试减少（-1h）。总工时不变。

---

## 六、风险与缓解

| 风险 | 缓解 |
|------|------|
| HSplitView 拖拽分割比例不记忆 | 使用 `@AppStorage("demoSplitRatio")` 存储分割比例 —— v1.2 起改为下方技术验证结论（方案 A/B 待编码期 mini-spike 决选） |

### v6.2 窗口补项（08-15 派令，Luke；Vera HIG 审计 P0 包）

- **Info.plist 机制化**：CFBundleShortVersionString/CFBundleVersion 由硬编码 6.0.0 改 `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`，project.yml 设 6.1.0——发布线脱钩根治（与 iOS GENERATE_INFOPLIST_FILE 机制对齐）
- **Settings footer 版本号**：关于区新增版本行（Bundle 真实版本 + build），plist 修复同 commit 在前、footer 在后（保证读到的一开始就是对的）
- **About 页（双平台）**：Settings 关于区加入口——版本/版权/隐私/反馈（版本复用同机制）；反馈邮箱常量待 Luke 提供后激活

### HSplitView 持久化技术验证（v1.2，Tina P1-5/P1-6 清偿）

> 验证方式：macOS 15.7 SDK API 面核对 + GeometryReader 探针实测；完整探针代码存档 `docs/spikes/hsplit-persistence-probe.swift`（注释内含四问验证与结论）。日期 2026-08-15。

| 问题 | 结论 |
|------|------|
| @AppStorage 能否直接绑定 HSplitView 分割比例？ | **不能（编译期事实）**：HSplitView 公开 API 零分割参数（无 init 比例、无 Binding、无拖拽回调）——v1.1「@AppStorage 持久化」表述为未验证假设，Tina P1-6 质疑成立 |
| 比例值能否持久化（间接路径）？ | **能（有条件）**：子视图 GeometryReader 测宽 + onChange + debounce 0.5s 回写 @AppStorage——拖拽期间连续触发，直接写 = 高频 UserDefaults 写，必须 debounce |
| 重启后能否恢复到拖拽后比例？ | **不能（HSplitView 原生）**：首帧固定 50/50，无 init 比例参数，存储值无法初始化首帧分割 |

**可选方案（v6.2 编码期 mini-spike 决选，不在此押注）**：
- **方案 A（零代码降级）**：接受会话内记忆 + 重启回 50/50——若产品可接受（演示页非高频路径）则零成本；验收口径已按此语义写入 §七
- **方案 B（自管分割，~40 行）**：HStack + 计算 width + 自绘 handle + DragGesture——init 可用存储值、精确恢复、完全可控；代价 = 放弃 HSplitView 原生手感与自动最小宽度语义
- 决选时点：v6.2 编码首日 mini-spike（半天内可出），决策人 Luke（产品语义 A/B 分叉）
| 窗口缩小时右侧面板被压缩到不可用 | 右侧面板设 `minWidth: 300` 保底 |
| 左右布局后棋盘过大/过小 | 棋盘区域 `aspectRatio(.fit)` + `maxWidth: .infinity`，自动居中缩放 |
| DemoControlBar 在 280 宽度溢出 | idealWidth 设为 340（v1.1 已修正） |

---

## 七、验收标准

- [ ] macOS 演示页面（大师棋谱 + 残局）为左右布局
- [ ] macOS 窗口可自由缩放，棋盘等比自适应不被拉伸
- [ ] macOS 点评在右侧面板常驻显示（不再是底部弹出气泡）
- [ ] macOS 两个演示页面都有走法记录面板
- [ ] iOS 布局不受影响
- [ ] DemoControlBar 在右侧面板中正常工作
- [ ] iPhone SE 小屏无溢出
- [ ] 演示 sheet minWidth 从 600 提到 800（v1.1 新增）
- [ ] **HSplitView 拖拽比例持久化（v1.2/Tina P1-1）**：拖拽分割线→关闭演示→重新打开→分割比例按所选方案语义保持（方案 A/B 见 §三.1 技术验证；若选 A，验收口径 = 会话内记忆 + 重启回默认 50/50 的诚实降级，需产品接受）
- [ ] **走法记录交互（v1.2/Tina P1-2）**：走法记录面板高亮当前步 + 点击某步跳转到该局面（新增交互行为，非仅“有面板”）
- [ ] **点评内容同步（v1.2/Tina P1-3）**：切换走法时右侧常驻点评内容同步更新（非仅“常驻显示”）
- [ ] **Sheet 统一约束（v1.2/Tina P1-4）**：受影响 sheet 同步调整——经 Tina §五逐 case 核实：**仅 `.puzzles` 与 `.studyHub` 改 800**（演示页面入口）；`.toolbarReplay`/`.historyReplay` 不承载演示布局、不需改，但为避免 sheet 间窗口尺寸跳变，**建议**统一 800（产品裁量项，非硬验收）；`.settings`/`.achievements`/`.analysis` 不动
- [ ] （Tina P2-1 顺手补，非 P1）：无点评数据时点评区显示「暂无点评」占位
- 验收口径：自动化 T1-T10 + 半自动 M1-M10 + iOS 回归 I1-I6，**清单直接引 Tina 第 3 轮评审 §三/§五表，不再重抄**（避免双源漂移）；手动项（M5-M9 等）标注进验收记录
