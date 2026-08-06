# v5.5.3 UI Bug 审计报告

> **审计人**: Alex（架构师）
> **日期**: 2026-08-03
> **触发**: 洪涛真机测试发现3个UI bug
> **范围**: 大师棋谱sidebar + 残局演示列表 + 残局演示导航

---

## 问题1 [P0]：大师棋谱 sidebar 只显示数字不显示名称

### 现象
左侧赛事/棋手列表只显示数字（棋谱数量），名称不显示。右侧"暂无棋谱数据"。

### 代码审查

**macOS sidebar 渲染逻辑**（`MasterGameBrowserView.swift`）：

```swift
// eventSidebarContent (行362-380)
ForEach(visible, id: \.stableId) { event in
    HStack {
        Text(event.nameCN)                    // ← 名称
            .font(.subheadline)
        if let year = event.year {
            Text("\(year)")...                // ← 年份
        }
        Spacer()
        countBadge(event.count)               // ← 数字
    }
    .tag(SidebarSelection.event(event))
}
```

代码本身逻辑正确——HStack 中 Text(nameCN) 在前，countBadge 在后。如果名称不显示但数字显示，原因不是代码逻辑而是渲染问题。

### 根因分析

**最可能根因：`masterStore.stats` 为 nil → sidebar 显示空状态**

sidebar 在 `.event` / `.player` 模式下的数据来源：

```swift
if let events = masterStore.stats?.events {
    // 正常显示名称+数字
} else {
    Text(L10n.shared.t("master.statsUnavailable"))  // ← "统计不可用"
}
```

如果 `master-stats.json` **加载失败或未打包进 App Bundle**，则 `stats` 为 nil，sidebar 在按赛事/棋手模式下只显示空提示或仅有少量默认数据。

但洪涛说"只显示数字"——这意味着 sidebar 里确实有数据条目（有 `event.count` / `player.count` 显示），但 `Text(event.nameCN)` 渲染为空。

**第二可能根因：`nameCN` 字段为空**

检查 `MasterStatsFile.EventStat` / `.PlayerStat` 的 `nameCN` 字段定义：如果 JSON 中 `nameCN` 为空字符串或缺失，Text 渲染空串但 countBadge 正常显示。

### 修复方案

1. **验证数据完整性**：
```swift
// 在 loadIfNeeded() 后加日志
#if DEBUG
print("[MasterStore] stats loaded: \(stats != nil)")
print("[MasterStore] players: \(stats?.players?.count ?? 0)")
print("[MasterStore] events: \(stats?.events?.count ?? 0)")
if let p = stats?.players?.first { print("[MasterStore] sample player: nameCN='\(p.nameCN)' count=\(p.count)") }
if let e = stats?.events?.first { print("[MasterStore] sample event: nameCN='\(e.nameCN)' count=\(e.count)") }
#endif
```

2. **如果是 nameCN 字段映射问题**：检查 `MasterStatsFile` 的 Codable 定义，确认 `nameCN` 的 JSON key 映射正确。

3. **如果是资源未打包**：检查 `xcodegen generate` 后的 `.app` bundle 是否包含 `master-stats.json`。

### 影响范围
- 改动量：诊断 + 可能只需要修 Codable mapping 或资源打包配置
- 风险：低

---

## 问题2 [P1]：残局演示列表布局不完整

### 现象
左侧列表只显示数字编号，残局名称/分类名称不显示。右侧内容区空白。

### 代码审查

**PuzzleDemoView.swift sidebar（macOS）**：

```swift
private var sidebar: some View {
    List(selection: $selectedCategory) {
        Section(L10n.shared.t("demo.sectionPuzzles")) {
            ForEach(PuzzleStore.shared.demoCategories, id: \.self) { cat in
                let count = PuzzleStore.shared.demoPuzzles(byCategory: cat).count
                HStack {
                    Text(DemoCategory.puzzles(cat).displayName)  // ← 分类名
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")                            // ← 数字
                        ...
                }
                .tag(DemoCategory.puzzles(cat))
            }
        }
    }
}
```

**`DemoCategory.displayName`** 的实现是关键——如果返回空字符串，则只显示数字。

### 根因分析

**最可能根因：`DemoCategory.puzzles(cat).displayName` 返回空字符串**

`DemoCategory` 是个枚举，`displayName` 可能通过 i18n key 查询。如果 key 不存在或映射错误，返回空串。

**第二可能根因：`PuzzleStore.shared.demoCategories` 返回的 category 名是 ID 而非显示名**

`demoCategories` 返回的是 `Array(Set(demoPuzzles.map { $0.category })).sorted()`——这是 puzzle 的 `category` 字段（如 "endgame_tactical"），不是用户可读的名称。如果 `DemoCategory.displayName` 直接用这个 ID 作为 i18n key 但没有对应翻译，就会显示空。

### 修复方案

1. **检查 DemoCategory.displayName 实现**：
```swift
// 需要确认 DemoCategory 定义
var displayName: String {
    switch self {
    case .puzzles(let name):
        return L10n.shared.t("demo.category.\(name)")  // ← 如果 key 不存在返回 key 本身还是空？
    }
}
```

2. **如果是 i18n key 缺失**：补充对应 key 到 Localizable.xcstrings

3. **右侧空白**：右侧是 `listContent`，当 `selectedCategory == nil` 时显示"选择分类"提示。如果左侧名称不显示导致用户无法选择 → 右侧始终空白。修好左侧名称后右侧自动解决。

### 影响范围
- 改动量：可能只需补几个 i18n key 或修 displayName 映射
- 风险：低

---

## 问题3 [P1]：残局演示点不进去

