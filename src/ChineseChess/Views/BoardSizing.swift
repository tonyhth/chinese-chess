import SwiftUI

/// 棋盘尺寸计算共享逻辑
///
/// ChessBoardView 和 ReplayBoardView 使用同一套计算方法，
/// 确保两个棋盘在相同容器空间下渲染大小完全一致。
enum BoardSizing {

    /// 网格常量
    static let gridCols = 8   // 8个间距，9条竖线
    static let gridRows = 9   // 9个间距，10条横线

    /// 最大 cellSize，防止窗口过大时棋盘无限放大
    static let maxCellSize: CGFloat = 80

    #if os(iOS)
    /// iOS 大屏棋盘最大尺寸约束
    static let maxBoardWidth: CGFloat = 600
    static let maxBoardHeight: CGFloat = 675
    #endif

    /// 棋盘尺寸计算结果
    struct Sizing {
        let cellSize: CGFloat
        let padding: CGFloat
        let boardWidth: CGFloat
        let boardHeight: CGFloat
    }

    /// 根据可用空间计算棋盘尺寸
    /// - Parameters:
    ///   - width: GeometryReader 提供的容器宽度
    ///   - height: GeometryReader 提供的容器高度
    /// - Returns: 棋盘尺寸信息（cellSize, padding, boardWidth, boardHeight）
    static func calculate(width: CGFloat, height: CGFloat) -> Sizing {
        #if os(iOS)
        let availableWidth = min(width, maxBoardWidth)
        let availableHeight = min(height, maxBoardHeight)
        #else
        let availableWidth = width
        let availableHeight = height
        #endif

        // padding 和 cellSize 循环依赖：一步迭代收敛
        let basePadding = min(availableWidth, availableHeight) * 0.04
        let cellSizeEst = min((availableWidth - basePadding * 2) / CGFloat(gridCols),
                              (availableHeight - basePadding * 2) / CGFloat(gridRows),
                              maxCellSize)
        // padding 至少等于棋子半径，防止边缘棋子被裁
        let padding = max(basePadding, cellSizeEst * 0.45)
        // 用最终 padding 重算 cellSize，补偿 padding 增加占用的空间
        let cellSize = min((availableWidth - padding * 2) / CGFloat(gridCols),
                           (availableHeight - padding * 2) / CGFloat(gridRows),
                           maxCellSize)
        let boardWidth = cellSize * CGFloat(gridCols) + padding * 2
        let boardHeight = cellSize * CGFloat(gridRows) + padding * 2

        return Sizing(cellSize: cellSize, padding: padding,
                      boardWidth: boardWidth, boardHeight: boardHeight)
    }

    /// Position → CGPoint（ZStack 内定位）
    /// - Parameter flipped: 翻转视角（执黑时为 true），row 映射为 9 - row
    static func posToCGPoint(_ pos: Position, cellSize: CGFloat, padding: CGFloat, flipped: Bool = false) -> CGPoint {
        let row = flipped ? 9 - pos.row : pos.row
        return CGPoint(
            x: padding + CGFloat(pos.col) * cellSize,
            y: padding + CGFloat(row) * cellSize
        )
    }

    /// CGPoint → Position（交互层点击坐标转换）
    /// - Parameter flipped: 翻转视角时逆映射 row
    static func cgPointToPos(_ point: CGPoint, cellSize: CGFloat, padding: CGFloat, flipped: Bool = false) -> Position? {
        // P2 fix: 坐标在 padding 内侧（半个格以内）返回 nil，避免误判 col=0/row=0
        let halfCell = cellSize / 2
        let adjustedX = point.x - padding
        let adjustedY = point.y - padding

        // 坐标在棋盘外（负方向）
        if adjustedX < -halfCell || adjustedY < -halfCell {
            return nil
        }

        let col = Int(round(adjustedX / cellSize))
        let rowRaw = Int(round(adjustedY / cellSize))
        let row = flipped ? 9 - rowRaw : rowRaw
        guard row >= 0, row <= 9, col >= 0, col <= 8 else { return nil }
        return Position(row: row, col: col)
    }
}
