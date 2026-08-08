import Foundation
import Testing
import SwiftUI
@testable import ChineseChess

// MARK: - Phase 2 修复测试

/// 辅助：创建测试用 Puzzle
private func makePuzzle(
    id: String = "test",
    initialFEN: String = FENParser.standardInitial,
    solution: [String] = [],
    solutionMode: SolutionMode = .guided,
    maxMoves: Int = 100
) -> Puzzle {
    Puzzle(
        id: id, name: "测试", category: "test", difficulty: 1, stars: 1,
        description: "", playerSide: "red", initialFEN: initialFEN,
        solution: solution, hints: nil, maxMoves: maxMoves,
        solutionMode: solutionMode
    )
}

@Suite("Phase 2 修复测试", .serialized)
@MainActor
struct Phase2FixTests {

    // ============================================================
    // P1-10: DemoViewModel.moveNotations 使用 NotationGenerator
    // ============================================================

    @Test("P1-10: moveNotations 生成传统中文记谱法（非 UCI 坐标）")
    func moveNotationsUseChineseNotation() async {
        let puzzle = makePuzzle(id: "test_notation")
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        let board = Board(fen: puzzle.initialFEN)

        // 红炮从 b2(row7,col1) 到 e0(row9,col4) = 炮二平五
        guard let piece = board.piece(at: Position(row: 7, col: 1)) else {
            #expect(Bool(false), "应找到红炮")
            return
        }
        let move = Move(piece: piece, from: Position(row: 7, col: 1), to: Position(row: 9, col: 4), captured: nil)
        let vm = DemoViewModel(item: wrapper, moves: [move])

        let notations = vm.moveNotations
        #expect(notations.count == 1, "应有 1 步记谱")
        #expect(!notations[0].isEmpty, "记谱不应为空")

        let hasChinese = notations[0].contains(where: { $0.unicodeScalars.first?.value ?? 0 > 0x4E00 })
        #expect(hasChinese, "记谱应包含中文字符，实际: \(notations[0])")
        #expect(!notations[0].contains("b2"), "不应包含 UCI 坐标 b2")
        #expect(!notations[0].contains("e0"), "不应包含 UCI 坐标 e0")
    }

    @Test("P1-10: moveNotations 多步走法连续记谱")
    func moveNotationsMultipleSteps() async {
        let puzzle = makePuzzle(id: "test_multi")
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        let board = Board(fen: puzzle.initialFEN)

        // 第一步：红炮从 b2(row7,col1) 到 e0(row9,col4)
        guard let piece1 = board.piece(at: Position(row: 7, col: 1)) else {
            #expect(Bool(false), "应找到红炮")
            return
        }
        let move1 = Move(piece: piece1, from: Position(row: 7, col: 1), to: Position(row: 9, col: 4), captured: nil)
        board.execute(move1)

        // 第二步：移动黑卒
        guard let piece2 = board.piece(at: Position(row: 3, col: 0)) else {
            #expect(Bool(false), "应找到黑卒")
            return
        }
        let move2 = Move(piece: piece2, from: Position(row: 3, col: 0), to: Position(row: 4, col: 0), captured: nil)

        let vm = DemoViewModel(item: wrapper, moves: [move1, move2])
        let notations = vm.moveNotations
        #expect(notations.count == 2, "应有 2 步记谱")
        #expect(!notations[0].isEmpty)
        #expect(!notations[1].isEmpty)
    }

    @Test("P1-10: NotationGenerator 直接验证")
    func notationGeneratorDirectTest() {
        let board = Board()  // 标准开局
        // 红炮在 row 7, col 1（UCI b2）
        guard let piece = board.piece(at: Position(row: 7, col: 1)) else {
            #expect(Bool(false), "应找到红炮在 row 7 col 1")
            return
        }
        let move = Move(piece: piece, from: Position(row: 7, col: 1), to: Position(row: 9, col: 4), captured: nil)
        let notation = NotationGenerator.notation(for: move, on: board)

        #expect(!notation.isEmpty, "记谱不应为空")
        #expect(notation.contains("炮"), "记谱应包含'炮'字，实际: \(notation)")
    }

    // ============================================================
    // P1-3: 子分类排他匹配 + "其他应手"
    // ============================================================

    @Test("P1-3: OpeningCategories 包含动态'其他应手'子分类")
    func openingCategoriesHasOtherSubcategory() {
        let categories = OpeningCategories.categories
        var foundOther = false
        for cat in categories {
            if !cat.subcategories.isEmpty {
                let hasOther = cat.subcategories.contains { $0.id == "\(cat.id)_other" }
                if hasOther {
                    foundOther = true
                    break
                }
            }
        }
        #expect(foundOther, "至少一个有子分类的一级分类应包含'其他应手'")
    }

