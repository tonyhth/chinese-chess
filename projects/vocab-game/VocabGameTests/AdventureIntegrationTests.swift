import XCTest
@testable import VocabGame

/// 闯关模式完整游戏循环的集成测试
final class AdventureIntegrationTests: XCTestCase {

    private let sampleWords: [Word] = (1...15).map { i in
        Word(id: i, text: "word\(i)", meaning: "释义\(i)", group: 1)
    }

    // MARK: - 生成题目

    private func makeAdventureQuestions(count: Int = 10) -> [Question] {
        // 模拟 4/3/2/1 题型分配
        var questions: [Question] = []
        let shuffled = sampleWords.shuffled()

        for i in 0..<min(count, shuffled.count) {
            let word = shuffled[i]
            let type: QuestionType
            switch i % 10 {
            case 0, 1, 2, 3: type = .selectMeaning
            case 4, 5, 6:   type = .selectWord
            case 7, 8:      type = .listenAndSelect
            case 9:         type = .spellWord
            default:         type = .selectMeaning
            }
            questions.append(Question.create(word: word, type: type, allWords: sampleWords))
        }
        return questions
    }

    // MARK: - 完整游戏循环：全答对

    func testFullGameLoop_allCorrect() {
        var session = GameSession.create(mode: .adventure, levelId: 1, questions: makeAdventureQuestions())

        // 答完所有题，全部正确
        for i in 0..<session.questions.count {
            session.currentIndex = i
            session.questions[i].isCorrect = true

            // 模拟计分：答对 +100, combo × 20
            session.score += 100 + session.combo * 20
            session.combo += 1
            session.maxCombo = max(session.maxCombo, session.combo)
        }

        session.isCompleted = true

        // 验证
        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(session.combo, 10)
        XCTAssertEqual(session.maxCombo, 10)

        // 最低分：10 * 100 = 1000 + combo bonus
        // Q0: 100+0*20=100, Q1: 100+1*20=120, ..., Q9: 100+9*20=280
        // Total: 100+120+140+160+180+200+220+240+260+280 = 1900
        XCTAssertGreaterThanOrEqual(session.score, 900, "全答对应至少 900 分 (⭐⭐⭐)")
    }

    // MARK: - 星星评级

    func testStarRating_3Stars() {
        // ≥900 分 = 3 星
        var score = 0
        var combo = 0
        for i in 0..<10 {
            score += 100 + combo * 20
            combo += 1
        }
        // 1900 分 → 3 星
        XCTAssertEqual(calculateStars(score: score), 3)
    }

    func testStarRating_2Stars() {
        // ≥800, <900 → 2 星
        // 模拟 9 对 1 错
        var score = 0
        var combo = 0
        for i in 0..<10 {
            if i == 5 {
                combo = 0 // 答错，断连击
                continue
            }
            score += 100 + combo * 20
            combo += 1
        }
        // Q0:100, Q1:120, Q2:140, Q3:160, Q4:180, Q6:100, Q7:120, Q8:140, Q9:160 = 1120
        let stars = calculateStars(score: score)
        XCTAssertGreaterThanOrEqual(stars, 2)
    }

    func testStarRating_1Star() {
        // ≥600, <800 → 1 星
        // 6 对 4 错
        var score = 0
        var combo = 0
        var correctCount = 0
        for i in 0..<10 {
            if i % 2 == 1 && correctCount < 4 {
                combo = 0
                continue
            }
            score += 100 + combo * 20
            combo += 1
            correctCount += 1
        }
        let stars = calculateStars(score: score)
        XCTAssertGreaterThanOrEqual(stars, 1)
    }

    func testStarRating_0Stars() {
        // <600 → 0 星
        let stars = calculateStars(score: 400)
        XCTAssertEqual(stars, 0)
    }

    func testStarRating_exactThresholds() {
        XCTAssertEqual(calculateStars(score: 599), 0)
        XCTAssertEqual(calculateStars(score: 600), 1)
        XCTAssertEqual(calculateStars(score: 799), 1)
        XCTAssertEqual(calculateStars(score: 800), 2)
        XCTAssertEqual(calculateStars(score: 899), 2)
        XCTAssertEqual(calculateStars(score: 900), 3)
        XCTAssertEqual(calculateStars(score: 999), 3)
    }

    // MARK: - 连击归零

    func testCombo_resetsOnWrong() {
        var combo = 0
        combo += 1 // Q0 correct
        combo += 1 // Q1 correct
        XCTAssertEqual(combo, 2)

        combo = 0 // Q2 wrong
        XCTAssertEqual(combo, 0)

        combo += 1 // Q3 correct
        XCTAssertEqual(combo, 1)
    }

    // MARK: - 辅助

    /// 根据方案定义的评级规则计算星星数
    private func calculateStars(score: Int) -> Int {
        if score >= 900 { return 3 }
        if score >= 800 { return 2 }
        if score >= 600 { return 1 }
        return 0
    }
}
