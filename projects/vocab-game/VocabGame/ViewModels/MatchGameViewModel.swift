import Foundation
import SwiftUI

struct MatchCard: Identifiable {
    let id: Int
    let text: String
    let pairId: Int       // links word card to meaning card
    let isWord: Bool      // true = word side, false = meaning side
    var isFlipped = false
    var isMatched = false
}

@MainActor
class MatchGameViewModel: ObservableObject {
    @Published var cards: [MatchCard] = []
    @Published var flippedIndices: Set<Int> = []
    @Published var score = 0
    @Published var moves = 0
    @Published var matchedPairs = 0
    @Published var totalPairs = 0
    @Published var isCompleted = false
    @Published var remainingSeconds: Int = 60
    @Published var isChecking = false
    @Published var errorMessage: String?
    @Published var sameTypeFlip = false

    nonisolated(unsafe) private var timer: Timer?
    private let wordRepo: WordRepository
    private let progressRepo: ProgressRepository
    private let petRepo: PetRepository

    init(wordRepo: WordRepository, progressRepo: ProgressRepository, petRepo: PetRepository) {
        self.wordRepo = wordRepo
        self.progressRepo = progressRepo
        self.petRepo = petRepo
    }

    func start(forLevel levelId: Int? = nil) {
        // Pick 8 word-meaning pairs
        var candidates: [Word]

        if let levelId = levelId {
            // Prioritize unmastered words from this level
            let levelWords = wordRepo.words(forLevel: levelId)
            let unmastered = levelWords.filter { wp in
                let p = progressRepo.wordProgress(for: wp.id)
                return p.mastery != .mastered
            }
            candidates = unmastered.isEmpty ? levelWords : unmastered
        } else {
            // From mistake words + learned words
            let mistakes = progressRepo.mistakeWords()
            let mistakeWords = mistakes.compactMap { wp in
                wordRepo.allWords.first(where: { $0.id == wp.wordId })
            }
            let learned = progressRepo.wordProgress.values
                .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
                .compactMap { wp in wordRepo.allWords.first(where: { $0.id == wp.wordId }) }

            candidates = mistakeWords
            candidates.append(contentsOf: learned.filter { w in
                !candidates.contains(where: { $0.id == w.id })
            })
        }

        let selected = Array(candidates.shuffled().prefix(8))
        guard selected.count >= 4 else {
            // Not enough words for a meaningful game
            candidates = wordRepo.allWords.shuffled()
            let fallback = Array(candidates.prefix(8))
            if fallback.isEmpty {
                errorMessage = "暂无题目数据"
                return
            }
            setupCards(with: fallback)
            return
        }
        setupCards(with: selected)
    }

    private func setupCards(with words: [Word]) {
        totalPairs = words.count
        matchedPairs = 0
        score = 0
        moves = 0
        isCompleted = false
        remainingSeconds = 60

        var newCards: [MatchCard] = []
        for (i, word) in words.enumerated() {
            newCards.append(MatchCard(id: i * 2, text: word.text, pairId: i, isWord: true))
            newCards.append(MatchCard(id: i * 2 + 1, text: word.meaning, pairId: i, isWord: false))
        }
        cards = newCards.shuffled()
        flippedIndices = []

        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        remainingSeconds = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.timer?.invalidate()
                    self.endGame()
                }
            }
        }
    }

    func flipCard(at index: Int) {
        guard !isChecking else { return }
        guard cards[index].isFlipped == false && cards[index].isMatched == false else { return }
        guard flippedIndices.count < 2 else { return }

        cards[index].isFlipped = true
        flippedIndices.insert(index)
        AudioService.shared.play(.flip)

        if flippedIndices.count == 2 {
            let indices = Array(flippedIndices)
            let card1 = cards[indices[0]]
            let card2 = cards[indices[1]]

            // 同类型检查：两张都是英文或两张都是中文，直接翻回，不计步数
            if card1.isWord == card2.isWord {
                sameTypeFlip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }
                    self.cards[indices[0]].isFlipped = false
                    self.cards[indices[1]].isFlipped = false
                    self.flippedIndices = []
                }
                return
            }

            isChecking = true
            checkMatch()
        }
    }

    private func checkMatch() {
        let indices = Array(flippedIndices)
        guard indices.count == 2 else { return }
        let card1 = cards[indices[0]]
        let card2 = cards[indices[1]]

        if card1.pairId == card2.pairId {
            // Match!
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.cards[indices[0]].isMatched = true
                self.cards[indices[1]].isMatched = true
                self.matchedPairs += 1
                self.moves += 1
                self.score += 50 + self.remainingSeconds // Faster = more points
                self.flippedIndices = []
                self.isChecking = false
                AudioService.shared.play(.match)

                // Update word progress for matched pair
                let wordText = card1.isWord ? card1.text : card2.text
                if let word = self.wordRepo.allWords.first(where: { $0.text == wordText }) {
                    var wp = self.progressRepo.wordProgress(for: word.id)
                    wp = SpacedRepetitionService.updateProgress(wp, isCorrect: true)
                    self.progressRepo.updateWordProgress(wp)
                }

                if self.matchedPairs >= self.totalPairs {
                    self.timer?.invalidate()
                    self.endGame()
                }
            }
        } else {
            // No match
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                self.cards[indices[0]].isFlipped = false
                self.cards[indices[1]].isFlipped = false
                self.moves += 1
                self.flippedIndices = []
                self.isChecking = false
                AudioService.shared.play(.wrong)

                // Update word progress for failed match (both cards involved)
                let wordText1 = card1.isWord ? card1.text : nil
                let wordText2 = card2.isWord ? card2.text : nil
                for text in [wordText1, wordText2].compactMap({ $0 }) {
                    if let word = self.wordRepo.allWords.first(where: { $0.text == text }) {
                        var wp = self.progressRepo.wordProgress(for: word.id)
                        wp = SpacedRepetitionService.updateProgress(wp, isCorrect: false)
                        self.progressRepo.updateWordProgress(wp)
                    }
                }
            }
        }
    }

    private func endGame() {
        isCompleted = true
        // Time bonus
        score += remainingSeconds * 5
        saveResult()
    }

    private func saveResult() {
        let coinsEarned = max(score / 50, 1)
        progressRepo.updateProfile { p in
            p.coins += coinsEarned
        }
        let expGained = score / 10
        _ = petRepo.addExp(expGained)
        progressRepo.recordPlay()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
