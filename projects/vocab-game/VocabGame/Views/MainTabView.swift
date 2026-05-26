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
    @State private var adventureLevelId: Int? = nil
    @State private var matchLevelId: Int? = nil
    @State private var adventureSheetId = UUID()
    @State private var spellSheetId = UUID()
    @State private var matchSheetId = UUID()
    @State private var dailySheetId = UUID()
    @State private var mistakeSheetId = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeWrapperView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)

            LevelMapWrapperView()
                .tabItem { Label("关卡", systemImage: "map.fill") }
                .tag(1)

            PetHouseWrapperView()
                .tabItem { Label("蛋仔", systemImage: "egg.fill") }
                .tag(2)

            ProfileWrapperView()
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(VGColors.primary)
        // Game mode sheets
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingAdventure, onDismiss: {
            adventureLevelId = nil
            app.progressRepo.clearActiveSession()
            adventureSheetId = UUID()
        }) {
            GamePlayView(mode: .adventure, levelId: adventureLevelId)
                .id(adventureSheetId)
        }
        .fullScreenCover(isPresented: $isShowingSpell, onDismiss: {
            app.progressRepo.clearActiveSession()
            spellSheetId = UUID()
        }) {
            SpellChallengeView(app: app)
                .id(spellSheetId)
        }
        .fullScreenCover(isPresented: $isShowingMatch, onDismiss: {
            matchLevelId = nil
            app.progressRepo.clearActiveSession()
            matchSheetId = UUID()
        }) {
            MatchGameView(app: app, levelId: matchLevelId)
                .id(matchSheetId)
        }
        .fullScreenCover(isPresented: $isShowingDaily, onDismiss: {
            app.progressRepo.clearActiveSession()
            dailySheetId = UUID()
        }) {
            DailyChallengeView(app: app)
                .id(dailySheetId)
        }
        .fullScreenCover(isPresented: $isShowingMistakeReview, onDismiss: {
            app.progressRepo.clearActiveSession()
            mistakeSheetId = UUID()
        }) {
            GamePlayView(mode: .mistakeReview, levelId: nil)
                .id(mistakeSheetId)
        }
        #else
        .sheet(isPresented: $isShowingAdventure, onDismiss: {
            adventureLevelId = nil
            app.progressRepo.clearActiveSession()
            adventureSheetId = UUID()
        }) {
            GamePlayView(mode: .adventure, levelId: adventureLevelId)
                .id(adventureSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingSpell, onDismiss: {
            app.progressRepo.clearActiveSession()
            spellSheetId = UUID()
        }) {
            SpellChallengeView(app: app)
                .id(spellSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingMatch, onDismiss: {
            matchLevelId = nil
            app.progressRepo.clearActiveSession()
            matchSheetId = UUID()
        }) {
            MatchGameView(app: app, levelId: matchLevelId)
                .id(matchSheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingDaily, onDismiss: {
            app.progressRepo.clearActiveSession()
            dailySheetId = UUID()
        }) {
            DailyChallengeView(app: app)
                .id(dailySheetId)
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $isShowingMistakeReview, onDismiss: {
            app.progressRepo.clearActiveSession()
            mistakeSheetId = UUID()
        }) {
            GamePlayView(mode: .mistakeReview, levelId: nil)
                .id(mistakeSheetId)
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
                case .matchPairs:
                    matchLevelId = app.currentGameLevel
                    isShowingMatch = true
                case .dailyChallenge:
                    isShowingDaily = true
                case .mistakeReview:
                    isShowingMistakeReview = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
