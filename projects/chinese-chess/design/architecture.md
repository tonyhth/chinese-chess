# 架构设计文档 — 中国象棋 macOS 原生应用

> 版本：v2 | 作者：Alex | 日期：2025-07-14

---

## 1. 架构总览

采用 **MVVM**（Model-View-ViewModel）架构，Swift + SwiftUI 原生实现。

```
┌──────────────────────────────────────────────────┐
│                    View Layer                     │
│  BoardView  PieceView  StatusBarView  MenuView    │
└──────────┬───────────────────────┬───────────────┘
           │ @Observable           │ @Observable
┌──────────▼───────────┐ ┌────────▼────────────────┐
│   GameViewModel      │ │   SettingsViewModel     │
│ (游戏状态/交互逻辑)  │ │ (难度/音效/主题设置)    │
└──────────┬───────────┘ └────────┬────────────────┘
           │                        │
┌──────────▼────────────────────────▼───────────────┐
│                  Model Layer                       │
│  Board  Piece  Move  GameRule  AIEngine  Sound     │
└───────────────────────────────────────────────────┘
```

### 架构选型理由

| 决策 | 理由 |
|------|------|
| MVVM | SwiftUI 天然数据驱动，@Observable + @Bindable 完美匹配 MVVM 的数据绑定需求 |
| SwiftUI | PRD 要求 macOS 14.0+，SwiftUI 在该版本已成熟，Canvas 绘制棋盘性能足够 |
| 无第三方依赖 | 象棋应用功能域收敛，不需要网络/数据库/云端服务，零依赖降低维护成本 |
| AI 引擎同步执行 | 搜索深度 ≤ 5 时单线程计算量可控（< 1s），无需引入异步框架，用 `Task.detached` 即可 |

---

## 2. 模块划分

### 2.1 模块关系图

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  BoardView  │────▶│GameViewModel│────▶│  Board      │
│  (SwiftUI)  │     │ (Observable)│     │  (Model)    │
└─────────────┘     └──────┬──────┘     └──────┬──────┘
                           │                    │
                    ┌──────▼──────┐      ┌──────▼──────┐
                    │  AIEngine   │      │MoveValidator│
                    │  (Model)    │      │  (Model)    │
                    └─────────────┘      └─────────────┘
                           │
                    ┌──────▼──────┐
                    │ SoundEngine │
                    │ (Service)   │
                    └─────────────┘
```

### 2.2 模块职责

#### 🎯 棋盘引擎模块（Board Engine）

**职责**：棋盘状态管理、棋子移动、规则校验、胜负判定。

| 类型 | 说明 |
|------|------|
| `Board` | 棋盘数据容器，10 行 × 9 列二维数组，持有所有棋子 |
| `Piece` | 棋子实体：类型、阵营、位置 |
| `Move` | 走一步棋的值类型：起点、终点、被吃棋子（可选） |
| `MoveValidator` | 纯函数集，给定 Board + Piece 判断走法是否合法 |
| `GameResult` | 枚举：进行中 / 红胜 / 黑胜 / 和棋 |

**关键规则覆盖**（MoveValidator 必须完整实现）：

- **马**：日字移动 + 蹩马腿检查（直线方向有子则不可走）
- **象/相**：田字移动 + 塞象眼检查（田字中心有子则不可走）+ 不可过河
- **将/帅**：九宫格内一步直行 + 将帅对面规则（两将不可同列无子对面）
- **士/仕**：九宫格内一步斜行
- **车**：直线任意格数，不可越子
- **炮**：直线移动不越子；吃子必须恰好翻越一个棋子（炮架）
- **兵/卒**：未过河只可前进；过河后可前进或左右平移，不可后退

#### 🤖 AI 引擎模块（AI Engine）

**职责**：根据当前棋盘状态计算 AI 走法。

| 难度 | 策略 | 详细设计见 |
|------|------|-----------|
| 初级 | 随机合法走法 | [ai-algorithm.md §2.1](#) |
| 中级 | 启发式评估 + 深度 2 搜索 | [ai-algorithm.md §2.2](#) |
| 高级 | Minimax + Alpha-Beta 剪枝 ≥ 深度 4 | [ai-algorithm.md §2.3](#) |

AI 引擎是纯计算模块，输入 `Board`，输出 `Move`，不持有可变状态。

#### 🖼 UI 层（View Layer）

**职责**：SwiftUI 视图渲染、用户交互、动画。

| 视图 | 说明 |
|------|------|
| `BoardView` | 棋盘主体，Canvas 绘制棋盘线 + 棋子叠加层 |
| `PieceView` | 单个棋子渲染（圆形 + 楷体字） |
| `StatusBarView` | 底部状态栏：当前轮次、被吃棋子、走棋历史 |
| `ToolbarView` | 工具栏：新局 / 悔棋 / 难度选择 |
| `GameOverOverlay` | 游戏结束弹窗 |

#### 🔊 音效层（Sound Engine）

**职责**：落子音效、吃子音效。

| 接口 | 说明 |
|------|------|
| `SoundEngine.playMove()` | 落子音效 |
| `SoundEngine.playCapture()` | 吃子音效 |
| `SoundEngine.isMuted: Bool` | 静音开关 |

使用 `AVFoundation` 的 `AVAudioPlayer` 播放 bundled 音频文件。音效为可选功能，缺失时静默降级（不 crash）。

---

## 3. 数据流

### 3.1 用户走棋流程

```
用户点击棋子
    │
    ▼
