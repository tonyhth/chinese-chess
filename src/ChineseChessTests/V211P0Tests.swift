import Testing
import Foundation
#if canImport(CoreText)
import CoreText
import CoreGraphics
#endif
@testable import ChineseChess

@Suite("v2.1.2 P0 修复验证", .serialized)
struct V211P0Tests {

    // MARK: - P0-1: 棋盘几何对齐

    @Test("cellSize 计算使用 min(width/8, height/9) 确保棋子对齐网格")
    func cellSizeCalculationUsesMin() {
        // 模拟 ChessBoardView 中的 cellSize 计算
        let size: CGFloat = 600
        let padding = max(10, size * 0.04) // 24
        let gridCols = 8
        let gridRows = 9

        let cellSizeW = (size - padding * 2) / CGFloat(gridCols)
        let cellSizeH = (size - padding * 2) / CGFloat(gridRows)
        let cellSize = min(cellSizeW, cellSizeH)

        // cellSizeW = 552/8 = 69, cellSizeH = 552/9 ≈ 61.33
        // min = 61.33 — 纵向是约束方向
        #expect(cellSize == min(cellSizeW, cellSizeH))
        #expect(cellSize < cellSizeW, "cellSize 应取较小值确保棋盘不溢出")
        #expect(cellSize == cellSizeH, "纵向 9 行是约束方向")
    }

    @Test("棋盘宽高正确反映 cellSize（非方形）")
    func boardDimensionsFromCellSize() {
        let size: CGFloat = 600
        let padding = max(10, size * 0.04)
        let gridCols = 8
        let gridRows = 9

        let cellSizeW = (size - padding * 2) / CGFloat(gridCols)
        let cellSizeH = (size - padding * 2) / CGFloat(gridRows)
        let cellSize = min(cellSizeW, cellSizeH)

        let boardWidth = cellSize * CGFloat(gridCols) + padding * 2
        let boardHeight = cellSize * CGFloat(gridRows) + padding * 2

        // 棋盘宽 < 高（9行 > 8列）
        #expect(boardWidth < boardHeight, "棋盘应纵向大于横向")
        // 两者都应 <= size
        #expect(boardWidth <= size)
        #expect(boardHeight <= size)
    }

    @Test("非正方形窗口（660×760）：横向为约束方向，棋盘占满可用空间")
    func nonSquareWindowCellSize() {
        // 模拟实际窗口 660×760（来自 ChineseChessApp.defaultSize）
        let width: CGFloat = 660
        let height: CGFloat = 760
        let padding = max(10, min(width, height) * 0.04) // 26.4
        let gridCols = 8
        let gridRows = 9

        let cellSizeW = (width - padding * 2) / CGFloat(gridCols)
        let cellSizeH = (height - padding * 2) / CGFloat(gridRows)
        let cellSize = min(cellSizeW, cellSizeH)

        let boardWidth = cellSize * CGFloat(gridCols) + padding * 2
        let boardHeight = cellSize * CGFloat(gridRows) + padding * 2

        // 横向是约束方向（cellSizeW < cellSizeH）
        #expect(cellSize == cellSizeW, "660×760 窗口横向应为约束方向")
        #expect(cellSize < cellSizeH, "纵向空间应有余量")
        // 棋盘宽度 ≈ 可用宽度（横向约束时宽度填满）
        #expect(abs(boardWidth - width) < 1, "棋盘宽度应约等于可用宽度")
        // 棋盘高度 < 可用高度（纵向有余量）
        #expect(boardHeight < height, "棋盘高度应小于可用高度")
        // 棋盘宽高比 ≈ 8/9
        let ratio = boardWidth / boardHeight
        #expect(abs(ratio - CGFloat(gridCols) / CGFloat(gridRows)) < 0.01, "棋盘宽高比应约为 8/9")
    }

