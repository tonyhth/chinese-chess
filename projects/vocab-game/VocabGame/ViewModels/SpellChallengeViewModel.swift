import Foundation
import SwiftUI

@MainActor
class SpellChallengeViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex = 0
    @Published var spelledAnswer = ""
    @Published var showFeedback = false
    @Published var isCorrect = false
    @Published var score = 0
    @Published var combo = 0
    @Published var maxCombo = 0
    @Published var isCompleted = false
    @Published var hintUsed = false
    @Published var streakTitle = false // "拼写达人" for 5 consecutive correct
    @Published var errorMessage: String?

    private let wordRepo: WordRepository
    private let progressRepo: ProgressRepository
    private let petRepo: PetRepository
    private let coinsPerHint = 10

    var currentWord: Word? {
        guard currentIndex < words.count else { return nil }
        return words[currentIndex]
    }

    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentIndex) / Double(words.count)
    }

    var hintDisplay: String {
        guard let word = currentWord else { return "" }
        if hintUsed {
            // Show first letter + word length
            return "\(word.text.first?.uppercased() ?? "?")... (\(word.text.count)个字母)"
        }
        return "(\(word.text.count)个字母)"
    }

    init(wordRepo: WordRepository, progressRepo: ProgressRepository, petRepo: PetRepository) {
        self.wordRepo = wordRepo
        self.progressRepo = progressRepo
        self.petRepo = petRepo
    }

    func start() {
        let learned = progressRepo.wordProgress.values
            .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
        let allWords = wordRepo.allWords
        words = learned.compactMap { wp -> Word? in
            allWords.first(where: { $0.id == wp.wordId })
        }.shuffled()

        // If not enough learned words, supplement from current playable levels
        if words.count < 10 {
            let learnedIds = Set(words.map { $0.id })
            let unlockedLevels = (1...25).filter { progressRepo.isLevelUnlocked($0) }
            let supplemental = unlockedLevels.flatMap { wordRepo.words(forLevel: $0) }
                .filter { !learnedIds.contains($0.id) }
                .shuffled()
            words.append(contentsOf: supplemental.prefix(10 - words.count))
        }

        words = Array(words.prefix(15)) // Cap at 15
        if words.isEmpty {
            // Fallback: use all words
            words = Array(wordRepo.allWords.shuffled().prefix(10))
        }
        if words.isEmpty {
            errorMessage = "暂无题目数据"
            return
        }
        words.shuffle()
        currentIndex = 0
        score = 0
        combo = 0
        maxCombo = 0
        isCompleted = false
        saveSession()
    }

    func submit() {
        guard let word = currentWord else { return }
        let normalized = spelledAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isCorrect = normalized == word.text.lowercased()
        showFeedback = true

        if isCorrect {
            score += 100 + combo * 20
            combo += 1
            maxCombo = max(maxCombo, combo)
            AudioService.shared.play(.correct)
            if combo >= 5 && !streakTitle {
                streakTitle = true
            }
        } else {
            combo = 0
            AudioService.shared.play(.wrong)
        }

        // Update word progress
        var wp = progressRepo.wordProgress(for: word.id)
        wp = SpacedRepetitionService.updateProgress(wp, isCorrect: isCorrect)
        progressRepo.updateWordProgress(wp)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.advance()
        }
    }

    func useHint() -> Bool {
        guard !hintUsed else { return false }
        let profile = progressRepo.profile
        guard profile.coins >= coinsPerHint else { return false }
        progressRepo.updateProfile { p in
            p.coins -= coinsPerHint
        }
        hintUsed = true
        return true
    }

    private func advance() {
        showFeedback = false
        spelledAnswer = ""
        hintUsed = false
        currentIndex += 1

        if currentIndex >= words.count {
            isCompleted = true
            progressRepo.clearActiveSession()
            saveResult()
        } else {
            saveSession()
        }
    }

    private func saveResult() {
        let coinsEarned = max(score / 100, 1) + (streakTitle ? 10 : 0)
        progressRepo.updateProfile { p in
            p.coins += coinsEarned
        }
        let expGained = score / 10 + maxCombo * 5 + (streakTitle ? 30 : 0)
        _ = petRepo.addExp(expGained)
        progressRepo.recordPlay()
    }

    private func saveSession() {
        // Wrap spell challenge state into a GameSession for persistence
        let questions = words.map { Question(word: $0, type: .spellWord, options: []) }
        var session = GameSession.create(mode: .spellChallenge, questions: questions)
        session.currentIndex = currentIndex
        session.score = score
        session.combo = combo
        session.maxCombo = maxCombo
        progressRepo.saveActiveSession(session)
    }
}
