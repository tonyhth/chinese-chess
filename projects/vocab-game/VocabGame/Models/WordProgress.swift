import Foundation

struct WordProgress: Codable {
    let wordId: Int
    var mastery: MasteryLevel
    var correctCount: Int
    var consecutiveCorrect: Int
    var wrongCount: Int
    var lastReviewed: Date
    var nextReviewDate: Date

    static func initial(wordId: Int) -> WordProgress {
        WordProgress(
            wordId: wordId,
            mastery: .new,
            correctCount: 0,
            consecutiveCorrect: 0,
            wrongCount: 0,
            lastReviewed: Date.distantPast,
            nextReviewDate: Date.distantPast
        )
    }
}

enum MasteryLevel: Int, Codable {
    case new = 0
    case learning = 1
    case familiar = 2
    case mastered = 3
}