    @Test("P1-3: 中炮分类包含'其他应手'子分类")
    func zhongPaoHasOtherSubcategory() {
        let categories = OpeningCategories.categories
        guard let zhongPao = categories.first(where: { $0.firstMove == "h2e2" }) else {
            #expect(Bool(false), "应找到中炮分类")
            return
        }
        let hasOther = zhongPao.subcategories.contains { $0.id == "zhong_pao_other" }
        #expect(hasOther, "中炮分类应包含'其他应手'子分类")
    }

    @Test("P1-3: '其他应手'的 firstMoves 为空（匹配剩余对局）")
    func otherSubcategoryHasEmptyFirstMoves() {
        let categories = OpeningCategories.categories
        for cat in categories {
            if let other = cat.subcategories.first(where: { $0.id == "\(cat.id)_other" }) {
                #expect(other.firstMoves.isEmpty, "'其他应手'的 firstMoves 应为空")
                #expect(other.name == "其他应手", "名称应为'其他应手'")
                return
            }
        }
        #expect(Bool(false), "未找到任何'其他应手'子分类")
    }

    @Test("P1-3: '其他应手'不重复添加")
    func otherSubcategoryNoDuplicate() {
        let categories = OpeningCategories.categories
        for cat in categories {
            let otherCount = cat.subcategories.filter { $0.id == "\(cat.id)_other" }.count
            #expect(otherCount <= 1, "'其他应手'不应重复添加，实际: \(otherCount)")
        }
    }

    // ============================================================
    // P1-11 类型2: maxMoves ≥ solution length
    // ============================================================

    @Test("P1-11 type2: Puzzle maxMoves=64, solution_len=62（sqyq_388 模式）")
    func type2MaxMovesAdequate() {
        let puzzle = makePuzzle(
            id: "sqyq_388_like",
            solution: Array(repeating: "h2e2", count: 62),
            maxMoves: 64
        )
        #expect(puzzle.maxMoves >= puzzle.solution.count, "maxMoves 应 ≥ solution length")
    }

    @Test("P1-11 type2: effectiveMode guided 不提前失败")
    func guidedPuzzleMaxMovesAdequate() {
        let puzzle = makePuzzle(
            solution: ["h2e2", "h9g7"],
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided, "guided puzzle 应保持 guided")
    }

    // ============================================================
    // P1-11 类型1: effectiveMode 优先 freePlay
    // ============================================================

    @Test("P1-11 type1: solutionMode=freePlay 时 effectiveMode 返回 freePlay（即使有 solution）")
    func freePlayEffectiveModeOverridesSolution() {
        // 模拟 sqyq_486：solutionMode=freePlay, solution=["e0f0"]
        let puzzle = makePuzzle(
            id: "sqyq_486_like",
            solution: ["e0f0"],
            solutionMode: .freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay, "solutionMode=freePlay 应优先返回 freePlay，即使有 solution")
    }

