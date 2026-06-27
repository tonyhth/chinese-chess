# Bug: 点击历史棋局后崩溃 (v2.2.18)

## 现象
- macOS/iOS 点击历史棋局回放后 App 崩溃退出
- 崩溃类型：`EXC_BAD_INSTRUCTION` (SIGILL)
- 崩溃栈核心：
  ```
  _assertionFailure(_:_:file:line:flags:)    (libswiftCore.dylib)
  ??                                          (SwiftUICore)
  ??                                          (SwiftUICore)
  specialized project2 ... KeyPath._projectReadOnly(from:) (libswiftCore.dylib)
  KeyPath._projectReadOnly(from:)            (libswiftCore.dylib)
  swift_getAtKeyPath                          (libswiftCore.dylib)
  ??                                          (SwiftUICore)  ← 符号被 strip
  AG::Graph::UpdateStack::update()            (AttributeGraph)
  ```

## 根因分析

### 直接原因
SwiftUI 的 `@Observable` KeyPath 追踪在 sheet/fullScreenCover 的 dismiss→present 过渡中 assertion failure。

### 根因链条

1. **`ReplayView` 用 `@State` 包装 `ReplayViewModel`（`@Observable` class）**
   ```swift
   struct ReplayView: View {
       @State private var viewModel: ReplayViewModel  // ← @State + class
       init(record: GameRecord) {
           self._viewModel = State(initialValue: ReplayViewModel(record: record))
       }
   }
   ```

2. **`.sheet(item: $historyReplayRecord)` / `.fullScreenCover(item:)` 的 dismiss→present 过渡**中，SwiftUI 的 AttributeGraph 可能持有对旧 ViewModel 实例的 KeyPath 观察引用

3. **旧 ViewModel 已释放但 AttributeGraph 仍尝试通过 KeyPath 访问其属性** → assertion failure → EXC_BAD_INSTRUCTION

4. **附加因素**：`ReplayViewModel` 持有 `Board`（也是 `@Observable` class），`board.execute()` 修改 Board 内部状态但不替换实例。SwiftUI 追踪嵌套 `@Observable` 的属性变化时也可能触发内部断言。

### 崩溃日志位置
- macOS: `~/Library/Logs/DiagnosticReports/ChineseChess-2026-06-17-111646.ips`
- macOS: `~/Library/Logs/DiagnosticReports/ChineseChess-2026-06-17-111500.ips`

## 修复方案

### 修复 1（必须）：给 ReplayView 的所有 sheet/fullScreenCover 加 `.id(record.id)`

**macOS App** (`ChineseChessApp.swift`)：

`.sheet(isPresented: $showReplay)` — toolbar 回放按钮：
```swift
.sheet(isPresented: $showReplay) {
    if let record = replayRecord {
        ReplayView(record: record)
            .frame(minWidth: 520, minHeight: 680)
            .id(record.id)  // ← 新增
    }
}
```

`.sheet(item: $historyReplayRecord)` — 历史列表回放：
```swift
.sheet(item: $historyReplayRecord) { record in
    ReplayView(record: record)
        .frame(minWidth: 520, minHeight: 680)
        .id(record.id)  // ← 新增
}
```

**iOS App** (`ChineseChessiOSApp.swift`)：

`.fullScreenCover(isPresented: $showReplay)`：
```swift
.fullScreenCover(isPresented: $showReplay) {
    if let record = replayRecord {
        ReplayView(record: record)
            .id(record.id)  // ← 新增
    }
}
```

`.fullScreenCover(item: $historyReplayRecord)`：
```swift
.fullScreenCover(item: $historyReplayRecord) { record in
    ReplayView(record: record)
        .id(record.id)  // ← 新增
}
```

**原理**：`.id(record.id)` 强制 SwiftUI 在 record 变化时重建整个视图层次，清除旧的 AttributeGraph 追踪引用。

### 修复 2（建议）：ReplayViewModel 每次 board.execute() 后替换实例

`ReplayViewModel.swift` 中两处 `board.execute(m)` 后加 `self.board = board.snapshot()`：

**`goForward()` 方法**（约第 50 行）：
```swift
board.execute(m)
self.board = board.snapshot()  // ← 新增：替换实例避免嵌套 @Observable KeyPath 追踪
takeSnapshotIfNeeded(at: currentIndex)
```

**`rebuildBoard(upTo:)` 方法末尾**（约第 136 行，`board.execute(m)` 循环之后）：
```swift
        board.execute(m)
    }
    self.board = board.snapshot()  // ← 新增
}
```

**原理**：`@Observable` 追踪属性引用变化。替换实例让 SwiftUI 检测到 `ReplayViewModel.board` 属性本身的变化（旧实例→新实例），而不是深入追踪 Board 内部属性变化。`Board.snapshot()` 已有实现，创建新 Board 实例并复制 pieces。

### 同类风险（不阻塞，后续处理）

| 位置 | 模式 | 风险 |
|------|------|------|
| `PuzzlePlayView` | `@State` + `PuzzleViewModel` | ⚠️ sheet 内 NavigationLink 推入 |
| `StatsPanelView` | `@State` + `StatsViewModel` | ⚠️ sheet 内 |
| `GameViewModel` | App 层 `@State`，所有 sheet 共享 | ⚠️ 低（单例，生命周期=App） |

## 验证要求

1. `swift test` 全部通过（当前 886 tests）
2. macOS App：下完一局后点击历史棋局回放，不崩溃
3. iOS App：同上
4. 回放功能正常：前进、后退、自动播放、跳到末尾
