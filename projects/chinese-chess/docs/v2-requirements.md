# 中国象棋 v2.0 — 需求文档

> 日期：2026-05-31
> 状态：待 Alex 设计
> 项目目录：~/DevTeam/projects/chinese-chess/

## 一、项目背景

v1.0 已交付，功能包括：完整走棋规则、MVVM 架构、3 级 AI（随机/minimax-2/minimax-4+alpha-beta）、中国风 UI、音效、悔棋。
v2.0 是重大升级，目标平台从 macOS-only 扩展为 **macOS + iOS 通用**，核心改进集中在 AI 难度、棋谱系统、残局闯关三大模块。

## 二、v1.0 代码现状（设计时必须基于此）

### 架构
- **MVVM**：Board（模型）→ GameViewModel（视图模型）→ BoardView/ToolbarView/StatusBarView（视图）
- **AI**：AIEngine struct，AIEngineProtocol 协议，AIDifficulty enum（easy/medium/hard）
- **棋盘**：Canvas 绘制线条 + ZStack 叠棋子 + DragGesture(minimumDistance: 0) 交互层
- **构建**：Swift Package Manager（Package.swift），无 Xcode 项目文件

### 关键数据模型
- `Piece`：id(UUID), kind, side, position, displayName, baseValue
- `Move`：piece, from, to, captured
- `Board`：pieces[], moveHistory[], currentTurn, execute/undoLastMove/snapshot
- `Position`：row(0-9), col(0-8)
- `AIDifficulty`：easy/medium/hard
- `GameState`：playing/redWon/blackWon/draw

### AI 现状
- **初级**：纯随机合法走法
- **中级**：Minimax depth=2，无 alpha-beta 剪枝
- **高级**：迭代加深 Minimax + alpha-beta，depth 4-5，1 秒限时
- 评估函数：子力价值 + 位置权重表（兵/马/车/炮/将/士/象各有独立权重矩阵）
- 走法排序：MVV-LVA（只考虑吃子价值）

## 三、v2.0 需求

### P0 — 核心功能（必须实现）

#### 3.1 AI 难度全面升级（5 级）

将 AIDifficulty 从 3 级扩展为 5 级：

| 难度 | 算法 | 目标水平 | 说明 |
|------|------|----------|------|
| 新手 | 随机 + 避免送大子（value>400不送） | 不会下棋的人 | 现初级太弱且毫无目的，加一点基础判断 |
| 初级 | Minimax depth=2 + alpha-beta + 基础走法排序 | 偶尔下棋 | 用现有中级算法加 alpha-beta |
| 中级 | Minimax depth=4 + alpha-beta + 开局库 + 将军优先排序 | 业余爱好者 | 加入开局库前 10 步 |
| 高级 | Minimax depth=6 + 迭代加深 + 杀法搜索 + 棋型识别 | 区县赛水平 | 核心改进在此档 |
| 大师 | depth=6+ + 深层杀法搜索 + 残局精确估值 + 时间管理 | 市级爱好者 | 最高难度 |

**核心算法改进点：**
1. **开局库**：内置 10-20 个经典开局变化（中炮对屏风马、飞相对士角炮等），前 10 步直接查表而非搜索
2. **走法排序优化**：将军走法 > 吃子(MVV-LVA) > 威胁子力 > 其他，大幅提升 alpha-beta 剪枝效率
3. **杀法搜索**：专门搜索连将杀（类似象棋软件的"杀法模块"），depth 可到 8-10 层但只搜将军链
4. **棋型识别**：识别单车胜、双车错、马后炮等基础杀法棋型，直接加分
5. **残局精确估值**：子力少时（≤6 子）切换为精确残局评估（单车对单马等）
6. **时间管理**：高级/大师难度有思考时间限制（3 秒/5 秒），超时返回当前最优
7. **Zobrist 哈希 + 置换表**：避免重复搜索同一局面

#### 3.2 棋谱系统

**数据模型扩展：**
- Move 扩展为 `GameMove`，增加：回合号、棋谱文本（如"炮二平五"）、时间戳、是否将军/将死
- 新增 `GameRecord`：棋谱标题、日期、红/黑方信息、难度、结果、走法列表

**棋谱格式：中国象棋纵线坐标法（ICCS 中文描述）**
- 红方从右到左一到九，黑方从右到左 1-9
- 示例：炮二平五、马8进7、车一进一、前车平四
- 在 GameViewModel 中每步自动生成棋谱文本

**棋谱记录面板：**
- 侧边栏/底部面板，列表形式显示每一步（如"1. 炮二平五  马8进7"）
- 支持点击某步跳转到该局面（回放功能基础）

#### 3.3 残局闯关模式

**残局库：**
- 自带 **50-100 局经典残局**，按难度分级（入门/初级/中级/高级）
- 每局包含：名称、初始局面（FEN 格式或自定义 JSON）、走法提示（可选）、正确答案
- 经典残局类型覆盖：单车胜、马后炮、双车错、钓鱼马、铁门栓、海底捞月、双马饮泉等
- 残局数据以 JSON bundle 内置

