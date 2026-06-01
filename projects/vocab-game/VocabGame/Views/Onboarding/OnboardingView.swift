import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var app: AppCoordinator
    @State private var currentPage = 0
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            TabView(selection: $currentPage) {
                hatchingPage.tag(0)
                tutorialPage.tag(1)
                petHousePage.tag(2)
                startPage.tag(3)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut(duration: 0.4), value: currentPage)
        }
    }

    // MARK: - Page 1: Hatching Animation

    private var hatchingPage: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()

            HatchingEggView()

            Text("嗨！我是你的学习伙伴蛋仔~")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(VGColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VGSpacing.xl)

            Text("和我一起学英语，让背单词变成好玩的游戏吧！")
                .font(.body)
                .foregroundColor(VGColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VGSpacing.xl)

            Spacer()

            pageControl
            nextButton(title: "开始认识蛋仔")
        }
    }

    // MARK: - Page 2: Interactive Tutorial

    private var tutorialPage: some View {
        VStack(spacing: VGSpacing.lg) {
            Spacer()

            Text("先来试试一道题吧！")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(VGColors.textPrimary)

            // Tutorial question card
            TutorialQuestionCard(onAnswered: {
                // Auto advance after answering
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { currentPage = 2 }
                }
            })

            Spacer()

            pageControl
            nextButton(title: "跳过教程")
        }
    }

    // MARK: - Page 3: Pet House Preview

    private var petHousePage: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()

            // Mini pet house preview
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "E8F5E9"), Color(hex: "C8E6C9")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            // Mini pet
                            Circle()
                                .fill(Color(hex: "FFE0B2"))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    VStack(spacing: 2) {
                                        HStack(spacing: 6) {
                                            Circle().fill(Color.black).frame(width: 5, height: 5)
                                            Circle().fill(Color.black).frame(width: 5, height: 5)
                                        }
                                        Text("▽")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: "FF8A65"))
                                    }
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 8)

                            Text("🏠 蛋仔之家")
                                .font(.headline)
                                .foregroundColor(VGColors.textPrimary)
                        }
                    )

                // Decorative items
                Text("🎩")
                    .font(.title2)
                    .offset(x: -80, y: -50)
                Text("⭐")
                    .font(.title3)
                    .offset(x: 70, y: -40)
            }
            .padding(.horizontal, VGSpacing.xl)

            Text("这是我们的家！")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(VGColors.textPrimary)

            Text("答题赚经验让蛋仔升级，还能买装饰打扮它~")
                .font(.body)
                .foregroundColor(VGColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VGSpacing.xl)

            Spacer()

            pageControl
            nextButton(title: "下一步")
        }
    }

    // MARK: - Page 4: Start Adventure

    private var startPage: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()

            // Excited pet
            VStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFE0B2"), Color(hex: "FFCC80")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        VStack(spacing: 6) {
                            HStack(spacing: 12) {
                                Circle().fill(Color.black).frame(width: 8, height: 8)
                                Circle().fill(Color.black).frame(width: 8, height: 8)
                            }
                            Text("▽")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "FF8A65"))
                        }
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 16)

                Text("🎉")
                    .font(.system(size: 40))
            }

            Text("准备好了吗？")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)

            Text("开始冒险吧！25个关卡等你挑战！")
                .font(.body)
                .foregroundColor(VGColors.textSecondary)

            Spacer()

            // Big start button
            Button {
                finishOnboarding()
            } label: {
                Text("🚀 开始冒险！")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [VGColors.primary, Color(hex: "FF6B9D")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                    .shadow(color: VGColors.primary.opacity(0.4), radius: 12, y: 6)
            }
            .padding(.horizontal, VGSpacing.xl)
            .padding(.bottom, VGSpacing.xl)
        }
    }

    // MARK: - Shared Components

    private var pageControl: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? VGColors.primary : Color.gray.opacity(0.3))
                    .frame(width: i == currentPage ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .padding(.bottom, VGSpacing.md)
    }

    private func nextButton(title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.4)) {
                currentPage += 1
            }
        } label: {
            Text(title)
                .foregroundColor(.white)
                .padding(.horizontal, VGSpacing.xl)
                .padding(.vertical, VGSpacing.md)
                .background(VGColors.primary)
                .cornerRadius(25)
        }
        .padding(.bottom, VGSpacing.xl)
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onFinish()
    }
}

// MARK: - Hatching Egg Animation

private struct HatchingEggView: View {
    @State private var cracking = false
    @State private var hatched = false
    @State private var eggScale: CGFloat = 1.0
    @State private var eggRotation: Double = 0

