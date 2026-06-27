# v3.2.3 红黑切换按钮重新设计

> 仅为 macOS 分支设计，iOS 不动。

## 问题分析

当前红黑切换是一个 20×20 圆点（`Circle` + `fill`），嵌在 `.buttonStyle(.bordered)` 框架中。虽然用了 `.bordered` 保持与其他按钮的容器一致性，但内容形态差异明显：

- 其他按钮：SF Symbol 图标，形状规整，语义明确
- 红黑按钮：纯色圆点，没有图标语义，视觉上像"装饰"而非"控件"

核心矛盾：**控件内容形态不统一**，导致用户第一眼无法理解这个圆点的功能。

## 候选方案

---

### 方案 A：实心圆 + 颜色切换（推荐）

**视觉风格**

- 形状：使用 SF Symbol `circle.fill`（单层实心圆，无外环）
- 尺寸：与右侧引擎切换按钮一致——不显式设 `.controlSize(.small)`，由 `.buttonStyle(.bordered)` 默认控制（见下方"右侧按钮尺寸策略"说明）
- 颜色：用 `.tint()` 区分——执红时 `.red`，执黑时 `Color(white: 0.2)`
- 状态表现：tint 着色整个图标为统一颜色。单层 `circle.fill` 在统一着色下不会出现层次丢失问题（双层的 `circle.circle.fill` 才会因内外同色丢失层次感）

```
执红状态：●  .tint(.red)             → 红色实心圆
执黑状态：●  .tint(Color(white: 0.2)) → 深灰/近黑色实心圆
```

**交互方式**

- 点击：切换执方 + 自动开新局（行为不变）
- Hover：`.bordered` 按钮自带的 hover 效果，无需额外处理
- Disabled（`isThinking`）：降低 opacity 至 0.5（与现有引擎切换按钮一致）

**与其他按钮的协调性**

- ✅ 统一使用 SF Symbol 图标（`circle.fill`）
- ✅ 统一使用 `.buttonStyle(.bordered)`
- ✅ 统一使用 `.tint()` 表达状态色
- ✅ 与右侧引擎切换按钮尺寸一致（均不显式设 `.controlSize`）
- ✅ 圆形语义天然关联"选择执方"——用户能理解这是一个有状态切换

**已知 trade-off**：方案 A 使用纯图标，没有文字标签。与新用户的可发现性低于左侧带文字 `Label` 的按钮。这与引擎切换按钮（也是纯图标）保持一致，属于"低频操作区纯图标"的设计策略，可接受。

**SwiftUI 实现要点**

```swift
Button(action: {
    let newSide: Side = viewModel.humanSide == .red ? .black : .red
    viewModel.setHumanSide(newSide)
    viewModel.newGame()
}) {
    Image(systemName: "circle.fill")
}
.disabled(viewModel.isThinking)
.opacity(viewModel.isThinking ? 0.5 : 1.0)
.buttonStyle(.bordered)
.tint(viewModel.humanSide == .red ? .red : Color(white: 0.2))
.help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
.accessibilityLabel(l10n.t("game.sideLabel"))
```

删除原有的 `Circle().fill().frame().overlay().frame()` 全部手动布局。

---

### 方案 B：分屏图标

**视觉风格**

- 形状：使用 SF Symbol `person.line.dotted.person`
- 尺寸：不显式设 `.controlSize(.small)`
- 颜色：`.tint(.red)` / `tint(Color(white: 0.2))`
- 状态表现：与方案 A 一致

**交互方式**

- 与方案 A 完全一致

**与其他按钮的协调性**

- ⚠️ `person.line.dotted.person` 语义偏"对战"而非"执方选择"，可能引起误解
- ✅ 形态统一，但图标语义不够精准

**SwiftUI 实现要点**

```swift
Button(action: {
    let newSide: Side = viewModel.humanSide == .red ? .black : .red
    viewModel.setHumanSide(newSide)
    viewModel.newGame()
}) {
    Image(systemName: "person.line.dotted.person")
}
.disabled(viewModel.isThinking)
.opacity(viewModel.isThinking ? 0.5 : 1.0)
.buttonStyle(.bordered)
.tint(viewModel.humanSide == .red ? .red : Color(white: 0.2))
.help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
.accessibilityLabel(l10n.t("game.sideLabel"))
```

---

### 方案 C：下拉菜单（Picker 风格）

**视觉风格**

- 形状：使用 `Picker` + `.menu` 样式，与难度选择器视觉统一
- 选项：`["执红先行", "执黑后行"]`
- 颜色：跟随系统默认，不做额外 tint
- 状态表现：与现有 `Picker` 一致

**交互方式**

- 点击：展开下拉菜单，选择执方后自动开新局
- Hover/Disabled：系统默认行为

**边界情况**：Picker 选择后自动 dismissal，但 `newGame()` 会重置棋盘。如果 `newGame()` 执行有延迟（如引擎启动慢），用户可能看到菜单收起但棋盘尚未更新。这是 Picker 方案的固有限制，方案 A/B 的一键切换不存在此问题。