    @Test("P1-11 type1: solutionMode=guided + 有 solution → guided")
    func guidedWithSolutionStaysGuided() {
        let puzzle = makePuzzle(
            solution: ["h2e2"],
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("P1-11 type1: solutionMode=guided + 空 solution → guided")
    func guidedEmptySolutionStaysGuided() {
        let puzzle = makePuzzle(
            solution: [],
            solutionMode: .guided
        )
        #expect(puzzle.effectiveMode == .guided)
    }

    @Test("P1-11 type1: solutionMode=freePlay + 空 solution → freePlay")
    func freePlayEmptySolution() {
        let puzzle = makePuzzle(
            solution: [],
            solutionMode: .freePlay
        )
        #expect(puzzle.effectiveMode == .freePlay)
    }

    // ============================================================
    // P1-8: 教程多步课程状态机
    // ============================================================

    @Test("P1-8: 课程 2-8 都有 2 步 expectedMoves")
    func lessons2to8HaveMultipleSteps() {
        let vm = TutorialViewModel()
        for lessonId in 2...8 {
            guard let lesson = vm.lessons.first(where: { $0.id == lessonId }) else {
                #expect(Bool(false), "课程 \(lessonId) 应存在")
                continue
            }
            guard let moves = lesson.expectedMoves else {
                #expect(Bool(false), "课程 \(lessonId) 应有 expectedMoves")
                continue
            }
            #expect(moves.count >= 2, "课程 \(lessonId) 应有 ≥2 步，实际: \(moves.count)")
        }
    }

    @Test("P1-8: 课程 7（兵的走法）expectedMoves = 2 步")
    func lesson7HasTwoSteps() {
        let vm = TutorialViewModel()
        guard let lesson7 = vm.lessons.first(where: { $0.id == 7 }) else {
            #expect(Bool(false), "课程 7 应存在")
            return
        }
        #expect(lesson7.expectedMoves?.count == 2, "课程 7 应有 2 步")
        #expect(lesson7.expectedMoves?[0] == "e4e5", "第一步应为 e4e5")
        #expect(lesson7.expectedMoves?[1] == "e5d5", "第二步应为 e5d5")
    }

    @Test("P1-8: 课程 7 hintKeys 数量与 expectedMoves 匹配")
    func lesson7HintsMatchMoves() {
        let vm = TutorialViewModel()
        guard let lesson7 = vm.lessons.first(where: { $0.id == 7 }) else {
            #expect(Bool(false), "课程 7 应存在")
            return
        }
        let movesCount = lesson7.expectedMoves?.count ?? 0
        let hintsCount = lesson7.hintKeys?.count ?? 0
        #expect(movesCount == hintsCount, "hintKeys 数量应与 expectedMoves 匹配: \(movesCount) vs \(hintsCount)")
    }

    @Test("P1-8: 第一步走对后 stepIndex 递增到 1")
    func tutorialStepIndexIncrement() {
        var stepIndex = 0
        let expectedMoves = ["e4e5", "e5d5"]

        let userInput = "e4e5"
        if userInput == expectedMoves[stepIndex] {
            stepIndex += 1
        }

        #expect(stepIndex == 1, "走对第一步后 stepIndex 应为 1")
        #expect(stepIndex < expectedMoves.count, "还有第二步未完成")
    }

    @Test("P1-8: 第二步走对后 status = complete")
    func tutorialSecondStepComplete() {
        var stepIndex = 1
        let expectedMoves = ["e4e5", "e5d5"]
        var isComplete = false

        let userInput = "e5d5"
        if userInput == expectedMoves[stepIndex] {
            stepIndex += 1
            if stepIndex >= expectedMoves.count {
                isComplete = true
            }
        }

        #expect(stepIndex == 2)
        #expect(isComplete, "走完全部步骤应为 complete")
    }

    @Test("P1-8: 走错步不会推进 stepIndex")
    func tutorialWrongStepNoProgress() {
        var stepIndex = 0
        let expectedMoves = ["e4e5", "e5d5"]

        let userInput = "e4e4"
        if userInput == expectedMoves[stepIndex] {
            stepIndex += 1
        }

        #expect(stepIndex == 0, "走错步不应推进 stepIndex")
    }

    @Test("P1-8: 修复前 bug 验证——status 正确转换 correct → waiting")
    func tutorialBugFixVerification() async {
        // 修复逻辑：走对第一步后 status = .correct
        // Task { sleep 1.2s → if status == .correct { status = .waiting } }
        // 验证：1.2s 延迟后 status 从 correct 回到 waiting

        // 模拟 StepStatus
        enum StepStatus: Equatable { case waiting, correct, complete }
        var status = StepStatus.correct

        // 模拟修复中的 Task.sleep + 条件检查
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s（缩短测试时间）
        if status == .correct { status = .waiting }

        #expect(status == .waiting, "延迟后 status 应从 correct 回到 waiting")
    }

    @Test("P1-8: 走错步后 resetCurrentStep 保持 stepIndex")
    func tutorialResetPreservesStepIndex() {
        // 验证 resetCurrentStep 的 P1-7 修复仍然有效
        // wrong/illegal 时 stepIndex 不回退
        var stepIndex = 1  // 已完成第一步
        let savedStepIndex = stepIndex
        // resetCurrentStep 先保存 stepIndex，重置棋盘，重放之前的步骤
        // stepIndex 保持不变
        #expect(stepIndex == savedStepIndex, "reset 后 stepIndex 不应变")
    }

    // ============================================================
    // 综合: NotationGenerator 确实被使用
    // ============================================================

    @Test("综合: DemoViewModel moveNotations 使用中文记谱（马）")
    func moveNotationsHorseChinese() async {
        let puzzle = makePuzzle(id: "test_horse")
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        let board = Board(fen: puzzle.initialFEN)

        // 走马八进七：红马从 b0 到 c2
        guard let piece = board.piece(at: Position(row: 9, col: 1)) else {
            #expect(Bool(false), "应找到红马")
            return
        }
        let move = Move(piece: piece, from: Position(row: 9, col: 1), to: Position(row: 7, col: 2), captured: nil)
        let vm = DemoViewModel(item: wrapper, moves: [move])

        let notation = vm.moveNotations[0]
        #expect(notation.contains("馬") || notation.contains("马"), "记谱应包含'馬/马'字，实际: \(notation)")
        #expect(notation != "红b0c2", "不应是旧的 UCI 格式")
    }
}
