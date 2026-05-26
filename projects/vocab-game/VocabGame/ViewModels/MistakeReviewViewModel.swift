import Foundation
import Combine

class MistakeReviewViewModel: ObservableObject {
    @Published var mistakeWords: [(word: Word, progress: WordProgress)] = []

    private let wordRepo: WordRepository
    private let progressRepo: ProgressRepository

    init(wordRepo: WordRepository, progressRepo: ProgressRepository) {
        self.wordRepo = wordRepo
        self.progressRepo = progressRepo
    }

    func load() {
        let mistakes = progressRepo.mistakeWords()
        mistakeWords = mistakes.compactMap { wp in
            guard let word = wordRepo.allWords.first(where: { $0.id == wp.wordId }) else { return nil }
            return (word: word, progress: wp)
        }
    }

    var isEmpty: Bool { mistakeWords.isEmpty }
}
