import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var app: AppCoordinator
    @State private var currentPage = 0
    let onFinish: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "🥚",
            title: "欢迎来到背单词！",
            description: "和蛋仔一起学英语，让背单词变成好玩的游戏",
            color: Color(hex: "FF6B9D")
        ),
        OnboardingPage(
            icon: "🗺️",
            title: "闯关答题",
            description: "25个关卡等你挑战！看单词选释义、听音选词、拼写挑战，学得又快又牢",
            color: Color(hex: "4ECDC4")
        ),
        OnboardingPage(
            icon: "🐣",
            title: "养成蛋仔",
            description: "答题赚经验，蛋仔会升级进化！还能买装饰打扮你的专属蛋仔",
            color: Color(hex: "FFD93D")
        ),
        OnboardingPage(
            icon: "🎮",
            title: "多种玩法",
            description: "拼写挑战、配对消消乐、每日挑战...总有你喜欢的模式",
            color: Color(hex: "A78BFA")
        )
    ]

    var body: some View {
        ZStack {
            (pages[currentPage].color.opacity(0.15))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                Spacer()

                // Page content
                VStack(spacing: VGSpacing.xl) {
                    Text(pages[currentPage].icon)
                        .font(.system(size: 80))

                    Text(pages[currentPage].title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(VGColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(pages[currentPage].description)
                        .font(.body)
                        .foregroundColor(VGColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VGSpacing.xl)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? VGColors.primary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, VGSpacing.lg)

                // Buttons
                HStack {
                    if currentPage < pages.count - 1 {
                        Button("跳过") {
                            finishOnboarding()
                        }
                        .foregroundColor(VGColors.textSecondary)
                    }

                    Spacer()

                    Button(currentPage < pages.count - 1 ? "下一步" : "开始学习！") {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage += 1
                            }
                        } else {
                            finishOnboarding()
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, VGSpacing.lg)
                    .padding(.vertical, VGSpacing.md)
                    .background(pages[currentPage].color)
                    .cornerRadius(25)
                    .animation(.spring(response: 0.3), value: currentPage)
                }
                .padding(.horizontal, VGSpacing.xl)
                .padding(.bottom, VGSpacing.xl)
            }
        }
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onFinish()
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
