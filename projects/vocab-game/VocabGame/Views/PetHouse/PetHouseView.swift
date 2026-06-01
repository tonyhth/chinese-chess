import SwiftUI

struct PetHouseWrapperView: View {
    @StateObject private var viewModel: PetHouseViewModel
    @EnvironmentObject var app: AppCoordinator
    @State private var showingShop = false

    init(petRepo: PetRepository, progressRepo: ProgressRepository) {
        _viewModel = StateObject(wrappedValue: PetHouseViewModel(petRepo: petRepo, progressRepo: progressRepo))
    }

    var body: some View {
        PetHouseContent(
            viewModel: viewModel,
            showingShop: $showingShop,
            easterEgg: app.easterEgg
        )
        .sheet(isPresented: $showingShop) {
            ShopViewWrapper(app: app)
                .environmentObject(app)
        }
    }
}

struct PetHouseContent: View {
    @ObservedObject var viewModel: PetHouseViewModel
    @Binding var showingShop: Bool
    @ObservedObject var easterEgg: EasterEggManager

    @State private var dialogueText: String = ""
    @State private var showFeedSheet = false
    @State private var showCharacterSelect = false
    @State private var dialogueTask: Task<Void, Never>?

    // v1.16: petting interaction states
    @State private var isPetting = false
    @State private var showHeartParticles = false
    @State private var pettingScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: VGSpacing.md) {
                Spacer()

                // Dialogue bubble
                if !dialogueText.isEmpty {
                    PetDialogueBubble(text: dialogueText)
                        .transition(.opacity)
                }

                // Pet display (tappable for petting)
                ZStack {
                    // Heart particles for petting
                    if showHeartParticles {
                        PettingHeartParticles(size: 180)
                    }

                    PetDisplayView(
                        petState: viewModel.petState,
                        size: 180,
                        showDizzy: easterEgg.showPetDizzy,
                        specialOutfit: easterEgg.specialOutfit
                    )
                    .scaleEffect(pettingScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pettingScale)
                }
                .onTapGesture {
                    triggerPetting()
                    easterEgg.onPetTapped()
                    dialogueTask?.cancel()
                    if viewModel.pet() {
                        showDialogue("好舒服~", duration: 2.0)
                    } else {
                        showDialogue("别急，让蛋仔休息一下~", duration: 1.5)
                    }
                }

                // Level & EXP
                VStack(spacing: 8) {
                    Text("Lv.\(viewModel.petState.level)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(VGColors.textPrimary)

                    if let expForNext = viewModel.petState.expForNextLevel {
                        ProgressView(value: viewModel.petState.expProgress)
                            .tint(VGColors.primary)
                            .frame(width: 200)
                        Text("\(viewModel.petState.exp)/\(expForNext) EXP")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    } else {
                        Text("MAX LEVEL!")
                            .font(.headline)
                            .foregroundColor(VGColors.secondary)
                    }
                }

                // Satiety bar
                VStack(spacing: 4) {
                    HStack {
                        Text("饱腹度")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                        Spacer()
                        Text("\(viewModel.petState.satiety)/100")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    }
                    ProgressView(value: Double(viewModel.petState.satiety) / 100.0)
                        .tint(viewModel.petState.satiety > 30 ? VGColors.accent : VGColors.error)
                }
                .padding(.horizontal, VGSpacing.xl)

                // Mood message
                Text(moodMessage)
                    .font(.subheadline)
                    .foregroundColor(VGColors.textPrimary)
                    .padding(.horizontal, VGSpacing.lg)
                    .padding(.vertical, VGSpacing.sm)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)

                // Interaction buttons
                HStack(spacing: VGSpacing.md) {
                    // Character select
                    Button {
                        showCharacterSelect = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.circle")
                                .font(.title3)
                            Text("角色")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 60)
                        .background(VGColors.accent)
                        .cornerRadius(16)
                    }

                    // Feed
                    Button {
                        showFeedSheet = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.title3)
                            Text("喂食")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 60)
                        .background(VGColors.peach)
                        .cornerRadius(16)
                    }

                    // Play
                    Button {
                        if viewModel.play() {
                            showDialogue("好开心！", duration: 2.0)
                        } else {
                            showDialogue("蛋仔还累着呢，稍后再玩~", duration: 1.5)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "figure.play")
                                .font(.title3)
                            Text("玩耍")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 60)
                        .background(VGColors.purple)
                        .cornerRadius(16)
                    }

                    // Shop
                    Button {
                        showingShop = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                                .font(.title3)
                            Text("商店")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 60)
                        .background(VGColors.primary)
                        .cornerRadius(16)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeBackground.ignoresSafeArea())
            .navigationTitle("蛋仔之家")
            .sheet(isPresented: $showFeedSheet) {
                feedSheet
            }
            .sheet(isPresented: $showCharacterSelect) {
                CharacterSelectView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.load()
                showDialogue(viewModel.getDialogue(scene: .greeting), duration: 3.0)
            }
            .onDisappear {
                dialogueTask?.cancel()
            }
        }
    }

    // MARK: - Feed Sheet

    private var feedSheet: some View {
        VStack(spacing: VGSpacing.md) {
            Text("选择食物")
                .font(.headline)
                .padding(.top)

            if viewModel.petState.ownedFoods.isEmpty {
                Text("没有食物了，去商店买一些吧！")
                    .foregroundColor(VGColors.textSecondary)
                    .padding()
            } else {
                // Count owned foods
                let foodCounts = Dictionary(grouping: viewModel.petState.ownedFoods, by: { $0 })
                    .mapValues { $0.count }

                ScrollView {
                    LazyVStack(spacing: VGSpacing.sm) {
                        ForEach(Array(foodCounts.keys.sorted()), id: \.self) { foodId in
                            if let food = Food.food(by: foodId) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(food.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("饱腹度+\(food.satiety)")
                                            .font(.caption)
                                            .foregroundColor(VGColors.textSecondary)
                                    }
                                    Spacer()
                                    Text("×\(foodCounts[foodId] ?? 0)")
                                        .font(.caption)
                                        .foregroundColor(VGColors.textSecondary)
                                    Button("喂食") {
                                        if viewModel.feed(foodId: foodId) {
                                            showFeedSheet = false
                                            showDialogue("好好吃！", duration: 2.0)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(VGColors.accent)
                                    .cornerRadius(10)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Button("关闭") { showFeedSheet = false }
                .font(.subheadline)
                .foregroundColor(VGColors.textSecondary)
                .padding(.bottom)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var currentTheme: ThemeSkin {
        switch viewModel.petState.currentScene {
        case "scene_beach": return .beach
        case "scene_starry": return .starry
        case "scene_candy": return .candy
        case "scene_castle": return .party
        case "scene_party": return .party
        case "scene_garden": return .garden
        default: return .garden
        }
    }

    private var themeBackground: LinearGradient {
        let colors = currentTheme.backgroundGradient
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var moodMessage: String {
        switch viewModel.petState.mood {
        case .happy: return "今天学了不少呢，继续保持~"
        case .normal: return "还有些单词需要复习哦！"
        case .sad: return "好久没见了，快来学习吧~"
        case .excited: return "太棒了！蛋仔好开心！"
        }
    }

    // MARK: - Petting Interaction

    private func showDialogue(_ text: String, duration: Double) {
        dialogueTask?.cancel()
        dialogueText = text
        dialogueTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            dialogueText = ""
        }
    }

    private func triggerPetting() {
        // Squish + heart particles
        pettingScale = 0.9
        showHeartParticles = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pettingScale = 1.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pettingScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showHeartParticles = false
        }
    }
}

// MARK: - Heart Particles for Petting

private struct PettingHeartParticles: View {
    let size: CGFloat
    @State private var hearts: [HeartParticle] = []
    @State private var triggered = false

    struct HeartParticle: Identifiable {
        let id = UUID()
        let xOffset: CGFloat
        let yOffset: CGFloat
        let delay: Double
        let scale: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(hearts) { h in
                Image(systemName: "heart.fill")
                    .font(.system(size: 12 * h.scale))
                    .foregroundColor(VGColors.primary.opacity(0.8))
                    .offset(
                        x: h.xOffset,
                        y: triggered ? h.yOffset - 60 : h.yOffset
                    )
                    .opacity(triggered ? 0 : 0.9)
                    .scaleEffect(h.scale)
                    .animation(.easeOut(duration: 1.0).delay(h.delay), value: triggered)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            hearts = (0..<6).map { _ in
                HeartParticle(
                    xOffset: CGFloat.random(in: -40...40),
                    yOffset: CGFloat.random(in: -30...10),
                    delay: Double.random(in: 0...0.3),
                    scale: CGFloat.random(in: 0.6...1.2)
                )
            }
            triggered = true
        }
    }
}
