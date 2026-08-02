import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.3 遗留问题修复测试

@Suite("v2.2.3 遗留问题修复", .serialized)
struct V222FixTests {

    // MARK: - 问题1：英文界面 → 硬编码中文（废弃本地化系统）
    // MARK: - 问题2：棋盘太小 → 增大初始窗口
    // MARK: - 问题3（v2.2.2）：残局列表 + 语义字体 + ResourceBundle fallback
    @Test("问题3(v222): PuzzleStore 实际加载残局数据")
    func testPuzzleStoreLoadsData() {
        let store = PuzzleStore.shared
        #expect(!store.puzzles.isEmpty, "残局列表不应为空")
    }

    @Test("问题3(v222): 残局数量检查（651 局）")
    func testPuzzleCount() {
        let store = PuzzleStore.shared
        #expect(store.puzzles.count == 551, "应有 551 局残局（适情雅趣），实际 \(store.puzzles.count) 局")
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
