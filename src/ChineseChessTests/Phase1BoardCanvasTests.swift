import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 1: BoardCanvasView 提取 + 两个棋盘视图重写测试

@Suite("Phase 1: BoardCanvasView 提取 + 棋盘视图重写", .serialized)
@MainActor
struct Phase1BoardCanvasTests {

    let srcRoot: String = "\(ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess"

    // MARK: - BoardCanvasView 存在性与结构

    @Test("BoardCanvasView.swift 存在且为独立 View")
    func boardCanvasViewExists() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("BoardCanvasView.swift 不存在"); return
        }
        #expect(content.contains("struct BoardCanvasView: View"))
    }

    @Test("BoardCanvasView 接收 board, lastMove, isFlipped, theme 四个参数")
    func boardCanvasViewParameters() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("let board: Board"))
        #expect(content.contains("let lastMove: (from: Position, to: Position)?"))
        #expect(content.contains("let isFlipped: Bool"))
        #expect(content.contains("var theme: ThemeColors"))
    }

    @Test("BoardCanvasView 包含完整渲染逻辑：背景、线条、楚河汉界、星位、高亮、棋子")
    func boardCanvasViewFullRendering() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        // 棋盘背景
        #expect(content.contains("LinearGradient"), "应有棋盘背景 LinearGradient")
        #expect(content.contains("boardBackground"), "应使用 theme.boardBackground")
        // 格线 Canvas
        #expect(content.contains("drawBoardLines"), "应绘制棋盘线条")
        // 楚河汉界
        #expect(content.contains("riverText"), "应有楚河汉界文字")
        #expect(content.contains("楚  河"), "应包含楚河")
        #expect(content.contains("汉  界"), "应包含汉界")
        // 星位标记
        #expect(content.contains("drawStarMarks"), "应有星位标记")
        // lastMove 高亮
        #expect(content.contains("lastMove"), "应高亮上一步")
        #expect(content.contains("Color.yellow"), "from 高亮应为黄色")
        #expect(content.contains("Color.green"), "to 高亮应为绿色")
        // 棋子
        #expect(content.contains("PieceView"), "应使用 PieceView 渲染棋子")
    }

    @Test("BoardCanvasView 使用 BoardSizing 统一尺寸计算")
    func boardCanvasViewUsesBoardSizing() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("BoardSizing.calculate"), "应使用 BoardSizing.calculate")
        #expect(content.contains("BoardSizing.posToCGPoint"), "应使用 BoardSizing.posToCGPoint")
    }

    @Test("BoardCanvasView 九宫斜线正确绘制")
    func boardCanvasViewPalaceDiagonals() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("drawPalaceDiagonals"), "应有九宫斜线绘制方法")
        // 两个九宫：(0,3) 和 (7,3)
        #expect(content.contains("startRow: 0, startCol: 3"), "应有上方九宫")
        #expect(content.contains("startRow: 7, startCol: 3"), "应有下方九宫")
    }

    @Test("BoardCanvasView 星位标记覆盖炮位和兵位")
    func boardCanvasViewStarMarksPositions() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        // 炮位：(2,1), (2,7), (7,1), (7,7)
        #expect(content.contains("cannonPositions"))
        // 兵位：6 个红兵 + 6 个黑卒
        #expect(content.contains("soldierPositions"))
    }

    @Test("BoardCanvasView 棋子有 spring 动画")
    func boardCanvasViewPieceAnimation() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains(".spring(response: 0.3, dampingFraction: 0.8)"), "棋子应有 spring 动画")
    }

    @Test("BoardCanvasView 棋子 allowsHitTesting(false)")
    func boardCanvasViewPiecesNonInteractive() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("allowsHitTesting(false)"), "棋子应禁用交互")
    }

    @Test("BoardCanvasView lastMove 高亮使用黄色和绿色 Circle")
    func boardCanvasViewLastMoveHighlightColors() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        // 在 renderOverlays 中查找黄色和绿色
        let overlaySection = content.components(separatedBy: "renderOverlays").dropFirst().joined()
        #expect(overlaySection.contains("Color.yellow"), "应有黄色高亮（from）")
        #expect(overlaySection.contains("Color.green"), "应有绿色高亮（to）")
    }

    @Test("BoardCanvasView 阴影效果")
    func boardCanvasViewShadow() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains(".shadow("), "应有阴影效果")
    }

    @Test("BoardCanvasView 使用 FontRegistry 字体渲染楚河汉界")
    func boardCanvasViewRiverFont() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("FontRegistry.bestAvailableFontName"), "楚河汉界应使用 FontRegistry 字体")
    }

    // MARK: - ReplayBoardView 薄壳验证

    @Test("ReplayBoardView 是 BoardCanvasView 的薄壳")
    func replayBoardViewIsThinShell() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains("BoardCanvasView("), "应调用 BoardCanvasView")
    }

    @Test("ReplayBoardView 传递 board, lastMove, isFlipped, theme 给 BoardCanvasView")
    func replayBoardViewPassesParameters() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains("board: viewModel.board"), "应传递 board")
        #expect(content.contains("lastMove: viewModel.lastMove"), "应传递 lastMove")
        #expect(content.contains("isFlipped: isFlipped"), "应传递 isFlipped")
        #expect(content.contains("theme: theme"), "应传递 theme")
    }

    @Test("ReplayBoardView 有翻转动画（spring）")
    func replayBoardViewFlipAnimation() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains(".animation(.spring"), "应有 spring 动画")
        #expect(content.contains("value: isFlipped"), "动画应绑定 isFlipped")
    }

    @Test("ReplayBoardView 仍直接持有 ReplayViewModel")
    func replayBoardViewStillHasViewModel() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        #expect(content.contains("let viewModel: ReplayViewModel"))
    }

    @Test("ReplayBoardView 不再包含内联渲染代码")
    func replayBoardViewNoInlineRendering() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift"); return
        }
        let nonCommentLines = content.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix(" *") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        // 薄壳应该很短（< 20 行非空非注释代码）
        #expect(nonCommentLines.count < 20, "ReplayBoardView 应为薄壳，代码行数应 < 20，实际 \(nonCommentLines.count)")
    }

    // MARK: - DemoBoardView 薄壳验证

    @Test("DemoBoardView 是 BoardCanvasView 的薄壳")
    func demoBoardViewIsThinShell() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        #expect(content.contains("BoardCanvasView("), "应调用 BoardCanvasView")
    }

    @Test("DemoBoardView 传递 board, lastMove, isFlipped, theme 给 BoardCanvasView")
    func demoBoardViewPassesParameters() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        #expect(content.contains("board: board"), "应传递 board")
        #expect(content.contains("lastMove: lastMove"), "应传递 lastMove")
        #expect(content.contains("isFlipped: isFlipped"), "应传递 isFlipped")
        #expect(content.contains("theme: theme"), "应传递 theme")
    }

    @Test("DemoBoardView 无翻转动画")
    func demoBoardViewNoFlipAnimation() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        #expect(!content.contains(".animation("), "DemoBoardView 不应有翻转动画")
    }

    @Test("DemoBoardView theme 为显式参数（非计算属性）")
    func demoBoardViewThemeIsExplicitParameter() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        // 旧版：private var theme: ThemeColors { ThemeManager.shared.colors }
        // 新版：var theme: ThemeColors = ThemeManager.shared.colors
        #expect(content.contains("var theme: ThemeColors = ThemeManager.shared.colors"),
               "theme 应为显式参数，带默认值")
        #expect(!content.contains("private var theme: ThemeColors {"), "不应为计算属性")
    }

    @Test("DemoBoardView 不再包含内联渲染代码")
    func demoBoardViewNoInlineRendering() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        // 旧版有 boardCanvas, boardGrid, lastMoveHighlights, piecesLayer 等方法
        #expect(!content.contains("boardCanvas("), "不应有内联 boardCanvas 方法")
        #expect(!content.contains("boardGrid("), "不应有内联 boardGrid 方法")
        #expect(!content.contains("piecesLayer("), "不应有内联 piecesLayer 方法")
        #expect(!content.contains("lastMoveHighlights("), "不应有内联 lastMoveHighlights 方法")
    }

    // MARK: - 渲染一致性：BoardCanvasView 复用 ReplayBoardView 原有逻辑

    @Test("BoardCanvasView 的线条绘制与原 ReplayBoardView 一致（横线10条+竖线上下半+边线+九宫）")
    func boardCanvasViewLineConsistency() {
        guard let canvasContent = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        // 横线：0...gridRows（10 条）
        #expect(canvasContent.contains("0...BoardSizing.gridRows"), "应有 10 条横线")
        // 竖线上半：0...gridCols（9 条），到 4*cellSize
        #expect(canvasContent.contains("4 * cellSize"), "竖线应断在河界（第4行）")
        // 竖线下半：5*cellSize 到 9*cellSize
        #expect(canvasContent.contains("5 * cellSize"), "竖线应从河界下方（第5行）开始")
        #expect(canvasContent.contains("9 * cellSize"), "竖线应到第9行")
    }

    @Test("BoardCanvasView 的坐标映射使用 BoardSizing.posToCGPoint（与 ChessBoardView 一致）")
    func boardCanvasViewCoordinateMapping() {
        guard let canvasContent = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(canvasContent.contains("BoardSizing.posToCGPoint"), "坐标映射应委托给 BoardSizing")
    }

    // MARK: - 调用方不受影响

    @Test("ReplayView 仍使用 ReplayBoardView(viewModel:)")
    func replayViewStillUsesReplayBoardView() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        #expect(content.contains("ReplayBoardView(viewModel:"))
    }

    @Test("PuzzleDemoView 使用 DemoBoardView")
    func puzzleDemoViewUsesDemoBoardView() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/PuzzleDemoView.swift") else {
            Issue.record("无法读取 PuzzleDemoView.swift"); return
        }
        #expect(content.contains("DemoBoardView("), "PuzzleDemoView 应使用 DemoBoardView")
    }

    @Test("AnalysisView 使用 ReplayBoardView")
    func analysisViewUsesReplayBoardView() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/AnalysisView.swift") else {
            Issue.record("无法读取 AnalysisView.swift"); return
        }
        #expect(content.contains("ReplayBoardView("), "AnalysisView 应使用 ReplayBoardView")
    }

    @Test("CoachSessionView 使用 ReplayBoardView")
    func coachSessionViewUsesReplayBoardView() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/CoachSessionView.swift") else {
            Issue.record("无法读取 CoachSessionView.swift"); return
        }
        #expect(content.contains("ReplayBoardView("), "CoachSessionView 应使用 ReplayBoardView")
    }

    // MARK: - BoardCanvasView lastMove 为 nil 时不崩溃

    @Test("BoardCanvasView body 中 lastMove 为 nil 时不渲染高亮 Circle")
    func boardCanvasViewLastMoveNilSafe() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        // 应有 if let last = lastMove 保护
        #expect(content.contains("if let last = lastMove"), "lastMove 应为可选安全解包")
    }

    // MARK: - BoardCanvasView 空 Board 安全

    @Test("BoardCanvasView 对 Board 的 pieces 数组使用 ForEach 安全遍历")
    func boardCanvasViewBoardPiecesSafe() {
        // Board() 有默认初始布局（32颗棋子），ForEach 能安全遍历
        let board = Board()
        #expect(!board.pieces.isEmpty, "默认 Board 应有棋子")
        // 确认每个 piece 都有 id（ForEach 要求 Identifiable）
        for piece in board.pieces {
            _ = piece.id
        }
        // 如果需要真正空的棋盘，通过 FEN 创建
        let emptyFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let emptyBoard = Board(fen: emptyFEN)
        // 只有两颗将帅
        #expect(emptyBoard.pieces.count == 2, "极简 Board 应只有将帅")
    }

    // MARK: - 翻转行为一致性

    @Test("BoardCanvasView 使用 isFlipped 参数控制翻转（与 BoardSizing.posToCGPoint 一致）")
    func boardCanvasViewFlipConsistency() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        // posToCGPoint 应传递 flipped: isFlipped
        #expect(content.contains("flipped: isFlipped"), "坐标映射应传递 isFlipped")
    }

    // MARK: - 旧测试兼容性：渲染组件存在于 BoardCanvasView

    @Test("BoardCanvasView 包含 Rectangle + LinearGradient（原 V2218 测试迁移）")
    func boardCanvasViewHasBackground() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("Rectangle"), "应有 Rectangle 背景")
        #expect(content.contains("LinearGradient"), "应有 LinearGradient 背景")
    }

    @Test("BoardCanvasView 包含 allowsHitTesting(false)（原 V2218 测试迁移）")
    func boardCanvasViewHasAllowsHitTesting() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/BoardCanvasView.swift") else {
            Issue.record("无法读取 BoardCanvasView.swift"); return
        }
        #expect(content.contains("allowsHitTesting(false)"), "棋子应禁用交互")
    }

    // MARK: - DemoBoardView 视觉升级确认

    @Test("DemoBoardView 不再使用 Text 棋子（已升级为 PieceView）")
    func demoBoardViewNoTextPieces() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        // 旧版使用 Text(piece.displayName)，新版委托给 BoardCanvasView 使用 PieceView
        #expect(!content.contains("piece.displayName"), "不应直接使用 Text 棋子")
    }

    @Test("DemoBoardView 不再使用自定义坐标计算（已统一为 BoardSizing）")
    func demoBoardViewNoCustomCoordinates() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/DemoBoardView.swift") else {
            Issue.record("无法读取 DemoBoardView.swift"); return
        }
        // 旧版用 boardSize / 10 等自定义计算
        #expect(!content.contains("boardSize / 10"), "不应有自定义坐标计算")
        #expect(!content.contains("boardSize * 8 / 9"), "不应有自定义宽度计算")
    }
}
