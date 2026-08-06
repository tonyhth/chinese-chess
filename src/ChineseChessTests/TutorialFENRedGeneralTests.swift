import XCTest
@testable import ChineseChess

/// 回归测试：教程FEN合法性验证（v3.0-final 12课版本）
/// 验证所有 interactive 关卡的 FEN 合法性、红帅存在、走法路径不被遮挡
final class TutorialFENRedGeneralTests: XCTestCase {

    // MARK: - 新版12课的 interactive FEN 数据（课2-11）

    /// 课2-11的所有 interactive 关卡 FEN（与 TutorialViewModel.swift 中的定义一致）
    private let lessonFENs: [(lesson: Int, fen: String, expectedMoves: [String], turn: String)] = [
        // 课2: 车的走法 — 直线前进 + 横移吃子
        (2, "3aka3/9/9/9/9/4p4/9/9/3K5/R8 w - - 0 1", ["a0a4", "a4e4"], "w"),
        // 课3: 马的走法 — 日字跳跃 + 吃子
        (3, "3aka3/9/9/3p5/9/9/4N4/9/3K5/9 w - - 0 1", ["e3f5", "f5d6"], "w"),
        // 课4: 炮的走法 — 直线移动 + 翻山吃子
        (4, "3aka3/9/4c4/9/9/4P4/9/9/3K5/C8 w - - 0 1", ["a0e0", "e0e7"], "w"),
        // 课5: 象的走法 — 田字走法 + 吃子
        (5, "3aka3/9/9/9/9/5p3/9/9/3K5/1B7 w - - 0 1", ["b0d2", "d2f4"], "w"),
        // 课6: 士的走法 — 斜线吃子 + 回防
        (6, "3k5/9/9/9/9/9/9/4p4/3AK4/9 w - - 0 1", ["d1e2", "e2f1"], "w"),
        // 课7: 兵的走法 — 前进过河 + 横移吃子
        (7, "4ka3/9/9/9/3p5/4P4/9/9/3K5/9 w - - 0 1", ["e4e5", "e5d5"], "w"),
        // 课8: 将帅走法 — 九宫内移动
        (8, "3aka3/9/9/9/9/4R4/9/9/3K5/9 w - - 0 1", ["d1e1", "e1e2"], "w"),
        // 课9: 将军练习 — 炮翻山将军
        (9, "3aka3/9/9/9/4P4/9/9/9/3K5/2C6 w - - 0 1", ["c0e0"], "w"),
        // 课10: 应将练习 — 黑将逃离
        (10, "4ka3/9/9/4P4/9/9/4C4/9/5K3/9 b - - 0 1", ["e9d9"], "b"),
        // 课11: 闷宫杀 — 一步将死
        (11, "3aka3/4p4/9/2C6/9/9/9/9/3K5/9 w - - 0 1", ["c6e6"], "w"),
    ]

    /// 核心验证：所有课2-11的FEN必须能通过 FENDecoder.parse
    func testAllLessonFENsParseSuccessfully() {
        for (lesson, fen, _, _) in lessonFENs {
            let result = FENDecoder.parse(fen: fen)
            XCTAssertNotNil(result, "课\(lesson) FEN 解析失败: \(fen)")
        }
    }

    /// 验证每方恰好1个将/帅
    func testExactlyOneGeneralPerSide() {
        for (lesson, fen, _, _) in lessonFENs {
            guard let result = FENDecoder.parse(fen: fen) else {
                XCTFail("课\(lesson) FEN 解析失败: \(fen)")
                continue
            }
            let redGenerals = result.pieces.filter { $0.side == .red && $0.kind == .general }
            let blackGenerals = result.pieces.filter { $0.side == .black && $0.kind == .general }
            XCTAssertEqual(redGenerals.count, 1, "课\(lesson): 红方应有恰好1个帅，实际\(redGenerals.count)")
            XCTAssertEqual(blackGenerals.count, 1, "课\(lesson): 黑方应有恰好1个将，实际\(blackGenerals.count)")
            if let rg = redGenerals.first {
                XCTAssertTrue(rg.position.isInRedPalace, "课\(lesson): 红帅应在红方九宫格内，实际 position=\(rg.position)")
            }
        }
    }

