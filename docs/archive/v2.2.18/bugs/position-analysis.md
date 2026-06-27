# Bug诊断报告：棋子与棋盘位置不匹配

## 问题描述
用户报告中国象棋v2.1棋子和棋盘位置对应不上。

## 数值分析

### 假设参数
- 容器尺寸 size = 360px（正方形）
- padding = 30px
- gridCols = 8（竖线间距数）
- gridRows = 9（横线间距数）

### 棋盘网格计算
```
cellSize = (size - padding*2) / max(gridCols, gridRows)
         = (360 - 60) / 9
         = 33.33px

boardWidth = cellSize * gridCols + padding*2
           = 33.33 * 8 + 60
           = 326.67px

boardHeight = cellSize * gridRows + padding*2
            = 33.33 * 9 + 60
            = 360px
```

### 棋盘交叉点坐标
| 列(col) | x坐标 | 行(row) | y坐标 |
|---------|-------|---------|-------|
| 0 | 30 | 0 | 30 |
| 1 | 63.33 | 1 | 63.33 |
| 2 | 96.67 | 2 | 96.67 |
| ... | ... | ... | ... |
| 8 | 296.67 | 9 | 330 |

### 棋子尺寸计算
```
pieceDiameter = boardSize.width / 10 * 0.85
              = 326.67 / 10 * 0.85
              = 27.77px
```

### 关键发现

**问题1：棋子尺寸计算基准不一致**

- `cellSize` 基于 `max(gridCols, gridRows) = 9` 作为分母
- `pieceDiameter` 基于 `boardWidth / 10` 作为分母
- 两个分母不同（9 vs 10），导致比例不匹配

**问题2：棋盘宽度计算**

棋盘实际宽度 `boardWidth = 326.67px`，但棋盘线条绘制范围：
- 竖线从 `x=padding` 到 `x=padding+gridCols*cellSize = 30 到 296.67`
- 实际绘制宽度 = 266.67px（不含padding）

棋子用 `.position()` 定位在交叉点上，但棋子直径27.77px vs cellSize33.33px，存在约6px差距。

**问题3：棋盘高度计算**

棋盘高度 `boardHeight = 360px`，刚好等于容器尺寸，但棋盘宽度 `boardWidth = 326.67px` 小于容器宽度360px。

这会导致棋盘在容器中居中显示，但棋子定位用的 `boardWidth` 可能与实际显示的棋盘位置有偏差。

## 根因分析

### 主要根因
**cellSize计算公式与棋盘几何定义不匹配**

中国象棋棋盘：
- 9列交叉点（0-8） → 需要8个间距
- 10行交叉点（0-9） → 需要9个间距
- 横纵间距应该相等（棋盘是正方形网格）

当前代码：
```swift
let cellSize = (size - padding * 2) / CGFloat(max(gridCols, gridRows))
```

这个公式用 `max(8,9)=9` 作为分母，导致：
- 横向：8个间距，总宽 = 8*cellSize = 266.67px
- 纵向：9个间距，总高 = 9*cellSize = 300px

棋盘应该是正方形网格，但实际：
- 横向间距范围：266.67px
- 纵向间距范围：300px
- **不相等！**

### 次要问题
棋子直径计算 `boardWidth/10*0.85` 用了10作为分母，与网格间距数（8/9）不对应。

## 修复方案

### 方案1：统一基准（推荐）
```swift
// 使用统一的网格单元尺寸
let gridUnit = 8  // 9列棋盘需要8个间距
let cellSize = (size - padding * 2) / CGFloat(gridUnit)

// 棋盘尺寸（正方形）
let boardWidth = cellSize * CGFloat(gridUnit) + padding * 2
let boardHeight = boardWidth  // 强制正方形

// 棋子直径与cellSize对应
let pieceDiameter = cellSize * 0.85
```

这样棋盘是正方形，棋子尺寸与网格间距直接对应。

### 方案2：保持纵横比（备选）
如果需要保持传统棋盘的纵横比（略扁），则：
```swift
let aspectRatio = CGFloat(gridCols) / CGFloat(gridRows)  // 8/9 ≈ 0.89
let cellSizeH = (size - padding * 2) / CGFloat(gridCols)  // 横向间距
let cellSizeV = (size - padding * 2) / CGFloat(gridRows)  // 纵向间距
// 坐标映射时横纵分别用对应间距
```

但中国象棋棋盘传统上横纵间距相等，方案1更符合实际需求。

## 建议修复步骤
1. 修改 ChessBoardView.swift 中 cellSize 计算，使用统一分母
2. 修改 PieceView.swift 中 pieceDiameter 计算，直接用 cellSize * 0.85
3. 确保 boardWidth == boardHeight（正方形棋盘）
4. 测试验证：棋子中心应精确落在交叉点上

## 相关文件
- `src/ChineseChess/Views/ChessBoardView.swift` (第28-33行)
- `src/ChineseChess/Views/PieceView.swift` (第17-19行)

---
诊断时间：2026-06-04