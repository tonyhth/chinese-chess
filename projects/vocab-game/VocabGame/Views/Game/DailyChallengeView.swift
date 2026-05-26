import SwiftUI

struct DailyChallengeView: View {
    @EnvironmentObject var app: AppCoordinator
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: DailyChallengeViewModel

    init(app: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: DailyChallengeViewModel(
            wordRepo: app.wordRepo,
            progressRepo: app.progressRepo,
            petRepo: app.petRepo
        ))
    }

    var body: some View {
        ZStack {
            VGColors.background.ignoresSafeArea()

            if viewModel.todayCompleted && viewModel.session == nil {
                alreadyCompletedView
            } else if let errorMessage = viewModel.errorMessage, viewModel.session == nil {
                errorView(message: errorMessage)
            } else if viewModel.isShowingResult, let s = viewModel.session {
                dailyResultView(session: s)
            } else if let session = viewModel.session, let question = session.currentQuestion {
                dailyPlayView(session: session, question: question)
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .foregroundColor(VGColors.textSecondary)
                        .padding(.top, 8)
                }
            }
        }
        .onAppear { viewModel.start() }
    }

    private var alreadyCompletedView: some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(VGColors.success)
            Text("今日挑战已完成!")
                .font(.title2)
                .fontWeight(.bold)
            Text("今日最高分: \(viewModel.todayBestScore)")
                .font(.subheadline)
                .foregroundColor(VGColors.textSecondary)
            Text("明天再来挑战吧~")
                .font(.subheadline)
                .foregroundColor(VGColors.textSecondary)
            Button("返回") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(VGColors.secondary)
            Text(message)
                .font(.title3)
                .foregroundColor(VGColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VGSpacing.lg)
            Button("返回") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
            Spacer()
        }
    }

    private func dailyPlayView(session: GameSession, question: Question) -> some View {
        VStack(spacing: 0) {
            // Header with timer
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(VGColors.textSecondary)
                        .padding(8)
                }
                Spacer()
                Text("每日挑战")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text("\(formatTime(viewModel.remainingSeconds))")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(viewModel.remainingSeconds <= 30 ? VGColors.error : VGColors.textPrimary)
            }
            .padding(.horizontal, VGSpacing.md)

            GameHeaderView(
                progress: session.progress,
                current: session.currentIndex + 1,
                total: session.questions.count,
                score: session.score,
                combo: session.combo
            )

            Spacer()

            // Question (reuse the same question UI pattern)
            DailyQuestionView(
                question: question,
                viewModel: viewModel,
                selectedAnswer: viewModel.selectedAnswer,
                showFeedback: viewModel.showAnswerFeedback,
                isCorrect: viewModel.isAnswerCorrect,
                spelledAnswer: $viewModel.spelledAnswer
            )
            .padding(.horizontal, VGSpacing.md)

            Spacer()
        }
    }

    private func dailyResultView(session: GameSession) -> some View {
        VStack(spacing: VGSpacing.xl) {
            Spacer()
            Text("每日挑战完成!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(VGColors.textPrimary)

            Text("\(session.score) 分")
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(VGColors.primary)

            let correct = session.questions.filter { $0.isCorrect == true }.count
            Text("正确率: \(session.questions.isEmpty ? 0 : correct * 100 / session.questions.count)%")
                .font(.subheadline)
                .foregroundColor(VGColors.textSecondary)

            Text("最高连击: \(session.maxCombo)x")
                .font(.subheadline)
                .foregroundColor(VGColors.textSecondary)

            Text("+\(viewModel.coinsEarned) 金币 (每日奖励)")
                .font(.subheadline)
                .foregroundColor(VGColors.secondary)

            Button("返回") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
            Spacer()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct DailyQuestionView: View {
    let question: Question
    @ObservedObject var viewModel: DailyChallengeViewModel
    let selectedAnswer: String?
    let showFeedback: Bool
    let isCorrect: Bool
    @Binding var spelledAnswer: String

    var body: some View {
        VStack(spacing: VGSpacing.lg) {
            Text(questionTypeLabel)
                .font(.caption)
                .foregroundColor(VGColors.textSecondary)

            switch question.type {
            case .selectMeaning:
                Text(question.word.text)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(VGColors.textPrimary)

            case .selectWord:
                Text(question.word.meaning)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(VGColors.textPrimary)

            case .listenAndSelect:
                Button(action: { TTSService.shared.speak(question.word.text) }) {
                    VStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title)
                            .foregroundColor(VGColors.primary)
                        Text("点击播放")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(VGColors.primary.opacity(0.1))
                    .cornerRadius(VGRadius.option)
                }

            case .spellWord:
                Text(question.word.meaning)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(VGColors.textPrimary)

                TextField("输入英文单词", text: $spelledAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif

                if showFeedback {
                    Text(isCorrect ? "✓ 正确!" : "✗ 正确答案: \(question.word.text)")
                        .font(.subheadline)
                        .foregroundColor(isCorrect ? VGColors.success : VGColors.error)
                }

                Button("提交") { viewModel.submitSpelling() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(spelledAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if question.type != .spellWord {
                let cols = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: VGSpacing.sm) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { _, option in
                        Button {
                            guard selectedAnswer == nil else { return }
                            viewModel.selectAnswer(option, question: question)
                        } label: {
                            Text(option)
                                .font(.subheadline)
                                .foregroundColor(VGColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(optionBg(option))
                                .cornerRadius(VGRadius.option)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VGRadius.option)
                                        .stroke(optionBdr(option), lineWidth: selectedAnswer == option ? 2 : 1)
                                )
                        }
                        .disabled(selectedAnswer != nil)
                    }
                }
            }
        }
    }

    private var questionTypeLabel: String {
        switch question.type {
        case .selectMeaning: return "选择正确的释义"
        case .selectWord: return "选择对应的单词"
        case .listenAndSelect: return "听发音选择单词"
        case .spellWord: return "拼写单词"
        }
    }

    private func optionBg(_ option: String) -> Color {
        guard showFeedback else {
            return selectedAnswer == option ? VGColors.primary.opacity(0.1) : Color.white
        }
        let correct = viewModel.correctAnswer(for: question)
        if option == correct { return VGColors.success.opacity(0.2) }
        if selectedAnswer == option { return VGColors.error.opacity(0.2) }
        return Color.white
    }

    private func optionBdr(_ option: String) -> Color {
        guard showFeedback else {
            return selectedAnswer == option ? VGColors.primary : Color.gray.opacity(0.3)
        }
        let correct = viewModel.correctAnswer(for: question)
        if option == correct { return VGColors.success }
        if selectedAnswer == option { return VGColors.error }
        return Color.gray.opacity(0.3)
    }
}