PieceView.onTapGesture
    │
    ▼
GameViewModel.selectPiece(at:)
    │ ┌─ 计算合法走法位置
    │ │ MoveValidator.legalMoves(for: on:)
    │ └─ 高亮可走位置
    ▼
用户点击目标位置
    │
    ▼
GameViewModel.movePiece(from:to:)
    │ ┌─ MoveValidator 校验合法性
    │ ├─ Board 执行移动（记录被吃棋子）
    │ ├─ 播放音效
    │ ├─ 检查胜负（GameResult）
    │ └─ 触发 AI 回合
    ▼
GameViewModel.triggerAIMove()
    │
    ▼
Task.detached { AIEngine.bestMove(for: board) }
    │
    ▼
GameViewModel.applyAIMove(_:)
    │ ┌─ Board 执行移动
    │ ├─ 播放音效
    │ └─ 检查胜负
    ▼
SwiftUI 自动刷新视图
```

### 3.2 悔棋流程

```
用户点击悔棋
    │
    ▼
GameViewModel.undoMove()
    │ ┌─ 撤销 AI 走法（还原被吃棋子）
    │ └─ 撤销玩家走法（还原被吃棋子）
    ▼
SwiftUI 自动刷新视图
```

### 3.3 数据绑定方式

| ViewModel 属性 | 类型 | View 绑定 |
|---------------|------|-----------|
| `board: Board` | `@Observable` | `BoardView` 读取棋盘状态渲染 |
| `selectedPosition: Position?` | `@Observable` | `PieceView` 判断选中高亮 |
| `legalMoves: [Position]` | `@Observable` | `BoardView` 绘制可走位置标记 |
| `currentTurn: PlayerSide` | `@Observable` | `StatusBarView` 显示当前轮次 |
| `capturedPieces: (red: [Piece], black: [Piece])` | `@Observable` | `StatusBarView` 显示被吃棋子 |
| `moveHistory: [Move]` | `@Observable` | `StatusBarView` 显示走棋历史 |
| `gameState: GameState` | `@Observable` | `GameOverOverlay` 判定是否弹出 |
| `isThinking: Bool` | `@Observable` | 状态栏显示 AI 思考中动画 |

---

## 4. 中国风视觉设计

### 4.1 配色方案

| 用途 | 颜色值 | 说明 |
|------|--------|------|
| 棋盘背景 | `#DEB887` (BurlyWood) | 温暖木质色 |
| 棋盘线条 | `#4A3728` (深棕) | 传统木刻线条感 |
| 楚河汉界文字 | `#4A3728` | 楷体，与线条同色 |
| 红方棋子底色 | `#FFF8DC` (Cornsilk) | 淡黄底 |
| 红方棋子文字 | `#CC0000` (中国红) | 楷体加粗 |
| 红方棋子边框 | `#CC0000` | 与文字同色 |
| 黑方棋子底色 | `#FFF8DC` | 同红方底色 |
| 黑方棋子文字 | `#1A1A1A` (墨黑) | 楷体加粗 |
| 黑方棋子边框 | `#1A1A1A` | 与文字同色 |
| 选中高亮 | `#FFD700` (金色) | 选中棋子外发光 |
| 可走位置标记 | `#32CD32` (LimeGreen) | 半透明圆点 |
| 窗口背景 | `#2C1810` (深木色) | 棋盘外区域 |
| 状态栏背景 | `#3C2415` | 略浅于窗口背景 |

### 4.2 字体

| 用途 | 字体 | 回退 |
|------|------|------|
| 棋子文字 | STKaiti (华文楷体) | Kaiti SC, serif |
| 楚河汉界 | STKaiti | Kaiti SC, serif |
| 状态栏/菜单 | systemDefault | — |

