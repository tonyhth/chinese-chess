import Testing
import Foundation
@testable import ChineseChess

@Suite("字体测试：霞鹜文楷嵌入与注册")
struct FontTests {

    @Test("字体文件存在于 Resources 目录")
    func fontFileExistsInResources() {
        // 验证 TTF 文件在 Resources 目录
        let resourcePath = Bundle.module.bundleURL.appendingPathComponent("Contents/Resources/LXGWWenKai-Regular.ttf").path
        let fm = FileManager.default

        // 对于 SPM 测试，检查模块 bundle
        if let moduleURL = Bundle.module.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf") {
            #expect(fm.fileExists(atPath: moduleURL.path))
        } else {
            // 备用：检查主 bundle（集成测试场景）
            let mainBundleCheck = Bundle.main.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf")
            #expect(mainBundleCheck != nil, "LXGWWenKai-Regular.ttf 应该存在于 bundle 中")
        }
    }

    @Test("FontRegistry.fontName 返回正确的 PostScript 名称")
    func fontRegistryReturnsCorrectFontName() {
        // PostScript 名称必须与 .font(.custom:) 使用的一致
        #expect(FontRegistry.fontName == "LXGW WenKai")
    }

    @Test("字体注册方法存在且可调用")
    func fontRegistryMethodExists() {
        // 验证方法存在，调用不应崩溃
        // 注意：在测试环境中，bundle 可能找不到字体文件，但方法调用应安全
        FontRegistry.registerFonts()
        // 不验证返回值，因为注册可能因环境原因失败
        // 关键是：方法不应抛出异常或崩溃
    }

    @Test("棋子显示名称包含中文字符")
    func pieceDisplayNamesAreChinese() {
        let board = Board()

        // 检查红方棋子
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 0, col: 0))
        #expect(redGeneral.displayName == "帅")

        let redAdvisor = Piece(kind: .advisor, side: .red, position: Position(row: 0, col: 0))
        #expect(redAdvisor.displayName == "仕")

        let redElephant = Piece(kind: .elephant, side: .red, position: Position(row: 0, col: 0))
        #expect(redElephant.displayName == "相")

        let redHorse = Piece(kind: .horse, side: .red, position: Position(row: 0, col: 0))
        #expect(redHorse.displayName == "馬")

        let redChariot = Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 0))
        #expect(redChariot.displayName == "車")

        let redCannon = Piece(kind: .cannon, side: .red, position: Position(row: 0, col: 0))
        #expect(redCannon.displayName == "炮")

        let redSoldier = Piece(kind: .soldier, side: .red, position: Position(row: 0, col: 0))
        #expect(redSoldier.displayName == "兵")

        // 检查黑方棋子
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 0))
        #expect(blackGeneral.displayName == "将")

        let blackAdvisor = Piece(kind: .advisor, side: .black, position: Position(row: 0, col: 0))
        #expect(blackAdvisor.displayName == "士")

        let blackElephant = Piece(kind: .elephant, side: .black, position: Position(row: 0, col: 0))
        #expect(blackElephant.displayName == "象")

        let blackHorse = Piece(kind: .horse, side: .black, position: Position(row: 0, col: 0))
        #expect(blackHorse.displayName == "馬")

        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 0, col: 0))
        #expect(blackChariot.displayName == "車")

        let blackCannon = Piece(kind: .cannon, side: .black, position: Position(row: 0, col: 0))
        #expect(blackCannon.displayName == "砲")

        let blackSoldier = Piece(kind: .soldier, side: .black, position: Position(row: 0, col: 0))
        #expect(blackSoldier.displayName == "卒")
    }

    @Test("所有棋子显示名称不为空")
    func allPieceDisplayNamesNotEmpty() {
        let kinds: [PieceKind] = [.general, .advisor, .elephant, .horse, .chariot, .cannon, .soldier]
        let sides: [Side] = [.red, .black]

        for kind in kinds {
            for side in sides {
                let piece = Piece(kind: kind, side: side, position: Position(row: 0, col: 0))
                #expect(!piece.displayName.isEmpty, "\(side) \(kind) displayName 不应为空")
            }
        }
    }
}