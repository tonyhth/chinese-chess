# C12 + V2 方案：退出确认/进度保存 + 后台暂停计时器

> 版本：v2.1（基于当前代码状态，C1+C2、C11 已由 Cody 完成；v2.1 修复 Vera 审查 P0/P1）  
> 范围：P0 问题 C12 / V2  
> 原则：最小侵入，不改动已完成的部分

---

## 审查修订记录

| 版本 | 修订内容 |
|------|--------|
| v2.0 | 初版方案 |
| v2.1 | 修复 Vera 第一轮审查 2 个 P0 + 5 个 P1 + 部分 P2 |
| v2.2 | 修复 Vera 第二轮审查 2 个 P1 + 部分 P2，无 P0，方案可实施 |

---

## 1. C12：游戏中途退出确认 + 进度保存策略

### 1.1 现状分析

**退出路径**（所有游戏模式相同）：

```
用户点击 X 按钮 → dismiss() → fullScreenCover onDismiss → clearActiveSession()
```

问题：
1. **无确认对话框**：点击 X 直接退出，用户可能误触
2. **进度全丢**：onDismiss 无条件调用 `clearActiveSession()`，不区分"自然完成"和"中途退出"
3. **自然完成时重复清除**：ViewModel 内部 advance/forceEnd 已调用 `clearActiveSession()`，onDismiss 又清一次（无副作用但逻辑混乱）

**当前保存机制**（已有）：

| ViewModel | 每次操作后保存 | 自然完成时清除 |
|-----------|--------------|--------------|
| DailyChallengeViewModel | ✅ `saveActiveSession` in advance | ✅ `clearActiveSession` in advance（完成时）|
| SpellChallengeViewModel | ✅ `saveSession` in advance | ✅ `clearActiveSession` in advance（完成时）|
| GamePlayView (adventure/mistakeReview) | ✅ `saveActiveSession` in advance/selectAnswer/submitSpelling | ✅ `clearActiveSession` in advanceToNext（完成时）|
| MatchGameViewModel | ❌ 不保存 session | ❌ endGame 不调用 clearActiveSession |

### 1.2 方案设计

#### 核心原则

1. **退出前弹确认对话框**，用户主动确认后才退出
2. **onDismiss 不再无条件 clearActiveSession**——由游戏视图内部控制
3. **自然完成时 ViewModel 内部 clearActiveSession**（已实现，保持不变）
4. **中途退出时保留 session**，下次打开可恢复
5. **配对游戏例外**：卡牌碎片化状态不值得保存，退出即丢

#### 1.2.1 退出确认对话框

每个游戏视图新增 `@State private var showExitConfirmation = false`。

**交互流程**：

```
用户点击 X 按钮
    ↓
showExitConfirmation = true
    ↓
confirmationDialog 弹出：
  "确定退出吗？"
  [继续游戏] (cancel)
  [退出] (destructive)
    ↓ 点击退出
dismiss()
```

**各视图具体文案**：

| 视图 | 标题 | 消息 |
|------|------|------|
| GamePlayView（冒险/错题）| "确定退出吗？" | "当前进度将保存，下次可继续。" |
| DailyChallengeView | "确定退出吗？" | "今日挑战进度将保存，下次可继续。" |
| SpellChallengeView | "确定退出吗？" | "当前拼写进度将保存，下次可继续。" |
| MatchGameView | "确定退出吗？" | "退出后配对进度将不会保存。" |

**为什么不用 alert 而用 confirmationDialog**：
- iOS 上 confirmationDialog 是 bottom sheet 风格，符合 iOS 设计规范
- 支持 destructive 角色（红色文字），视觉上明确"退出"是危险操作

**实现模板**（以 DailyChallengeView 为例）：

```swift
// 新增 State
@State private var showExitConfirmation = false

// X 按钮改为触发确认
Button(action: { showExitConfirmation = true }) {
    Image(systemName: "xmark")
        .foregroundColor(VGColors.textSecondary)
        .padding(8)
}

// 挂 confirmationDialog
.confirmationDialog("确定退出吗？", isPresented: $showExitConfirmation, titleVisibility: .visible) {
    Button("继续游戏", role: .cancel) {}
    Button("退出", role: .destructive) {
        dismiss()
    }
} message: {
    Text("今日挑战进度将保存，下次可继续。")
}
```