**与其他按钮的协调性**

- ✅ 与难度 Picker 视觉完全统一
- ⚠️ 但改变了交互模型——从"一键切换"变成"选择-确认"两步
- ⚠️ 工具栏右侧出现两个 Picker，视觉单调

**SwiftUI 实现要点**

```swift
Picker(l10n.t("game.sideLabel"), selection: Binding(
    get: { viewModel.humanSide },
    set: { side in
        viewModel.setHumanSide(side)
        viewModel.newGame()
    }
)) {
    Label(l10n.t("game.redSide"), systemImage: "circle.fill")
        .tag(Side.red)
    Label(l10n.t("game.blackSide"), systemImage: "circle.fill")
        .tag(Side.black)
}
.pickerStyle(.menu)
.labelsHidden()
.help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
```

## 方案对比

| 维度 | A（实心圆） | B（分屏图标） | C（下拉菜单） |
|------|-----------|-------------|-------------|
| 视觉统一性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 操作效率（一键切换） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 语义清晰度 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 实现复杂度 | 极低（删代码） | 极低 | 低 |
| 与现有代码兼容 | 只改按钮内部 | 只改图标名 | 需改结构 |
| 改动范围 | 仅 `ToolbarView.swift` | 仅 `ToolbarView.swift` | 仅 `ToolbarView.swift` |

## 推荐

**方案 A**。

理由：
1. **改动最小**——本质上是把手动绘制的 `Circle` 替换为一个 SF Symbol，删除多余的手动 frame 布局
2. **形态统一**——与其他按钮保持一致的 SF Symbol + `.bordered` 风格
3. **保留一键切换**——不改变交互模型，用户已有的使用习惯不受影响
4. **颜色对比明确**——执红 `.red` vs 执黑 `Color(white: 0.2)`，对立感强，不与 disabled 状态（opacity 0.5）混淆
5. **单层图标无层次问题**——`circle.fill` 是单层图形，tint 统一着色不会出现双层图标内外同色的层次丢失问题

方案 B 的图标语义不够精准，方案 C 增加了操作步骤且存在 dismissal 时机问题。A 是最稳妥的选择。

## 右侧按钮尺寸策略

当前工具栏布局分为左右两组：
- **左侧**（棋局控制）：新局、悔棋、提示——均设置了 `.controlSize(.small)`
- **右侧**（设置区）：难度 Picker、引擎切换、红黑切换——均**未**设置 `.controlSize(.small)`

这是现有的设计，左侧高频操作按钮稍小、右侧低频操作按钮使用默认尺寸，形成视觉层次。本次改动只替换红黑按钮的图标内容，不改尺寸策略，保持与引擎切换按钮一致。

## 实施说明

### 改动范围

- **仅改** `ToolbarView.swift` 的 macOS 分支（`#else` / `#if os(macOS)` 块内）
- 不改 iOS 分支
- 不改 `GameViewModel` 的逻辑
- 不新增 L10n key（复用现有的 `game.sideTooltip`（`%@` 格式）/ `game.sideLabel` / `game.redSide` / `game.blackSide`）

### 删除的代码

当前红黑按钮的整个自定义绘制部分：

```swift
// 删除这些
Circle()
    .fill(viewModel.humanSide == .red ? Color.red : Color(white: 0.2))
    .frame(width: 20, height: 20)
    .overlay(
        Circle()
            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
    )
    .frame(width: 36, height: 28)
```

替换为：

```swift
Image(systemName: "circle.fill")
```

### 保持不变的代码

- `disabled(viewModel.isThinking)`
- `opacity(viewModel.isThinking ? 0.5 : 1.0)`
- `.buttonStyle(.bordered)`
- `.help()`
- `.accessibilityLabel()`
- 点击行为（切换 + 新局）

## Vera 审查修复记录（v2）

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| 1 | P0 | `circle.circle.fill` 双层图标 tint 统一着色会丢失层次感 | 改为单层 `circle.fill`，tint 统一着色不影响单层图标 |
| 2 | P0 | 描述中出现 `imageScale(.medium)` + `.font(.title3)` 但代码块中没有 | 删除描述中的这两行，代码块和描述保持一致 |
| 3 | P1 | `.controlSize(.small)` 是否加的决策未说明 | 明确：右侧按钮不加 `.controlSize`，与引擎切换保持一致，属于现有设计策略 |
| 4 | P1 | 执黑用 `.secondary` 区分度不足，可能与 disabled 混淆 | 执黑改为 `Color(white: 0.2)`，与原设计颜色意图一致 |
| 5 | P1 | 方案 C 的 dismissal 时机未说明 | 在方案 C 的"交互方式"中补充边界情况 |
| 6 | P2 | 纯图标可发现性 trade-off 未承认 | 在方案 A 中增加"已知 trade-off"段落 |
| 7 | P2 | L10n `.help()` 参数拼接格式是否匹配 | 已确认 `game.sideTooltip` 使用 `%@` 格式，拼接正确 |
