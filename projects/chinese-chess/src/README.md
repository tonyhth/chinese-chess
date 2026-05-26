# 中国象棋 — macOS 原生应用

macOS 原生中国象棋游戏，Swift + SwiftUI 实现，支持人机对战。

## 系统要求

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Swift 5.9+

## 构建

```bash
cd src
swift build
```

## 运行测试

```bash
cd src
swift test
```

## 使用 Xcode 打开

由于本项目使用 SPM (Swift Package Manager)，可以：

1. 在 `src/` 目录下执行 `swift package generate-xcodeproj` 生成 Xcode 项目
2. 或直接用 Xcode 打开 `src/Package.swift`

## 功能

- ✅ 完整走棋规则（将/帅、士/仕、象/相、马、车、炮、兵/卒）
- ✅ 将帅对面规则
- ✅ 三个 AI 难度（初级随机 / 中级 Minimax 深度2 / 高级 Alpha-Beta 深度≥4）
- ✅ 悔棋、新局
- ✅ 中国风视觉（木纹棋盘、楷体字、圆形棋子）
- ✅ 状态栏（当前轮次、被吃棋子、走棋历史）
- ✅ 棋子移动动画

## 项目结构

```
src/
├── Package.swift
├── ChineseChess/
│   ├── App/
│   │   └── ChineseChessApp.swift
│   ├── Models/
│   │   ├── Board.swift
│   │   ├── Enums.swift
│   │   ├── Move.swift
│   │   ├── Piece.swift
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
│   └── Services/
│       └── SoundEngine.swift
└── ChineseChessTests/
    ├── BoardTests.swift
    ├── MoveValidatorTests.swift
    └── AIEngineTests.swift
```

## 架构

MVVM 架构，严格单向依赖：View → ViewModel → Model。

详见 `design/architecture.md`。
