# Round 3 代码质量深度审查

**审查者**：Ruby  
**日期**：2025-06-10  
**版本**：v2.1.7  
**Commit**：4480cfe  

---

## P0 — 严重（必须修复）

### P0-01 `PuzzleViewModel.resetPuzzle()` 用 while 循环逐个 undo 回到初始状态，`board` 是 `let` 无法重建

**位置**：`PuzzleViewModel.swift` `resetPuzzle()` 方法

**问题**：`board` 声明为 `let`，无法直接赋新值。`resetPuzzle()` 的实现是 `while board.moveHistory.count > 0 { board.undoLastMove() }`。这有两个问题：

1. **性能**：如果残局走了很多步（maxMoves 可达 40+），每次 undo 要遍历 pieces 数组查找棋子 + 恢复被吃棋子，40 步 undo 的开销是 O(40 × pieces)。
2. **正确性风险**：`board.undoLastMove()` 依赖 moveHistory 的正确性。如果之前某步的 execute/undo 有任何不一致（比如 PuzzleViewModel 中 fallback 手动 execute + `toggleTurn()` 补偿路径），while 循环可能导致棋盘状态异常。

**建议**：将 `board` 改为 `var`，`resetPuzzle()` 直接 `board = Board(fen: puzzle.initialFEN)`，一步到位且无状态累积风险。注意 Board 是 `@Observable`，改为 `var` 后重新赋值会正确触发 UI 刷新。

---

### P0-02 `SoundEngine` 在 `play()` 中直接访问 `_isMuted` 和 `players`，未经过 dispatch queue 同步

**位置**：`SoundEngine.swift` `play(_:)` 方法

**问题**：`SoundEngine` 用 `queue = DispatchQueue(label: ...)` 保护 `_isMuted`，`isMuted` 的 get 用 `queue.sync`、set 用 `queue.async`。但 `play(_:)` 方法也在 `queue.async` 闭包内调用，此时直接访问 `_isMuted` 和 `players`——这本身是安全的（同一串行队列）。

但问题是 `init()` 中 `players` 字典的填充在 queue 外完成，而 `play()` 在 queue 内访问。`init()` 是 `private` 且只调用一次（`static let shared`），所以在实践中不会出问题。但 `loadSound` 返回的 `AVAudioPlayer` 对象在主线程创建、在后台 queue 使用，`AVAudioPlayer` 的 `play()` 方法是否线程安全未验证。

**风险等级**：AVAudioPlayer 的 `currentTime = 0; play()` 在后台线程调用，Apple 文档未明确保证线程安全。如果主线程同时访问（比如 UI 查询播放状态），可能崩溃。

**建议**：将 `play()` 调度回主线程执行（`DispatchQueue.main.async { player.play() }`），或确保所有 `AVAudioPlayer` 操作都在同一线程。当前 `queue` 是自定义串行队列而非主队列。

---

## P1 — 重要（应修复）

### P1-01 `TranspositionTable` 不是线程安全的，`AIEngine` 在 `Task.detached` 中使用

**位置**：`TranspositionTable.swift` + `GameViewModel.triggerAIMove()` / `PuzzleViewModel.triggerDefenderMove()`

**问题**：`TranspositionTable` 的 `table` 数组没有任何同步保护。`GameViewModel` 和 `PuzzleViewModel` 都通过 `Task.detached { engine.bestMove(for: snapshot, ...) }` 调用 AI。虽然每个 ViewModel 有独立的 `AIEngine` 实例，`Task.detached` 本身不保证在固定线程执行——Swift concurrency 的 executor 可能将同一个 Task 的不同段分到不同线程。

实际上，`bestMove(for:)` 内部对 `snapshot()` 做了深拷贝，搜索过程中只修改 `workBoard`，但 `transpositionTable` 和 `moveOrderer` 是实例级可变状态。如果同一个 `AIEngine` 的 `bestMove` 被并发调用（比如用户快速悔棋后立即走棋，前一个 Task 还没结束），两个 Task 会同时读写 `transpositionTable`，造成数据竞争。

**当前缓解**：`isThinking` 标志阻止了用户在 AI 思考时操作，所以实践中很难触发。但这不是硬保证。

**建议**：
- 短期：在 `triggerAIMove` 开始时检查 `isThinking`，如果为 true 则直接返回（已有 guard，但 Task.detached 后无法取消正在执行的搜索）
- 中期：用 `AsyncSerialQueue` 或 actor 包装 AIEngine，确保 bestMove 不会被并发调用

