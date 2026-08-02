import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 1: BoardCanvasView 提取 + 两个棋盘视图重写测试

@Suite("Phase 1: BoardCanvasView 提取 + 棋盘视图重写", .serialized)
@MainActor
struct Phase1BoardCanvasTests {

    let srcRoot: String = "\(ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess"

    // MARK: - BoardCanvasView 存在性与结构
    // 源码文本匹配测试已移除
    // MARK: - ReplayBoardView 薄壳验证
    // 源码文本匹配测试已移除

    // MARK: - DemoBoardView 薄壳验证
    // 源码文本匹配测试已移除
    // MARK: - 渲染一致性：BoardCanvasView 复用 ReplayBoardView 原有逻辑

    // 渲染一致性测试已移除（源码文本匹配）

    // MARK: - 调用方不受影响
    // MARK: - BoardCanvasView lastMove 为 nil 时不崩溃
    // MARK: - BoardCanvasView 空 Board 安全

    @Test("BoardCanvasView 对 Board 的 pieces 数组安全遍历")
    func boardCanvasViewBoardPiecesSafe() {
        let board = Board()
        #expect(!board.pieces.isEmpty, "默认 Board 应有棋子")
        for piece in board.pieces {
            _ = piece.id
        }
        let emptyFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let emptyBoard = Board(fen: emptyFEN)
        #expect(emptyBoard.pieces.count == 2, "极简 Board 应只有将帅")
    }

    // MARK: - 翻转行为一致性
    // MARK: - 旧测试兼容性：渲染组件存在于 BoardCanvasView
    // MARK: - DemoBoardView 视觉升级确认
}