**需要修改的视图**（4 个）：

1. `DailyChallengeView.swift` — `dailyPlayView` 中的 X 按钮
2. `MatchGameView.swift` — `matchPlayView` 中的 X 按钮
3. `SpellChallengeView.swift` — `spellPlayView` 中的 X 按钮
4. `GamePlayView.swift` — 游戏进行中没有 X 按钮（只有关卡选择器有），需在 `gamePlayContent` 中加一个退出按钮

> **GamePlayView 特殊处理**：当前 `gamePlayContent` 没有退出按钮，只有 `levelPickerView` 有。需要在游戏进行中的界面顶部加一个退出按钮（参考其他视图的 X 按钮样式）。

**不需要确认的场景**：
- 关卡选择器中的返回按钮（还没开始游戏）
- 结果页的返回按钮（游戏已自然完成）
- 错误页的返回按钮（游戏未开始）
- "今日已完成"页的返回按钮

这些场景中的 `dismiss()` 保持不变。

#### 1.2.2 MainTabView onDismiss 改造

**核心改动**：onDismiss 不再调用 `clearActiveSession()`。

```swift
// 改前
.fullScreenCover(isPresented: $isShowingAdventure, onDismiss: {
    adventureLevelId = nil
    app.progressRepo.clearActiveSession()   // ← 删掉
    adventureSheetId = UUID()
})

// 改后
.fullScreenCover(isPresented: $isShowingAdventure, onDismiss: {
    adventureLevelId = nil
    // 不再 clearActiveSession：
    // - 自然完成时 ViewModel 内部已 clear
    // - 中途退出时保留 session 供下次恢复
    adventureSheetId = UUID()
})
```

**onDismiss 按模式分类处理**（Vera P0 #2 修复）：

| 模式 | onDismiss | 理由 |
|------|-----------|------|
| adventure | 不 clear | 保留 session 供恢复 |
| spellChallenge | 不 clear | 保留 session 供恢复 |
| dailyChallenge | 不 clear | 保留 session 供恢复 |
| mistakeReview | 不 clear | 保留 session 供恢复 |
| **matchPairs** | **clear** ✅ | 配对游戏不保存进度，onDismiss 兜底清除 |

```swift
// 配对游戏 onDismiss 保留 clearActiveSession 作为兜底
.fullScreenCover(isPresented: $isShowingMatch, onDismiss: {
    matchLevelId = nil
    app.progressRepo.clearActiveSession()  // 配对游戏始终清除
    matchSheetId = UUID()
})

// 其他 4 个模式 onDismiss 删除 clearActiveSession
.fullScreenCover(isPresented: $isShowingAdventure, onDismiss: {
    adventureLevelId = nil
    // 不 clear：自然完成时 ViewModel 内部已 clear；中途退出保留 session
    adventureSheetId = UUID()
})
// ... 其他 3 个同理
```

**配对游戏双重保障**：
1. 自然完成 → `endGame()` 调用 `clearActiveSession()`
2. 中途退出 → 确认对话框 destructive action 调用 `clearActiveSession()`
3. 兜底 → `onDismiss` 调用 `clearActiveSession()`

三重保障确保配对游戏不会 session 泄漏。

#### 1.2.3 进度保存策略

| 模式 | 中途退出保存 | 保存内容 | 恢复方式 |
|------|------------|---------|---------|
| adventure | ✅ | session (currentIndex, score, combo, questions) | GamePlayView.resumeSession 已实现 |
| mistakeReview | ✅ | session (同上) | GamePlayView.resumeSession 已实现 |
| dailyChallenge | ✅ | session + remainingSeconds | **需新增 resume 逻辑** |
| spellChallenge | ✅ | session (currentIndex, score, combo) | **需新增 resume 逻辑** |
| matchPairs | ❌ | 不保存 | 退出即丢失 |

**关键发现**：GamePlayView 已有恢复逻辑（`resumeSession`），DailyChallengeView 和 SpellChallengeView 没有。

#### 1.2.4 GameSession 模型扩展

当前 `GameSession` 没有 `remainingSeconds` 字段，无法保存每日挑战的倒计时状态。

```swift
// Models/GameSession.swift — 新增字段
struct GameSession: Codable {
    // 现有字段不变 ...
    var remainingSeconds: Int? = nil   // 仅 dailyChallenge 使用，保存计时器状态
}
```