### 现象
从学棋中心→残局闯关→残局演示卡片，NavigationLink(value:) 可能不响应。

### 代码审查

**导航路径**：
1. `StudyHubView` → `NavigationLink(destination: ChapterSelectView())` ✅ 直接 destination
2. `ChapterSelectView` → `NavigationLink(value: NavigationRoute.puzzleDemo)` → 残局演示入口卡片
3. `ChapterSelectView` 内 `.navigationDestination(for: NavigationRoute.self)` 处理路由：

```swift
.navigationDestination(for: NavigationRoute.self) { route in
    switch route {
    case .chapter(let chapter): PuzzleSelectView(chapter: chapter)
    case .puzzleDemo: PuzzleDemoView()                              // ← 目标
    case .masterGame: MasterGameBrowserView()
    case .openingExplorer: OpeningExplorerView()
    }
}
```

### 根因分析

**根因：`navigationDestination` 注册在 `ChapterSelectView` 的 body 上，但 `StudyHubView` 的 `NavigationLink(destination:)` 使用的是直接 destination（不是 value-based）**

当从 `StudyHubView` 通过 `NavigationLink(destination: ChapterSelectView())` 进入 `ChapterSelectView` 时，ChapterSelectView 内部的 `NavigationLink(value: NavigationRoute.puzzleDemo)` 需要一个 `NavigationStack` 上下文来处理 value-based 导航。

**关键问题**：如果 `StudyHubView` 外层没有 `NavigationStack`，或 `ChapterSelectView` 被推入时没有继承 NavigationStack 上下文，`NavigationLink(value:)` 不会响应。

检查：`StudyHubView` 被用在哪里？

```swift
// 典型用法（ContentView 或主视图）
NavigationStack {
    StudyHubView()
}
```

如果 `NavigationLink(destination:)` 推入 `ChapterSelectView`，新的 view 继承 NavigationStack。然后 `ChapterSelectView` 内的 `NavigationLink(value:)` 应该能工作。

**但有一个微妙问题**：`navigationDestination(for:)` 和 `NavigationLink(destination:)` 混用时，destination-based Link 不走 NavigationStack 的路由系统。如果 ChapterSelectView 内部用 `NavigationLink(value:)` 但 `navigationDestination` 没有正确关联到同一个 NavigationStack，value-based link 会失效。

**最可能的具体根因**：`navigationDestination(for: NavigationRoute.self)` 挂在 `ChapterSelectView` 的 body 上，但它只处理到达 ChapterSelectView **之后**产生的 value-based NavigationLink。如果 ChapterSelectView 是通过 destination-based NavigationLink 推入的（StudyHubView 中 `studyCard(destination: ChapterSelectView())`），navigationDestination 应该正常工作——它在 ChapterSelectView 的父 NavigationStack 中注册。

**排查方向**：
1. 确认 `StudyHubView` 外层确实有 `NavigationStack`
2. 在 `ChapterSelectView` 的 NavigationLink(value:) 处加 `.simultaneousGesture(TapGesture().onEnded { print("tapped puzzleDemo") })` 确认点击事件是否触发
3. 检查 iOS 真机上 `NavigationRoute.puzzleDemo` 的 Hashable 实现是否正确

### 修复方案

**方案 A（推荐）**：如果确认 `navigationDestination` 在某些路径下不生效，改为 destination-based：

```swift
// ChapterSelectView 中
NavigationLink(destination: PuzzleDemoView()) {  // ← 直接 destination
    DemoEntryCard(...)
}
// 替代
// NavigationLink(value: NavigationRoute.puzzleDemo) { ... }
```

简单直接，消除 value-based 导航的潜在问题。

**方案 B**：如果需要保持 value-based（如 deep linking 支持），确保 NavigationStack 在顶层包裹所有导航路径，且 navigationDestination 在正确的层级注册。

### 影响范围
- 改动量：1个 NavigationLink 改法（方案A）
- 风险：低
- 注意：如果方案A，`navigationDestination(for:)` 中的 `.puzzleDemo` case 可以保留（向后兼容）也可以删除

---

## 总结

| # | 问题 | 级别 | 根因（最可能） | 修复方向 |
|---|------|------|--------------|---------|
| 1 | 大师棋谱 sidebar 名称不显示 | P0 | `masterStore.stats` 为 nil 或 `nameCN` 字段为空 | 验证数据加载+JSON映射 |
| 2 | 残局演示列表名称不显示 | P1 | `DemoCategory.displayName` i18n key 缺失 | 补 i18n key 或修映射 |
| 3 | 残局演示点不进去 | P1 | `NavigationLink(value:)` + `navigationDestination` 在真机上可能不生效 | 改为 `NavigationLink(destination:)` |

### 排查优先级

1. **先确认问题1和2是数据问题还是渲染问题**——在真机上加 debug 日志，打印 `stats?.events?.first?.nameCN` 和 `DemoCategory.puzzles(cat).displayName` 的实际值
2. **问题3** 如果是 NavigationLink value-based 不生效，直接改 destination-based 最快

### 共同点

问题1和2可能是**同一类问题**：i18n key 或数据字段映射缺失导致名称为空。如果近期有 JSON 结构变更或 i18n key 重命名，两个问题可能同源。

---

## 实施建议

| 步骤 | 负责人 | 工作内容 |
|------|--------|---------|
| 1 | Cody | 问题1：加 debug 日志验证 stats 加载和 nameCN 值 |
| 2 | Cody | 问题2：加 debug 日志验证 displayName 返回值 |
| 3 | Cody | 问题3：NavigationLink(value:) 改为 destination-based |
| 4 | Tina | 真机验证3个问题是否修复 |
