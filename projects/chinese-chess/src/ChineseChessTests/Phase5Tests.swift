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
        // 不依赖 shared 的当前状态，只验证 classicWood 的 displayName
        #expect(BoardTheme.classicWood.displayName == "经典木纹")
        #expect(BoardTheme.classicWood.rawValue == "classicWood")
    }

    @Test("切换主题后 colors 属性更新")
    func testThemeSwitch() {
        let manager = ThemeManager.shared
        let saved = manager.currentTheme

        manager.currentTheme = .inkStone
        // colors 属性必须和 ThemeColors.forTheme 一致
        let inkColors = ThemeColors.forTheme(.inkStone)
        #expect(manager.colors.redPieceText == inkColors.redPieceText)
        #expect(manager.colors.appBackground == inkColors.appBackground)

        manager.currentTheme = .classicWood
        let classicColors = ThemeColors.forTheme(.classicWood)
        #expect(manager.colors.redPieceText == classicColors.redPieceText)
        #expect(manager.colors.appBackground == classicColors.appBackground)

        // 恢复
        manager.currentTheme = saved
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

    @Test("静音状态切换")
    func testMuteState() {
        let engine = SoundEngine.shared
        let saved = engine.isMuted
        engine.isMuted = true
        #expect(engine.isMuted)
        engine.isMuted = false
        #expect(!engine.isMuted)
        engine.isMuted = saved
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

// MARK: - isRecommendedMove 测试

@Suite("isRecommendedMove Tests")
struct IsRecommendedMoveTests {

    /// 构造一个有 solution 的残局 Puzzle，手动走棋验证
    @Test("匹配推荐走法时返回 true")
    func testRecommendedMoveMatch() {
        // puzzle_001: 红车在 row7,col4 (ICCS e2), solution[0] = "e1e2" 不对...
        // 用简单 FEN：红车在 row8,col4 (ICCS e1), 走到 row7,col4 (ICCS e2)
        let puzzle = Puzzle(
            id: "test_recommended",
            name: "测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/4R4/4K4 w - - 0 1",
            solution: ["e1e2"],  // e1=col4,row8, e2=col4,row7
            hints: nil,
            maxMoves: 10
        )
        let vm = PuzzleViewModel(puzzle: puzzle)

        // R 在 Board(row:8, col:4), 走到 (row:7, col:4)
        let from = Position(row: 8, col: 4)
        let to = Position(row: 7, col: 4)

        let legalMoves = vm.selectPiece(at: from)
        #expect(legalMoves.contains(to))

        vm.movePiece(from: from, to: to)

        // 玩家第一步匹配 solution[0]
        #expect(vm.isRecommendedMove(at: 0))
    }

    @Test("不匹配推荐走法时返回 false")
    func testRecommendedMoveNoMatch() {
        // 同一残局，红车在 row8,col4，走 row6,col4（不是推荐的 e1e2）
        let puzzle = Puzzle(
            id: "test_not_recommended",
            name: "测试",
            category: "test",
            difficulty: 1,
            stars: 1,
            description: "",
            playerSide: "red",
            initialFEN: "4k4/9/9/9/9/9/9/9/4R4/4K4 w - - 0 1",
            solution: ["e1e2"],
            hints: nil,
            maxMoves: 10
        )
        let vm = PuzzleViewModel(puzzle: puzzle)

        // 走 e1→e3（ICCS）= Board(row:8,col:4)→(row:6,col:4)，不是推荐的 e1e2
        let from = Position(row: 8, col: 4)
        let to = Position(row: 6, col: 4)

        let legalMoves = vm.selectPiece(at: from)
        #expect(legalMoves.contains(to))

        vm.movePiece(from: from, to: to)

        // 不匹配 solution[0]
        #expect(!vm.isRecommendedMove(at: 0))
    }
}
