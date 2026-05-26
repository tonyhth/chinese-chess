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
    case matchPairs
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
            var distractors = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.meaning }
            // Pad if not enough distractors
            while distractors.count < 3 {
                distractors.append("(无选项)")
            }
            distractors.append(word.meaning)
            options = distractors.shuffled()
        case .selectWord:
            var distractors = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.text }
            while distractors.count < 3 {
                distractors.append("(无选项)")
            }
            distractors.append(word.text)
            options = distractors.shuffled()
        case .spellWord:
            options = []
        case .listenAndSelect:
            var distractors = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.text }
            while distractors.count < 3 {
                distractors.append("(无选项)")
            }
            distractors.append(word.text)
            options = distractors.shuffled()
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
