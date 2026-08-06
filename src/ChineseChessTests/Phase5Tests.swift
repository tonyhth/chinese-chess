import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 5 新手引导 + 选边测试")
struct Phase5Tests {

    // MARK: - TutorialViewModel 测试

    @MainActor
@Test("教程包含 12 步课程")
    func tutorialHasTwelveLessons() {
        let vm = TutorialViewModel()
        #expect(vm.lessons.count == 12, "应有 12 步教程")
    }

    @MainActor
@Test("课程标题正确")
    func lessonTitlesCorrect() {
        let vm = TutorialViewModel()
        #expect(vm.lessons[0].titleKey == "tutorial.lesson0.title")
        #expect(vm.lessons[1].titleKey == "tutorial.lesson1.title")
        #expect(vm.lessons[2].titleKey == "tutorial.lesson2.title")
        #expect(vm.lessons[3].titleKey == "tutorial.lesson3.title")
        #expect(vm.lessons[4].titleKey == "tutorial.lesson4.title")
        #expect(vm.lessons[11].titleKey == "tutorial.lesson11.title")
    }

    @MainActor
@Test("下一课功能")
    func nextLesson() {
        let vm = TutorialViewModel()
        #expect(vm.currentLesson == 0)
        vm.nextLesson()
        #expect(vm.currentLesson == 1)
        vm.nextLesson()
        #expect(vm.currentLesson == 2)
    }

    @MainActor
@Test("上一课功能")
    func previousLesson() {
        let vm = TutorialViewModel()
        vm.currentLesson = 2
        vm.previousLesson()
        #expect(vm.currentLesson == 1)
    }

    @MainActor
@Test("上一课不越界（第 0 课不能再退）")
    func previousLessonAtZero() {
        let vm = TutorialViewModel()
        vm.previousLesson()
        #expect(vm.currentLesson == 0)
    }

    @MainActor
@Test("下一课不越界（最后一课不能再进）")
    func nextLessonAtLast() {
        let vm = TutorialViewModel()
        vm.currentLesson = vm.lessons.count - 1
        vm.nextLesson()
        #expect(vm.currentLesson == vm.lessons.count - 1)
    }

    @MainActor
@Test("isLastLesson 判断")
    func isLastLesson() {
        let vm = TutorialViewModel()
        #expect(vm.isLastLesson == false)
        vm.currentLesson = vm.lessons.count - 1
        #expect(vm.isLastLesson == true)
    }

    @MainActor
@Test("走法课3（马）数据正确")
    func knightLessonData() {
        let vm = TutorialViewModel()
        let lesson = vm.lessons[3]
        #expect(lesson.descriptionKey == "tutorial.lesson3.description")
        #expect(lesson.titleKey == "tutorial.lesson3.title")
        #expect(lesson.type == .interactive)
        #expect(lesson.expectedMoves?.count == 2, "课3（马）应有2步")
    }

    // MARK: - 教程完成状态

    @MainActor
@Test("教程完成标记和重置")
    func tutorialCompletionTracking() {
        TutorialViewModel.resetTutorial()
        #expect(TutorialViewModel.hasCompletedTutorial == false)

        TutorialViewModel.markTutorialCompleted()
        #expect(TutorialViewModel.hasCompletedTutorial == true)

        TutorialViewModel.resetTutorial()
        #expect(TutorialViewModel.hasCompletedTutorial == false)
    }

    // MARK: - 选边测试

    @MainActor
@Test("GameViewModel 默认执红")
    func gameViewModelDefaultSide() {
        let vm = GameViewModel()
        // 清除 UserDefaults 可能的残留
        UserDefaults.standard.removeObject(forKey: "chinesechess.humanSide")
        let freshVM = GameViewModel()
        #expect(freshVM.humanSide == .red, "默认应执红")
    }

    @MainActor
@Test("GameViewModel 切换执边")
    func gameViewModelSwitchSide() {
        let vm = GameViewModel()
        vm.setHumanSide(.black)
        #expect(vm.humanSide == .black)
        #expect(UserDefaults.standard.string(forKey: "chinesechess.humanSide") == "black")

        vm.setHumanSide(.red)
        #expect(vm.humanSide == .red)
        #expect(UserDefaults.standard.string(forKey: "chinesechess.humanSide") == "red")

        // 清理
        UserDefaults.standard.removeObject(forKey: "chinesechess.humanSide")
    }

    @MainActor
@Test("选边后 newGame 正常执行")
    func newGameAfterSideSelection() {
        let vm = GameViewModel()
        vm.setHumanSide(.red)
        vm.newGame()
        #expect(vm.gameState == .playing)
        #expect(vm.board.currentTurn == .red)

        // 清理
        UserDefaults.standard.removeObject(forKey: "chinesechess.humanSide")
    }

    @MainActor
@Test("执黑时玩家选择对方棋子无效")
    func blackSideCannotSelectRedPieces() {
        let vm = GameViewModel()
        vm.setHumanSide(.black)
        // 标准局面，红方在底部（row 9 附近）
        // 玩家执黑时不能选择红方棋子
        let redPiecePos = Position(row: 9, col: 0)  // 红车
        vm.selectPiece(at: redPiecePos)
        #expect(vm.selectedPosition == nil, "执黑时不能选择红方棋子")

        // 清理
        UserDefaults.standard.removeObject(forKey: "chinesechess.humanSide")
    }

    @MainActor
@Test("各难度 AI 返回合法走法（选边后）")
    func allDifficultiesWithSideSelection() {
        for side in [Side.red, .black] {
            let vm = GameViewModel()
            vm.setHumanSide(side)
            vm.newGame()
            #expect(vm.gameState == .playing, "选边后应正常开始对局")
        }
        UserDefaults.standard.removeObject(forKey: "chinesechess.humanSide")
    }
}
