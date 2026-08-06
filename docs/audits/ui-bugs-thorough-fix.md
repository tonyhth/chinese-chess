# v5.5.3 UI Bug 彻底修复方案

> **设计人**: Alex（架构师）
> **日期**: 2026-08-03
> **版本**: v1.4 — Vera 审查通过，步骤1+2合并建议 + 步骤3(frame+overlay)为推荐方案
> **触发**: 洪涛要求彻底修复3+1个UI问题，不接受"加日志"和"无法复现"

---

## 问题A [P0]：macOS sidebar 只显示数字不显示名称

### 现象
macOS 下大师棋谱和残局演示的左侧 sidebar 只显示数字（棋谱/残局数量），名称不显示。iOS 下正常。

### 逐层排查

#### 层1：数据层 — ⚠️ 发现两个数据问题

**大师棋谱数据验证**：
- `master-stats.json` 中 `players[0].nameCN = "吕钦"` 等 — PlayerStat 数据正确 ✅
- **VB-1 [P0] EventStat.nameCN 全英文**：50条赛事的 `nameCN` 字段全部直接复制了英文名（如 `"2014 China Xiangqi League 2014"`），没有中文翻译。这是**数据质量问题**，不是代码 bug。洪涛看到的“名称不显示”可能是 sidebar 显示了不直观的英文赛事名
- `MasterStatsFile.PlayerStat.nameCN` 的 Codable 映射正确

**VB-1 修复**：更新 `data/master-stats.json` 中所有 EventStat 的 `nameCN` 字段为中文翻译

**残局演示数据验证**：
- `puzzles.json` 中 category 值为中文（"车马炮类"、"单车类"等）— 数据完整 ✅
- `DemoCategory.puzzles(cat).displayName` 直接返回 category 字符串（"车马炮类"），**不走 i18n**，不可能为空

**结论**：大师棋谱的 EventStat.nameCN 全英文是数据质量问题（VB-1）；残局演示的 displayName 数据无问题。

#### 层2：视图渲染层 — ⚠️ 发现根因

**大师棋谱 macOS sidebar**（`MasterGameBrowserView.swift`）：

```swift
// eventSidebarContent (行362)
ForEach(visible, id: \.stableId) { event in
    HStack {
        Text(event.nameCN)
            .font(.subheadline)       // ← 没有显式 foregroundColor
        ...
        Spacer()
        countBadge(event.count)        // ← countBadge 内部用 .foregroundStyle(.secondary)
    }
    .tag(SidebarSelection.event(event))
}
```

**残局演示 macOS sidebar**（`PuzzleDemoView.swift` 行129）：

```swift
ForEach(PuzzleStore.shared.demoCategories, id: \.self) { cat in
    HStack {
        Text(DemoCategory.puzzles(cat).displayName)
            .font(.subheadline)       // ← 没有显式 foregroundColor
        Spacer()
        Text("\(count)")              // ← 用了 .foregroundStyle(.secondary)
            ...
    }
    .tag(DemoCategory.puzzles(cat))
}
```

**根因定位**：两个 sidebar 的 `Text(name)` 都没有显式设置 `foregroundColor`。在 macOS 的 `List(.sidebar)` style 中：

1. **`.sidebar` style 使用 NSVisualEffectView 作为背景，带 vibrancy material（半透明混合效果）**：这是 macOS sidebar 的系统级行为。纯文字 Text（无背景装饰）在 vibrency material 上对比度极低，暗色模式下尤其严重（约 1.5:1 ~ 2:1），**视觉上极难辨认**。
2. **数字（countBadge）可见的原因**：countBadge 有 `.background(Color.secondary.opacity(0.1))` + `.clipShape(Capsule())`，Capsule 形状+背景提供了视觉锚点，绕过了 vibrancy 混合问题。

> **Vera 修正**：根因不是"sidebar 默认用 .secondary"，而是 vibrancy material 导致对比度问题。`.foregroundColor(.primary)` 修复方向正确，但需 Tina 在 4 种主题 × 亮/暗模式下截图验证。如果 `.primary` 在 vibrancy 上仍不够清晰，需用更强制的颜色方案。

**而 iOS 不受影响的原因**：iOS 用 `Button(action:) { categoryRow(name:count:) }` 包装，Button 的 `.buttonStyle(.plain)` 保留了 `Text` 的 `.body` 前景色（`.primary`），在 List 中清晰可见。

#### 修复方案

