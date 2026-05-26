import SwiftUI

struct SpellChallengeView: View {
    @EnvironmentObject var app: AppCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: SpellChallengeViewModel

    init(app: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: SpellChallengeViewModel(
            wordRepo: app.wordRepo,
            progressRepo: app.progressRepo,
            petRepo: app.petRepo
        ))
    }

    var body: some View {
        ZStack {
            VGColors.background.ignoresSafeArea()

            if viewModel.isCompleted {
                spellResultView
            } else if let word = viewModel.currentWord {
                spellPlayView(word: word)
            } else {
                VStack(spacing: VGSpacing.lg) {
                    Text("还没有学过的单词")
                        .font(.title3)
                        .foregroundColor(VGColors.textSecondary)
                    Button("返回") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(width: 200)
                }
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
        .onAppear { viewModel.start() }
    }

    private func spellPlayView(word: Word) -> some View {
        VStack(spacing: VGSpacing.xl) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(VGColors.textSecondary)
                        .padding(8)
                }
                Spacer()
                Text("拼写挑战")
                    .font(.headline)
                Spacer()
                Text("⭐ \(viewModel.score)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.secondary)
            }
            .padding(.horizontal, VGSpacing.md)

            // Progress
            ProgressView(value: viewModel.progress)
                .tint(VGColors.primary)
                .padding(.horizontal, VGSpacing.md)

            Spacer()

            // Word meaning prompt
            VStack(spacing: VGSpacing.md) {
                Text("拼写出这个单词")
                    .font(.caption)
                    .foregroundColor(VGColors.textSecondary)

                Text(word.meaning)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(VGColors.textPrimary)
                    .multilineTextAlignment(.center)

                // Hint
                Text(viewModel.hintDisplay)
                    .font(.subheadline)
                    .foregroundColor(VGColors.primary)
            }
            .padding(.horizontal, VGSpacing.lg)

            // Input
            VStack(spacing: VGSpacing.md) {
                TextField("输入英文单词", text: $viewModel.spelledAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif

                // Hint button
                if !viewModel.hintUsed {
                    Button(action: {
                        _ = viewModel.useHint()
                    }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                            Text("使用提示 (10金币)")
                        }
                        .font(.subheadline)
                        .foregroundColor(VGColors.secondary)
                    }
                }

                if viewModel.showFeedback {
                    if viewModel.isCorrect {
                        Text("✓ 正确!")
                            .font(.headline)
                            .foregroundColor(VGColors.success)
                    } else {
                        Text("✗ 正确答案: \(word.text)")
                            .font(.subheadline)
                            .foregroundColor(VGColors.error)
                    }
                }

                Button("提交") {
                    viewModel.submit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.spelledAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, VGSpacing.xl)
            }
            .padding(.horizontal, VGSpacing.md)

            Spacer()
        }
    }

    private var spellResultView: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()

            if viewModel.streakTitle {
                Text("🏆 拼写达人!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.secondary)
            }

            Text("拼写挑战完成!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)

            Text("\(viewModel.score) 分")
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(VGColors.primary)

            Text("最高连击: \(viewModel.maxCombo)x")
                .font(.subheadline)
                .foregroundColor(VGColors.textSecondary)

            Button("返回") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)

            Spacer()
        }
    }
}
