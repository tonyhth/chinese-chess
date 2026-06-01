import SwiftUI

@main
struct VocabGameApp: App {
    @StateObject private var app = AppCoordinator()
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                MainTabView()
                    .environmentObject(app)
            } else {
                OnboardingView {
                    withAnimation { hasSeenOnboarding = true }
                }
                .environmentObject(app)
            }
        }
    }
}

/// Central coordinator holding shared repositories and state
@MainActor
class AppCoordinator: ObservableObject {
    let wordRepo = WordRepository()
    let progressRepo = ProgressRepository()
    let petRepo = PetRepository()
    let achievementRepo: AchievementRepository
    let easterEgg = EasterEggManager()

    @Published var currentGameLevel: Int? = nil
    @Published var currentGameMode: GameMode? = nil
    @Published var isDictationMode: Bool = false
    @Published var showingAchievements: Bool = false

    init() {
        try? wordRepo.loadWords()
        progressRepo.load()
        achievementRepo = AchievementRepository(progressRepo: progressRepo)
        achievementRepo.load()
        easterEgg.specialOutfit = EasterEggManager.specialOutfitForToday()
        AudioService.shared.preload()
    }

    func startGame(levelId: Int) {
        currentGameLevel = levelId
        currentGameMode = .adventure
    }

    func startMatchGame(levelId: Int) {
        currentGameLevel = levelId
        currentGameMode = .matchPairs
    }

    func startMistakeReview() {
        currentGameMode = .mistakeReview
        currentGameLevel = nil
    }

    func resumeSession() {
        if let session = progressRepo.activeSession {
            currentGameLevel = session.levelId
            currentGameMode = session.gameMode
        }
    }
}