**方案：给 macOS sidebar 中所有名称 Text 加显式 foregroundColor**

```swift
// 修复1：MasterGameBrowserView.swift — eventSidebarContent
Text(event.nameCN)
    .font(.subheadline)
    .foregroundColor(.primary)          // ← 加这行

// 修复2：MasterGameBrowserView.swift — playerSidebarContent
Text(player.nameCN)
    .font(.subheadline)
    .foregroundColor(.primary)          // ← 加这行

// 修复3：MasterGameBrowserView.swift — openingSidebarContent
Text(opening.name)
    .font(.subheadline)
    .foregroundColor(.primary)          // ← 加这行

Text(sub.name)
    .font(.subheadline)
    .foregroundColor(.primary)          // ← 加这行

// 修复4：PuzzleDemoView.swift — sidebar
Text(DemoCategory.puzzles(cat).displayName)
    .font(.subheadline)
    .foregroundColor(.primary)          // ← 加这行
```

**改动量**：5处 Text 加 `.foregroundColor(.primary)`

**风险**：极低 — 只加 foregroundColor modifier，不改布局/逻辑

### 问题A 深入排查（v1.3 — Luke 预排查后的新线索）

#### 新线索

Luke 预排查确认：
1. **数据层正常**：master-stats.json 的 nameCN 有中文值，OpeningCategories 的 name 有中文值
2. **丹妮已加 `.foregroundColor(.primary)` 但无效** — **说明根因不是颜色**
3. **洪涛看到的数字是 15/45/59/32** — 不是 player.count（吕钦1837），更像是开局子分类的 gameCount
4. **PuzzleStore.demoCategories 只有1个分类"古谱残局"** — 残局演示 sidebar 只显示1行

#### 排除项

| 假设 | 状态 | 理由 |
|------|------|------|
| ❌ nameCN 为空 | 排除 | 数据验证有中文值 |
| ❌ foregroundColor 问题 | 排除 | 丹妮加了 .primary 后仍无效 |
| ❌ i18n key 缺失 | 排除 | displayName 直接返回中文 category，不经 i18n |
| ❌ 数据加载失败 | 排除 | 洪涛看到了数字 badge，说明数据已加载 |

#### 新根因假设（按可能性排序）

**假设1 [最可能]：HStack 中 Text 被 Spacer + Capsule badge 挤压为 0 宽度**

在 macOS List `.sidebar` style 中，List row 的布局可能受到 NSTableView 的 cell 渲染影响。`HStack { Text; Spacer; countBadge }` 中：
- countBadge 有 `.padding` + `.background` + `.clipShape(Capsule())` — 是固定尺寸的 shaped view
- Text 只有 `.font(.subheadline)` — 是灵活尺寸的 text view
- Spacer 是灵活间距
- macOS 的 List cell 可能给 shaped view（Capsule）更高优先级，把 Text 压缩到最小宽度

**验证方式**：给 Text 加 `.fixedSize(horizontal: false, vertical: false)` 或 `.lineLimit(1)` + `.layoutPriority(1)`

**假设2 [可能]：DisclosureGroup 的 label HStack 渲染异常**

洪涛看到的 15/45/59/32 是子分类的小 gameCount。如果洪涛展开了 DisclosureGroup（如"仙人指路"展开看到"仙人指路对起马: 15"），label 中 Text("中炮") 被某种方式隐藏。

macOS 的 DisclosureGroup 在 sidebar List 中的 label 渲染与普通 HStack 不同——label 可能只显示文字部分，不显示 HStack 内的其他内容。

**假设3 [较少可能]：List(selection:) 的 tag 和 ForEach 的 id 冲突**

`ForEach(visible, id: \,stableId)` 使用 `stableId` 作为 id，而 `.tag(SidebarSelection.player(player))` 使用 `SidebarSelection` 作为 selection 标识。如果 List 的 selection binding 和 ForEach 的 id 不一致，可能导致 row 渲染异常。

#### 修复方案（分步验证）

**步骤1：加 layoutPriority**

```swift
// 所有 sidebar Text 加 layoutPriority(1)，确保优先占空间
Text(opening.name)
    .font(.subheadline)
    .foregroundColor(.primary)
    .layoutPriority(1)        // ← 新增：优先级高于 Spacer/badge
```

如果步骤1有效 → 根因是假设1（Text 被 Spacer+badge 挤压）

**步骤2（如果步骤1无效）：用 fixedSize**

