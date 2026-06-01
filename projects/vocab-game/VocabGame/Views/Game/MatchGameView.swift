import SwiftUI

struct MatchGameView: View {
    @EnvironmentObject var app: AppCoordinator
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var viewModel: MatchGameViewModel
    @State private var showExitConfirmation = false
    let levelId: Int?

    init(app: AppCoordinator, levelId: Int? = nil) {
        self.levelId = levelId
        _viewModel = StateObject(wrappedValue: MatchGameViewModel(
            wordRepo: app.wordRepo,
            progressRepo: app.progressRepo,
            petRepo: app.petRepo,
            achievementRepo: app.achievementRepo
        ))
    }

    private let columns = [
        GridItem(.flexible()), GridItem(.flexible()),
        GridItem(.flexible()), GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            VGColors.background.ignoresSafeArea()

            if viewModel.isCompleted {
                matchResultView
            } else {
                matchPlayView
            }
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        ), actions: {
            Button("好的") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .task { viewModel.start(forLevel: levelId) }
        .onDisappear { viewModel.stop() }
        .confirmationDialog("确定退出吗？", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("继续游戏", role: .cancel) {}
            Button("退出", role: .destructive) {
                app.progressRepo.clearActiveSession()  // 配对游戏退出时清除
                dismiss()
            }
        } message: {
            Text("退出后配对进度将不会保存。")
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.pauseTimer()
            case .active:
                viewModel.resumeTimer()
            default:
                break
            }
        }
    }

    private var matchPlayView: some View {
        VStack(spacing: VGSpacing.md) {
            // Header
            HStack {
                Button(action: { showExitConfirmation = true }) {
                    Image(systemName: "xmark")
                        .foregroundColor(VGColors.textSecondary)
                        .padding(8)
                }
                Spacer()
                Text("配对消消乐")
                    .font(.headline)
                Spacer()
                Text("⭐ \(viewModel.score)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.secondary)
            }
            .padding(.horizontal, VGSpacing.md)

            // Timer
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(viewModel.remainingSeconds <= 10 ? VGColors.error : VGColors.textSecondary)
                Text("\(viewModel.remainingSeconds)s")
                    .font(.headline)
                    .foregroundColor(viewModel.remainingSeconds <= 10 ? VGColors.error : VGColors.textPrimary)
                Spacer()
                Text("\(viewModel.matchedPairs)/\(viewModel.totalPairs) 对")
                    .font(.subheadline)
                    .foregroundColor(VGColors.textSecondary)
            }
            .padding(.horizontal, VGSpacing.md)

            // Same type hint
            if viewModel.sameTypeFlip {
                Text("请选择一张英文和一张中文进行配对")
                    .font(.caption)
                    .foregroundColor(VGColors.error)
                    .transition(.opacity)
            }

            // Card grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: VGSpacing.sm) {
                    ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                        MatchCardView(card: card, sameTypeFlip: viewModel.sameTypeFlip && card.isFlipped) {
                            viewModel.flipCard(at: index)
                        }
                    }
                }
                .padding(VGSpacing.md)
            }
        }
        .onChange(of: viewModel.sameTypeFlip) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    viewModel.sameTypeFlip = false
                }
            }
        }
    }

    private var matchResultView: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()
            Text("配对完成!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)

            Text("\(viewModel.score) 分")
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(VGColors.primary)

            VStack(spacing: 8) {
                Text("用了 \(viewModel.moves) 步")
                    .font(.subheadline)
                    .foregroundColor(VGColors.textSecondary)
                if viewModel.remainingSeconds > 0 {
                    Text("剩余 \(viewModel.remainingSeconds) 秒")
                        .font(.subheadline)
                        .foregroundColor(VGColors.success)
                }
            }

            Button("返回") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
            Spacer()
        }
    }
}

struct MatchCardView: View {
    let card: MatchCard
    var sameTypeFlip: Bool = false
    let onTap: () -> Void

    @State private var rotation: Double = 0
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Back of card
                RoundedRectangle(cornerRadius: 8)
                    .fill(card.isWord ? VGColors.primary.opacity(0.8) : VGColors.secondary.opacity(0.8))
                    .frame(height: 70)
                    .overlay(
                        Image(systemName: "questionmark")
                            .foregroundColor(.white)
                            .font(.title3)
                    )

                // Front of card (shown when flipped)
                if card.isFlipped || card.isMatched {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(card.isMatched ? VGColors.success.opacity(0.3) : Color.white)
                        .frame(height: 70)
                        .overlay(
                            Text(card.text)
                                .font(.caption)
                                .foregroundColor(VGColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(4)
                        )
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(card.isMatched ? 0.3 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: card.isFlipped)
        .shake(active: sameTypeFlip)
    }
}

// MARK: - Shake Modifier

struct ShakeModifier: ViewModifier {
    let active: Bool
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: active) { _, newValue in
                guard newValue else { return }
                withAnimation(.easeInOut(duration: 0.05)) {
                    shakeOffset = 6
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.05)) {
                        shakeOffset = -6
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.05)) {
                        shakeOffset = 4
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.05)) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

extension View {
    func shake(active: Bool) -> some View {
        modifier(ShakeModifier(active: active))
    }
}