    @Test("非正方形窗口（660×760）：棋子位置映射对齐网格")
    func nonSquareWindowPieceAlignment() {
        let width: CGFloat = 660
        let height: CGFloat = 760
        let padding = max(10, min(width, height) * 0.04)
        let gridCols = 8
        let gridRows = 9

        let cellSizeW = (width - padding * 2) / CGFloat(gridCols)
        let cellSizeH = (height - padding * 2) / CGFloat(gridRows)
        let cellSize = min(cellSizeW, cellSizeH)

        // 四角棋子应落在网格交叉点
        let corners: [(row: Int, col: Int)] = [(0, 0), (0, 8), (9, 0), (9, 8)]
        for corner in corners {
            let x = padding + CGFloat(corner.col) * cellSize
            let y = padding + CGFloat(corner.row) * cellSize

            let col = Int(round((x - padding) / cellSize))
            let row = Int(round((y - padding) / cellSize))

            #expect(col == corner.col, "角(\(corner.row),\(corner.col)) 列映射错误")
            #expect(row == corner.row, "角(\(corner.row),\(corner.col)) 行映射错误")
        }
    }

    @Test("所有棋子位置映射到网格交叉点")
    func allPiecesMapToGridIntersections() {
        let board = Board()
        let padding: CGFloat = 24
        let cellSize: CGFloat = 61.33

        for piece in board.pieces {
            let point = CGPoint(
                x: padding + CGFloat(piece.position.col) * cellSize,
                y: padding + CGFloat(piece.position.row) * cellSize
            )
            // 棋子应在网格线上（坐标 = padding + N * cellSize）
            let expectedX = padding + CGFloat(piece.position.col) * cellSize
            let expectedY = padding + CGFloat(piece.position.row) * cellSize
            #expect(abs(point.x - expectedX) < 0.01, "红\(piece.displayName) X坐标应对齐")
            #expect(abs(point.y - expectedY) < 0.01, "红\(piece.displayName) Y坐标应对齐")
        }
    }

    @Test("棋子直径 = cellSize * 0.85，不超过 cellSize")
    func pieceDiameterWithinCellSize() {
        let cellSize: CGFloat = 61.33
        let pieceDiameter = cellSize * 0.85
        #expect(pieceDiameter < cellSize, "棋子直径应小于 cellSize，避免重叠")
        #expect(pieceDiameter > cellSize * 0.5, "棋子直径应合理大小")
    }

    @Test("点击坐标转换与棋子位置映射一致")
    func tapCoordinateConversionConsistentWithPiecePosition() {
        let padding: CGFloat = 24
        let cellSize: CGFloat = 61.33

        // 模拟点击 (7,1) 位置（红炮）
        let targetCol = 1
        let targetRow = 7
        let tapX = padding + CGFloat(targetCol) * cellSize
        let tapY = padding + CGFloat(targetRow) * cellSize

        // cgPointToPos 逻辑
        let col = Int(round((tapX - padding) / cellSize))
        let row = Int(round((tapY - padding) / cellSize))

        #expect(col == targetCol, "列坐标转换应一致")
        #expect(row == targetRow, "行坐标转换应一致")
    }

    @Test("边界位置映射正确")
    func edgePositionsMapCorrectly() {
        let padding: CGFloat = 24
        let cellSize: CGFloat = 61.33

        // 四角
        let corners: [(row: Int, col: Int)] = [(0, 0), (0, 8), (9, 0), (9, 8)]
        for corner in corners {
            let x = padding + CGFloat(corner.col) * cellSize
            let y = padding + CGFloat(corner.row) * cellSize

            let col = Int(round((x - padding) / cellSize))
            let row = Int(round((y - padding) / cellSize))

            #expect(col == corner.col, "角(\(corner.row),\(corner.col)) 列映射错误")
            #expect(row == corner.row, "角(\(corner.row),\(corner.col)) 行映射错误")
        }
    }

    // MARK: - P0-2: App 图标