**Codable 向后兼容分析**（Vera P1 修复）：
- Swift 的 `Codable` struct 中，新增 Optional 字段带默认值 `= nil` 时，JSONDecoder 解码旧数据（缺少该 key）会自动使用默认值
- 但注意：Swift `Codable` 的 synthesized init 不会自动为缺失 key 使用属性默认值——需要让编译器合成 `init(from decoder:)` 时正确处理。实测 Swift 5.9+ 中 Optional 属性有默认值时，缺失 key 解码为 nil ✅
- **验证建议**：Cody 实施时写一个简单单测：用旧格式 JSON（无 remainingSeconds key）解码 GameSession，确认 remainingSeconds 为 nil

#### 1.2.5 DailyChallengeViewModel — 保存与恢复

**remainingSeconds 保存点明确标注**（Vera P1 修复）：

| 保存点 | 方法 | 代码位置 |
|--------|------|---------|
| SP-1 | `start()` | 创建 session 后：`session.remainingSeconds = remainingSeconds`（此时为 180）|
| SP-2 | `advance()` else 分支 | 每次切下一题：`s.remainingSeconds = remainingSeconds` |
| SP-3 | `selectAnswer()` / `submitSpelling()` | 答题后通过 answerTask → advance() → SP-2 触发 |

**SP-1 实现**：
```swift
// start() 中创建 session 后
var session = GameSession.create(mode: .dailyChallenge, questions: questions)
session.remainingSeconds = remainingSeconds  // SP-1
self.session = session
progressRepo.saveActiveSession(session)
```

**SP-2 实现**：
```swift
// advance() 的 else 分支中（每次切下一题时保存）
s.remainingSeconds = remainingSeconds  // SP-2
progressRepo.saveActiveSession(s)
```

> 注意：remainingSeconds 在 Timer Task 中每秒自减，但 saveActiveSession 只在 advance 时调用。也就是说保存的 remainingSeconds 比实际值最多多 1 秒（上次 advance 到这次的计时误差）。恢复后用户多 1 秒是可接受的。

**新增 resume 方法**：

```swift
func resume(_ savedSession: GameSession) {
    todayCompleted = progressRepo.isDailyCompleted  // 一致性检查（Vera P1 修复）
    todayBestScore = progressRepo.dailyBestScore
    session = savedSession
    remainingSeconds = savedSession.remainingSeconds ?? 180
    startTimer()
}
```

#### 1.2.6 DailyChallengeView — 恢复逻辑

```swift
// 改前
.task { viewModel.start() }

// 改后
.task {
    if let active = app.progressRepo.activeSession, active.gameMode == .dailyChallenge {
        viewModel.resume(active)
    } else {
        viewModel.start()
    }
}
```

#### 1.2.7 SpellChallengeViewModel — 保存与恢复

当前 `saveSession()` 已将 currentIndex/score/combo 写入 GameSession，保存链路完整。

**新增 resume 方法**：

```swift
func resume(_ savedSession: GameSession) {
    let questions = savedSession.questions
    words = questions.map { $0.word }
    currentIndex = savedSession.currentIndex
    score = savedSession.score
    combo = savedSession.combo
    maxCombo = savedSession.maxCombo
    isCompleted = false
}
```

#### 1.2.8 SpellChallengeView — 恢复逻辑

```swift
// 改前
.task { viewModel.start() }

// 改后
.task {
    if let active = app.progressRepo.activeSession, active.gameMode == .spellChallenge {
        viewModel.resume(active)
    } else {
        viewModel.start()
    }
}
```

#### 1.2.9 MatchGameViewModel — endGame 补充 clearActiveSession

当前 `endGame()` 不调用 `clearActiveSession()`。修改后 onDismiss 虽然会兜底 clear，但自然完成路径也应该 clear（减少对 onDismiss 时序的依赖）。

```swift
// MatchGameViewModel.endGame() 中新增
private func endGame() {
    isCompleted = true
    score += remainingSeconds * 5
    progressRepo.clearActiveSession()  // 新增：配对游戏完成时清除
    saveResult()
}
```

### 1.3 修改文件清单

