# v3.2.3 红黑切换按钮颜色修复

> 紧急修复。macOS SwiftUI `.bordered` 按钮中 `Image(systemName:)` 不受 `.tint()` / `.foregroundStyle()` 影响（图标始终白色），需要替代方案。

## 问题根因

macOS SwiftUI 的 `.buttonStyle(.bordered)` 对纯 `Image` label 的颜色有特殊处理：`.tint()` 和 `.foregroundStyle()` 都无法改变图标颜色，图标始终保持系统默认色。这与 iOS 行为不同。

左侧按钮（新局、悔棋、提示）使用 `Label(text, systemImage:)`——文字部分能显示 tint 颜色，所以看起来正常。但纯图标按钮没有文字部分，颜色无法表达。

## 方案

---

### 方案 A：Label 文字 + 图标（推荐）

**核心思路**：利用 `.bordered` 对 `Label` 文字部分的颜色响应能力，用文字颜色表达红/黑状态，图标作为辅助。

**视觉表现**

```
执红：[ ● 红 ]    ← 文字"红"显示为红色，图标 circle.fill 跟随（或忽略）
执黑：[ ● 黑 ]    ← 文字"黑"显示为深灰色
```

- 形状：`Label` + `.bordered`，与左侧按钮风格完全一致
- 颜色：通过 `.tint()` 着色 Label 文字——`.tint(.red)` 显示红色文字，`.tint(Color(white: 0.2))` 显示深灰文字
- 尺寸：不设 `.controlSize(.small)`，与右侧引擎按钮一致（保持现有策略）

**SwiftUI 实现**

```swift
Button(action: {
    let newSide: Side = viewModel.humanSide == .red ? .black : .red
    viewModel.setHumanSide(newSide)
    viewModel.newGame()
}) {
    Label(l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide"),
          systemImage: "circle.fill")
}
.disabled(viewModel.isThinking)
.opacity(viewModel.isThinking ? 0.5 : 1.0)
.buttonStyle(.bordered)
.tint(viewModel.humanSide == .red ? .red : Color(white: 0.2))
.help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
.accessibilityLabel(l10n.t("game.sideLabel"))
```

**优点**

- ✅ 使用现有 L10n key（`game.redSide` = "红"，`game.blackSide` = "黑"），不新增
- ✅ 与左侧按钮 `Label` 风格统一
- ✅ `.tint()` 对 Label 文字在 `.bordered` 下生效（左侧按钮已验证）
- ✅ 改动极小：只替换按钮 label 内容 + 改用 `.tint()`
- ✅ 一键切换行为不变

**缺点**

- ⚠️ 右侧按钮从纯图标变成图标+文字，与引擎切换按钮（纯图标）风格略有差异
- ⚠️ 按钮宽度比之前稍大（多了文字），但"红"/"黑"只有一个字，影响很小

---

### 方案 B：手绘 Circle + 不用 .bordered

**核心思路**：放弃 `.bordered`，用自定义背景模拟按钮外观，内放手绘 Circle。

**视觉表现**

```
执红：[ 🔴 ]    ← 圆角矩形背景 + 红色填充 Circle
执黑：[ ⚫ ]    ← 圆角矩形背景 + 深灰填充 Circle
```

**SwiftUI 实现**

```swift
Button(action: {
    let newSide: Side = viewModel.humanSide == .red ? .black : .red
    viewModel.setHumanSide(newSide)
    viewModel.newGame()
}) {
    Circle()
        .fill(viewModel.humanSide == .red ? .red : Color(white: 0.2))
        .frame(width: 16, height: 16)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        )
}
.disabled(viewModel.isThinking)
.opacity(viewModel.isThinking ? 0.5 : 1.0)
.buttonStyle(.plain)
.help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
.accessibilityLabel(l10n.t("game.sideLabel"))
```

**优点**

- ✅ Circle 颜色完全可控（手绘不受 `.bordered` 限制）
- ✅ 视觉上保持"圆点"的原有语义
- ✅ 自定义背景模拟 `.bordered` 外观，hover 需额外处理

**缺点**

- ❌ 不使用 `.bordered`，需要手动模拟 hover/pressed/disabled 的视觉状态
- ❌ 自定义背景在 Dark Mode / Light Mode 下需要额外适配
- ❌ 与其他按钮的 hover 动画不一致（`.bordered` 有系统级 hover 效果）
- ⚠️ 实现复杂度高于方案 A

---

### 方案 C：Toggle + 自定义外观

**核心思路**：用 `Toggle` 控件 + `.toggleStyle(.button)` 替代 `Button`，利用 Toggle 的状态绑定。

**SwiftUI 实现**

```swift
Toggle(isOn: Binding(
    get: { viewModel.humanSide == .black },
    set: { isBlack in
        viewModel.setHumanSide(isBlack ? .black : .red)
        viewModel.newGame()
    }
)) {
    Label(l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide"),
          systemImage: "circle.fill")
}
.tint(viewModel.humanSide == .red ? .red : Color(white: 0.2))
.disabled(viewModel.isThinking)
.help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
```

**优点**

- ✅ Toggle 的选中/未选中状态自带视觉区分

**缺点**

- ❌ Toggle 点击后值变化触发 `newGame()`，但 Toggle 的 Binding set 会触发两次（isOn 变化 + newGame 内的 side 变化），可能导致副作用
- ❌ Toggle 语义是"开/关"，不是"红/黑切换"，用户理解成本高
- ⚠️ 过度设计

---

## 推荐

**方案 A**。

理由：
1. **直接解决问题**——利用 `.bordered` 对 `Label` 文字的颜色响应，绕过纯 Image 不着色的限制
2. **与现有按钮风格一致**——左侧三个按钮全部是 `Label(text, systemImage:)` + `.bordered`，方案 A 完全同构
3. **改动最小**——只改按钮 label 从 `Image(systemName:)` 变成 `Label(text, systemImage:)`，加 `.tint()`
4. **不过度设计**——不引入自定义背景、不引入 Toggle、不改变交互模型
5. **复用现有 L10n**——`game.redSide`("红")、`game.blackSide`("黑") 已有

方案 B 的自定义背景需要模拟系统按钮行为，方案 C 语义不匹配。A 是最稳妥、改动最小的选择。

## 改动范围

**仅改 `ToolbarView.swift` macOS 分支**，具体改动：

1. 按钮内容从 `Image(systemName: "circle.fill")` 改为 `Label(text, systemImage: "circle.fill")`
2. `.foregroundStyle(...)` 改为 `.tint(...)`
3. 其余（action、disabled、opacity、help、accessibilityLabel）不变