棋子文字字号根据棋子尺寸动态计算，约为棋子直径的 45%。

### 4.3 棋子样式

- 圆形，直径约为格子间距的 85%
- 立体感：`DropShadow` + 渐变底色（从中心高光到边缘暗色）
- 选中状态：外圈金色光晕（`shadow(color: .gold, radius: 6)`）
- 悬停状态：轻微放大（`scaleEffect(1.05)`）

### 4.4 棋盘样式

- 9 × 10 格线，Canvas 绘制
- 九宫格斜线（将/帅活动区域）
- 楚河汉界：第 5 行与第 6 行之间的空白区域，居中显示"楚河 汉界"楷体文字
- 兵/卒位置的标记点（传统象棋棋盘的星位标记）
- 木纹背景：使用 SwiftUI 的 `LinearGradient` 模拟简单木纹（避免加载外部图片）

### 4.5 动画

| 动画 | 实现 | 时长 |
|------|------|------|
| 棋子移动 | `withAnimation(.easeInOut)` 移动位置 | 0.25s |
| 吃子 | 被吃棋子淡出 + 缩小 | 0.2s |
| 选中高亮 | 金色光晕呼吸动画 | 重复 |
| AI 思考 | 状态栏脉冲动画 | 重复 |

---

## 5. 部署方案

### 5.1 项目结构

```
ChineseChess/
├── ChineseChess.xcodeproj
├── ChineseChess/
│   ├── App/
│   │   └── ChineseChessApp.swift        # @main 入口
│   ├── Models/
│   │   ├── Board.swift
│   │   ├── Piece.swift
│   │   ├── Move.swift
│   │   ├── Position.swift
│   │   └── MoveValidator.swift
│   ├── ViewModels/
│   │   ├── GameViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── BoardView.swift
│   │   ├── PieceView.swift
│   │   ├── StatusBarView.swift
│   │   ├── ToolbarView.swift
│   │   └── GameOverOverlay.swift
│   ├── AI/
│   │   └── AIEngine.swift
│   ├── Services/
│   │   └── SoundEngine.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Sounds/
│           ├── move.wav
│           └── capture.wav
├── ChineseChessTests/
│   ├── MoveValidatorTests.swift
│   ├── AIEngineTests.swift
│   └── BoardTests.swift
└── README.md
```

### 5.2 构建与运行

```bash
# 命令行构建（Xcode Command Line Tools）
xcodebuild -project ChineseChess.xcodeproj \
  -scheme ChineseChess \
  -configuration Debug build

# 或直接 Xcode 打开项目运行
open ChineseChess.xcodeproj
```

### 5.3 系统要求

| 项目 | 要求 |
|------|------|
| macOS 最低版本 | 14.0 (Sonoma) |
| Xcode 最低版本 | 15.0 |
| Swift 版本 | 5.9+ |
| 架构 | Universal (Apple Silicon + Intel) |

---

## 6. 分期计划

### Phase 1 — 核心引擎（优先）

- Board / Piece / Position 数据模型
- MoveValidator 完整规则实现
- GameViewModel 基础框架
- BoardView 基础渲染（无动画）

### Phase 2 — AI + 对战

- AIEngine 三级难度
- 人机对战完整流程
- 胜负判定
- 悔棋功能

### Phase 3 — 视觉打磨

- 中国风配色和字体
- 棋子立体感和动画
- 音效集成
- 状态栏和历史记录

### Phase 4 — 测试 + 收尾

- MoveValidator 单元测试（覆盖所有特殊规则）
- AIEngine 单元测试
- 集成测试（完整对局流程）
- README 文档

---

## 7. 错误处理策略

| 场景 | 处理方式 |
|------|---------|
| 非法走法 | ViewModel 忽略，可选 toast 提示"不合法的走法" |
| AI 计算超时 | 设置最大思考时间 5s，超时返回当前最优解 |
| 音效文件缺失 | 静默跳过，不 crash |
| 棋盘状态异常 | `assert` + `precondition` 防御性检查（Debug 模式） |

---

## 8. 性能考虑

| 关注点 | 策略 |
|--------|------|
| AI 计算 | `Task.detached` 异步执行，不阻塞 UI；高级难度限制搜索时间 |
| 棋盘渲染 | SwiftUI Canvas 只在 board 状态变化时重绘 |
| 走法生成 | MoveValidator 结果可缓存（同一 board 状态下） |
| 内存 | AI 搜索过程中不复制整个 Board，用 make/unmake 模式原地修改 |
