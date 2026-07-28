# 中国象棋 v5.2 深度分析与改进方案

> 版本：v2.0（Vera 审查修订版） | 作者：Alex（架构师） | 日期：2026-07-28
>
> v2.0 变更：修复 Vera 审查 P0-A/B/C、P1-A~E、P2-A/B/C 共 11 条反馈

## 目录

1. [问题总览](#1-问题总览)
2. [P0-1: 分类菜单只显示数字没有名称](#2-p0-1-分类菜单只显示数字没有名称)
3. [P0-2: 分类不均匀 — 车马炮类 38.5%](#3-p0-2-分类不均匀)
4. [P0-3: 大师对局放在残局演示入口里不合理](#4-p0-3-信息架构重组)
5. [P1-4: 棋谱显示不完整](#5-p1-4-棋谱显示不完整)
6. [P1-5/9: 移动端功能入口问题](#6-p1-59-移动端功能入口问题)
7. [P1-6: 开局库功能太简单](#7-p1-6-开局库功能太简单)
8. [P1-7: 新手教程走子功能不工作](#8-p1-7-新手教程走子功能不工作)
9. [P1-8: 部分界面中文显示不完整](#9-p1-8-部分界面中文显示不完整)
10. [P2-10: 主动审计发现](#10-p2-10-主动审计发现)
11. [信息架构重组方案](#11-信息架构重组方案)
12. [分期实施计划](#12-分期实施计划)
13. [工作量总览](#13-工作量总览)
14. [Vera 审查反馈处理记录](#14-vera-审查反馈处理记录)

---

## 1. 问题总览

| # | 问题 | 优先级 | 根因类别 | 预估工作量 |
|---|------|--------|----------|-----------|
| 1 | 分类菜单只显示数字没有名称 | P0 | 代码缺陷 | 0.5d |
| 2 | 分类不均匀（车马炮类 38.5%） | P0 | 数据模型+数据 | 2.5d |
| 3 | 大师对局放在残局演示入口里 | P0 | 信息架构 | 4d |
| 4 | 棋谱显示不完整 | P1 | 布局约束 | 1.5d |
| 5/9 | 移动端功能入口问题 | P1 | 信息架构 | 含在 #3 |
| 6 | 开局库功能太简单 | P1 | 数据+功能 | 3d |
| 7 | 新手教程走子功能不工作 | P1 | 交互逻辑 | 2d |
| 8 | 部分界面中文显示不完整 | P1 | 布局+本地化 | 1d |
| 10a | iOS 残局入口直接进 PuzzleSelectView 而非 ChapterSelectView | P1 | 入口错误 | 0.5d |
| 10b | 大师棋谱无独立入口 | P1 | 信息架构 | 含在 #3 |
| 10c | 开局探索与大师棋谱无联动 | P2 | 功能缺口 | 2d |
| 10d | 残局演示 iOS 无棋谱回放面板 | P2 | 功能缺口 | 1d |

---

## 2. P0-1: 分类菜单只显示数字没有名称

### 根因分析

**文件**：`Views/PuzzleDemoView.swift` → `sidebar`（macOS）和 `categoryPicker`（iOS）

**macOS 侧边栏**：当前代码实际已显示分类名称（`Text(cat)`），但数字和名称并排，在某些系统主题下分类名可能不够醒目。

**iOS Picker**：使用 `.pickerStyle(.menu)` 下拉菜单，每个选项是 `Text("\(cat) (\(count))")`。问题在于 `.menu` 样式下，Picker 的选项文字可能被系统截断，尤其是中文分类名+括号数字组合过长时。用户反馈"只显示数字"，很可能是 Menu 弹出时只渲染了 tag 关联值，或 Menu 宽度不够导致文字被截断只留下数字。

### 方案设计

**改动范围**：`PuzzleDemoView.swift`

1. **iOS 端**：将 `Picker(.menu)` 替换为 `Menu` + 嵌套 `Section` 的分层结构，确保分类名完整显示
2. **统一分类显示格式**：macOS 和 iOS 都用分类名+ badge 计数，而非括号内嵌
3. **为 DemoCategory 增加 displayName 和 count 属性**，避免每次在 View 层拼字符串

**iOS 替代方案**：用 `List` + `Section` 的全屏选择页替代 `Picker(.menu)`，与 macOS 侧边栏信息密度对齐。

### 影响评估

- 仅影响 `PuzzleDemoView` 的分类选择 UI
- 不影响数据模型或业务逻辑

### 工作量

**0.5 天**

### 优先级建议

P0 — 用户无法识别分类，功能基本不可用

---

## 3. P0-2: 分类不均匀

### 数据现状

| 分类 | 数量 | 占比 |
|------|------|------|
| 车马炮类 | 212 | 38.5% |
| 车炮类 | 88 | 16.0% |
| 单车类 | 61 | 11.1% |
| 单炮类 | 46 | 8.3% |
| 马炮类 | 39 | 7.1% |
| 单马类 | 33 | 6.0% |
| 车马类 | 30 | 5.4% |
| 兵类 | 17 | 3.1% |
| 综合类 | 14 | 2.5% |
| 双车类 | 11 | 2.0% |

核心问题：**车马炮类 212 局**，几乎等于其余 9 类总和。

### 方案 A：按战术子类拆分（推荐）

在 `Puzzle` 模型上新增 `tacticalGroup: String?` 字段，对车马炮类按**战术主题**拆分：

> **v2.0 修订**：原方案复用 `subcategory` 字段，但该字段已有明确语义——"难度标签（入门/简单/中等/困难/大师）"，不应二义复用。新增 `tacticalGroup` 字段，语义分离，代价极小。

| 新子分类 | 含义 | 预估数量 |
|---------|------|----------|
| 车马炮·杀势 | 直接杀法类 | ~80 |
| 车马炮·困毙 | 困毙/无路可走 | ~30 |
| 车马炮·催杀 | 催杀/逼杀 | ~40 |
| 车马炮·弃子攻杀 | 弃子战术 | ~35 |
| 车马炮·其他 | 其他战术 | ~27 |

**优点**：
- 语义清晰，用户按战术意图查找
- 新增 `tacticalGroup` 字段与现有 `subcategory`（难度标签）完全分离，无二义性
- 可渐进式标注，先拆车马炮类，其他类视需要再拆

**缺点**：
- 需要人工/半自动标注 212 局的子分类
- 其他大分类（车炮类 88 局）可能也需要拆
- 新增字段需同步更新 CodingKeys 和解码逻辑（向后兼容，`decodeIfPresent`）

### 方案 B：按难度+子类二级分类

在分类下增加**难度**作为二级维度：

| 车马炮类 → | ★★★ 入门 | ★★★★ 中级 | ★★★★★ 大师 |
|-----------|----------|-----------|-----------|
| 数量 | ~50 | ~100 | ~62 |

每个难度下再按战术主题细分。

**优点**：
- 难度是最常见的筛选维度
- `stars` 字段已有，无需额外标注

**缺点**：
- 同一难度下仍有 50-100 局，细分不够
- 难度维度和章节系统重叠（7 章本身就是按难度分）

### 推荐：方案 A 为主 + 方案 B 为辅

1. 一级维度：战术子类（`tacticalGroup` 字段）
2. 二级维度：难度（`stars` 字段排序，或现有 `subcategory` 难度标签）
3. 先对车马炮类和车炮类做子分类标注

### 数据标注策略

> **v2.0 修订**：原方案用启发式规则（solution 步数 ≤ 3 → 杀势类）做初分，过于粗糙。3 步可能是杀势也可能是困毙，弃子攻杀的核心特征是"先弃后取"，步数无法区分。改为两步法：

**第一步：标注规范校准**（0.5d）
1. 先取 10-20 局车马炮类残局，手动标注 5 个子分类
2. 确认 5 个子分类的边界清晰、标注人理解一致
3. 输出标注规范文档（含边界 case 说明）

**第二步：Pikafish 辅助标注**（1d）
1. 用 Pikafish 分析 solution 终局特征：
   - 对方将被将死 → `杀势`
   - 对方无合法走法但未被将军 → `困毙`
   - solution 中出现弃子（子力先减后增或持平）→ `弃子攻杀`
   - 连续将军或威胁导致对方被动 → `催杀`
   - 以上都不匹配 → `其他`
2. 212 局自动标注后，随机抽 30 局交叉核验
3. 准确率低于 90% 的分类需调整判定规则

**改动范围**：
- `Puzzle.swift`：新增 `tacticalGroup: String?` 字段（`decodeIfPresent` 向后兼容）
- `PuzzleStore.swift`：新增 `demoTacticalGroups(for:)` 查询方法
- `PuzzleDemoView.swift`：侧边栏增加子分类层级
- `puzzles.json`：为车马炮类和车炮类残局补充 `tacticalGroup` 值

### 影响评估

- 新增 `tacticalGroup` 字段有向后兼容（`decodeIfPresent`），旧 JSON 不受影响
- `subcategory`（难度标签）完全不受影响，两个维度互不干扰
- `ChapterSelectView` 和 `PuzzleSelectView` 不受影响（它们用章节体系，不按分类浏览）

### 工作量

**2.5 天**（含标注规范校准 0.5d + Pikafish 辅助标注 1d + UI 改造 1d）

### 优先级建议

P0 — 38.5% 的残局混在一个分类里等于没分类

---

## 4. P0-3: 信息架构重组

### 根因分析

**核心问题**：大师对局和残局演示共用 `PuzzleDemoView` 的侧边栏，两个语义完全不同的功能被混在一个入口里。

**代码层面的原因**：
1. `DemoCategory` 枚举同时包含 `.puzzles(String)` 和 `.opening(OpeningCategory)`，一个 enum 混合了两种领域
2. `PuzzleDemoView` 同时承担"残局演示"和"大师棋谱浏览"两个职责
3. 入口路径：`ChapterSelectView` → `DemoEntryCard` → `PuzzleDemoView`，用户从"残局闯关"入口进来却发现"大师棋谱"
4. iOS 端从底部 toolbar "残局"按钮 → `PuzzleSelectView`（不是 ChapterSelectView！），完全没有大师棋谱入口

**更深层原因**：当前 App 的信息架构是**功能驱动**的（一个功能一个 sheet），而不是**用户场景驱动**的。用户的心智模型是：
- "我想练习残局" → 残局入口
- "我想看大师下棋" → 大师对局入口
- "我想学习开局" → 开局探索入口

### 方案设计

详见 [第 11 节：信息架构重组方案](#11-信息架构重组方案)

**核心改动**：
1. 将 `PuzzleDemoView` 拆分为 `PuzzleDemoView`（纯残局演示）和 `MasterGameBrowserView`（大师棋谱浏览）
2. 新增 `StudyHubView` 作为"学棋"功能的统一入口
3. iOS 底部 toolbar 重组
4. `DemoCategory` 简化为仅 `.puzzles`，大师棋谱用独立数据流

### 影响评估

- **大范围重构**，涉及 NavigationRoute、SheetDestination、底部 toolbar、侧边栏
- `DemoItemWrapper` 需拆分为 `DemoItemWrapper`（残局）+ `MasterGameItemWrapper`（大师棋谱）
- `DemoViewModel` 需拆分为 `DemoViewModel`（残局）+ `MasterGameViewModel`（大师棋谱）
- `ChapterSelectView` 中的 `DemoEntryCard` 导航目标需调整
- iOS `ChineseChessiOSApp` 的 `SheetDestination` 需新增 `masterGames` case

### 工作量

**4 天**（含 UI 重构 + 导航调整 + 影响链迁移 + iOS/macOS 双端适配）

### 优先级建议

P0 — 信息架构错误导致功能不可发现

---

## 5. P1-4: 棋谱显示不完整

### 根因分析

**文件**：`Views/RecordPanelView.swift`

**问题链**：
1. `RecordPanelView` 使用 `ScrollView` + `VStack` 渲染棋步列表
2. macOS 上作为 sheet 展示，`maxHeight: 400` 限制了可见区域
3. iOS 上被底部 toolbar + 操作栏挤压，可见区域更小
4. `ScrollView` 本身可以滚动，但**底部导出栏**占用了固定空间，用户可能不知道可以滚动
5. `pairMoves` 生成所有回合对，步数多时（大师棋谱 100+ 步）渲染压力大

**关键发现**：sheet 本身可滚动，但**初始可见区域小 + 无滚动提示**，用户误以为内容被截断。

### 方案设计

1. **macOS**：将棋谱 sheet 的 `maxHeight` 从 400 改为 600
2. **iOS**：sheet 改为 `.presentationDetents([.medium, .large])`，允许用户拉大
3. **滚动提示**：当棋步数 > 20 步时，在底部显示 "↓ 向下滚动查看更多" 提示
4. **性能优化**：`pairMoves` 改为懒加载，只渲染可见区域的回合对

```swift
// iOS presentation detents
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)
```

### 影响评估

- 仅影响 `RecordPanelView` 和其弹出方式
- macOS 端 `ChineseChessApp.swift` 中 `.record` case 的 frame 需调整
- **与 P0-3 有串行依赖**：拆分 PuzzleDemoView 后 RecordPanelView 的引用位置也要跟着调

### 工作量

**1.5 天**

### 优先级建议

P1 — 功能可用但体验差

---

## 6. P1-5/9: 移动端功能入口问题

### 根因分析

**文件**：`ChineseChessiOSApp.swift`

**当前 iOS 底部 toolbar 结构**：
```
[棋谱] [残局] [回放]  ···  [更多▼]
                           ├─ 统计
                           ├─ 历史记录
                           ├─ 主题
                           ├─ ──────
                           ├─ 每日挑战
                           ├─ 成就
                           ├─ 段位特权
                           ├─ 开局探索
                           ├─ ──────
                           └─ 设置
```

**问题**：
1. **开局探索**藏在"更多"里，而它是核心学习功能
2. **每日挑战**是日活驱动力，入口太深
3. **大师棋谱**完全没有入口
4. 底部只有 3 个直接入口 + 1 个"更多"，高频功能被淹没

### 方案设计

结合信息架构重组（详见第 11 节），iOS 底部 toolbar 改为：

```
[棋谱] [学棋] [回放]  ···  [更多▼]
```

"学棋"按钮 NavigationLink 推入 `StudyHubView`，包含：残局闯关、大师棋谱、开局探索、每日挑战。

### 工作量

**含在 P0-3 方案内**

### 优先级建议

P1 — 结合 P0-3 统一解决

---

## 7. P1-6: 开局库功能太简单

### 根因分析

**文件**：`Models/OpeningCategories.swift`、`Views/OpeningExplorerView.swift`

**数据现状**（master-stats.json，40732 局）：

| 一级分类 | firstMove | 对局数 | 二级分类数 |
|---------|-----------|--------|-----------|
| 中炮 | h2e2 | 23341 | 4 |
| 仙人指路 | c3c4 | 7214 | 1 |
| 飞相 | g0e2 | 3634 | 0 |
| 起马 | b0c2 | 1413 | 0 |
| 起兵 | g3g4 | 1222 | 0 |
| 过宫炮 | h2f2 | 547 | 0 |
| 其他 | — | ~3000+ | 0 |

**问题**：
1. **一级分类不完整**：缺少士角炮(h2d2, 1097局)等常见开局
2. **二级分类极少**：中炮只有 4 个子类，飞相/起马等完全没有二级分类
3. **OpeningCategories 是硬编码**：无法动态扩展
4. **OpeningExplorerView 有开局树**但两套分类系统无联动

### 数据扩展可行性评估

**现有数据**：40732 局大师对局的 `firstMoves` 字段已包含前 N 步走法序列，足以构建丰富的二级分类。

**数据量估算**：
- 一级分类可扩展到 12-15 个
- 二级分类可扩展到 40-60 个（基于前 3 步聚类）

### 方案设计

1. **替换硬编码 OpeningCategories**：改为从预处理文件动态加载
2. **构建二级分类数据**：基于 `firstMoves` 前 3 步序列聚类
3. **统一开局分类系统**：共用同一套分类数据
4. **开局探索增强**：增加"按分类浏览"模式

> **v2.0 补充：OpeningCategories 动态化过渡方案**
>
> **阶段 1（Phase C 实施）**：保留 `OpeningCategories` 的静态接口签名不变，内部改为从预处理文件加载。
> - 新增预处理脚本，从 `master-stats.json` 的 `openingDistribution` + `firstMoves` 聚类，输出 `opening-categories.json`
> - `OpeningCategories.categories` 改为 lazy static，首次访问时从 JSON 加载，fallback 到硬编码默认值
> - ID 命名规范：沿用现有 `zhong_pao` 等拼音 ID 格式，新增分类用同规则生成（如 `shijiao_pao`），确保稳定可 Hashable
>
> **阶段 2（后续迭代）**：运行时聚类。首次启动时后台执行聚类，结果缓存到本地文件。
>
> **引用点迁移清单**：
>
> | 引用点 | 当前用法 | 迁移策略 |
> |--------|---------|----------|
> | `DemoItemWrapper.demoCategory` | 反查 OpeningCategories 获取分类名 | 移至 MasterGameBrowserView 内部 |
> | `MasterGameStore.byOpening()` | 用 firstMatch 过滤 | 接口不变，内部改用动态分类 |
> | `PuzzleDemoView.sidebar` | 遍历 categories 构建列表 | 拆分后 MasterGameBrowserView 接管 |
> | `OpeningExplorerView` | 独立开局树 | 共享分类数据，增加分类浏览模式 |

**改动范围**：
- `OpeningCategories.swift`：重构为动态加载
- `MasterGameStore.swift`：增加按二级分类查询方法
- 新增 `OpeningCategoryBuilder` 预处理脚本

### 影响评估

- `OpeningCategories` 被多处引用，改动需保持接口兼容（lazy static + fallback 保证）
- `OpeningSubcategory` 的 `firstMoves` 匹配逻辑可能需要调整

### 工作量

**3 天**（含预处理脚本 + 分类重构 + 引用点迁移 + UI 调整）

### 优先级建议

P1 — 功能存在但内容太薄，用户价值低

---

## 8. P1-7: 新手教程走子功能不工作

### 根因分析

**文件**：`Views/Tutorial/TutorialInteractiveView.swift`、`ViewModels/TutorialViewModel.swift`

**代码审查发现**：

1. **FEN 坐标系问题**：教程的 `initialFEN` 使用标准 FEN 格式，但 `expectedMoves` 使用 UCI 格式。`UCIMoveConverter.uciString(from:)` 的坐标映射与 FEN 解析是否一致需要验证。

2. **走子验证逻辑**：`validateMove` 方法先用 `MoveValidator.legalMoves` 检查合法性，再用 `UCIMoveConverter.uciString(from:)` 转换后与 `expectedMoves[stepIndex]` 比较——坐标系不匹配的可能性存在。

3. **MiniChessBoard 坐标映射**：`onMove` 回调传回的 `Position` 类型与 FEN 坐标系是否一致需要验证。如果 `MiniChessBoard` 用 Canvas 坐标，`validateMove` 接收到的 `Position` 就和 FEN 坐标系不匹配。

4. **resetCurrentStep 的时序 bug（主因）**：

> **v2.0 修订**：原方案诊断的 boardRevision 问题不是主因。Vera 指出真正的 bug：

```swift
private func resetCurrentStep() {
    setupBoard()          // ← stepIndex = 0
    if let expected = lesson.expectedMoves {
        for i in 0..<stepIndex {   // ← 0..<0，循环体永远不执行
            ...
        }
    }
}
```

`setupBoard()` 第一行就把 `stepIndex = 0`，紧接着 `0..<0` 是空区间，重放循环根本不跑。用户按"重试"后，所有之前走对的步骤全部丢失——回到初始局面。

5. **`enabledSide` 从 FEN 解析走方可能出错**：`lesson.initialFEN` 在 `info` 类型课程中为 nil，`setupBoard` 会 fallback 到标准初始局面。

### 方案设计

> **v2.0 修订**：修复 resetCurrentStep 时序 bug（主因），验证坐标映射，增强走子反馈。移除"调试模式"建议（不应进生产）。

**修复 1：resetCurrentStep 时序 bug**（主因）

当前代码的问题：`setupBoard()` 先把 `stepIndex = 0`，然后 `0..<0` 空区间不执行。

修复方案：拆分 `setupBoard()` 为 `resetBoardOnly()`（不碰 stepIndex）+ `resetProgress()`：

```swift
private func resetCurrentStep() {
    let savedStepIndex = stepIndex   // 先保存
    resetBoardOnly()                 // 只重置棋盘，不碰 stepIndex
    // 重放之前的正确步骤
    if let expected = lesson.expectedMoves {
        for i in 0..<savedStepIndex {
            if let move = UCIMoveConverter.move(from: expected[i], on: board) {
                board.execute(move)
            }
        }
        boardRevision += 1
    }
    status = .waiting
}
```

> **补充**：当 status 为 `.wrong` 或 `.illegal` 时，`board.execute(move)` 不会被调用，棋盘状态未变。理论上 `resetCurrentStep` 只需 `status = .waiting` 即可。当前方案是防御性写法，不会出错，但属于过度重置。保留此写法以防边界 case，后续维护者注意：wrong/illegal 时棋盘未被修改。

**修复 2：验证 MiniChessBoard 坐标映射**

在 `onMove` 回调中添加断言，确认传回的 `Position` 与 FEN 坐标系一致。如果坐标系不匹配，需要在 `validateMove` 入口做转换。

**修复 3：增强走子反馈**

当用户走了合法但非期望的棋时，高亮期望走法的起点/终点（用半透明棋子标记）。

**改动范围**：
- `TutorialInteractiveView.swift`：拆分 setupBoard、修复 resetCurrentStep、增强反馈
- `MiniChessBoard.swift`：验证/修复坐标映射
- `TutorialViewModel.swift`：可能需要调整 FEN 或 expectedMoves

### 影响评估

- 仅影响教程模块

### 工作量

**2 天**（含 resetCurrentStep 时序修复 0.5d + MiniChessBoard 坐标验证 0.5d + 走子反馈增强 0.5d + 测试 0.5d）

### 优先级建议

P1 — 新手首次体验就遇到问题，影响留存

---

## 9. P1-8: 部分界面中文显示不完整

### 根因分析

**问题场景**：
1. iOS 底部 toolbar 的 `Label` 文字被截断（中文字符宽度大于英文）
2. `PuzzleDemoView` iOS `categoryPicker` 中的分类名+计数被截断
3. 某些 Button 使用固定 `frame(width:)` 限制，中文无法自适应

### 方案设计

1. **iOS 底部 toolbar**：改用图标+短标签，避免中文被截断（与信息架构重组联动）
2. **PuzzleDemoView**：分类选择改为全屏列表页
3. **通用方案**：审查所有 `frame(width: N)` 硬编码宽度，改用 `minWidth` + `maxWidth`
4. **本地化适配**：用 `.lineLimit(1)` + `.minimumScaleFactor(0.8)` 自动缩放

### 影响评估

- 多处 UI 微调，不影响逻辑
- 需要在 iOS 真机上验证

### 工作量

**1 天**

### 优先级建议

P1 — 影响中文用户体验

---

## 10. P2-10: 主动审计发现

### 10a. iOS 残局入口直接进 PuzzleSelectView 而非 ChapterSelectView

**严重程度**：P1

**根因**：`ChineseChessiOSApp.swift` 中 `.puzzles` case 打开的是 `PuzzleSelectView()`（无参数构造），而不是 `ChapterSelectView()`。macOS 端打开的是 `ChapterSelectView`。

**影响**：iOS 用户完全看不到章节系统（7 章难度渐进）。

**修复**：将 iOS `.puzzles` 改为打开 `ChapterSelectView`。

**工作量**：0.5 天

### 10b. 大师棋谱无独立入口

**严重程度**：P1（已含在 P0-3 方案中）

### 10c. 开局探索与大师棋谱无联动

**严重程度**：P2

**根因**：`OpeningExplorerView` 的节点（基于 firstMoves 序列）和 `MasterGameBrowserView` 的分类（基于 OpeningCategory.firstMove）是两种不同的索引结构。

> **v2.0 修订**：补充数据流设计，工期从 1d 调为 2d。

**数据流设计**：
1. 从 `OpeningExplorerNode` 的 `pathFromRoot()` 获取走法序列
2. 取最后 N 步映射到 `OpeningCategory.firstMove` 或 `OpeningSubcategory.firstMoves`
3. 在 `MasterGameStore` 上新增 `games(matchingFirstMoves: [String])` 方法，按走法序列匹配对局
4. 跳转到 `MasterGameBrowserView` 时传入匹配条件作为初始过滤

**工作量**：2 天

### 10d. 残局演示 iOS 无棋谱回放面板

**严重程度**：P2

**根因**：`PuzzleDemoView` 的 `iosLayout` 只有棋盘+控制栏，没有棋谱回放面板。

**方案**：在 iOS 演示模式下增加可折叠的棋谱面板。

**工作量**：1 天

---

## 11. 信息架构重组方案

### 现状

```
主界面
├─ [棋谱] → RecordPanelView (sheet)
├─ [残局] → ChapterSelectView → PuzzleSelectView → PuzzlePlayView
│                                    └─ DemoEntryCard → PuzzleDemoView
│                                                          ├─ 残局分类侧边栏
│                                                          └─ 大师棋谱侧边栏 ← ❌ 语义错位
├─ [回放] → ReplayView (fullScreenCover)
├─ [更多] → Menu
│   ├─ 统计 / 历史记录 / 主题
│   ├─ 每日挑战 ← 入口太深
│   ├─ 成就 / 段位特权
│   ├─ 开局探索 ← 入口太深
│   └─ 设置
└─ macOS 顶部 toolbar: 12 个按钮平铺
```

### 目标架构

```
主界面（NavigationStack）
├─ [棋谱] → RecordPanelView (sheet)
├─ [学棋] → StudyHubView（NavigationLink 推入主 NavigationStack）
│   ├─ 📋 残局闯关 → ChapterSelectView → PuzzleSelectView
│   ├─ 👑 大师棋谱 → MasterGameBrowserView（独立视图）
│   ├─ 📖 开局探索 → OpeningExplorerView
│   └─ 🎯 每日挑战 → DailyChallengeView
├─ [回放] → ReplayView (fullScreenCover)
├─ [更多] → Menu
│   ├─ 统计 / 历史记录 / 主题 / 成就 / 段位特权 / 设置
│   └─ （过渡期保留：残局 / 开局探索 快捷入口）
└─ macOS: 保留平铺 toolbar，按组分隔
    ├─ 棋局组：棋谱 / 残局 / 回放 / 分析 / 教练
    ├─ 学棋组：开局探索 / 大师棋谱（新增） / 每日挑战
    └─ 设置组：主题 / 历史 / 成就 / 段位 / 设置
```

> **v2.0 修订**：
> 1. StudyHubView 不用 sheet，改为 NavigationLink 推入主 NavigationStack（避免 sheet 内嵌多层 NavigationStack 的手势冲突和内存问题）
> 2. macOS 保留平铺 toolbar + 分组分隔，不做合并（老用户肌肉记忆不断裂）
> 3. 用户迁移策略：首次升级时显示一次性引导提示

### 关键改动

#### 1. 新增 StudyHubView

> **v2.0 修订**：StudyHubView 不用 sheet，改为 NavigationLink 推入主 NavigationStack。

iOS 主界面已有 `NavigationStack`（`ChineseChessiOSApp` 的 body），"学棋"按钮点击后推入 `StudyHubView`：

```swift
// StudyHubView：入口卡片页，推入主 NavigationStack
struct StudyHubView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                StudyEntryCard(title: "残局闯关", icon: "puzzlepiece") {
                    // NavigationLink → ChapterSelectView
                }
                StudyEntryCard(title: "大师棋谱", icon: "crown") {
                    // NavigationLink → MasterGameBrowserView
                }
                StudyEntryCard(title: "开局探索", icon: "book") {
                    // NavigationLink → OpeningExplorerView
                }
                StudyEntryCard(title: "每日挑战", icon: "target") {
                    // NavigationLink → DailyChallengeView
                }
            }
        }
        .navigationTitle("学棋")
    }
}
```

优势：残局闯关的 `ChapterSelectView → PuzzleSelectView → PuzzlePlayView` 三层导航在主 NavigationStack 内完成，不存在 sheet 内嵌 NavigationStack 的问题。

#### 2. 拆分 PuzzleDemoView

- `PuzzleDemoView`：仅负责残局演示（精简后只处理 `DemoCategory.puzzles`）
- 新增 `MasterGameBrowserView`：独立的大师棋谱浏览器
  - 一级分类：开局分类（从 `OpeningCategories` 动态加载）
  - 二级分类：子开局/棋手
  - 列表：对局条目
  - 播放：复用 `DemoBoardView` + 控制栏
- 新增 `MasterGameItemWrapper`：从 `DemoItemWrapper` 拆出大师棋谱分支
- 新增 `MasterGameViewModel`：从 `DemoViewModel` 拆出大师棋谱播放逻辑

#### 3. 简化 DemoCategory + 影响链

> **v2.0 修订**：补充 DemoCategory 拆分的影响链分析。

```swift
enum DemoCategory: Identifiable, Hashable {
    case puzzles(String)  // 仅残局分类
    // .opening 和 .player 移到 MasterGameBrowserView
}
```

**影响链清单**：

| 影响点 | 当前用法 | 迁移方案 |
|--------|---------|----------|
| `DemoItemWrapper.demoCategory` | 反查 `OpeningCategories` 获取大师棋谱分类名 | 拆分后 `DemoItemWrapper` 仅含 `.puzzle` case；大师棋谱用独立的 `MasterGameItemWrapper` |
| `DemoItemWrapper.initialFEN` | `.masterGame` 分支有 `fen==nil` 断言 | `MasterGameItemWrapper` 自行管理 FEN |
| `DemoItemWrapper.shouldFlipBoard` | `.masterGame` 固定返回 false | `MasterGameItemWrapper` 自行管理 |
| `DemoViewModel` | 根据 `DemoCategory` 分支走不同加载逻辑 | `DemoViewModel` 精简为仅残局；大师棋谱用 `MasterGameViewModel` |
| `PuzzleDemoView.sidebar` | 遍历 `DemoCategory` 两个 section | 精简为仅残局分类；大师棋谱由独立视图接管 |
| `PuzzleDemoView.categoryPicker` (iOS) | 同上 | 同上 |
| `PuzzleDemoView.rebuildListCache` | `switch cat` 两个分支 | 精简为仅 `.puzzles` 分支 |
| `PuzzleDemoView.playItem` | `switch wrapper` 两个分支 | 精简为仅 `.puzzle` 分支 |

结论：`DemoItemWrapper` 和 `DemoViewModel` 都需要对应拆分。`DemoCategory` 的 `.opening` 和 `.player` case 删除后，相关分支逻辑全部移至新组件。

> **补充**：`.player(String)` case 在 `rebuildListCache` 中返回空列表，是死分支。拆分时一并移除（或移至 MasterGameBrowserView 做后续扩展），避免遗漏导致编译报错。

#### 4. iOS toolbar 调整

```swift
// 底部 toolbar
ToolbarItemGroup(placement: .bottomBar) {
    Button { /* RecordPanelView */ } label: {
        Label("棋谱", systemImage: "doc.text")
    }
    Button { /* StudyHubView */ } label: {
        Label("学棋", systemImage: "graduationcap")
    }
    Button { /* ReplayView */ } label: {
        Label("回放", systemImage: "play.circle")
    }
    Spacer()
    Menu { /* 低频功能 */ } label: {
        Label("更多", systemImage: "ellipsis.circle")
    }
}
```

#### 5. macOS 调整

> **v2.0 修订**：保留平铺 toolbar，不做合并。改为分组 + 视觉分隔。

macOS 顶部 toolbar 保留所有按钮平铺，但用 `Divider()` 分为三组：
- **棋局组**：棋谱 / 残局 / 回放 / 分析 / 教练
- **学棋组**：开局探索 / 大师棋谱（新增） / 每日挑战
- **设置组**：主题 / 历史 / 成就 / 段位 / 设置

理由：
- macOS 屏幕宽度充足，12 个按钮平铺完全放得下
- 老用户已有肌肉记忆，合并反而增加学习成本
- 新增"大师棋谱"按钮填补入口缺失即可

#### 6. 用户迁移策略

> **v2.0 新增**（P2-A 反馈）

iOS toolbar 从 [棋谱/残局/回放/更多] 改为 [棋谱/学棋/回放/更多]，老用户肌肉记忆会断裂。

**迁移方案**：
1. 升级后首次打开 App，在"学棋"按钮旁显示一次性引导气泡（`tooltip` 或 `overlay`）："残局和开局探索已移至'学棋'"
2. 气泡点击后消失，标志位 `chinesechess.studyHubTooltipShown` 持久化
3. 保留 1 个版本的过渡期（v5.2.x），"更多"菜单里仍保留"残局"和"开局探索"的快捷入口

#### 7. 导航结构调整

```swift
// NavigationRoute 扩展
enum NavigationRoute: Hashable {
    case chapter(PuzzleChapter)
    case puzzleDemo
    case masterGame(MasterGameIndex)  // 新增
    case openingExplorer              // 新增
}

// SheetDestination 扩展（iOS）
enum SheetDestination: Identifiable {
    // ...existing...
    case masterGames    // 新增（从 StudyHubView 内部推入，不需要独立 sheet）
}
```

### 实施步骤

1. **Step 1**：新增 `StudyHubView` + iOS 底部 toolbar 改为 4 按钮 + NavigationLink 推入（1d）
2. **Step 2**：拆分 `MasterGameBrowserView` + `MasterGameItemWrapper` + `MasterGameViewModel`（1d）
3. **Step 3**：简化 `PuzzleDemoView` + `DemoCategory`，按影响链清单逐点迁移（1d）
4. **Step 4**：macOS toolbar 分组 + 新增大师棋谱按钮（0.5d）
5. **Step 5**：用户迁移气泡 + 入口联通 + E2E 测试（0.5d）

---

## 12. 分期实施计划

### Phase A — 紧急修复（P0 阻塞性问题，3 天）

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| P0-1: 分类菜单显示修复 | P0 | 0.5d |
| P0-2: 车马炮类子分类拆分（新增 `tacticalGroup` 字段 + Pikafish 辅助标注 + UI） | P0 | 2.5d |

### Phase B1 — 信息架构重组核心（P0，4 天）

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| P0-3: StudyHubView + MasterGameBrowserView + DemoCategory 拆分 + macOS 分组 | P0 | 4d |

### Phase B2 — 入口修复 + 体验优化（P1，3 天）

> **v2.0 修订**：从 Phase B 拆出，避免在复杂阶段压工期。P1-4 棋谱修复与 P0-3 有串行依赖（拆分 PuzzleDemoView 后 RecordPanelView 的引用位置也变了）。

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| P1-10a: iOS 残局入口修复（改为 ChapterSelectView） | P1 | 0.5d |
| P1-8: 中文显示修复（frame 硬编码审查 + 本地化适配） | P1 | 1d |
| P1-4: 棋谱显示修复（与 B1 有串行依赖，须在拆分后实施） | P1 | 1.5d |

### Phase C — 功能增强（P1，5 天）

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| P1-6: 开局库增强（含过渡方案 + 引用点迁移） | P1 | 3d |
| P1-7: 教程走子修复（resetCurrentStep 时序 + 坐标验证 + 反馈增强） | P1 | 2d |

### Phase D — 打磨（P2，3 天）

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| P2-10c: 开局探索与大师棋谱联动（含数据流设计） | P2 | 2d |
| P2-10d: 残局演示 iOS 棋谱面板 | P2 | 1d |

---

## 13. 工作量总览

| Phase | 工作量 | 核心交付 |
|-------|--------|----------|
| A | 3d | 分类显示修复 + 车马炮子分类 |
| B1 | 4d | 信息架构重组核心 |
| B2 | 3d | 入口修复 + 中文/棋谱修复 |
| C | 5d | 开局库增强 + 教程修复 |
| D | 3d | 联动 + 棋谱面板 |
| **合计** | **18d** | |

> **工期说明**：v1.0 估算 14.5d，v2.0 调整为 18d（+24%）。增量来自：拆分影响链迁移（DemoCategory 8 个影响点）、标注规范校准环节、联动数据流设计。v2.0 更贴近实际，非范围蔓延。

---

## 14. Vera 审查反馈处理记录

| 反馈 | 级别 | 处理 |
|------|------|------|
| P0-A: resetCurrentStep 根因定位错误 | P0 | ✅ 重新诊断：stepIndex 时序 bug 是主因，拆分 setupBoard 为 resetBoardOnly + resetProgress |
| P0-B: subcategory 字段语义冲突 | P0 | ✅ 新增 `tacticalGroup: String?` 字段，与 `subcategory`（难度标签）分离 |
| P0-C: Phase B 工期低估 | P0 | ✅ 拆为 B1(4d) + B2(3d)，P1-4 标注串行依赖 |
| P1-A: StudyHubView 导航深度 | P1 | ✅ 改为 NavigationLink 推入主 NavigationStack，不用 sheet |
| P1-B: 半自动标注准确度 | P1 | ✅ 改为两步法：先校准标注规范(10-20局)，再用 Pikafish 终局特征分类 + 30 局交叉核验 |
| P1-C: OpeningCategories 过渡方案 | P1 | ✅ 补充两阶段过渡方案 + 引用点迁移清单 + ID 命名规范 |
| P1-D: macOS toolbar 方案未决 | P1 | ✅ 决定：保留平铺 + 分组分隔，不合并 |
| P1-E: DemoCategory 拆分影响链 | P1 | ✅ 补充完整影响链清单（8 个影响点 + 迁移方案） |
| P2-A: 用户迁移策略 | P2 | ✅ 新增一次性引导气泡 + 过渡期保留快捷入口 |
| P2-B: 10c 联动数据流 | P2 | ✅ 工期从 1d 调为 2d，补充数据流设计 |
| P2-C: 调试模式不应进生产 | P2 | ✅ 移除调试模式建议，改为内部开发工具 |

### 非阻塞建议（第 2 轮审查，不阻碍开工）

| # | 建议 | 处理 |
|---|------|------|
| 1 | DemoCategory.player(String) 归属未说明 | ✅ 补充：`.player` 是死分支，拆分时一并移除 |
| 2 | resetCurrentStep 可精简（wrong/illegal 时棋盘未变） | ✅ 补充注释说明防御性写法理由 |
| 3 | 总工期 18d vs 14.5d 差距需说明 | ✅ 补充工期说明：增量来自影响链迁移+标注校准+联动数据流，非范围蔓延 |