### P1-02 `ReplayViewModel.startAutoPlay()` 中 `try? await Task.sleep` 吞掉了 `CancellationError`

**位置**：`ReplayViewModel.swift` `startAutoPlay()` 方法

**问题**：`try? await Task.sleep(for: .seconds(stepInterval))` 用 `try?` 吞掉了取消错误。当 `stopAutoPlay()` 调用 `autoPlayTask?.cancel()` 时，`Task.sleep` 抛出 `CancellationError`，被 `try?` 静默忽略，循环继续执行 `goForward()`。

虽然循环条件有 `!Task.isCancelled` 检查，但存在时间窗口：cancel 发生在 `Task.isCancelled` 检查之后、`goForward()` 之前的短暂间隔。结果是取消后可能多走一步。

**建议**：改为 `try await Task.sleep(...)`，外层 `catch` 中检查 `Task.isCancelled` 并 break。

### P1-03 `GameHistoryStore` 和 `StatsManager` 的读写操作不是线程安全的

**位置**：`GameHistoryStore.swift`、`StatsManager.swift`

**问题**：这两个单例用 UserDefaults 存储数据，`stats` / `records` 属性每次访问都从 UserDefaults 解码。如果 `recordWin` 和 `recordLoss` 被快速连续调用（比如 AI 走棋后立即判定胜负），两次读-改-写之间没有同步，可能导致后一次覆盖前一次的更新。

`GameHistoryStore` 的 `addRecord` 也有同样问题：读取 index → 添加 → 保存，非原子操作。

**当前缓解**：统计更新只在游戏结束时发生（频率极低），实践中不太可能触发。

**建议**：如果未来有多处同时更新统计/历史的场景，用 actor 或串行队列保护。当前可暂缓。

### P1-04 `PuzzleViewModel.undoMove()` 没有恢复 `solutionHint` 状态

**位置**：`PuzzleViewModel.swift` `undoMove()` 方法

**问题**：`undoMove()` 撤销棋步并清理了 `currentHint` 和 `gameState`，但没有清理 `solutionHint`（"💡 有更优走法"提示）。悔棋后这个提示仍然显示，但对应的走法已经撤销，提示信息与当前棋盘状态不一致。

**建议**：在 `undoMove()` 末尾添加 `solutionHint = nil`。

### P1-05 `ChessBoardView` 棋盘上将军高亮直接调 `MoveValidator.isInCheck`，每次视图重算都执行

**位置**：`ChessBoardView.swift` 第 147 行

**问题**：`if MoveValidator.isInCheck(board.currentTurn, on: board), let kingPos = ...` 这行代码在 ChessBoardView 的 body 中，每次 SwiftUI 重算视图时都会执行 `isInCheck` 检查。`isInCheck` 需要遍历对方所有棋子、对每个棋子检查攻击路径——复杂度 O(pieces × board_size)。

虽然象棋棋盘小（最多 32 子），但 ChessBoardView 的 body 已经包含大量视图代码（网格、棋子、高亮、提示），重算频率不低。每次手指移动（选中棋子后）都会触发重算。

**建议**：将 `isInCheck` 结果缓存到 ViewModel（类似 `GameViewModel.isInCheck` stored property），视图直接读 ViewModel 属性。PuzzleViewModel 也需要添加 `isInCheck` 属性。

### P1-06 `bestAvailableFontName` 每次调用都创建 `NSFont`/`UIFont` 实例探测字体可用性

**位置**：`FontRegistry.swift` `bestAvailableFontName` 属性

**问题**：`bestAvailableFontName` 每次调用都创建 `NSFont(name:size:)` / `UIFont(name:size:)` 来检测字体是否存在。如果 `.custom(FontRegistry.bestAvailableFontName, ...)` 在视图中使用，每次重算都会创建临时字体对象。

**建议**：用 `static let` 缓存结果，App 启动时计算一次。

---

## P2 — 建议改进

### P2-01 `OpeningBook.init()` 同步加载 JSON + 预计算所有 Zobrist hash，App 启动时阻塞主线程

**位置**：`OpeningBook.swift` `init()`

**问题**：`init()` 中 `Data(contentsOf: url)` 同步读取文件，然后遍历所有 variations 并逐步执行棋盘走法计算 Zobrist hash。如果开局库较大（>100 个 variations），初始化可能需要几十毫秒。

