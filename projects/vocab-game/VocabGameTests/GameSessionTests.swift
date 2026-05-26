import XCTest
@testable import VocabGame

final class GameSessionTests: XCTestCase {

    private let sampleWords: [Word] = (1...10).map { i in
        Word(id: i, text: "word\(i)", meaning: "释义\(i)", group: 1)
    }

    private func makeQuestions(count: Int = 10) -> [Question] {
        sampleWords.prefix(count).map { word in
            Question(word: word, type: .selectMeaning,
                     options: [word.meaning, "干扰A", "干扰B", "干扰C"])
        }
    }

    // MARK: - 创建

    func testCreate_initialState() {
        let questions = makeQuestions()
        let session = GameSession.create(mode: .adventure, levelId: 1, questions: questions)

        XCTAssertEqual(session.gameMode, .adventure)
        XCTAssertEqual(session.levelId, 1)
        XCTAssertEqual(session.questions.count, 10)
        XCTAssertEqual(session.currentIndex, 0)
        XCTAssertEqual(session.score, 0)
        XCTAssertEqual(session.combo, 0)
        XCTAssertEqual(session.maxCombo, 0)
        XCTAssertFalse(session.isCompleted)
    }

    func testCreate_dailyChallenge_noLevelId() {
        let session = GameSession.create(mode: .dailyChallenge, levelId: nil, questions: makeQuestions())
        XCTAssertNil(session.levelId)
    }

    // MARK: - currentQuestion

    func testCurrentQuestion_atStart_returnsFirstQuestion() {
        let session = GameSession.create(mode: .adventure, levelId: 1, questions: makeQuestions())
        XCTAssertEqual(session.currentQuestion?.word.id, 1)
    }

    func testCurrentQuestion_afterAdvancing_returnsCorrectQuestion() {
        var session = GameSession.create(mode: .adventure, levelId: 1, questions: makeQuestions())
        session.currentIndex = 5
        XCTAssertEqual(session.currentQuestion?.word.id, 6)
    }

    func testCurrentQuestion_pastEnd_returnsNil() {
        var session = GameSession.create(mode: .adventure, levelId: 1, questions: makeQuestions())
        session.currentIndex = 10
        XCTAssertNil(session.currentQuestion)
    }

    // MARK: - progress

    func testProgress_atStart_isZero() {
        let session = GameSession.create(mode: .adventure, levelId: 1, questions: makeQuestions())
        XCTAssertEqual(session.progress, 0.0)
    }

    func testProgress_halfWay_isHalf() {
        var session = GameSession.create(mode: .adventure, levelId: 1, questions: makeQuestions())
        session.currentIndex = 5
        XCTAssertEqual(session.progress, 0.5)
    }

    func testProgress_completed_is1() {
        var session = GameSession.create(mode: .adventure, levelId: 1, questions: makeQuestions())
        session.currentIndex = 10
        XCTAssertEqual(session.progress, 1.0)
    }

    func testProgress_emptyQuestions_isZero() {
        let session = GameSession.create(mode: .adventure, levelId: 1, questions: [])
        XCTAssertEqual(session.progress, 0.0)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let session = GameSession.create(mode: .adventure, levelId: 3, questions: makeQuestions())
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(GameSession.self, from: data)

        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.gameMode, session.gameMode)
        XCTAssertEqual(decoded.levelId, session.levelId)
        XCTAssertEqual(decoded.score, session.score)
        XCTAssertEqual(decoded.questions.count, session.questions.count)
    }
}
