import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppCoordinator
    @Environment(\.scenePhase) var scenePhase
    @State private var selectedTab = 0

    // Game mode triggers
    @State private var isShowingAdventure = false
    @State private var isShowingSpell = false
    @State private var isShowingMatch = false
    @State private var isShowingDaily = false
    @State private var isShowingMistakeReview = false
    @State private var isShowingWordRunner = false
    @State private var adventureLevelId: Int? = nil
    @State private var matchLevelId: Int? = nil
    @State private var adventureSheetId = UUID()
    @State private var spellSheetId = UUID()
    @State private var matchSheetId = UUID()
    @State private var dailySheetId = UUID()
    @State private var mistakeSheetId = UUID()
    @State private var wordRunnerSheetId = UUID()
    @FocusState private var isTabBarFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            TabView(selection: $selectedTab) {
                HomeWrapperView(progressRepo: app.progressRepo)
                    .tag(0)

                LevelMapWrapperView(progressRepo: app.progressRepo)
                    .tag(1)

                PetHouseWrapperView(petRepo: app.petRepo, progressRepo: app.progressRepo)
                    .tag(2)

                ProfileWrapperView(progressRepo: app.progressRepo)
                    .tag(3)
            }
            .tint(VGColors.primary)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        // Game mode sheets
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingAdventure, onDismiss: {
            adventureLevelId = nil
            // 不 clearActiveSession：自然完成时 ViewModel 内部已 clear；中途退出保留 session
            adventureSheetId = UUID()
        }) {
            GamePlayView(mode: .adventure, levelId: app.currentGameLevel)
                .id(adventureSheetId)
        }
        .fullScreenCover(isPresented: $isShowingSpell, onDismiss: {
            // 不 clearActiveSession：保留 session 供恢复
            spellSheetId = UUID()
        }) {
            SpellChallengeView(app: app)
                .id(spellSheetId)
        }
        .fullScreenCover(isPresented: $isShowingMatch, onDismiss: {
            matchLevelId = nil
            app.progressRepo.clearActiveSession()  // 配对游戏始终清除
            matchSheetId = UUID()
        }) {
            MatchGameView(app: app, levelId: app.currentGameLevel)
                .id(matchSheetId)
        }
        .fullScreenCover(isPresented: $isShowingDaily, onDismiss: {
            // 不 clearActiveSession：保留 session 供恢复
            dailySheetId = UUID()
        }) {
            DailyChallengeView(app: app)
                .id(dailySheetId)
        }
        .fullScreenCover(isPresented: $isShowingMistakeReview, onDismiss: {
            // 不 clearActiveSession：保留 session 供恢复
            mistakeSheetId = UUID()
        }) {
            GamePlayView(mode: .mistakeReview, levelId: nil)
                .id(mistakeSheetId)
        }
        .fullScreenCover(isPresented: $isShowingWordRunner, onDismiss: {
            wordRunnerSheetId = UUID()
        }) {
            WordRunnerView(app: app)
                .id(wordRunnerSheetId)
        }
        #else
        .sheet(isPresented: $isShowingAdventure, onDismiss: {
            adventureLevelId = nil
            // 不 clearActiveSession：自然完成时 ViewModel 内部已 clear；中途退出保留 session
            adventureSheetId = UUID()
        }) {
            GamePlayView(mode: .adventure, levelId: app.currentGameLevel)
                .id(adventureSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingSpell, onDismiss: {
            // 不 clearActiveSession：保留 session 供恢复
            spellSheetId = UUID()
        }) {
            SpellChallengeView(app: app)
                .id(spellSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingMatch, onDismiss: {
            matchLevelId = nil
            app.progressRepo.clearActiveSession()  // 配对游戏始终清除
            matchSheetId = UUID()
        }) {
            MatchGameView(app: app, levelId: app.currentGameLevel)
                .id(matchSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingDaily, onDismiss: {
            // 不 clearActiveSession：保留 session 供恢复
            dailySheetId = UUID()
        }) {
            DailyChallengeView(app: app)
                .id(dailySheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingMistakeReview, onDismiss: {
            // 不 clearActiveSession：保留 session 供恢复
            mistakeSheetId = UUID()
        }) {
            GamePlayView(mode: .mistakeReview, levelId: nil)
                .id(mistakeSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingWordRunner, onDismiss: {
            wordRunnerSheetId = UUID()
        }) {
            WordRunnerView(app: app)
                .id(wordRunnerSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        #endif
        .onChange(of: app.currentGameMode) { _, newMode in
            if let mode = newMode {
                switch mode {
                case .adventure:
                    adventureLevelId = app.currentGameLevel
                    isShowingAdventure = true
                case .spellChallenge:
                    isShowingSpell = true
                case .dictation:
                    app.isDictationMode = true
                    isShowingSpell = true
                case .matchPairs:
                    matchLevelId = app.currentGameLevel
                    isShowingMatch = true
                case .dailyChallenge:
                    isShowingDaily = true
                case .mistakeReview:
                    isShowingMistakeReview = true
                case .wordRunner:
                    isShowingWordRunner = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    app.currentGameMode = nil
                }
            }
        }
        .onAppear {
            AudioService.shared.startBGM()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                AudioService.shared.stopBGM()
            case .active:
                AudioService.shared.startBGM()
            default:
                break
            }
        }
    }
}
