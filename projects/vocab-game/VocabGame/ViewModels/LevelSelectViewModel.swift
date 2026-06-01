import Foundation
import Combine

class LevelSelectViewModel: ObservableObject {
    @Published var levels: [(definition: LevelDefinition, progress: LevelProgress, isUnlocked: Bool)] = []

    private let progressRepo: ProgressRepository

    var totalStars: Int { progressRepo.totalStars }
    var completedCount: Int { levels.filter { $0.progress.isCompleted }.count }

    init(progressRepo: ProgressRepository) {
        self.progressRepo = progressRepo
        loadLevels()
    }

    func loadLevels() {
        levels = LevelDefinition.allLevels.map { def in
            let prog = progressRepo.levelProgress(for: def.id)
            let unlocked = progressRepo.isLevelUnlocked(def.id)
            return (definition: def, progress: prog, isUnlocked: unlocked)
        }
    }
}
