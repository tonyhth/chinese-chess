import SwiftUI

struct SpellChallengeView: View {
    @EnvironmentObject var app: AppCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: SpellChallengeViewModel
    @State private var showExitConfirmation = false
    @State private var dictationAutoPlayTask: Task<Void, Never>?

    init(app: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: SpellChallengeViewModel(
            wordRepo: app.wordRepo,
            progressRepo: app.progressRepo,
            petRepo: app.petRepo,
            achievementRepo: app.achievementRepo,
            easterEgg: app.easterEgg
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
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .font(.subheadline)
                        .foregroundColor(VGColors.textSecondary)
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
        .task {
            viewModel.isDictationMode = app.isDictationMode
            app.isDictationMode = false
            if let active = app.progressRepo.activeSession, active.gameMode == .spellChallenge {
                viewModel.resume(active)
            } else {
                viewModel.start()
            }
        }
        .confirmationDialog("确定退出吗？", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("继续游戏", role: .cancel) {}
            Button("退出", role: .destructive) { dismiss() }
        } message: {
            Text("当前拼写进度将保存，下次可继续。")
        }
    }

    private func spellPlayView(word: Word) -> some View {
        VStack(spacing: VGSpacing.xl) {
            // Header
            HStack {
                Button(action: { showExitConfirmation = true }) {
                    Image(systemName: "xmark")
                        .foregroundColor(VGColors.textSecondary)
                        .padding(8)
                }
                Spacer()
                Text(viewModel.isDictationMode ? "听写挑战" : "拼写挑战")
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

            if viewModel.isDictationMode {
                // Dictation mode: no meaning, audio controls
                dictationPromptView(word: word)
            } else {
                // Normal spell mode: show meaning
                VStack(spacing: VGSpacing.md) {
                    Text("拼写出这个单词")
                        .font(.caption)
                        .foregroundColor(VGColors.textSecondary)

                    Text(word.meaning)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(VGColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(viewModel.hintDisplay)
                        .font(.subheadline)
                        .foregroundColor(VGColors.primary)
                }
                .padding(.horizontal, VGSpacing.lg)
            }

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
                    .onSubmit {
                        viewModel.submit()
                    }

                HStack(spacing: VGSpacing.md) {
                    // Hint / First letter hint
                    if viewModel.isDictationMode {
                        if !viewModel.usedDictationHint {
                            Button(action: {
                                _ = viewModel.useFirstLetterHint()
                            }) {
                                HStack {
                                    Image(systemName: "textformat.first")
                                    Text("首字母 (10币)")
                                }
                                .font(.caption)
                                .foregroundColor(VGColors.secondary)
                            }
                        } else {
                            Text("首字母: \(viewModel.firstLetterHint)")
                                .font(.caption)
                                .foregroundColor(VGColors.primary)
                        }
                    } else if !viewModel.hintUsed {
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

    // MARK: - Dictation Prompt

    private func dictationPromptView(word: Word) -> some View {
        VStack(spacing: VGSpacing.md) {
            Text("听发音，拼写出单词")
                .font(.caption)
                .foregroundColor(VGColors.textSecondary)

            // Play audio button
            Button(action: {
                TTSService.shared.speak(word.text)
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(VGColors.primary)
                    Text("播放发音")
                        .font(.caption)
                        .foregroundColor(VGColors.textSecondary)
                }
                .frame(width: 100, height: 100)
                .background(VGColors.primary.opacity(0.1))
                .cornerRadius(20)
            }

            // Replay (costs 5 coins)
            if viewModel.replayCount == 0 {
                Text("已自动播放 2 遍")
                    .font(.caption2)
                    .foregroundColor(VGColors.textSecondary)
            }

            Button(action: {
                if viewModel.replayAudio() {
                    TTSService.shared.speak(word.text)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("再听一次 (5币)")
                }
                .font(.caption)
                .foregroundColor(VGColors.accent)
            }
        }
        .padding(.horizontal, VGSpacing.lg)
        .onAppear {
            TTSService.shared.speak(word.text)
            dictationAutoPlayTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                TTSService.shared.speak(word.text)
            }
        }
        .onDisappear {
            dictationAutoPlayTask?.cancel()
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