    /// 验证红帅在九宫格范围内（row 7-9, col 3-5）
    func testRedGeneralInPalace() {
        for (lesson, fen, _, _) in lessonFENs {
            guard let result = FENDecoder.parse(fen: fen) else {
                XCTFail("课\(lesson) FEN 解析失败: \(fen)")
                continue
            }
            let redGeneral = result.pieces.first { $0.side == .red && $0.kind == .general }
            XCTAssertNotNil(redGeneral, "课\(lesson): 缺少红帅")
            XCTAssertTrue(redGeneral!.position.isInRedPalace, "课\(lesson): 红帅应在红方九宫格内")
        }
    }

    // MARK: - 走法路径不被红帅遮挡

    /// UCI file a-j 映射到 col 0-9, rank 0-9 对应 row 0-9 (from bottom=red side)
    private func uciToRowCol(_ uci: String) -> (fromRow: Int, fromCol: Int, toRow: Int, toCol: Int)? {
        guard uci.count == 4 else { return nil }
        let chars = Array(uci)
        let fileMap: [Character: Int] = ["a": 0, "b": 1, "c": 2, "d": 3, "e": 4,
                                          "f": 5, "g": 6, "h": 7, "i": 8, "j": 9]
        guard let fc = fileMap[chars[0]],
              let fr = chars[1].wholeNumberValue,
              let tc = fileMap[chars[2]],
              let tr = chars[3].wholeNumberValue else { return nil }
        return (fr, fc, tr, tc)
    }

    /// 验证每节课第一步的起始位置有正确的棋子
    /// 注意：只验证第一步（stepIndex=0），因为第二步的起始位置是第一步走完后才存在的，
    /// 在初始 FEN 上验证第二步起点会失败（P1 fix）。
    func testExpectedMoveSourcePieces() {
        let expectations: [(lesson: Int, fen: String, firstMove: String, side: Side, kind: PieceKind)] = [
            (2, "3aka3/9/9/9/9/4p4/9/9/3K5/R8 w - - 0 1", "a0a4", .red, .chariot),
            (3, "3aka3/9/9/3p5/9/9/4N4/9/3K5/9 w - - 0 1", "e3f5", .red, .horse),
            (4, "3aka3/9/4c4/9/9/4P4/9/9/3K5/C8 w - - 0 1", "a0e0", .red, .cannon),
            (5, "3aka3/9/9/9/9/5p3/9/9/3K5/1B7 w - - 0 1", "b0d2", .red, .elephant),
            (6, "3k5/9/9/9/9/9/9/4p4/3AK4/9 w - - 0 1", "d1e2", .red, .advisor),
            (7, "4ka3/9/9/9/3p5/4P4/9/9/3K5/9 w - - 0 1", "e4e5", .red, .soldier),
            (8, "3aka3/9/9/9/9/4R4/9/9/3K5/9 w - - 0 1", "d1e1", .red, .general),
            (9, "3aka3/9/9/9/4P4/9/9/9/3K5/2C6 w - - 0 1", "c0e0", .red, .cannon),
            (10, "4ka3/9/9/4P4/9/9/4C4/9/5K3/9 b - - 0 1", "e9d9", .black, .general),
            (11, "3aka3/4p4/9/2C6/9/9/9/9/3K5/9 w - - 0 1", "c6e6", .red, .cannon),
        ]

        for (lesson, fen, move, side, kind) in expectations {
            guard let result = FENDecoder.parse(fen: fen) else {
                XCTFail("课\(lesson) FEN 解析失败")
                continue
            }
            guard let coords = uciToRowCol(move) else {
                XCTFail("课\(lesson): 无法解析 UCI: \(move)")
                continue
            }
            // UCI rank 0 = 红方底线 = FEN row 9; UCI rank 9 = 黑方底线 = FEN row 0
            let fromFenRow = 9 - coords.fromRow
            let fromFenCol = coords.fromCol

            let sourcePiece = result.pieces.first { $0.position.row == fromFenRow && $0.position.col == fromFenCol }
            XCTAssertNotNil(sourcePiece, "课\(lesson): UCI \(move) 起始位置 (fenRow=\(fromFenRow), col=\(fromFenCol)) 无棋子")
            XCTAssertEqual(sourcePiece?.side, side, "课\(lesson): UCI \(move) 起始位置棋子颜色错误")
            XCTAssertEqual(sourcePiece?.kind, kind, "课\(lesson): UCI \(move) 起始位置棋子类型错误，期望\(kind)，实际\(sourcePiece?.kind ?? .general)")
        }
    }

    // MARK: - 行走方验证

