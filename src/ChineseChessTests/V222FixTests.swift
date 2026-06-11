import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.3 遗留问题修复测试

@Suite("v2.2.3 遗留问题修复")
struct V222FixTests {

    // MARK: - 问题1：英文界面 → 硬编码中文（废弃本地化系统）

    @Test("问题1: 代码中不再使用 String(localized:)")
    func testNoLocalizedString() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let srcDir = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess"
        let files = try? FileManager.default.contentsOfDirectory(atPath: srcDir)
        guard let files = files else {
            #expect(Bool(false), "无法列出源码目录")
            return
        }

        let swiftFiles = files.filter { $0.hasSuffix(".swift") }
        for file in swiftFiles {
            let path = "\(srcDir)/\(file)"
            let content = (try? String(contentsOfFile: path)) ?? ""
            let lines = content.components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                #expect(!trimmed.contains("String(localized:"),
                       "\(file) 第 \(i+1) 行不应使用 String(localized:)")
            }
        }
    }

    @Test("问题1: 不使用 .environment(\\.locale)")
    func testNoEnvironmentLocale() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let appFiles = [
            "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift",
            "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift",
        ]
        for path in appFiles {
            guard let content = try? String(contentsOfFile: path) else { continue }
            #expect(!content.contains(".environment(\\.locale"),
                   "\(path) 不应使用 .environment(\\.locale)")
        }
    }

    @Test("问题1: 不设置 AppleLanguages")
    func testNoAppleLanguages() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let appFiles = [
            "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift",
            "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift",
        ]
        for path in appFiles {
            guard let content = try? String(contentsOfFile: path) else { continue }
            #expect(!content.contains("AppleLanguages"),
                   "\(path) 不应设置 AppleLanguages")
        }
    }

    @Test("问题1: App 入口直接使用中文标题")
    func testChineseTitles() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("中国象棋"), "App 应使用中文标题")
        #expect(content.contains("残局闯关"), "残局 sheet 标题应为中文")
    }

    // MARK: - 问题2：棋盘太小 → 增大初始窗口

    @Test("问题2: 初始窗口不小于 760x860")
    func testInitialWindowSize() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("760") && content.contains("860"),
               "defaultSize 应为 760x860")
    }

    @Test("问题2: 棋盘有最小高度")
    func testBoardMinHeight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("minHeight: 480"),
               "BoardView 应设置 minHeight: 480")
    }

    // MARK: - 问题3（v2.2.2）：残局列表 + 语义字体 + ResourceBundle fallback

    @Test("问题2(v222): PuzzleSelectView 不使用语义字体")
    func testPuzzleSelectViewNoSemanticFonts() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 PuzzleSelectView.swift")
            return
        }
        let semanticFonts = [".caption)", ".subheadline)", ".title2)", ".title3)", ".caption2)"]
        for sf in semanticFonts {
            let lines = content.components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                if trimmed.contains(".font(.system(\(sf)") || trimmed.contains(".font(\(sf)") {
                    #expect(Bool(false), "第 \(i+1) 行不应使用语义字体 \(sf)")
                }
            }
        }
    }

    @Test("问题2(v222): StatusBarView 不使用语义字体")
    func testStatusBarViewNoSemanticFonts() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 StatusBarView.swift")
            return
        }
        let semanticFonts = [".caption)", ".subheadline)", ".caption2)"]
        let lines = content.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }
            for sf in semanticFonts {
                if trimmed.contains(".font(.system(\(sf)") || trimmed.contains(".font(\(sf)") {
                    #expect(Bool(false), "StatusBarView 第 \(i+1) 行不应使用语义字体 \(sf)")
                }
            }
        }
    }

    @Test("问题2(v222): StatsPanelView 不使用语义字体")
    func testStatsPanelViewNoSemanticFonts() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatsPanelView.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 StatsPanelView.swift")
            return
        }
        let semanticFonts = [".caption)", ".subheadline)", ".caption2)"]
        let lines = content.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }
            for sf in semanticFonts {
                if trimmed.contains(".font(.system(\(sf)") || trimmed.contains(".font(\(sf)") {
                    #expect(Bool(false), "StatsPanelView 第 \(i+1) 行不应使用语义字体 \(sf)")
                }
            }
        }
    }

    @Test("问题2(v222): RecordPanelView 不使用语义字体")
    func testRecordPanelViewNoSemanticFonts() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/RecordPanelView.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 RecordPanelView.swift")
            return
        }
        let semanticFonts = [".caption)", ".subheadline)", ".caption2)"]
        let lines = content.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }
            for sf in semanticFonts {
                if trimmed.contains(".font(.system(\(sf)") || trimmed.contains(".font(\(sf)") {
                    #expect(Bool(false), "RecordPanelView 第 \(i+1) 行不应使用语义字体 \(sf)")
                }
            }
        }
    }

    @Test("问题3(v222): PuzzleStore 有 ResourceBundle fallback 逻辑")
    func testPuzzleStoreFallback() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Services/PuzzleStore.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 PuzzleStore.swift")
            return
        }
        #expect(content.contains("ResourceBundle.url(forResource: \"puzzles\", withExtension: \"json\")"),
               "应有 ResourceBundle 主路径查找")
        #expect(content.contains("subdirectory:"), "应有 subdirectory fallback")
    }

    @Test("问题3(v222): SoundEngine 有 fallback 逻辑")
    func testSoundEngineFallback() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Services/SoundEngine.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 SoundEngine.swift")
            return
        }
        #expect(content.contains("ResourceBundle.url"), "应使用 ResourceBundle")
        #expect(content.contains("subdirectory:"), "应有 subdirectory fallback")
    }

    @Test("问题3(v222): PuzzleStore 实际加载残局数据")
    func testPuzzleStoreLoadsData() {
        let store = PuzzleStore.shared
        #expect(!store.puzzles.isEmpty, "残局列表不应为空")
    }

    @Test("问题3(v222): 残局数量检查（116 局）")
    func testPuzzleCount() {
        let store = PuzzleStore.shared
        #expect(store.puzzles.count == 116, "应有 116 局残局，实际 \(store.puzzles.count) 局")
    }

    @Test("问题3(v222): SoundEngine 不崩溃")
    func testSoundEngineNoCrash() {
        let engine = SoundEngine.shared
        engine.isMuted = false
        engine.playMove()
        engine.playCapture()
        engine.playCheck()
        engine.playUndo()
        engine.playVictory()
        engine.playDefeat()
        engine.isMuted = true
        engine.playMove()
        #expect(true, "SoundEngine 所有方法不崩溃")
    }

    // MARK: - 残局数据合法性验证

    @Test("残局 FEN 合法性：每方棋子数量不超标")
    func testPuzzleFENLegality() {
        let store = PuzzleStore.shared
        for puzzle in store.puzzles {
            let fen = puzzle.initialFEN
            let board = fen.components(separatedBy: " ").first ?? fen

            var redK = 0, redA = 0, redB = 0, redN = 0, redR = 0, redC = 0, redP = 0
            var blkK = 0, blkA = 0, blkB = 0, blkN = 0, blkR = 0, blkC = 0, blkP = 0

            for ch in board {
                switch ch {
                case "K": redK += 1
                case "A": redA += 1
                case "B": redB += 1
                case "N": redN += 1
                case "R": redR += 1
                case "C": redC += 1
                case "P": redP += 1
                case "k": blkK += 1
                case "a": blkA += 1
                case "b": blkB += 1
                case "n": blkN += 1
                case "r": blkR += 1
                case "c": blkC += 1
                case "p": blkP += 1
                default: break
                }
            }

            #expect(redK == 1, "\(puzzle.id) \(puzzle.name): 红帅=\(redK)，应为1")
            #expect(blkK == 1, "\(puzzle.id) \(puzzle.name): 黑将=\(blkK)，应为1")
            #expect(redA <= 2, "\(puzzle.id) \(puzzle.name): 红仕=\(redA)，应≤2")
            #expect(blkA <= 2, "\(puzzle.id) \(puzzle.name): 黑士=\(blkA)，应≤2")
            #expect(redB <= 2, "\(puzzle.id) \(puzzle.name): 红相=\(redB)，应≤2")
            #expect(blkB <= 2, "\(puzzle.id) \(puzzle.name): 黑象=\(blkB)，应≤2")
            #expect(redN <= 2, "\(puzzle.id) \(puzzle.name): 红马=\(redN)，应≤2")
            #expect(blkN <= 2, "\(puzzle.id) \(puzzle.name): 黑马=\(blkN)，应≤2")
            #expect(redR <= 2, "\(puzzle.id) \(puzzle.name): 红车=\(redR)，应≤2")
            #expect(blkR <= 2, "\(puzzle.id) \(puzzle.name): 黑车=\(blkR)，应≤2")
            #expect(redC <= 2, "\(puzzle.id) \(puzzle.name): 红炮=\(redC)，应≤2")
            #expect(blkC <= 2, "\(puzzle.id) \(puzzle.name): 黑炮=\(blkC)，应≤2")
            #expect(redP <= 5, "\(puzzle.id) \(puzzle.name): 红兵=\(redP)，应≤5")
            #expect(blkP <= 5, "\(puzzle.id) \(puzzle.name): 黑卒=\(blkP)，应≤5")
        }
    }
}
