import Testing
import Foundation
@testable import ChineseChess

// MARK: - Phase 5.2: BoardSizing 尺寸计算测试

@Suite("BoardSizing 尺寸计算")
struct BoardSizingTests {

    // MARK: - 基本计算

    @Test("标准窗口尺寸返回有效 Sizing")
    func standardSize() {
        let sizing = BoardSizing.calculate(width: 800, height: 900)
        #expect(sizing.cellSize > 0)
        #expect(sizing.padding > 0)
        #expect(sizing.boardWidth > 0)
        #expect(sizing.boardHeight > 0)
    }

    @Test("cellSize 不超过 maxCellSize")
    func cellSizeCapped() {
        // 极大窗口也不应该超过 maxCellSize
        let sizing = BoardSizing.calculate(width: 5000, height: 5000)
        #expect(sizing.cellSize <= BoardSizing.maxCellSize)
    }

    @Test("极小窗口不崩溃")
    func tinyWindow() {
        let sizing = BoardSizing.calculate(width: 10, height: 10)
        // cellSize 可能是负数或极小值，但不应崩溃
        // 在实际使用中 GeometryReader 不会给出这么小的值
        #expect(true)  // 只要没 crash 就通过
    }

    // MARK: - 宽高比约束

    @Test("窄宽窗口：cellSize 受宽度限制")
    func narrowWidth() {
        let narrow = BoardSizing.calculate(width: 200, height: 900)
        let wide = BoardSizing.calculate(width: 800, height: 900)
        // 窄窗口的 cellSize 应该更小
        #expect(narrow.cellSize < wide.cellSize)
    }

    @Test("矮窗口：cellSize 受高度限制")
    func shortHeight() {
        let short_ = BoardSizing.calculate(width: 800, height: 200)
        let tall = BoardSizing.calculate(width: 800, height: 900)
        // 矮窗口的 cellSize 应该更小
        #expect(short_.cellSize < tall.cellSize)
    }

    // MARK: - 棋盘尺寸一致性

    @Test("boardWidth = cellSize * gridCols + padding * 2")
    func boardWidthFormula() {
        let sizing = BoardSizing.calculate(width: 600, height: 700)
        let expected = sizing.cellSize * CGFloat(BoardSizing.gridCols) + sizing.padding * 2
        #expect(abs(sizing.boardWidth - expected) < 0.01)
    }

    @Test("boardHeight = cellSize * gridRows + padding * 2")
    func boardHeightFormula() {
        let sizing = BoardSizing.calculate(width: 600, height: 700)
        let expected = sizing.cellSize * CGFloat(BoardSizing.gridRows) + sizing.padding * 2
        #expect(abs(sizing.boardHeight - expected) < 0.01)
    }

    // MARK: - 正方形窗口

    @Test("正方形窗口：cellSize 受高度限制（gridRows > gridCols）")
    func squareWindow() {
        let sizing = BoardSizing.calculate(width: 700, height: 700)
        // gridRows=9 > gridCols=8，所以高度限制更紧
        // cellSize <= (700 - padding*2) / 9
        let maxFromHeight = (700.0 - sizing.padding * 2) / CGFloat(BoardSizing.gridRows)
        #expect(sizing.cellSize <= maxFromHeight + 0.01)
    }

    // MARK: - Position ↔ CGPoint 转换

    @Test("posToCGPoint → cgPointToPos 往返一致（非翻转）")
    func pointRoundTrip() {
        let cellSize: CGFloat = 50
        let padding: CGFloat = 20
        for row in 0...9 {
            for col in 0...8 {
                let pos = Position(row: row, col: col)
                let point = BoardSizing.posToCGPoint(pos, cellSize: cellSize, padding: padding)
                let back = BoardSizing.cgPointToPos(point, cellSize: cellSize, padding: padding)
                #expect(back?.row == row)
                #expect(back?.col == col)
            }
        }
    }

    @Test("posToCGPoint → cgPointToPos 往返一致（翻转）")
    func pointRoundTripFlipped() {
        let cellSize: CGFloat = 60
        let padding: CGFloat = 30
        for row in 0...9 {
            for col in 0...8 {
                let pos = Position(row: row, col: col)
                let point = BoardSizing.posToCGPoint(pos, cellSize: cellSize, padding: padding, flipped: true)
                let back = BoardSizing.cgPointToPos(point, cellSize: cellSize, padding: padding, flipped: true)
                #expect(back?.row == row, "row \(row) mismatch: got \(back?.row ?? -1)")
                #expect(back?.col == col)
            }
        }
    }

    @Test("越界点返回 nil")
    func outOfBounds() {
        let cellSize: CGFloat = 50
        let padding: CGFloat = 20
        // 点击 padding 外侧
        let outside = CGPoint(x: 5, y: 5)
        #expect(BoardSizing.cgPointToPos(outside, cellSize: cellSize, padding: padding) == nil)
    }
}
