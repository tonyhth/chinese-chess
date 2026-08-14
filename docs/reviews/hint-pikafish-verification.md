# Hint Pikafish 验证报告

## Commit: 1523a43 fix(hint): always use Pikafish for hint regardless of difficulty

## 验证日期: 2026-08-15

---

## 1. 编译验证
✅ **BUILD SUCCEEDED**

## 2. 代码审查

### 改动内容（1 文件，2 处）

**GameViewModel.swift `requestHint()`**：
1. 引擎获取方式：`EngineRouter.shared.engineFor(difficulty: currentDifficulty)` → `EngineRouter.shared.switchEngineIfNeeded()`
2. bestMove difficulty 参数：`currentDifficulty` → `.grandmaster`

### 引擎路由验证

`switchEngineIfNeeded()` 返回值：
- Pikafish 开关 ON → `EmbeddedPikafishEngine` ✅
- Pikafish 开关 OFF → `nativeEngine`（自研 lvl5，合理 fallback）

`difficulty: .grandmaster`：
- 对 Pikafish → Skill 20（最强）✅
- 对 nativeEngine → lvl5（最强自研）✅

**结论**：hint 始终使用当前可用引擎中最强的，不受用户难度影响 ✅

### 对弈路由不受影响

`triggerAIMove()` 仍然使用 `engineFor(difficulty: currentDifficulty)` 按难度路由 ✅
- 第 580 行：`_ = await EngineRouter.shared.switchEngineIfNeeded()`（只切换，不取返回值）
- 第 599 行：`let engine = EngineRouter.shared.engineFor(difficulty: currentDifficulty)`（按难度获取）

## 3. 已有测试

无专门的 hint 单元测试类。已有 hint 引用均在 Puzzle/Tutorial 数据结构中（`hints: nil`），与 GameViewModel.requestHint() 无关。不 break 任何现有测试 ✅

## 4. 用户路径覆盖审查

| # | 用户操作 | 入口位置 | 数据查询 | 空数据保护 | 错误处理 | 用户反馈 |
|---|---------|---------|---------|-----------|---------|---------|
| 1 | 点击提示按钮 | requestHint() | switchEngineIfNeeded() → bestMove() | ✅ guard isThinking/gameState | ✅ engineFallbackMessage | ✅ hintMove + hintText |
| 2 | Pikafish 关闭时点提示 | requestHint() | nativeEngine.bestMove(.grandmaster) | ✅ 同上 | ✅ 同上 | ✅ fallback 到 lvl5 |
| 3 | 引擎返回 nil | requestHint() | bestMove 返回 nil | — | ✅ engineFallbackMessage | ✅ "提示失败"提示 |

## 5. 结论

**✅ 验证通过**

- hint 始终使用 Pikafish（或 fallback 到 native lvl5），不受用户难度影响
- 对弈走棋不受影响，仍按难度路由
- 编译通过，无现有测试 break
- 用户路径覆盖完整，错误处理和用户反馈到位
