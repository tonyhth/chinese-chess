import Foundation
import SwiftUI

@MainActor
class WordRunnerViewModel: ObservableObject {
    @Published var fallingWords: [FallingWord] = []
    @Published var lanes: [LaneOption] = [LaneOption(text: "", isCorrect: false), LaneOption(text: "", isCorrect: false), LaneOption(text: "", isCorrect: false)]
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var lives: Int = 3
    @Published var isRunning: Bool = false
    @Published var isCompleted: Bool = false
    @Published var timeRemaining: Int = 60
    @Published var errorMessage: String?

    private let wordRepo: WordRepository
    private let progressRepo: ProgressRepository
    private let petRepo: PetRepository

    private var allWords: [Word] = []
    private var usedWordIds: Set<Int> = []
    private var gameTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var fallSpeed: Double = 2.0 // seconds per step
    private var currentCorrectWord: Word?

    struct FallingWord: Identifiable {
        let id = UUID()
        let word: Word
        var y: CGFloat
        let lane: Int // -1 = not in lane yet
        var isFalling: Bool = true
    }

    struct LaneOption {
        var text: String
        var isCorrect: Bool
    }

    init(wordRepo: WordRepository, progressRepo: ProgressRepository, petRepo: PetRepository) {
        self.wordRepo = wordRepo
        self.progressRepo = progressRepo
        self.petRepo = petRepo
    }

    func start() {
        allWords = wordRepo.allWords.shuffled()
        if allWords.count < 4 {
            errorMessage = "单词数量不足"
            return
        }
        score = 0
        combo = 0
        maxCombo = 0
        lives = 3
        timeRemaining = 60
        fallSpeed = 2.0
        isRunning = true
        isCompleted = false
        usedWordIds = []
        fallingWords = []

        spawnNextWord()
        startGameLoop()
        startTimer()
    }

    func stop() {
        gameTask?.cancel()
        timerTask?.cancel()
        isRunning = false
    }

    private func startGameLoop() {
        gameTask = Task { @MainActor in
            while isRunning && lives > 0 && timeRemaining > 0 {
                try? await Task.sleep(for: .seconds(fallSpeed))
                guard !Task.isCancelled else { return }

                // Move falling words down
                for i in fallingWords.indices {
                    fallingWords[i].y += 0.15
                }

                // Check if any word reached bottom without being caught
                let missed = fallingWords.filter { $0.y >= 1.0 && $0.isFalling }
                for word in missed {
                    if let idx = fallingWords.firstIndex(where: { $0.id == word.id }) {
                        fallingWords[idx].isFalling = false
                        lives -= 1
                        combo = 0
                        AudioService.shared.play(.wrong)
                    }
                }

                // Remove old words
                fallingWords.removeAll { $0.y >= 1.3 }

                // Spawn new word if current one is halfway or gone
                if fallingWords.filter({ $0.isFalling }).isEmpty {
                    spawnNextWord()
                }

                // Speed up
                if timeRemaining < 40 { fallSpeed = 1.5 }
                if timeRemaining < 20 { fallSpeed = 1.2 }
                if timeRemaining < 10 { fallSpeed = 1.0 }
            }

            if lives <= 0 || timeRemaining <= 0 {
                endGame()
            }
        }
    }

    private func startTimer() {
        timerTask = Task { @MainActor in
            while isRunning && timeRemaining > 0 && lives > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }
            if timeRemaining <= 0 {
                endGame()
            }
        }
    }

    private func spawnNextWord() {
        let available = allWords.filter { !usedWordIds.contains($0.id) }
        guard let correctWord = available.randomElement() else {
            // Reset used words if exhausted
            usedWordIds = []
            guard let word = allWords.randomElement() else { return }
            spawnWordOptions(correct: word)
            return
        }
        usedWordIds.insert(correctWord.id)
        spawnWordOptions(correct: correctWord)
    }

    private func spawnWordOptions(correct: Word) {
        currentCorrectWord = correct
        let wrongWords = allWords.filter { $0.id != correct.id }.shuffled().prefix(2).map { $0.meaning }

        var options = [correct.meaning] + Array(wrongWords)
        options.shuffle()

        lanes = options.enumerated().map { (idx, text) in
            LaneOption(text: text, isCorrect: text == correct.meaning)
        }

        fallingWords.append(FallingWord(word: correct, y: 0, lane: -1))
    }

    func selectLane(_ laneIndex: Int) {
        guard laneIndex < lanes.count else { return }
        guard let fallingIdx = fallingWords.firstIndex(where: { $0.isFalling }) else { return }

        if lanes[laneIndex].isCorrect {
            // Correct!
            score += 100 + combo * 10
            combo += 1
            maxCombo = max(maxCombo, combo)
            AudioService.shared.play(.correct)
        } else {
            // Wrong
            lives -= 1
            combo = 0
            AudioService.shared.play(.wrong)
        }

        fallingWords[fallingIdx].isFalling = false

        if lives <= 0 {
            endGame()
        } else {
            // Spawn next immediately
            spawnNextWord()
        }
    }

    private func endGame() {
        guard !isCompleted else { return }
        isRunning = false
        isCompleted = true
        gameTask?.cancel()
        timerTask?.cancel()

        // Rewards
        let coinsEarned = max(score / 100, 1)
        progressRepo.updateProfile { p in
            p.coins += coinsEarned
        }
        _ = petRepo.addExp(30)
        progressRepo.recordPlay()
    }
}
