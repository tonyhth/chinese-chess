import Testing
import Foundation
@testable import ChineseChess

/// R1-1.20 / R1-1.28 / R2-5.20：记谱格式切换测试
/// 验证 NotationGenerator 根据 notationFormat 设置正确输出中文/ICCS 格式
@Suite("记谱格式切换", .serialized)
struct NotationFormatSwitchTests {

    private func makeBoard() -> Board {
        Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w")
    }

    private func clearFormat() {
        UserDefaults.standard.removeObject(forKey: "chinesechess.notationFormat")
    }

    /// 构造红炮 h2→e2 的走法
    private func cannonMove() -> Move {
        let piece = Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 7))
        return Move(piece: piece, from: Position(row: 7, col: 7), to: Position(row: 7, col: 4), captured: nil)
    }

    /// 默认格式 = 中文
    @Test("默认 notationFormat 为中文")
    func defaultFormatIsChinese() {
        clearFormat()
        let board = makeBoard()
        let notation = NotationGenerator.notation(for: cannonMove(), on: board)
        #expect(notation.contains("炮"), "默认格式应输出中文记谱，实际: \(notation)")
        #expect(!notation.allSatisfy { $0.isASCII }, "中文记谱不应为纯 ASCII，实际: \(notation)")
    }

    /// 设置 chinese 格式 → 输出中文
    @Test("notationFormat=chinese 输出中文记谱")
    func chineseFormat() {
        UserDefaults.standard.set("chinese", forKey: "chinesechess.notationFormat")
        defer { clearFormat() }

        let board = makeBoard()
        let notation = NotationGenerator.notation(for: cannonMove(), on: board)
        #expect(notation.contains("炮"), "应输出「炮」，实际: \(notation)")
    }

    /// 设置 iccs 格式 → 输出 ICCS 坐标
    @Test("notationFormat=iccs 输出 ICCS 坐标记谱")
    func iccsFormat() {
        UserDefaults.standard.set("iccs", forKey: "chinesechess.notationFormat")
        defer { clearFormat() }

        let board = makeBoard()
        let notation = NotationGenerator.notation(for: cannonMove(), on: board)
        #expect(notation == "h2e2", "ICCS 格式应输出 h2e2，实际: \(notation)")
    }

    /// ICCS 格式：初始局面所有合法走法都应为纯 ASCII
    @Test("ICCS 格式输出纯 ASCII")
    func iccsFormatIsPureASCII() {
        UserDefaults.standard.set("iccs", forKey: "chinesechess.notationFormat")
        defer { clearFormat() }

        let board = makeBoard()
        let engine = AIEngine()
        guard let move = engine.bestMove(for: board.snapshot(), difficulty: .beginner) else {
            Issue.record("AI 未返回走法")
            return
        }
        let notation = NotationGenerator.notation(for: move, on: board)
        #expect(notation.allSatisfy { $0.isASCII }, "ICCS 格式应纯 ASCII，实际: \(notation)")
        // ICCS 格式应为 4 字符：如 a7a6, h7h6, b7c7 等
        #expect(notation.count == 4, "ICCS 格式应为 4 字符，实际: \(notation)（长度 \(notation.count)）")
    }

    /// 格式切换即时生效（不依赖重启）
    @Test("格式切换即时生效")
    func formatSwitchTakesEffectImmediately() {
        let board = makeBoard()
        let move = cannonMove()

        // 先中文
        UserDefaults.standard.set("chinese", forKey: "chinesechess.notationFormat")
        let zhNotation = NotationGenerator.notation(for: move, on: board)
        #expect(zhNotation.contains("炮"), "中文格式: \(zhNotation)")

        // 切 ICCS
        UserDefaults.standard.set("iccs", forKey: "chinesechess.notationFormat")
        let iccsNotation = NotationGenerator.notation(for: move, on: board)
        #expect(iccsNotation == "h2e2", "ICCS 格式: \(iccsNotation)")

        // 切回中文
        UserDefaults.standard.set("chinese", forKey: "chinesechess.notationFormat")
        let zh2Notation = NotationGenerator.notation(for: move, on: board)
        #expect(zh2Notation.contains("炮"), "切回中文: \(zh2Notation)")

        clearFormat()
    }

    /// 多种棋子类型的 ICCS 输出验证
    @Test("ICCS 格式：多种棋子类型")
    func iccsFormatVariousPieces() {
        UserDefaults.standard.set("iccs", forKey: "chinesechess.notationFormat")
        defer { clearFormat() }

        let board = Board(fen: "4k4/9/9/9/9/9/9/9/4P4/4K4 w")

        // 红兵 row8→row7 (ICCS: e1→e2)
        let pawn = Piece(kind: .soldier, side: .red, position: Position(row: 8, col: 4))
        let pawnMove = Move(piece: pawn, from: Position(row: 8, col: 4), to: Position(row: 7, col: 4), captured: nil)
        let pawnNotation = NotationGenerator.notation(for: pawnMove, on: board)
        #expect(pawnNotation == "e1e2", "红兵 ICCS: \(pawnNotation)")

        // 红帅 row9→row8 (ICCS: e0→e1)
        let king = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let kingMove = Move(piece: king, from: Position(row: 9, col: 4), to: Position(row: 8, col: 4), captured: nil)
        let kingNotation = NotationGenerator.notation(for: kingMove, on: board)
        #expect(kingNotation == "e0e1", "红帅 ICCS: \(kingNotation)")
    }

    /// 中文格式的完整性验证（原有逻辑不回归）
    @Test("中文格式不回归：炮二平五")
    func chineseFormatNoRegression() {
        UserDefaults.standard.set("chinese", forKey: "chinesechess.notationFormat")
        defer { clearFormat() }

        let board = makeBoard()
        let notation = NotationGenerator.notation(for: cannonMove(), on: board)
        // 应包含：棋子名 + 起始纵线 + 动作 + 目标
        #expect(notation.contains("炮"), "棋子名: \(notation)")
        #expect(notation.contains("二") || notation.contains("五"), "纵线: \(notation)")
        #expect(notation.contains("平") || notation.contains("进") || notation.contains("退"), "动作: \(notation)")
    }

    /// 未知格式值 → 回退中文（安全默认）
    @Test("未知格式值回退中文")
    func unknownFormatFallback() {
        UserDefaults.standard.set("french", forKey: "chinesechess.notationFormat")
        defer { clearFormat() }

        let board = makeBoard()
        let notation = NotationGenerator.notation(for: cannonMove(), on: board)
        // 未知格式应回退到中文（非 iccs 即中文）
        #expect(notation.contains("炮"), "未知格式应回退中文，实际: \(notation)")
    }
}