| 文件 | 改动 | 风险 |
|------|------|------|
| `GameSession.swift` | 新增 `remainingSeconds: Int?` | 低（Optional 字段，向后兼容） |
| `MainTabView.swift` | 5 个 onDismiss 删除 `clearActiveSession()` | **中**（核心退出逻辑变化） |
| `DailyChallengeView.swift` | 新增退出确认 + resume 逻辑 | 中 |
| `DailyChallengeViewModel.swift` | 新增 `resume()`、保存时写入 remainingSeconds | 中 |
| `SpellChallengeView.swift` | 新增退出确认 + resume 逻辑 | 中 |
| `SpellChallengeViewModel.swift` | 新增 `resume()` | 低 |
| `GamePlayView.swift` | 游戏中加退出按钮 + 退出确认 | 中 |
| `MatchGameView.swift` | 退出确认（带 clearActiveSession） | 中 |
| `MatchGameViewModel.swift` | endGame 补充 clearActiveSession | 低 |

### 1.4 风险与注意事项

1. **恢复后计时器精度**：每日挑战恢复时，`remainingSeconds` 从保存值继续。保存值比实际最多多 1 秒（参见 SP-2 说明），用户体验可接受。
2. **每日挑战恢复的时效性**：如果用户今天中途退出，明天才重新打开，activeSession 仍是昨天的。此时应判断：如果 session 的 `startTime` 不是今天，则视为过期，走 `start()` 而非 `resume()`。
   ```swift
   // DailyChallengeView.task 中
   if let active = app.progressRepo.activeSession, active.gameMode == .dailyChallenge {
       if Calendar.current.isDateInToday(active.startTime) {
           viewModel.resume(active)
       } else {
           app.progressRepo.clearActiveSession()
           viewModel.start()
       }
   }
   ```
3. **配对游戏 session 不会泄漏**：三重保障——endGame clear + 确认对话框 clear + onDismiss 兜底 clear（Vera P0 #2 修复）。
4. **GamePlayView 恢复不需要改**：已有 `resumeSession` 逻辑，通过 `session.gameMode` 区分 adventure/mistakeReview。onDismiss 不再 clear 后自然生效。（Vera P2 修复：确认 GamePlayView 的 `.task` 中 `if let active = app.progressRepo.activeSession` 不需要按 mode 过滤，因为 fullScreenCover 只会在对应 mode 下打开。）
5. **结果页/已完成页的返回按钮不需要确认**：这些是正常退出路径，直接 dismiss 即可。
6. **isProcessing 与 pauseTimer 的交互**（Vera P1 修复）：pauseTimer 只取消 timerTask（倒计时），不取消 answerTask（答题动画）。isProcessing 由 answerTask 管控，和 V2 无关。后台回来后 answerTask 正常完成，isProcessing 自然重置为 false。
7. **DailyChallengeView alreadyCompletedView 的返回路径**（Vera P2）：如果今天已完成，start() 中 `guard !todayCompleted` 直接 return，不创建 session。但 activeSession 可能有来自其他模式的残留。修改：在 start() 的 todayCompleted 分支中，如果 activeSession.gameMode == .dailyChallenge 就清除它。或者更简单：onDismiss 中对 daily 模式加一个兜底检查——但这和其他模式的 onDismiss 不 clear 逻辑冲突。**决策**：在 start() 的 todayCompleted 分支加 `if progressRepo.activeSession?.gameMode == .dailyChallenge { progressRepo.clearActiveSession() }`。
8. **SpellChallengeViewModel.resume 的 hintUsed**（Vera P2）：有意忽略。hintUsed 绑定的是单次答题状态，恢复后用户进入的是同一题，允许重新使用提示。10 金币的小问题不值得额外复杂度。

---

## 2. V2：后台切换暂停计时器

### 2.1 现状分析

`MainTabView` 已有 `onChange(of: scenePhase)` 但只处理 BGM：

```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background:
        AudioService.shared.stopBGM()
    case .active:
        AudioService.shared.startBGM()
    default:
        break
    }
}
```

有计时器的 ViewModel：
- `DailyChallengeViewModel`：`timerTask`（Task.sleep 循环，后台继续跑）
- `MatchGameViewModel`：`timerTask`（同上）

无计时器的 ViewModel（不需要改）：
- `SpellChallengeViewModel`：无倒计时
- `GamePlayView`（adventure/mistakeReview）：无倒计时

