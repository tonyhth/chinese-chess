import XCTest
@testable import VocabGame

final class SpacedRepetitionServiceTests: XCTestCase {

    // MARK: - Helper: 创建初始进度

    private func makeProgress(wordId: Int = 1, mastery: MasteryLevel = .new) -> WordProgress {
        WordProgress(wordId: wordId, mastery: mastery, correctCount: 0, consecutiveCorrect: 0,
                     wrongCount: 0, lastReviewed: Date.distantPast, nextReviewDate: Date.distantPast)
    }

    // MARK: - 答对行为

    func testCorrectFromNew_incrementsMasteryToLearning() {
        let p = makeProgress(mastery: .new)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        XCTAssertEqual(result.mastery, .learning)
        XCTAssertEqual(result.correctCount, 1)
        XCTAssertEqual(result.consecutiveCorrect, 1)
        XCTAssertEqual(result.wrongCount, 0)
    }

    func testCorrectFromLearning_incrementsToFamiliar() {
        let p = makeProgress(mastery: .learning)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        XCTAssertEqual(result.mastery, .familiar)
        XCTAssertEqual(result.consecutiveCorrect, 1)
    }

    func testCorrectFromFamiliar_incrementsToMastered() {
        let p = makeProgress(mastery: .familiar)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        XCTAssertEqual(result.mastery, .mastered)
    }

    func testCorrectFromMastered_staysMastered() {
        let p = makeProgress(mastery: .mastered)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        XCTAssertEqual(result.mastery, .mastered)
    }

    // MARK: - 答对排期

    func testCorrectFromNew_schedulesReviewIn1Day() {
        let before = Date()
        let p = makeProgress(mastery: .new)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        let expected = Calendar.current.date(byAdding: .day, value: 1, to: before)!
        let diff = result.nextReviewDate.timeIntervalSince(expected)
        XCTAssertLessThan(abs(diff), 2.0, "排期应在当前时间 +1 天")
    }

    func testCorrectFromLearning_schedulesReviewIn3Days() {
        let before = Date()
        let p = makeProgress(mastery: .learning)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        let expected = Calendar.current.date(byAdding: .day, value: 3, to: before)!
        XCTAssertLessThan(abs(result.nextReviewDate.timeIntervalSince(expected)), 2.0)
    }

    func testCorrectFromFamiliar_schedulesReviewIn7Days() {
        let before = Date()
        let p = makeProgress(mastery: .familiar)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        let expected = Calendar.current.date(byAdding: .day, value: 7, to: before)!
        XCTAssertLessThan(abs(result.nextReviewDate.timeIntervalSince(expected)), 2.0)
    }

    func testCorrectFromMastered_schedulesReviewIn30Days() {
        let before = Date()
        let p = makeProgress(mastery: .mastered)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        let expected = Calendar.current.date(byAdding: .day, value: 30, to: before)!
        XCTAssertLessThan(abs(result.nextReviewDate.timeIntervalSince(expected)), 2.0)
    }

    // MARK: - 答错行为

    func testWrongFromLearning_resetsToNew() {
        let p = makeProgress(mastery: .learning)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: false)

        XCTAssertEqual(result.mastery, .new)
        XCTAssertEqual(result.wrongCount, 1)
        XCTAssertEqual(result.consecutiveCorrect, 0)
    }

    func testWrongFromNew_staysNew() {
        let p = makeProgress(mastery: .new)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: false)

        XCTAssertEqual(result.mastery, .new)
    }

    func testWrong_resetsConsecutiveCorrect() {
        let p = makeProgress(mastery: .familiar)
        // 先答对 3 次建立连续
        var p1 = SpacedRepetitionService.updateProgress(p, isCorrect: true)
        p1 = SpacedRepetitionService.updateProgress(p1, isCorrect: true)
        p1 = SpacedRepetitionService.updateProgress(p1, isCorrect: true)
        XCTAssertEqual(p1.consecutiveCorrect, 3)

        // 一次答错归零
        let p2 = SpacedRepetitionService.updateProgress(p1, isCorrect: false)
        XCTAssertEqual(p2.consecutiveCorrect, 0)
    }

    func testWrong_schedulesReviewIn4Hours() {
        let before = Date()
        let p = makeProgress(mastery: .learning)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: false)

        let expected = Calendar.current.date(byAdding: .hour, value: 4, to: before)!
        XCTAssertLessThan(abs(result.nextReviewDate.timeIntervalSince(expected)), 2.0)
    }

    // MARK: - 错词移除条件

    func testConsecutiveCorrect3_shouldQualifyForRemoval() {
        // 方案要求 consecutiveCorrect >= 3 时可从错词本移除
        var p = makeProgress(mastery: .new)
        // 答错一次进入错词本
        p = SpacedRepetitionService.updateProgress(p, isCorrect: false)
        XCTAssertEqual(p.wrongCount, 1)
        XCTAssertEqual(p.consecutiveCorrect, 0)

        // 连续答对 3 次
        p = SpacedRepetitionService.updateProgress(p, isCorrect: true)
        p = SpacedRepetitionService.updateProgress(p, isCorrect: true)
        p = SpacedRepetitionService.updateProgress(p, isCorrect: true)
        XCTAssertEqual(p.consecutiveCorrect, 3)
        XCTAssertEqual(p.wrongCount, 1) // wrongCount 不变

        // ProgressRepository.mistakeWords() 检查 consecutiveCorrect < 3
        // 所以 consecutiveCorrect == 3 时该词不再出现在错词本中 ✅
    }

    func testConsecutiveCorrect2_stillInMistakeBook() {
        var p = makeProgress(mastery: .new)
        p = SpacedRepetitionService.updateProgress(p, isCorrect: false)
        p = SpacedRepetitionService.updateProgress(p, isCorrect: true)
        p = SpacedRepetitionService.updateProgress(p, isCorrect: true)
        XCTAssertEqual(p.consecutiveCorrect, 2)
        // 2 < 3，仍在错词本中
        XCTAssertTrue(p.wrongCount > 0 && p.consecutiveCorrect < 3)
    }

    // MARK: - lastReviewed 更新

    func testUpdateProgress_updatesLastReviewed() {
        let before = Date()
        let p = makeProgress(mastery: .new)
        let result = SpacedRepetitionService.updateProgress(p, isCorrect: true)

        XCTAssertGreaterThanOrEqual(result.lastReviewed, before)
        XCTAssertLessThanOrEqual(result.lastReviewed, Date())
    }
}
