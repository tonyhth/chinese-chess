import XCTest
@testable import VocabGame

final class QuestionTests: XCTestCase {

    private let allWords: [Word] = (1...20).map { i in
        Word(id: i, text: "word\(i)", meaning: "释义\(i)", group: 1)
    }

    // MARK: - selectMeaning

    func testCreateSelectMeaning_has4Options() {
        let word = allWords[0]
        let q = Question.create(word: word, type: .selectMeaning, allWords: allWords)

        XCTAssertEqual(q.type, .selectMeaning)
        XCTAssertEqual(q.options.count, 4)
        XCTAssertTrue(q.options.contains(word.meaning))
    }

    func testCreateSelectMeaning_correctAnswerIsInOptions() {
        let word = allWords[5]
        let q = Question.create(word: word, type: .selectMeaning, allWords: allWords)

        XCTAssertTrue(q.options.contains(word.meaning), "正确答案必须出现在选项中")
    }

    // MARK: - selectWord

    func testCreateSelectWord_has4Options() {
        let word = allWords[0]
        let q = Question.create(word: word, type: .selectWord, allWords: allWords)

        XCTAssertEqual(q.type, .selectWord)
        XCTAssertEqual(q.options.count, 4)
        XCTAssertTrue(q.options.contains(word.text))
    }

    // MARK: - spellWord

    func testCreateSpellWord_hasNoOptions() {
        let word = allWords[0]
        let q = Question.create(word: word, type: .spellWord, allWords: allWords)

        XCTAssertEqual(q.type, .spellWord)
        XCTAssertTrue(q.options.isEmpty)
    }

    // MARK: - listenAndSelect

    func testCreateListenAndSelect_has4Options() {
        let word = allWords[0]
        let q = Question.create(word: word, type: .listenAndSelect, allWords: allWords)

        XCTAssertEqual(q.type, .listenAndSelect)
        XCTAssertEqual(q.options.count, 4)
        XCTAssertTrue(q.options.contains(word.text))
    }

    // MARK: - 边界：词库不足

    func testCreate_withInsufficientWords_stillHas4Options() {
        // 只有 2 个词时，应填充 "(无选项)" 占位符
        let smallList: [Word] = [
            Word(id: 1, text: "hello", meaning: "你好", group: 1),
            Word(id: 2, text: "world", meaning: "世界", group: 1),
        ]
        let q = Question.create(word: smallList[0], type: .selectMeaning, allWords: smallList)

        XCTAssertEqual(q.options.count, 4, "词库不足时应用占位符填充到 4 个")
        XCTAssertTrue(q.options.contains("你好"))
        XCTAssertTrue(q.options.contains(smallList[0].meaning))
    }

    func testCreate_withOnlyOneWord_stillHas4Options() {
        let single: [Word] = [
            Word(id: 1, text: "hello", meaning: "你好", group: 1),
        ]
        let q = Question.create(word: single[0], type: .selectWord, allWords: single)

        XCTAssertEqual(q.options.count, 4)
        XCTAssertTrue(q.options.contains("hello"))
        // 应有 3 个 "(无选项)" 占位
        let placeholderCount = q.options.filter { $0 == "(无选项)" }.count
        XCTAssertEqual(placeholderCount, 3)
    }

    // MARK: - 边界：空词库

    func testCreate_withEmptyAllWords_throwsNoCrash() {
        // 全局只有目标词
        let word = Word(id: 1, text: "hello", meaning: "你好", group: 1)
        let q = Question.create(word: word, type: .selectMeaning, allWords: [word])

        XCTAssertEqual(q.options.count, 4)
    }

    // MARK: - 初始状态

    func testQuestion_initialIsCorrectIsNil() {
        let word = allWords[0]
        let q = Question(word: word, type: .selectMeaning, options: ["a", "b", "c", "d"])

        XCTAssertNil(q.isCorrect)
    }
}