### 2.2 方案设计

**选择 View 层监听 scenePhase + 调用 ViewModel 方法**。

理由：
- ViewModel 不应持有 `@Environment`（不符合 SwiftUI 架构）
- 游戏视图已有 ViewModel 引用，直接调方法最简单
- fullScreenCover 内部可以访问 `@Environment(\.scenePhase)`

**scenePhase 在 fullScreenCover 内的可用性**（Vera P1 修复）：
- iOS 16+ 的 SwiftUI 中，`scenePhase` 环境值通过 window scene 传递，fullScreenCover 创建的新 window 同属于当前 scene，`scenePhase` 可正常访问
- iPad 多窗口场景中，每个 scene 有独立的 scenePhase，fullScreenCover 依附于触发它的 scene，行为正确
- **Fallback**：如果实测发现 scenePhase 不可靠（如特定 iOS 版本），改用 NotificationCenter 监听 `UIApplication.didEnterBackgroundNotification` / `UIApplication.willEnterForegroundNotification`，在 View 的 `.onReceive` 中调用 ViewModel 方法。实施时先验证 scenePhase 可用性，不可用再切 fallback

#### 2.2.1 ViewModel 新增方法

**DailyChallengeViewModel**：

```swift
func pauseTimer() {
    timerTask?.cancel()
    timerTask = nil
}

func resumeTimer() {
    guard session != nil, !isShowingResult, remainingSeconds > 0 else { return }
    startTimer()
}
```

**MatchGameViewModel**：

```swift
func pauseTimer() {
    timerTask?.cancel()
    timerTask = nil
}

func resumeTimer() {
    guard !isCompleted, remainingSeconds > 0 else { return }
    startTimer()
}
```

> 注意：`startTimer()` 内部已先 cancel 旧 task 再创建新的，所以 `resumeTimer` 直接调 `startTimer` 即可。但 `MatchGameViewModel.startTimer()` 会重置 `remainingSeconds = 60`，这是个 bug——需要修改。

**修复 MatchGameViewModel.startTimer**：

```swift
// 改前
private func startTimer() {
    timerTask?.cancel()
    remainingSeconds = 60  // ← 问题：resumeTimer 会重置倒计时
    timerTask = Task { ... }
}

// 改后：拆分为 setupTimer（初始化用）和 resumeTimerInternal（恢复用）
private func startTimer() {
    timerTask?.cancel()
    // remainingSeconds 由调用方设置（setupCards 或外部）
    timerTask = Task { @MainActor in
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                self.endGame()
                return
            }
        }
    }
}
```

把 `remainingSeconds = 60` 从 `startTimer` 移到 `setupCards` 中（已有 `remainingSeconds = 60` 在那里）。`startTimer` 只负责创建 Task，不重置秒数。

**startTimer 调用点确认**（Vera P1 修复）：

| 调用点 | 调用前 remainingSeconds | 安全 |
|--------|------------------------|------|
| `setupCards(with:)` | 已设为 60 ✅ | ✅ |
| `resumeTimer()`（V2 新增）| 已有正确值（从暂停恢复）✅ | ✅ |

`startTimer` 是 `private` 方法，只有以上 2 个调用点，无其他入口。

#### 2.2.2 View 层监听

**DailyChallengeView**：

```swift
@Environment(\.scenePhase) var scenePhase

// 在 body 根视图上挂
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background:
        viewModel.pauseTimer()
    case .active:
        viewModel.resumeTimer()
    default:
        break
    }
}
```

**MatchGameView**（同理）：

```swift
@Environment(\.scenePhase) var scenePhase

// 在 body 根视图上挂
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background:
        viewModel.pauseTimer()
    case .active:
        viewModel.resumeTimer()
    default:
        break
    }
}
```

**不需要修改的视图**：
- `GamePlayView`（无计时器）
- `SpellChallengeView`（无计时器）
- `MainTabView`（已有 scenePhase 监听处理 BGM，不需要改）

#### 2.2.3 后台期间其他状态处理

| 项目 | 后台 | 前台恢复 |
|------|------|---------|
| 倒计时 | 暂停（cancel timerTask） | 从 remainingSeconds 继续 |
| 答题反馈动画 | 不影响（isProcessing=true 时用户无法操作） | 自然恢复 |
| 配对翻牌动画 | 不影响 | 自然恢复 |
| BGM | 已处理（MainTabView） | 已处理 |