**闯关 UI：**
- 独立的残局选择界面（列表/网格）
- 显示：残局名称、难度星级、是否通关
- 进入残局后，玩家执先（部分执后），走对即通关，走错提示"再想想"
- 支持悔棋（残局中可无限悔棋）

**初始局面解析：**
- Board 支持从 FEN 或自定义 JSON 初始化（不再只有标准开局）
- FEN 格式参考象棋标准：`rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1`

#### 3.4 人人对战模式

- 新增 `GameMode` enum：singlePlayer(人机) / localPVP(本地人人)
- 本地人人对战：两人轮流在同一设备上操作
- 人人对战时隐藏 AI 相关 UI，显示"红方走棋"/"黑方走棋"切换提示

#### 3.5 胜率统计

- `UserDefaults` 持久化存储
- 按难度记录：胜/负/和次数、总局数、胜率
- 在主界面或设置页显示统计面板
- 人人对战记录红方/黑方各自的胜负

### P1 — 体验提升（应实现）

#### 3.6 桌面图标重设计

- 重新设计 macOS 应用图标（.icns）
- 风格要求：中国风、专业、辨识度高
- 当前图标为 Alex 设计的帅棋+木色棋盘，需要全新设计

#### 3.7 音效升级

- 扩充音效种类：走棋（已有）、吃子（已有）、将军、将死、悔棋、胜利、失败
- 将军和将死音效应有紧迫感/胜利感
- 保持系统 fallback 策略（v1.0 的做法）

#### 3.8 走子动画

- 棋子移动加平滑过渡动画（当前有 .easeInOut(0.25) 但只是视觉位移）
- 吃子时加消除效果（缩小+淡出）
- 选中棋子加呼吸效果或发光效果（替代当前简单的 scaleEffect）

#### 3.9 棋盘主题

- 至少 2 套可切换主题：
  1. **经典木纹**（当前默认风格，保持）
  2. **石材水墨**（灰白棋盘+水墨风棋子）
- 主题切换不影响功能逻辑
- 棋子样式（圆形立体/扁平水墨）可随主题变化

#### 3.10 对局回放

- 基于 3.2 的棋谱记录，支持走完一局后回放
- 回放控制：上一步、下一步、自动播放（可调速度）、跳到开始/结束
- 回放时棋盘状态根据走法列表重建
- 支持从残局闯关和人人对战的结果进行回放

### P2 — 锦上添花（时间允许再做）

#### 3.11 走法提示

- 在人机对战中，玩家可选择"提示"
- AI 为玩家方计算推荐走法，高亮显示推荐起点和终点
- 初级难度以上可用（新手不建议）

#### 3.12 棋谱导入导出

- 导出：将对局保存为标准文本格式（纯文本棋谱，非 PGN），方便分享
- 导入：从文本加载棋谱并回放
- 暂不需要网络导入，本地文件即可

## 四、平台与架构要求

### 4.1 macOS + iOS 通用

- **必须从 v1.0 的 SPM 项目迁移到 Xcode 项目**（.xcodeproj），支持双平台 target
- SwiftUI 跨平台适配：macOS 用 WindowGroup，iOS 用 NavigationStack
- 棋盘交互：macOS 继续 DragGesture，iOS 用 DragGesture 或 LongPress + move
- pbxproj 管理用丹妮的 Python 脚本（与 vocab-game 相同方案）
- **丹妮直接管理 pbxproj**，编码团队只负责 Swift 源码

### 4.2 架构原则

- 保持 MVVM 架构
- AI 引擎保持 `AIEngineProtocol` 协议，方便未来替换或测试
- 新增模块用独立文件，不膨胀现有文件
- 棋谱/残局数据与游戏逻辑分离

## 五、不在 v2.0 范围内

- ❌ 联机对战（网络功能）
- ❌ 用户自定义残局导入（只做内置残局库）
- ❌ PGN 标准格式（中国象棋通用 ICCS 文本格式即可）
- ❌ 棋谱云同步

## 六、交付标准

- macOS + iOS 双平台编译通过
- 单元测试覆盖：AI 引擎核心算法、棋谱生成、残局解析、走法验证
- 集成测试：完整对局流程、残局闯关流程
- 中文 UI
- 无 P0 bug

## 七、已知约束

- v1.0 P0 修复经验：macOS 上 `onTapGesture` 不可靠，必须用 `DragGesture(minimumDistance: 0)` + 透明 overlay
- STKaiti 字体 macOS 可用，iOS 可能需要 fallback
- pbxproj 新增文件必须手动声明（PBXFileReference + PBXBuildFile + group + Sources phase），教训 046
- iOS→macOS 迁移必须同步改 dependency + SDKROOT + TEST_HOST，教训 045
