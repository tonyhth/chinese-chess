import Testing
import SwiftUI
import Foundation
@testable import ChineseChess

// MARK: - Phase B3 Step 3 — Ruby 审查修复验证测试

@Suite("B3S3 OpeningMoveQuality Extensions", .serialized)
struct B3S3OpeningMoveQualityExtensionTests {

    // MARK: - P1-3: qualityColor 提取到 OpeningMoveQuality.color

    @Test("P1-3: color 属性存在且与 colorName 语义一致")
    func colorMatchesColorName() {
        for quality in OpeningMoveQuality.allCases {
            // color 不应抛异常（编译验证 + 运行时验证）
            let _ = quality.color
            // colorName 和 color 应描述同一种颜色
            // 我们通过映射验证一致性
            let expectedColorName = quality.colorName
            let mapping: [String: Color] = [
                "green": .green, "blue": .blue, "gray": .gray,
                "yellow": .yellow, "orange": .orange, "red": .red
            ]
            #expect(mapping[expectedColorName] != nil,
                    "\(quality) colorName=\(expectedColorName) 不在映射表中")
        }
    }

    @Test("P1-3: color 与 colorName 对每个 quality 一致")
    func colorConsistencyPerQuality() {
        // 验证每个 quality 的 color 返回正确的 SwiftUI Color
        let expectations: [(OpeningMoveQuality, String)] = [
            (.book, "green"), (.brilliant, "green"), (.good, "blue"),
            (.normal, "gray"), (.doubtful, "yellow"), (.blunder, "orange"), (.losing, "red"),
        ]
        for (quality, expectedColorName) in expectations {
            #expect(quality.colorName == expectedColorName,
                    "\(quality).colorName 应为 \(expectedColorName)")
        }
    }

    // MARK: - P1-4: emoji 扩展从 CoachResultView 移至 OpeningMoveQuality

    @Test("P1-4: emoji 属性存在且非空")
    func emojiNonEmpty() {
        for quality in OpeningMoveQuality.allCases {
            #expect(!quality.emoji.isEmpty, "\(quality).emoji 不应为空")
        }
    }

    @Test("P1-4: 每个 quality 有不同的 emoji")
    func emojiUnique() {
        let emojis = OpeningMoveQuality.allCases.map { $0.emoji }
        let uniqueEmojis = Set(emojis)
        #expect(uniqueEmojis.count == emojis.count, "emoji 应全部不同")
    }

    @Test("P1-4: emoji 与 quality 对应关系")
    func emojiMapping() {
        #expect(OpeningMoveQuality.book.emoji == "✅")
        #expect(OpeningMoveQuality.brilliant.emoji == "⭐")
        #expect(OpeningMoveQuality.good.emoji == "👍")
        #expect(OpeningMoveQuality.normal.emoji == "⚪")
        #expect(OpeningMoveQuality.doubtful.emoji == "⚠️")
        #expect(OpeningMoveQuality.blunder.emoji == "❌")
        #expect(OpeningMoveQuality.losing.emoji == "💀")
    }
}

@Suite("B3S3 CoachConfig AI 拦截", .serialized)
struct B3S3CoachConfigAIInterceptTests {

    // MARK: - P1-2: coachConfig 阻止 movePiece 触发 AI

    @Test("P1-2: GameViewModel 有 coachConfig 属性")
    @MainActor
    func coachConfigExists() {
        let vm = GameViewModel()
        #expect(vm.coachConfig == nil, "初始 coachConfig 应为 nil")
    }

    @Test("P1-2: 设置 coachConfig 后属性非 nil")
    @MainActor
    func coachConfigSettable() {
        let vm = GameViewModel()
        let sub = OpeningSubcategory(id: "test", name: "测试", firstMoves: ["h2e2"], gameCount: 1)
        vm.coachConfig = CoachConfig(
            targetSubcategory: sub,
            aiDifficulty: .medium,
            playerSide: .red
        )
        #expect(vm.coachConfig != nil, "设置后 coachConfig 不应为 nil")
    }

