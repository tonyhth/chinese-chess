import Testing
import Foundation
#if canImport(CoreText)
import CoreText
import CoreGraphics
#endif
@testable import ChineseChess

@Suite("字体测试：霞鹜文楷嵌入与注册")
struct FontTests {

    @Test("字体文件存在于 Resources 目录")
    func fontFileExistsInResources() {
        // 验证 TTF 文件在 Resources 目录
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
        #expect(FontRegistry.fontName == "LXGWWenKai-Regular")
    }

    @Test("字体注册方法存在且可调用")
    func fontRegistryMethodExists() {
        // 验证方法存在，调用不应崩溃
        // 注意：在测试环境中，bundle 可能找不到字体文件，但方法调用应安全
        FontRegistry.registerFonts()
        // 不验证返回值，因为注册可能因环境原因失败
        // 关键是：方法不应抛出异常或崩溃
    }

    @Test("注册后 CTFont 可以按名称加载霞鹜文楷")
    func ctFontCanBeLoadedAfterRegistration() {
        #if canImport(CoreText)
        // 在测试环境中，从 Bundle.module 获取字体 URL 并直接注册
        var registered = false

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
                registered = true
            }
        } else {
            // App bundle fallback
            FontRegistry.registerFonts()
            let testFont = CTFontCreateWithName("LXGWWenKai-Regular" as CFString, 16.0, nil)
            let testName = CTFontCopyName(testFont, kCTFontPostScriptNameKey) as? String ?? ""
            registered = (testName == "LXGWWenKai-Regular")
        }

        if registered {
            // 验证 PostScript Name 加载
            let font = CTFontCreateWithName("LXGWWenKai-Regular" as CFString, 16.0, nil)
            let actualName = CTFontCopyName(font, kCTFontPostScriptNameKey) as? String ?? ""
            #expect(actualName == "LXGWWenKai-Regular",
                    "CTFont PostScript 名称应为 LXGWWenKai-Regular，实际: \(actualName)")
        } else {
            print("[FontTests] 跳过 CTFont 验证：测试 bundle 无法访问字体资源（App 运行时正常）")
            Issue.record("测试 bundle 无法注册字体，CTFont 验证跳过（App 运行时正常）")
        }
        #else
        // 非 Apple 平台跳过
        #endif
    }

    @Test("字体文件大小合理（非空/非截断）")
    func fontFileSizeIsValid() {
        let fm = FileManager.default
        var fontURL: URL?

        if let moduleURL = Bundle.module.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf") {
            fontURL = moduleURL
        } else if let mainURL = Bundle.main.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf") {
            fontURL = mainURL
        }

        guard let url = fontURL else {
            // 字体不在测试 bundle 中——可能是资源未拷贝
            #expect(Bool(false), "无法找到字体文件，无法验证大小")
            return
        }

        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let fileSize = attrs?[.size] as? UInt64 ?? 0
        // LXGWWenKai-Regular.ttf ~24MB，合理下限 1MB
        #expect(fileSize > 1_000_000, "字体文件应大于 1MB，实际: \(fileSize) bytes")
    }

    @Test("棋子显示名称包含中文字符")
    func pieceDisplayNamesAreChinese() {
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