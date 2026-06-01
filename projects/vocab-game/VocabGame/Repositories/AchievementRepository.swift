import Foundation
import SwiftUI

/// Centralized achievement tracking — event-driven.
/// ViewModels emit events; this repository handles unlock logic.
@MainActor
class AchievementRepository: ObservableObject {
    @Published var achievements: [Achievement] = Achievement.catalog
    @Published var newlyUnlocked: Achievement? = nil

    private let progressRepo: ProgressRepository
    private var showUnlockTask: Task<Void, Never>? = nil

    init(progressRepo: ProgressRepository) {
        self.progressRepo = progressRepo
    }

    func load() {
        // Restore saved progress/unlocked state from PlayerProfile
        let saved = progressRepo.profile.achievementProgress
        for i in achievements.indices {
            if let savedEntry = saved[achievements[i].id] {
                achievements[i].progress = savedEntry.progress
                achievements[i].isUnlocked = savedEntry.isUnlocked
                achievements[i].unlockedAt = savedEntry.unlockedAt
            }
        }
    }

    // MARK: - Event Recording

    func record(_ event: AchievementEvent) {
        switch event {
        case .wordLearned(let count):
            updateProgress("first_word", to: count, unlockAt: 1)
            updateProgress("word_master_50", to: count, unlockAt: 50)
        case .wordMastered(let count):
            updateProgress("word_master_50", to: count, unlockAt: 50)
        case .streakDay(let count):
            updateProgress("streak_7", to: count, unlockAt: 7)
        case .comboReached(let count):
            updateProgress("combo_10", to: count, unlockAt: 10)
        case .petLevelUp(let level):
            updateProgress("pet_max", to: level, unlockAt: 5)
        case .itemCollected(let count):
            updateProgress("collector_10", to: count, unlockAt: 10)
        case .matchCompleted(let remaining):
            if remaining >= 30 { // completed in ≤30s means ≥30s remaining
                updateProgress("speed_demon", to: 1, unlockAt: 1)
            }
        case .levelCompleted, .dailyChallengeCompleted, .gamePlayed:
            break // future expansion
        }
        persist()
    }

    // MARK: - Internal

    private func updateProgress(_ id: String, to value: Int, unlockAt: Int) {
        guard let idx = achievements.firstIndex(where: { $0.id == id }) else { return }
        achievements[idx].progress = value
        if !achievements[idx].isUnlocked && value >= unlockAt {
            achievements[idx].isUnlocked = true
            achievements[idx].unlockedAt = Date()
            // Grant coin reward
            let reward = achievements[idx].reward
            progressRepo.updateProfile { p in
                p.coins += reward
            }
            // Show unlock popup
            let unlocked = achievements[idx]
            showUnlockTask?.cancel()
            showUnlockTask = Task { @MainActor in
                newlyUnlocked = unlocked
                try? await Task.sleep(for: .seconds(3))
                newlyUnlocked = nil
            }
        }
    }

    private func persist() {
        var dict: [String: AchievementSaveEntry] = [:]
        for a in achievements {
            dict[a.id] = AchievementSaveEntry(progress: a.progress, isUnlocked: a.isUnlocked, unlockedAt: a.unlockedAt)
        }
        progressRepo.updateProfile { p in
            p.achievementProgress = dict
        }
    }
}