    var body: some View {
        ZStack {
            if hatched {
                // Hatched pet
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "FFE0B2"))
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 4) {
                                HStack(spacing: 10) {
                                    Circle().fill(Color.black).frame(width: 6, height: 6)
                                    Circle().fill(Color.black).frame(width: 6, height: 6)
                                }
                                Text("▽")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "FF8A65"))
                            }
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 8)
                }
                .scaleEffect(hatched ? 1.0 : 0.5)
                .opacity(hatched ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: hatched)
            } else {
                // Egg
                ZStack {
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFF8E1"), Color(hex: "FFE0B2")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 70, height: 90)
                        .shadow(color: .orange.opacity(0.3), radius: 8)

                    // Crack lines
                    if cracking {
                        Path { path in
                            path.move(to: CGPoint(x: 25, y: 35))
                            path.addLine(to: CGPoint(x: 35, y: 45))
                            path.addLine(to: CGPoint(x: 28, y: 55))
                            path.addLine(to: CGPoint(x: 38, y: 65))
                        }
                        .stroke(Color(hex: "BCAAA4"), lineWidth: 2)

                        Path { path in
                            path.move(to: CGPoint(x: 45, y: 30))
                            path.addLine(to: CGPoint(x: 40, y: 42))
                            path.addLine(to: CGPoint(x: 48, y: 52))
                        }
                        .stroke(Color(hex: "BCAAA4"), lineWidth: 2)
                    }
                }
                .scaleEffect(eggScale)
                .rotationEffect(.degrees(eggRotation))
                .animation(.spring(response: 0.3), value: eggScale)
                .animation(.easeInOut(duration: 0.2), value: eggRotation)
            }

            // Egg shell pieces (after hatch)
            if hatched {
                ForEach(0..<4, id: \.self) { i in
                    ShellPiece(angle: Double(i) * 90 + 45)
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                // Egg wobble
                for _ in 0..<3 {
                    eggRotation = 8
                    try? await Task.sleep(for: .milliseconds(300))
                    eggRotation = -8
                    try? await Task.sleep(for: .milliseconds(300))
                }
                eggRotation = 0

                // Cracking
                cracking = true
                eggScale = 1.1
                try? await Task.sleep(for: .seconds(0.5))
                eggScale = 1.0

                // Hatch!
                hatched = true
            }
        }
    }
}

private struct ShellPiece: View {
    let angle: Double
    @State private var scattered = false

    var body: some View {
        Ellipse()
            .fill(Color(hex: "FFE0B2"))
            .frame(width: 15, height: 20)
            .offset(
                x: scattered ? CGFloat(cos(angle * .pi / 180) * 60) : 0,
                y: scattered ? CGFloat(sin(angle * .pi / 180) * 60) - 20 : 0
            )
            .rotationEffect(.degrees(scattered ? angle : 0))
            .opacity(scattered ? 0 : 1)
            .animation(.easeOut(duration: 0.6), value: scattered)
            .onAppear {
                scattered = true
            }
    }
}

// MARK: - Tutorial Question Card

private struct TutorialQuestionCard: View {
    @State private var selectedOption: String? = nil
    @State private var isCorrect = false
    @State private var answered = false
    let onAnswered: () -> Void

    private let word = "apple"
    private let options = ["香蕉", "苹果", "橘子", "葡萄"]
    private let correctAnswer = "苹果"

    var body: some View {
        VStack(spacing: VGSpacing.lg) {
            // Word
            Text(word)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)
                .padding(.vertical, VGSpacing.sm)

            Text("选择正确的释义")
                .font(.caption)
                .foregroundColor(VGColors.textSecondary)

            // Options with highlight for correct answer
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: VGSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    Button {
                        guard !answered else { return }
                        selectedOption = option
                        answered = true
                        isCorrect = option == correctAnswer

                        // Highlight correct answer
                        withAnimation(.spring(response: 0.3)) {
                            selectedOption = correctAnswer
                        }

                        onAnswered()
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .foregroundColor(
                                answered && option == correctAnswer ? .white :
                                (selectedOption == option && !isCorrect ? VGColors.error : VGColors.textPrimary)
                            )
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                answered && option == correctAnswer ? VGColors.success :
                                (selectedOption == option && !isCorrect ? VGColors.error.opacity(0.2) : Color.white)
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        answered && option == correctAnswer ? VGColors.success : Color.gray.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .disabled(answered)
                }
            }
            .padding(.horizontal, VGSpacing.lg)

            if answered {
                Text(isCorrect ? "✓ 答对了！就是这样~" : "没关系，正确答案已高亮显示~")
                    .font(.subheadline)
                    .foregroundColor(isCorrect ? VGColors.success : VGColors.textSecondary)
                    .transition(.opacity)
            }
        }
        .padding(VGSpacing.lg)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, VGSpacing.lg)
    }
}
