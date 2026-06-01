import Foundation

struct GameSession: Codable {
    let id: UUID
    let gameMode: GameMode
    let levelId: Int?
    let startTime: Date
    var questions: [Question]
    var currentIndex: Int
    var score: Int
    var combo: Int
    var maxCombo: Int
    var isCompleted: Bool
    var remainingSeconds: Int? = nil   // 仅 dailyChallenge 使用，保存计时器状态

    static func create(mode: GameMode, levelId: Int? = nil, questions: [Question]) -> GameSession {
        GameSession(
            id: UUID(),
            gameMode: mode,
            levelId: levelId,
            startTime: Date(),
            questions: questions,
            currentIndex: 0,
            score: 0,
            combo: 0,
            maxCombo: 0,
            isCompleted: false
        )
    }

    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }
}

enum GameMode: String, Codable, CaseIterable {
    case adventure
    case spellChallenge
    case dictation
    case matchPairs
    case wordRunner
    case dailyChallenge
    case mistakeReview
}

struct Question: Codable {
    let word: Word
    let type: QuestionType
    var options: [String]
    var isCorrect: Bool? = nil

    static func create(word: Word, type: QuestionType, allWords: [Word]) -> Question {
        let options: [String]
        switch type {
        case .selectMeaning:
            let correctAnswer = word.meaning
            var distractors = Array(Set(
                allWords
                    .filter { $0.id != word.id && $0.meaning != correctAnswer }
                    .map { $0.meaning }
            ))
            distractors.shuffle()
            let selected = Array(distractors.prefix(3))
            var padded = selected
            while padded.count < 3 {
                padded.append("(无选项)")
            }
            padded.append(correctAnswer)
            options = padded.shuffled()
        case .selectWord, .listenAndSelect:
            let correctAnswer = word.text
            var distractors = Array(Set(
                allWords
                    .filter { $0.id != word.id && $0.text != correctAnswer }
                    .map { $0.text }
            ))
            distractors.shuffle()
            let selected = Array(distractors.prefix(3))
            var padded = selected
            while padded.count < 3 {
                padded.append("(无选项)")
            }
            padded.append(correctAnswer)
            options = padded.shuffled()
        case .spellWord:
            options = []
        }
        return Question(word: word, type: type, options: options)
    }
}

enum QuestionType: String, Codable, CaseIterable {
    case selectMeaning
    case selectWord
    case spellWord
    case listenAndSelect
}