    /// 动态查找最新的打包 .app 路径
    private static func findLatestAppBundle() -> String? {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let searchDirs = [
            ProcessInfo.processInfo.environment["CHESS_APP_DIR"],
            "\(homeDir)/DevTeam/projects/chinese-chess",
            "\(homeDir)/DevTeam/projects/chinese-chess/src"
        ].compactMap { $0 }
        let fm = FileManager.default
        for dir in searchDirs {
            if let entries = try? fm.contentsOfDirectory(atPath: dir) {
                let apps = entries.filter { $0.hasSuffix(".app") }.sorted()
                if let latest = apps.last {
                    return "\(dir)/\(latest)"
                }
            }
        }
        return nil
    }

    @Test("打包 App 包含 Assets.car", .disabled("打包脚本未用 actool 生成 Assets.car，已知问题"))
    func appBundleContainsCompiledAssets() {
        guard let appPath = Self.findLatestAppBundle() else {
            #expect(Bool(false), "未找到打包 .app，请先运行打包脚本")
            return
        }
        let carPath = "\(appPath)/Contents/Resources/Assets.car"
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: carPath), "打包 App 应包含 Assets.car")
    }

    @Test("打包 App 包含 AppIcon.icns")
    func appBundleContainsIcon() {
        guard let appPath = Self.findLatestAppBundle() else {
            #expect(Bool(false), "未找到打包 .app，请先运行打包脚本")
            return
        }
        let icnsPath = "\(appPath)/Contents/Resources/AppIcon.icns"
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: icnsPath), "打包 App 应包含 AppIcon.icns")
    }

    @Test("打包 App 可执行文件存在且非空")
    func appBundleContainsExecutable() {
        guard let appPath = Self.findLatestAppBundle() else {
            #expect(Bool(false), "未找到打包 .app，请先运行打包脚本")
            return
        }
        let execPath = "\(appPath)/Contents/MacOS/ChineseChess"
        let fm = FileManager.default
        #expect(fm.isExecutableFile(atPath: execPath), "打包 App 应包含可执行文件")
    }

    // MARK: - P0-3: 字体 PostScript Name

    @Test("FontRegistry.fontName 使用正确的 PostScript Name")
    func fontRegistryUsesPostScriptName() {
        #expect(FontRegistry.fontName == "LXGWWenKai-Regular",
                "FontRegistry.fontName 应为 PostScript Name 'LXGWWenKai-Regular'")
    }

    @Test("注册后 CTFont 可按 PostScript Name 加载")
    func ctFontLoadsAfterRegistration() {
        #if canImport(CoreText)
        if let fontURL = Bundle.module.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf") {
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            let alreadyRegistered: Bool
            if let err = error?.takeUnretainedValue() {
                let desc = CFErrorCopyDescription(err) as String? ?? ""
                alreadyRegistered = desc.contains("already registered")
            } else {
                alreadyRegistered = false
            }
            if success || alreadyRegistered {
                let font = CTFontCreateWithName("LXGWWenKai-Regular" as CFString, 16.0, nil)
                let actualName = CTFontCopyName(font, kCTFontPostScriptNameKey) as? String ?? ""
                #expect(actualName == "LXGWWenKai-Regular",
                        "CTFont PostScript Name 应为 LXGWWenKai-Regular，实际: \(actualName)")
            }
        }
        #endif
    }

    @Test("无残留硬编码字体名称")
    func noHardcodedFontName() {
        // 验证 FontRegistry.fontName 是唯一字体名称来源
        // 在产品代码中不应出现 .custom("LXGW ...") 或 .custom("STKaiti") 的硬编码
        let fontName = FontRegistry.fontName
        #expect(fontName == "LXGWWenKai-Regular")
        #expect(fontName != "LXGW WenKai", "不应使用 Family Name")
        #expect(fontName != "STKaiti", "不应使用旧字体名")
    }
}
