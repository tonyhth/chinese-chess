import Foundation

class PetRepository {
    private let defaults: UserDefaults
    private let petKey: String

    private(set) var petState: PetState

    init(testKey: String? = nil) {
        self.defaults = UserDefaults.standard
        self.petKey = testKey ?? "petState"
        if let data = defaults.data(forKey: petKey),
           let state = try? JSONDecoder().decode(PetState.self, from: data) {
            self.petState = state
        } else {
            self.petState = PetState()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(petState) {
            defaults.set(data, forKey: petKey)
        }
    }

    func updatePetState(_ update: (inout PetState) -> Void) {
        update(&petState)
        save()
    }

    @discardableResult
    func addExp(_ amount: Int) -> Bool {
        let didLevelUp = petState.addExp(amount)
        save()
        return didLevelUp
    }

    func updateMood(_ mood: PetMood) {
        petState.mood = mood
        save()
    }

    /// Calculate mood based on play state
    func calculateMood(profile: PlayerProfile, hasMistakeWords: Bool, hasTriggeredExcited: Bool = false) -> PetMood {
        if hasTriggeredExcited { return .excited }

        let lastPlay = profile.lastPlayDate
        let today = Date()

        if let lastPlay = lastPlay {
            let daysSince = Calendar.current.dateComponents([.day], from: lastPlay, to: today).day ?? 0
            if daysSince > 1 { return .sad }
        } else {
            return .sad // Never played
        }

        let hasPlayedToday = Calendar.current.isDateInToday(lastPlay!)
        if hasPlayedToday && !hasMistakeWords { return .happy }
        if hasPlayedToday && hasMistakeWords { return .normal }
        return .sad
    }
}
