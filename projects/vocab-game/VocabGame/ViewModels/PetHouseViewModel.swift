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
        checkCharacterUnlocks()
        petState = petRepo.petState
    }

    // MARK: - v1.17: Character Unlock Checks

    /// Check and auto-unlock streak7 / master50 characters
    private func checkCharacterUnlocks() {
        var state = petRepo.petState
        var changed = false

        // streak7: current streak >= 7
        let streak = progressRepo.profile.currentStreak
        if streak >= 7 && !state.ownedCharacterIds.contains("egg_black") {
            state.ownedCharacterIds.append("egg_black")
            changed = true
        }

        // master50: mastered word count >= 50
        let masteredCount = progressRepo.wordProgress.values.filter { $0.mastery == .mastered }.count
        if masteredCount >= 50 && !state.ownedCharacterIds.contains("egg_red") {
            state.ownedCharacterIds.append("egg_red")
            changed = true
        }

        if changed {
            petRepo.updatePetState { $0 = state }
        }
    }

    // MARK: - V2 Interactions

    @discardableResult
    func pet() -> Bool {
        let result = petRepo.pet()
        if result { petState = petRepo.petState }
        return result
    }

    func feed(foodId: String) -> Bool {
        let result = petRepo.feed(foodId: foodId)
        if result { petState = petRepo.petState }
        return result
    }

    @discardableResult
    func play() -> Bool {
        let result = petRepo.play()
        if result { petState = petRepo.petState }
        return result
    }

    func getDialogue(scene: PetDialogueScene) -> String {
        return petRepo.getDialogue(scene: scene)
    }

    // MARK: - v1.17: Character System

    func ownsCharacter(_ id: String) -> Bool {
        return petState.ownedCharacterIds.contains(id)
    }

    func switchCharacter(to id: String) {
        guard ownsCharacter(id) else { return }
        petRepo.updatePetState { state in
            state.currentCharacterId = id
        }
        petState = petRepo.petState
    }
}