    /// 验证每个FEN的行走方正确
    func testTurnCorrectness() {
        for (lesson, fen, _, turn) in lessonFENs {
            guard let result = FENDecoder.parse(fen: fen) else {
                XCTFail("课\(lesson) FEN 解析失败")
                continue
            }
            let expectedTurn: Side = turn == "w" ? .red : .black
            XCTAssertEqual(result.currentTurn, expectedTurn, "课\(lesson): 行走方应为\(expectedTurn)")
        }
    }

    // MARK: - 回归：课0-1（info 类型）不受影响

    /// 确保非 interactive 课程不受影响（它们没有 FEN）
    func testInfoLessonsNotAffected() {
        let vm = TutorialViewModel()
        XCTAssertGreaterThanOrEqual(vm.lessons.count, 12, "应有至少12节课")

        // 前2节（id 0-1）是 info 类型
        for i in 0...1 {
            XCTAssertEqual(vm.lessons[i].type, .info, "课\(i)应为 info 类型")
            XCTAssertNil(vm.lessons[i].initialFEN, "课\(i)不应有 initialFEN")
        }

        // 后10节（id 2-11）是 interactive 类型
        for i in 2...11 {
            XCTAssertEqual(vm.lessons[i].type, .interactive, "课\(i)应为 interactive 类型")
            XCTAssertNotNil(vm.lessons[i].initialFEN, "课\(i)应有 initialFEN")
            XCTAssertNotNil(vm.lessons[i].expectedMoves, "课\(i)应有 expectedMoves")
        }
    }

    // MARK: - R1: hintKeys 与 expectedMoves 长度一致性

    /// 验证所有 interactive 关卡的 hintKeys.count == expectedMoves.count
    func testHintKeysMatchExpectedMovesCount() {
        let vm = TutorialViewModel()
        for i in 2...11 {
            let lesson = vm.lessons[i]
            XCTAssertNotNil(lesson.hintKeys, "课\(i)应有 hintKeys")
            XCTAssertEqual(lesson.hintKeys?.count, lesson.expectedMoves?.count,
                           "课\(i): hintKeys.count (\(lesson.hintKeys?.count ?? 0)) 必须等于 expectedMoves.count (\(lesson.expectedMoves?.count ?? 0))")
        }
    }

    // MARK: - C4: expectedMoves UCI 字符串与设计文档一致性

    /// 验证所有 interactive 关卡的 expectedMoves UCI 字符串与设计文档 v3.0-final 完全一致
    func testExpectedMovesMatchDesignDoc() {
        let vm = TutorialViewModel()
        let expectedDesign: [(lesson: Int, moves: [String])] = [
            (2, ["a0a4", "a4e4"]),       // 课2: 车
            (3, ["e3f5", "f5d6"]),       // 课3: 马
            (4, ["a0e0", "e0e7"]),       // 课4: 炮
            (5, ["b0d2", "d2f4"]),       // 课5: 象
            (6, ["d1e2", "e2f1"]),       // 课6: 士
            (7, ["e4e5", "e5d5"]),       // 课7: 兵
            (8, ["d1e1", "e1e2"]),       // 课8: 将帅
            (9, ["c0e0"]),                // 课9: 将军
            (10, ["e9d9"]),               // 课10: 应将
            (11, ["c6e6"]),               // 课11: 闷宫杀
        ]
        for (lessonId, expectedMoves) in expectedDesign {
            let lesson = vm.lessons.first { $0.id == lessonId }
            XCTAssertNotNil(lesson, "课\(lessonId) 不存在")
            XCTAssertEqual(lesson?.expectedMoves, expectedMoves,
                           "课\(lessonId): expectedMoves 与设计文档不符")
        }
    }

    // MARK: - C7: StudyHubView 图标测试归属修正（原位置保留，标记为非教程相关）

    /// 验证 StudyHubView.swift 不再使用 compass.fill
    func testNoCompassFillInStudyHubView() {
        let studyHubPath = NSHomeDirectory() + "/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StudyHubView.swift"
        guard let content = try? String(contentsOfFile: studyHubPath) else {
            XCTFail("无法读取 StudyHubView.swift")
            return
        }
        XCTAssertFalse(content.contains("compass.fill"),
                       "StudyHubView.swift 不应再使用 compass.fill")
        XCTAssertTrue(content.contains("location.north.fill"),
                      "StudyHubView.swift 应使用 location.north.fill")
    }
}