```swift
Text(opening.name)
    .font(.subheadline)
    .foregroundColor(.primary)
    .fixedSize(horizontal: false, vertical: false)  // ← 允许 Text 按需扩展
```

**步骤3（如果步骤1+2都无效）：不用 HStack+Spacer，改用 frame**

```swift
// 替代 HStack { Text; Spacer; badge } 的写法
Text(opening.name)
    .font(.subheadline)
    .foregroundColor(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)  // ← 文字左对齐填满
    .overlay(alignment: .trailing) {
        countBadge(masterStore.gameCount(for: opening))
    }
```

这种写法不使用 HStack 和 Spacer，Text 用 frame 占满空间，badge 用 overlay 叠加在右侧。

**步骤4（终极方案）：换用 LazyVStack 替代 List**

如果 List(.sidebar) 本身有系统 bug，用 LazyVStack + ScrollView 替代：

```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: 0) {
        // 同样的 ForEach 内容，但不在 List 内
    }
}
```

代价：失去 List(selection:) 的自动 selection 管理，需要手动处理点击高亮。但完全绕过 List(.sidebar) 的所有渲染 bug。

#### Vera 审查补充（v1.4）

1. **步骤1+2 合并测试**：layoutPriority 和 fixedSize 解决同一类问题，合并不影响诊断
2. **步骤3（frame+overlay）是推荐方案**：完全绕过 HStack 布局协商，是 macOS NSTableView cell 问题的经典绕法。Cody 如时间紧迫可直接跳到步骤3
3. **假设6（Vera 补充）**：modePicker/searchField 的 `.listRowSeparator(.hidden)` 可能有副作用影响同 Section 其他 row。如步骤1-3都无效，检查此 modifier
4. **数据纠正**：Luke 说"PuzzleStore.demoCategories 只有1个分类'古谱残局'"不准确——实际有10个分类（兵类/单炮类/单车类等），建议向 Luke 确认信息来源

#### 实施建议

Cody 从步骤3（frame+overlay）开始测试，这是最可能生效的方案。如果生效则确认根因为 HStack 布局挤压。

---

## 问题B [P0]：残局演示点不进去

### 现象
学棋中心 → 残局闯关 → 残局演示卡片，点击无反应。

### 导航链路分析

```
ChineseChessiOSApp (行73: NavigationStack)
  └─ ToolbarView (行162: NavigationLink { StudyHubView() })  ← destination-based
      └─ StudyHubView (行111: NavigationLink(destination: ChapterSelectView()))  ← destination-based
          └─ ChapterSelectView
              ├─ 行27: NavigationLink(value: NavigationRoute.puzzleDemo) { DemoEntryCard }  ← value-based
              ├─ 行42: NavigationLink(value: NavigationRoute.chapter(chapter)) { ChapterCard }  ← value-based
              └─ 行67: .navigationDestination(for: NavigationRoute.self) { ... }
```

### 根因定位

**根因：destination-based 和 value-based NavigationLink 混用，导致 `navigationDestination(for:)` 注册时机问题**

当 ChapterSelectView 通过 destination-based `NavigationLink(destination:)` 被推入 NavigationStack 后：
1. ChapterSelectView 的 `.navigationDestination(for: NavigationRoute.self)` 挂在 ChapterSelectView 的根 VStack 上
2. **但 `navigationDestination(for:)` 只在视图**第一次出现并完成布局后**才注册到 NavigationStack 的路由表**
3. 在注册完成前，用户点击 `NavigationLink(value: .puzzleDemo)` 时，NavigationStack 找不到匹配的 destination → **点击无反应**

这是 SwiftUI iOS 16/17 的已知行为：`navigationDestination(for:)` 的注册不是同步的——它在视图 appear 后的下一个 runloop 才生效。如果用户快速点击，或者在视图刚出现时点击，value-based link 不响应。

**为什么"v5.2 Phase B2 改了入口路由仍然点不进去"**：Phase B2 可能改了路由定义（NavigationRoute 枚举），但没有解决 destination-based → value-based 的**混用断裂**问题。

### 修复方案

**方案：ChapterSelectView 内的 NavigationLink(value:) 全部改为 NavigationLink(destination:)**

