import Foundation
import Combine

class PetHouseViewModel: ObservableObject {
    @Published var petState: PetState = PetState()

    private let petRepo: PetRepository
    private let progressRepo: ProgressRepository

    init(petRepo: PetRepository, progressRepo: ProgressRepository) {
        self.petRepo = petRepo
        self.progressRepo = progressRepo
    }

    func load() {
        let profile = progressRepo.profile
        let hasMistakes = !progressRepo.mistakeWords().isEmpty
        let mood = petRepo.calculateMood(profile: profile, hasMistakeWords: hasMistakes)
        petRepo.updateMood(mood)
        petState = petRepo.petState
    }
}
