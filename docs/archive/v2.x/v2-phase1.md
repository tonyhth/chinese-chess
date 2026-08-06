# 棋谱自动演示 v2.2 — Phase 1：核心演示 + 大师对局

> 通用设计见：docs/phases/v2-common.md
> 完整方案见：docs/design/auto-demo-design.md

---

## Phase 1 任务列表

| # | 任务 | 说明 | 依赖 | 预估 |
|---|------|------|------|------|
| 1 | 离线索引构建脚本 | build_master_index.py（二进制模式+边界检测+年份提取+棋手名映射+哨兵通用化+大小写归一化） | 无 | 1d |
| 2 | name_map.json 人工补全 | 构建脚本输出模板，人工补全中文名 | #1 | 0.5d |
| 3 | MasterGameStore | 索引加载+倒排索引+PGN hash 校验+二级开局分类倒排 | #1 | 0.5d |
| 4 | PGNImporter 扩展 | parseSingleAtOffset + ImportResult 返回 | 无 | 0.5d |
| 5 | DemoViewModel | 播放逻辑 + 自动连播 + 状态机 + DemoPlayState | #3, #4 | 1d |
| 6 | PuzzleDemoView | 演示主视图 + 棋盘 + 控制栏 | #5 | 1d |
| 7 | CommentaryEngine | 规则推断（将军/将死/最后一步）+ 终局结果推导 | 无 | 0.5d |
| 8 | CommentaryOverlay | 点评气泡 UI | #7 | 0.5d |
| 9 | DemoInfoBar | 对局信息展示（残局+大师统一，中文名+年份） | #3 | 0.5d |
| 10 | 残局分类浏览 | 10 分类侧边栏/Picker | #5 | 0.5d |
| 11 | 大师对局分类浏览 | 按开局(含二级)/棋手/赛事 + LazyVStack 虚拟化 | #3, #6 | 1d |
| 12 | ICCS→GameMove 转换 | DemoMoveConverter | 无 | 0.5d |

## 可并行分组

- **A 组（数据层，可先行）**：#1 → #2 + #3 → #4
- **B 组（UI 层，依赖 A 组）**：#5 → #6 + #9 + #10 + #11
- **C 组（独立模块）**：#7 → #8, #12（与 B 组并行）

## 交付标准

- 残局：按分类浏览 534 局，自动播放+点评+暂停/步进/速度调节+自动连播
- 大师对局：按开局(含二级分类)/棋手/赛事分类浏览，中文名展示，点击后按需解析播放+点评+连播

## 关键实现细节

### 任务 #1 构建脚本关键约束

1. **二进制模式**：`open('rb')`，`f.tell()` 返回真实字节偏移
2. **哨兵通用化**：走法段结束检测用 `[`（任何标签行标志新局开始），不用 `[Event`
3. **棋手名归一化**：`normalize_name()` 全大写→title case；映射表用小写键 `name_map_lower` 查找
4. **年份提取**：从 Event 标签正则提取 4 位数字年份
5. **moveCount 与 PGNImporter 一致**：`count_moves()` 使用相同的 token 过滤逻辑
6. **bySubcategory 长度守卫**：`game.firstMoves.count >= sub.firstMoves.count`

### 任务 #3 MasterGameStore 关键约束

1. **Lazy Load**：首次进入 PuzzleDemoView 时加载，非 App 启动
2. **倒排索引**：playerIndex/eventIndex/openingIndex/subcategoryIndex，O(1) 查询
3. **二级开局分类**：预构建倒排，加长度守卫
4. **pgnHash 校验**：SHA256 of PGN 前 1KB

### 任务 #4 PGNImporter 扩展

- `parseSingleAtOffset` 返回 `ImportResult`（与 `parse()` 一致）
- 支持部分成功（单局内部分走法非法仍允许播放已解析部分）

### 任务 #5 DemoViewModel

- DemoPlayState：idle → loading → ready(GameRecord) / failed(String)
- 自动连播状态机：播放中 → 结束 → 关键步暂停(1.5s) → 展示结果(2s) → 加载下一局 → 播放中
- 解析失败自动跳到下一局
- 用 `// ReplayViewModel-sync` 标记与 ReplayViewModel 的同步点

### 任务 #7 CommentaryEngine

- Phase 1 仅规则推断：将军/将死/最后一步
- 终局结果推导：将死→红胜/黑胜、困毙/重复/子力不足→和棋、未终结→"对局记录结束"

### 任务 #11 大师对局分类浏览

- 按开局（含二级分类，中炮下细分屏风马/反宫马等）
- 按棋手（master-stats.json top 100）
- 按赛事（master-stats.json top 50）
- LazyVStack 虚拟化 + 分段加载（每段 200 条）
- 棋手名用中文名（redNameCN/blackNameCN），无映射回退英文