```swift
// 修复前 (行27):
NavigationLink(value: NavigationRoute.puzzleDemo) {
    DemoEntryCard(...)
}

// 修复后:
NavigationLink(destination: PuzzleDemoView()) {
    DemoEntryCard(...)
}

// 修复前 (行42):
NavigationLink(value: NavigationRoute.chapter(chapter)) {
    ChapterCard(chapter: chapter)
}

// 修复后:
NavigationLink(destination: PuzzleSelectView(chapter: chapter)) {
    ChapterCard(chapter: chapter)
}
```

> **VB-3 补充（Vera 审查）**：chapter 的 NavigationLink 也必须一并改为 destination-based。如果 puzzleDemo 的 value-based link 失效，chapter 的同样会失效——两者在同一视图中使用相同的导航机制。

**`navigationDestination(for:)` 可保留也可删除**：改为 destination-based 后不再需要，但保留不影响功能（向后兼容）。建议保留，未来如有 deep linking 需求可复用。

**改动量**：2处 NavigationLink 改 value→destination

**风险**：低 — destination-based 是最稳定的导航方式

---

## 问题C [P1]：新手教程入口藏太深

### 现象
教程入口只在首次启动弹窗和设置里，日常使用中不易找到。

### 修复方案

在 `StudyHubView` 增加教程入口卡片，与其他功能平级：

```swift
// macOSLayout 和 iOSLayout 中都加:
studyCard(
    title: l10n.t("tutorial.title"),
    icon: "graduationcap.fill",
    color: .green,
    destination: TutorialView(onComplete: nil)
)
```

位置建议：放在 StudyHubView 卡片列表的**第一位**——新手教程是学习路径的起点，应排在所有功能之前。

**新增 i18n key**:
- `tutorial.title` = "新手教程" / "Beginner Tutorial"

（如 `tutorial.title` key 已存在则复用。）

---

## 问题D [P2]：三个棋盘布局复用评估

### 现状

| 视图 | 棋盘组件 | 控制栏 | 信息栏 |
|------|---------|--------|--------|
| 大师棋谱 (MasterGameBrowserView) | DemoBoardView | DemoControlBar | DemoInfoBar |
| 残局演示 (PuzzleDemoView) | DemoBoardView | DemoControlBar | 无 |
| 开局探索 (OpeningExplorerView) | 自定义棋盘 | 自定义控制 | 自定义信息 |

### 评估

**DemoBoardView + DemoControlBar + DemoInfoBar 已被大师棋谱和残局演示共用**。开局探索有独立的棋盘渲染。

**统一到单一棋盘组件的可行性**：
- 大师棋谱和残局演示已经统一 ✅
- 开局探索差异较大（需要走法标记、分支树等功能），强行统一会增加复杂度
- **建议**：当前架构已经合理——2个视图共用 Demo* 组件，开局探索独立。不推荐本轮统一

**工作量估算**（如强行统一）：3-5天（重构 OpeningExplorerView 的棋盘渲染 + 测试回归）

**结论**：不推荐本轮实施。当前 DemoBoardView 共用方案已足够。

---

## 实施清单

| 步骤 | 负责人 | 文件 | 改动 |
|------|--------|------|------|
| 1 | Cody | `MasterGameBrowserView.swift` | 6处 Text 加 `.foregroundColor(.primary)`（问题A） |
| 2 | Cody | `PuzzleDemoView.swift` | 1处 Text 加 `.foregroundColor(.primary)`（问题A） |
| 3 | Cody | `ChapterSelectView.swift` | 2处 NavigationLink value→destination（问题B，含 chapter link） |
| 4 | Cody | `StudyHubView.swift` | 加教程入口卡片（问题C） |
| 5 | Cody | `data/master-stats.json` | VB-1：翻译50条 EventStat 的 nameCN 为中文 |
| 6 | Cody | `Localizable.xcstrings` | 补 `tutorial.title` key（如需要） |
| 7 | Ruby | 审查 | 代码质量 |
| 8 | Tina | 测试 | macOS 截图确认 + 导航链路 + 教程入口 + 赛事名称中文 |

**问题D**：不实施，评估结论为"当前架构合理"。

---

## 验收标准

| 问题 | 验收条件 |
|------|---------|
| A | macOS 大师棋谱 sidebar 中赛事/棋手/开局名称清晰可见（4种主题下截图确认） |
| A | macOS 残局演示 sidebar 中分类名称清晰可见 |
| B | iOS 和 macOS 均能从学棋中心 → 残局闯关 → 残局演示正常进入 |
| C | 学棋中心页面可见"新手教程"入口卡片，点击进入教程 |
