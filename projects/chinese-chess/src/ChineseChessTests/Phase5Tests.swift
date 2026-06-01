import Testing
import Foundation

@testable import ChineseChess

// MARK: - BoardTheme 测试

@Suite("BoardTheme Tests")
struct BoardThemeTests {

    @Test("主题枚举数量")
    func testThemeCount() {
        #expect(BoardTheme.allCases.count == 2)
    }

    @Test("主题显示名非空")
    func testThemeDisplayNames() {
        for theme in BoardTheme.allCases {
            #expect(!theme.displayName.isEmpty)
        }
    }

    @Test("每种主题生成有效颜色配置")
    func testThemeColorsValid() {
        for theme in BoardTheme.allCases {
            let colors = ThemeColors.forTheme(theme)
            #expect(colors.boardBackground.count == 3)
            #expect(colors.pieceFill.count == 3)
        }
    }

    @Test("两个主题颜色有差异")
    func testThemesDiffer() {
        let classic = ThemeColors.forTheme(.classicWood)
        let ink = ThemeColors.forTheme(.inkStone)
        #expect(classic.redPieceText != ink.redPieceText)
        #expect(classic.appBackground != ink.appBackground)
    }
}

// MARK: - ThemeManager 测试

@Suite("ThemeManager Tests")
struct ThemeManagerTests {

    @Test("默认主题是经典木纹")
    func testDefaultTheme() {
        let manager = ThemeManager.shared
        #expect(manager.currentTheme == .classicWood)
    }

    @Test("切换主题后 colors 更新")
    func testThemeSwitch() {
        let manager = ThemeManager.shared
        let original = manager.currentTheme

        manager.currentTheme = .inkStone
        let inkColors = ThemeColors.forTheme(.inkStone)
        #expect(manager.colors == inkColors)

        // 恢复
        manager.currentTheme = original
    }

    @Test("主题序列化 roundtrip")
    func testThemeCodable() {
        for theme in BoardTheme.allCases {
            let encoded = try? JSONEncoder().encode(theme)
            #expect(encoded != nil)
            if let encoded {
                let decoded = try? JSONDecoder().decode(BoardTheme.self, from: encoded)
                #expect(decoded == theme)
            }
        }
    }
}

// MARK: - SoundEngine 扩展测试

@Suite("SoundEngine v2 Tests")
struct SoundEngineV2Tests {

    @Test("所有音效方法不崩溃")
    func testAllSoundMethods() {
        let engine = SoundEngine.shared
        // 确保静音，不实际播放
        engine.isMuted = true

        // v1.0
        engine.playMove()
        engine.playCapture()

        // v2.0 新增
        engine.playCheck()
        engine.playCheckmate()
        engine.playUndo()
        engine.playVictory()
        engine.playDefeat()

        // 没有崩溃即通过
        #expect(true)
    }

    @Test("静音状态")
    func testMuteState() {
        let engine = SoundEngine.shared
        engine.isMuted = true
        #expect(engine.isMuted)
        engine.isMuted = false
        #expect(!engine.isMuted)
    }
}

// MARK: - 主题切换集成测试

@Suite("Theme Integration Tests")
struct ThemeIntegrationTests {

    @Test("BoardView 在两个主题下均能构建棋盘")
    func testBoardWithBothThemes() {
        for theme in BoardTheme.allCases {
            let colors = ThemeColors.forTheme(theme)
            // 验证颜色值合理（非零/非透明）
            #expect(colors.boardBackground.allSatisfy { $0 != .clear })
            #expect(colors.lineColor != .clear)
            #expect(colors.redPieceText != .clear)
            #expect(colors.blackPieceText != .clear)
            #expect(colors.pieceFill.allSatisfy { $0 != .clear })
        }
    }

    @Test("标准开局在两个主题下棋子颜色正确")
    func testPieceColorsInBothThemes() {
        let board = Board()
        for theme in BoardTheme.allCases {
            let colors = ThemeColors.forTheme(theme)
            let redPiece = board.pieces.first { $0.side == .red }
            let blackPiece = board.pieces.first { $0.side == .black }
            #expect(redPiece != nil)
            #expect(blackPiece != nil)
            #expect(colors.redPieceText != colors.blackPieceText)
        }
    }
}
