import SwiftUI

struct WordRunnerView: View {
    @EnvironmentObject var app: AppCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: WordRunnerViewModel

    init(app: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: WordRunnerViewModel(
            wordRepo: app.wordRepo,
            progressRepo: app.progressRepo,
            petRepo: app.petRepo
        ))
    }

    var body: some View {
        ZStack {
            VGGradients.ocean.ignoresSafeArea()

            if viewModel.isCompleted {
                resultView
            } else if viewModel.errorMessage != nil {
                errorView
            } else {
                gameView
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Game View

    private var gameView: some View {
        GeometryReader { geo in
            ZStack {
                // Falling words area
                ForEach(viewModel.fallingWords.filter { $0.isFalling }) { fw in
                    Text(fw.word.text)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(VGColors.primary)
                                .shadow(color: VGColors.primary.opacity(0.4), radius: 6)
                        )
                        .position(
                            x: geo.size.width / 2,
                            y: CGFloat(fw.y) * geo.size.height
                        )
                }

                // Top bar: score + lives + time
                VStack {
                    HStack {
                        Text("⭐ \(viewModel.score)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("🔥 \(viewModel.combo)x")
                            .font(.subheadline)
                            .foregroundColor(VGColors.secondary)
                        Spacer()
                        Text("❤️ \(Array(repeating: "❤️", count: viewModel.lives).joined())")
                            .font(.subheadline)
                        Spacer()
                        Text("⏱ \(viewModel.timeRemaining)s")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))

                    Spacer()

                    // Lane buttons
                    HStack(spacing: VGSpacing.sm) {
                        ForEach(0..<3, id: \.self) { i in
                            Button {
                                viewModel.selectLane(i)
                            } label: {
                                Text(viewModel.lanes.count > i ? viewModel.lanes[i].text : "")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(VGColors.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, VGSpacing.md)
                    .padding(.bottom, VGSpacing.lg)
                }
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()

            Text("单词跑酷结束!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("\(viewModel.score) 分")
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(VGColors.secondary)

            Text("最高连击: \(viewModel.maxCombo)x")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Button("返回") { dismiss() }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(VGColors.primary)
                .cornerRadius(20)

            Spacer()
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: VGSpacing.lg) {
            Text("出错了")
                .font(.title)
                .foregroundColor(.white)
            Text(viewModel.errorMessage ?? "未知错误")
                .foregroundColor(.white.opacity(0.8))
            Button("返回") { dismiss() }
                .foregroundColor(.white)
                .padding()
                .background(VGColors.primary)
                .cornerRadius(12)
        }
    }
}