### 2.3 修改文件清单

| 文件 | 改动 | 风险 |
|------|------|------|
| `DailyChallengeViewModel.swift` | 新增 `pauseTimer()` / `resumeTimer()` | 低 |
| `DailyChallengeView.swift` | 新增 scenePhase 监听 | 低 |
| `MatchGameViewModel.swift` | 新增 `pauseTimer()` / `resumeTimer()`；修复 startTimer 重置 remainingSeconds 的 bug | **中**（修复 startTimer 需确保不影响正常流程） |
| `MatchGameView.swift` | 新增 scenePhase 监听 | 低 |

### 2.4 风险与注意事项

1. **Task.sleep 精度**：`Task.sleep(for: .seconds(1))` 不是精确的 1 秒，暂停/恢复后可能有 ±100ms 误差。对游戏体验可忽略。
2. **快速 background↔active 切换**：`resumeTimer` 调 `startTimer`，`startTimer` 开头 cancel 旧 task，不会叠加。
3. **inactive 状态**：`scenePhase` 有 `inactive` 中间态（如控制中心下拉），不处理。只有 `background` 才暂停。
4. **MatchGameViewModel.startTimer 的 remainingSeconds 重置 bug**：当前 `startTimer` 里 `remainingSeconds = 60` 意味着如果调用 resumeTimer → startTimer，倒计时会被重置为 60 秒。必须把初始化逻辑和 Task 创建逻辑分开。
5. **scenePhase fallback 方案**（Vera P1）：如果 fullScreenCover 内 scenePhase 不可靠，改用 NotificationCenter。示例代码：
   ```swift
   .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
       viewModel.pauseTimer()
   }
   .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
       viewModel.resumeTimer()
   }
   ```

---

## 3. 实施顺序与工期

> 注意：本方案范围仅为 C12 + V2。C1+C2、C11 已由 Cody 完成。

| 步骤 | 内容 | 预估工时 | 依赖 |
|------|------|---------|------|
| 1 | GameSession 扩展 remainingSeconds | 0.5h | 无 |
| 2 | V2：ViewModel 新增 pause/resume + 修复 MatchGame startTimer bug | 1h | 无 |
| 3 | V2：View 层 scenePhase 监听 | 1h | 步骤 2 |
| 4 | C12：ViewModel 新增 resume 方法 + remainingSeconds 保存点 | 1.5h | 步骤 1 |
| 5 | C12：View 层退出确认 + resume 逻辑 | 2h | 步骤 4 |
| 6 | C12：MainTabView onDismiss 改造 + MatchGame endGame 补 clear | 1h | 步骤 5 |
| 7 | 联调 + 测试 | 2h | 全部 |
| **合计** | | **~9h** | |

**与 C11 的交叉点说明**（Vera P2 修复）：C11 由 Cody 独立完成，给 ViewModel 加了 isProcessing 状态。本方案的 V2 pauseTimer 不触碰 isProcessing（见风险 #6），C12 的 resume 方法也不触碰 isProcessing。两者修改不同方法，不冲突。如果 Cody 后续需要调整 isProcessing 的重置逻辑，不受本方案影响。

**命名统一决策**（Vera P2 修复）：MatchGameViewModel 的 `isChecking` **保留不改名**。理由：`isChecking` 语义上就是"正在检查配对"，在配对游戏上下文比 `isProcessing` 更清晰。其他 ViewModel 用 `isProcessing` 统一命名即可。

## 4. 测试要点

- [ ] 每个游戏模式点击 X → 确认对话框弹出 → 点"继续游戏"留在当前游戏
- [ ] 每个游戏模式点击 X → 点"退出" → dismiss → 重新打开 → 进度恢复
- [ ] 每日挑战中途退出恢复后倒计时继续（不是重置 180s）
- [ ] 每日挑战隔天恢复应视为过期，重新开始
- [ ] 配对游戏中途退出 → session 不保留 → 重新打开是新游戏
- [ ] 配对游戏自然完成 → session 清除
- [ ] 后台切走 → 倒计时暂停 → 前台恢复 → 倒计时继续
- [ ] 快速 background↔active 切换不导致计时器叠加
- [ ] 结果页/已完成页的返回按钮不弹确认对话框