`AIEngine` 在 `init()` 中创建 `OpeningBook()`，而 `GameViewModel` 在 `@State` 初始化时创建 `AIEngine`，最终在 SwiftUI 视图首次渲染时同步执行。

**建议**：懒加载 `OpeningBook`（首次 `bestMove` 时初始化），或在 `GameViewModel.init` 中异步初始化。

### P2-02 `PuzzleViewModel.resetPuzzle()` 没有清理 `_cachedPlayerSolutionMoves`

**位置**：`PuzzleViewModel.swift` `resetPuzzle()`

**问题**：`_cachedPlayerSolutionMoves` 在 `resetPuzzle()` 中没有被重置。虽然 `playerSolutionMoves` 的计算不依赖 board 状态（基于 `puzzle.initialFEN` 和 `puzzle.solution`），所以缓存值在 reset 后仍然正确。但这是一个隐患——如果未来 `playerSolutionMoves` 的计算逻辑变化依赖了 board 状态，缓存就会出错。

**建议**：在 `resetPuzzle()` 中添加 `_cachedPlayerSolutionMoves = nil`。

### P2-03 `Board.snapshot()` 创建的副本保留 `moveHistory`，AI 搜索中的 snapshot 不需要

**位置**：`Board.swift` `snapshot()`

**问题**：`snapshot()` 复制了 `moveHistory`，但 AI 搜索用 `board.snapshot()` 创建工作棋盘时不需要 moveHistory（搜索过程中通过 execute/undo 维护自己的历史）。每次 snapshot 都复制 moveHistory 数组是浪费。

**建议**：添加 `snapshotForSearch()` 方法，不复制 moveHistory。或让 `bestMove(for:)` 中直接用 `Board(pieces:)` 初始化。

### P2-04 `GameViewModel` 和 `PuzzleViewModel` 的 AI 闭包中缺少对 `gameState` 变化的处理

**位置**：`GameViewModel.triggerAIMove()` / `PuzzleViewModel.triggerDefenderMove()`

**问题**：`Task.detached` 闭包中的 `[weak self]` + `puzzleVersion` / `gameVersion` 检查可以防止"旧 Task 覆盖新数据"。但如果 AI 计算期间用户点了"新局"（`gameVersion` 增加），旧 Task 的 guard 会跳过，但 `isThinking` 已经在 `newGame()` 中重置为 `false`，而旧 Task 闭包中 `self?.isThinking = false` 不会执行（guard 失败）。这是正确行为。

但存在边界情况：AI 计算完成后、`MainActor.run` 执行前，如果用户恰好点了"新局"，`gameVersion` 已变但 `isThinking` 还是 `true`（因为 `newGame` 设置 `isThinking = false` 和 `gameVersion += 1` 不是原子操作）。实际上 `newGame` 在主线程同步执行，`MainActor.run` 也在主线程，所以不会交叉。**风险极低，仅记录。**

### P2-05 `ReplayViewModel.snapshots` 字典无限增长

**位置**：`ReplayViewModel.swift`

**问题**：`snapshots: [Int: Board]` 每 20 步存一个快照。对于长对局（100+ 步），最多存储 5 个快照，内存开销很小。但如果频繁 `jumpTo` 导致反复 `rebuildBoard`，快照数量不会超过 `moves.count / 20`。**实际不是问题，仅确认。**

### P2-06 `FontRegistry` 重复注册检查依赖字符串匹配 `"already registered"`

**位置**：`FontRegistry.swift` `registerFontAt()`

**问题**：判断字体是否已注册的逻辑是 `desc.contains("already registered")`，依赖 CoreText 错误描述的英文文本。如果系统语言不是英文，错误描述可能是本地化的，导致匹配失败，打印虚假的注册失败警告。

**建议**：改用 CTFontManager 的 error code 判断，不依赖错误描述文本。

---

## 审查汇总

| 级别 | 数量 | 项 |
|------|------|----|
| P0 | 2 | P0-01 resetPuzzle while-undo 风险, P0-02 SoundEngine 线程安全 |
| P1 | 6 | P1-01 TT 线程安全, P1-02 Task.sleep 取消, P1-03 Store 线程安全, P1-04 undoMove solutionHint, P1-05 isInCheck 视图重算, P1-06 字体探测缓存 |
| P2 | 6 | P2-01 OpeningBook 启动阻塞, P2-02 缓存清理, P2-03 snapshot 冗余, P2-04 AI 闭包边界, P2-05 snapshots 增长(确认无问题), P2-06 字体注册错误码 |

**方案级问题**：无
