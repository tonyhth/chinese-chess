import Foundation
import SwiftUI

@MainActor
class DailyChallengeViewModel: ObservableObject {
    @Published var session: GameSession? = nil
    @Published var selectedAnswer: String? = nil
    @Published var spelledAnswer: String = ""
    @Published var showAnswerFeedback = false
    @Published var isAnswerCorrect = false
    @Published var isShowingResult = false
    @Published var remainingSeconds: Int = 180 // 3 minutes
    @Published var todayCompleted = false
    @Published var todayBestScore = 0
    @Published var coinsEarned: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    nonisolated(unsafe) private var timer: Timer?
    private let wordRepo: WordRepository
    private let progressRepo: ProgressRepository
    private let petRepo: PetRepository

    init(wordRepo: WordRepository, progressRepo: ProgressRepository, petRepo: PetRepository) {
        self.wordRepo = wordRepo
        self.progressRepo = progressRepo
        self.petRepo = petRepo
    }

    func start() {
        // Check if already completed today
        todayCompleted = progressRepo.isDailyCompleted
        todayBestScore = progressRepo.dailyBestScore

        guard !todayCompleted else { return }

        isLoading = true

        // Generate questions using date as seed for deterministic daily set
        let today = Date()
        let seed = Calendar.current.component(.day, from: today) * 10000
            + Calendar.current.component(.month, from: today) * 100
            + Calendar.current.component(.year, from: today) % 100

        // Get learned words (mastery >= .learning)
        var candidates = progressRepo.wordProgress.values
            .filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }
            .compactMap { wp in wordRepo.allWords.first(where: { $0.id == wp.wordId }) }

        // Supplement if not enough learned words: use unlocked level words
        if candidates.count < 15 {
            let learnedIds = Set(candidates.map { $0.id })
            let unlockedLevels = (1...25).filter { progressRepo.isLevelUnlocked($0) }
            let supplemental = unlockedLevels.flatMap { wordRepo.words(forLevel: $0) }
                .filter { !learnedIds.contains($0.id) }
            candidates.append(contentsOf: supplemental)
        }

        // Fallback: if still not enough, use level 1 words (always available)
        if candidates.count < 5 {
            let existingIds = Set(candidates.map { $0.id })
            let level1Words = wordRepo.words(forLevel: 1)
                .filter { !existingIds.contains($0.id) }
            candidates.append(contentsOf: level1Words)
        }

        // Seeded shuffle using the date-based seed
        var generator = SeededRandomGenerator(seed: seed)
        let shuffled = candidates.shuffled(using: &generator)
        let selected = Array(shuffled.prefix(15))

        guard !selected.isEmpty else {
            isLoading = false
            errorMessage = "暂无可用单词，请先学习一些单词再挑战"
            return
        }

        let allWords = wordRepo.allWords
        var questions: [Question] = []
        for (i, word) in selected.enumerated() {
            let type: QuestionType
            switch i % 4 {
            case 0: type = .selectMeaning
            case 1: type = .selectWord
            case 2: type = .listenAndSelect
            default: type = .spellWord
            }
            questions.append(Question.create(word: word, type: type, allWords: allWords))
        }

        session = GameSession.create(mode: .dailyChallenge, questions: questions)
        remainingSeconds = 180
        isLoading = false
        progressRepo.saveActiveSession(session)
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.timer?.invalidate()
                    self.forceEnd()
                }
            }
        }
    }

    func selectAnswer(_ answer: String, question: Question) {
        guard var s = session else { return }
        selectedAnswer = answer

        switch question.type {
        case .selectMeaning: isAnswerCorrect = answer == question.word.meaning
        case .selectWord, .listenAndSelect: isAnswerCorrect = answer == question.word.text
        case .spellWord: return
        }

        showAnswerFeedback = true
        s.questions[s.currentIndex].isCorrect = isAnswerCorrect
        applyScore(isCorrect: isAnswerCorrect, session: &s, wordId: question.word.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.advance() }
    }

    func submitSpelling() {
        guard var s = session, let question = s.currentQuestion else { return }
        let normalized = spelledAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isAnswerCorrect = normalized == question.word.text.lowercased()
        showAnswerFeedback = true
        s.questions[s.currentIndex].isCorrect = isAnswerCorrect
        applyScore(isCorrect: isAnswerCorrect, session: &s, wordId: question.word.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.advance() }
    }

    private func applyScore(isCorrect: Bool, session: inout GameSession, wordId: Int) {
        if isCorrect {
            session.score += 100 + session.combo * 20
            session.combo += 1
            session.maxCombo = max(session.maxCombo, session.combo)
            AudioService.shared.play(.correct)
            if session.combo >= 3 { AudioService.shared.play(.combo) }
        } else {
            session.combo = 0
            AudioService.shared.play(.wrong)
        }
        self.session = session

        var wp = progressRepo.wordProgress(for: wordId)
        wp = SpacedRepetitionService.updateProgress(wp, isCorrect: isCorrect)
        progressRepo.updateWordProgress(wp)
    }

    private func advance() {
        guard var s = session else { return }
        selectedAnswer = nil
        spelledAnswer = ""
        showAnswerFeedback = false

        s.currentIndex += 1
        if s.currentIndex >= s.questions.count {
            s.isCompleted = true
            isShowingResult = true
            timer?.invalidate()
            progressRepo.clearActiveSession()
            saveResult(s)
        } else {
            progressRepo.saveActiveSession(s)
        }
        session = s
    }

    private func forceEnd() {
        guard var s = session else { return }
        s.isCompleted = true
        isShowingResult = true
        session = s
        saveResult(s)
    }

    private func saveResult(_ s: GameSession) {
        // Daily reward: coins + streak bonus
        coinsEarned = max(s.score / 100, 5) + 10 // Base daily reward
        progressRepo.updateProfile { p in
            p.coins += coinsEarned
        }

        // Update daily record via ProgressRepository
        progressRepo.recordDailyCompletion(score: s.score)
        todayBestScore = progressRepo.dailyBestScore
        todayCompleted = true

        let expGained = s.score / 10 + s.maxCombo * 5 + 30 // Daily bonus
        _ = petRepo.addExp(expGained)
        progressRepo.recordPlay()
    }

    func correctAnswer(for question: Question) -> String {
        switch question.type {
        case .selectMeaning: return question.word.meaning
        case .selectWord, .listenAndSelect: return question.word.text
        case .spellWord: return question.word.text
        }
    }

    deinit {
        timer?.invalidate()
    }
}
