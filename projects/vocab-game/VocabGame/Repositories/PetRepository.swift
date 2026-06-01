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
        // V2: decay satiety on load
        petState.decaySatiety()
        save()
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

    // MARK: - V2 Interactions

    /// 抚摸蛋仔，经验+5，30s 冷却
    @discardableResult
    func pet() -> Bool {
        guard petState.canPet else { return false }
        updatePetState { state in
            state.lastPetTime = Date()
            state.interactionCount += 1
        }
        addExp(5)
        return true
    }

    /// 喂食，消耗 ownedFoods 中的食物
    func feed(foodId: String) -> Bool {
        guard let food = Food.food(by: foodId) else { return false }
        guard let idx = petState.ownedFoods.firstIndex(of: foodId) else { return false }

        updatePetState { state in
            state.ownedFoods.remove(at: idx)
            state.satiety = min(100, state.satiety + food.satiety)
            state.lastFedTime = Date()

            switch food.effect {
            case .happyMood:
                state.mood = .happy
            case .doubleExp:
                state.currentEffect = "double_exp"
            default:
                break
            }
        }
        if food.effect == .expBoost20 {
            addExp(20)
        }
        return true
    }

    /// 玩耍，心情变 happy，4h 冷却
    @discardableResult
    func play() -> Bool {
        guard petState.canPlay else { return false }
        updatePetState { state in
            state.mood = .happy
            state.lastPlayTime = Date()
            state.interactionCount += 1
        }
        return true
    }

    /// 获取蛋仔对话
    func getDialogue(scene: PetDialogueScene) -> String {
        if scene == .hungry && petState.satiety < 30 {
            return PetDialogue.randomDialogue(for: .hungry)
        }
        return PetDialogue.randomDialogue(for: scene)
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