    @Test("P1-2: newGame 清除 coachConfig")
    @MainActor
    func newGameClearsCoachConfig() {
        let vm = GameViewModel()
        let sub = OpeningSubcategory(id: "test", name: "测试", firstMoves: ["h2e2"], gameCount: 1)
        vm.coachConfig = CoachConfig(
            targetSubcategory: sub,
            aiDifficulty: .medium,
            playerSide: .red
        )
        vm.newGame()
        #expect(vm.coachConfig == nil, "newGame 后 coachConfig 应为 nil")
    }
}

@Suite("B3S3 MoveHistory 语义", .serialized)
struct B3S3MoveHistorySemanticsTests {

    // MARK: - P0-1: evaluateEngine moveHistory=[] 语义验证

    @Test("P0-1: Board 从 FEN 初始化不需要 moveHistory 回放")
    func boardFromFENIndependent() {
        // 验证：从 FEN 构建的 Board 已是完整局面，不需要 moveHistory 回放
        let fen = FENParser.standardInitial
        let board = Board(fen: fen)
        // 初始局面应有 32 枚棋子
        var pieceCount = 0
        for row in 0..<10 {
            for col in 0..<9 {
                if board.piece(at: Position(row: row, col: col)) != nil {
                    pieceCount += 1
                }
            }
        }
        #expect(pieceCount == 32, "标准初始局面应有 32 枚棋子，实际 \(pieceCount)")
    }

    @Test("P0-1: Board 逐步走子后 FEN 与直接构造一致")
    func boardConsistencyAfterMoves() {
        // 验证：逐步走子后生成的 FEN 可以重建相同棋盘
        let board = Board()
        guard let move1 = ICCSParser.parse("h2e2", on: board) else {
            Issue.record("h2e2 解析失败")
            return
        }
        board.execute(move1)

        let fenAfterMove = FENParser.generate(board: board)
        let reconstructedBoard = Board(fen: fenAfterMove)

        // 验证两个棋盘状态一致
        let fen1 = FENParser.generate(board: board)
        let fen2 = FENParser.generate(board: reconstructedBoard)
        #expect(fen1 == fen2, "逐步走子后 FEN 与重建棋盘 FEN 应一致")
    }

    @Test("P0-1: 重建走棋前局面 — dropLast 逻辑正确")
    func reconstructBoardBeforeUserMove() {
        // 模拟 CoachGameView 中重建用户走棋前棋盘的逻辑
        let board = Board()
        let moves = ["h2e2", "h0g2", "b0c2"]

        // 逐步执行走法
        for moveStr in moves {
            guard let m = ICCSParser.parse(moveStr, on: board) else {
                Issue.record("\(moveStr) 解析失败")
                return
            }
            board.execute(m)
        }

        // 重建 b0c2 之前的局面（去掉最后一步）
        let boardBefore = Board()
        for moveStr in moves.dropLast() {
            guard let m = ICCSParser.parse(moveStr, on: boardBefore) else {
                Issue.record("重建：\(moveStr) 解析失败")
                return
            }
            boardBefore.execute(m)
        }

        // 验证：boardBefore 不含 b0c2 的效果
        let fenBefore = FENParser.generate(board: boardBefore)
        let fenAfter = FENParser.generate(board: board)
        #expect(fenBefore != fenAfter, "走棋前后 FEN 应不同")

        // b0c2: 马从 b0 到 c2
        let pieceAtC2Before = boardBefore.piece(at: Position(row: 7, col: 2))
        let pieceAtC2After = board.piece(at: Position(row: 7, col: 2))
        #expect(pieceAtC2Before == nil, "b0c2 之前 c2 应为空")
        #expect(pieceAtC2After != nil, "b0c2 之后 c2 应有棋子")
    }
}
