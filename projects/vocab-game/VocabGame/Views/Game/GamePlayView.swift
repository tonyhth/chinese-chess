import SwiftUI

struct GamePlayView: View {
    let mode: GameMode
    let levelId: Int?

    @EnvironmentObject var app: AppCoordinator
    @Environment(\.dismiss) var dismiss
    @State private var session: GameSession? = nil
    @State private var selectedAnswer: String? = nil
    @State private var spelledAnswer: String = ""
    @State private var showAnswerFeedback = false
    @State private var isAnswerCorrect = false
    @State private var isShowingResult = false
    @State private var showingLevelPicker = true
    @State private var errorMessage: String?

    // 当有 levelId 时直接进入游戏（不显示关卡选择器），避免 sheet 弹出时闪一下关卡列表
    private var shouldShowLevelPicker: Bool { mode == .adventure && levelId == nil }
    @State private var showAlert = false

    var body: some View {
        ZStack {
            VGColors.background.ignoresSafeArea()

            if shouldShowLevelPicker && showingLevelPicker && mode == .adventure && session == nil {
                levelPickerView
            } else if let s = session, !isShowingResult {
                gamePlayContent(session: s)
            } else if isShowingResult, let s = session {
                ResultView(session: s) {
                    saveResult(s)
                    dismiss()
                }
            } else if errorMessage == nil {
                // Loading: onAppear 尚未完成（session 正在创建）
                // 或真正的未开放模式（无 levelId 的非 adventure 模式）
                if mode == .adventure && session == nil {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    VStack(spacing: VGSpacing.lg) {
                        Text("暂未开放")
                            .font(.title)
                            .foregroundColor(VGColors.textPrimary)
                        Button("返回") { dismiss() }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(width: 200)
                    }
                }
            }
        }
        .alert("提示", isPresented: Binding(
            get: { showAlert },
            set: { newValue in
                showAlert = newValue
                if !newValue { errorMessage = nil }
            }
        ), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onAppear {
            if mode == .adventure, let lid = levelId {
                startLevel(lid)
            } else if mode == .mistakeReview {
                startMistakeReview()
            } else if let active = app.progressRepo.activeSession {
                resumeSession(active)
            }
        }
    }

    // MARK: - Level Picker

    private var levelPickerView: some View {
        VStack(spacing: VGSpacing.lg) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(VGColors.textSecondary)
                }
                Spacer()
                Text("选择关卡").font(.headline)
                Spacer()
                Color.clear.frame(width: 28)
            }
            .padding(.horizontal, VGSpacing.md)

            ScrollView {
                LazyVStack(spacing: VGSpacing.sm) {
                    ForEach(1...25, id: \.self) { lid in
                        let isUnlocked = app.progressRepo.isLevelUnlocked(lid)
                        let progress = app.progressRepo.levelProgress(for: lid)
                        let def = LevelDefinition.allLevels[lid - 1]

                        Button {
                            startLevel(lid)
                        } label: {
                            HStack {
                                Text("\(lid)")
                                    .fontWeight(.bold)
                                    .foregroundColor(isUnlocked ? .white : .gray)
                                    .frame(width: 36, height: 36)
                                    .background(isUnlocked ? VGColors.primary : Color.gray.opacity(0.3))
                                    .cornerRadius(18)

                                VStack(alignment: .leading) {
                                    Text(def.name)
                                        .font(.subheadline)
                                        .foregroundColor(isUnlocked ? VGColors.textPrimary : .gray)
                                    if progress.isCompleted {
                                        HStack(spacing: 2) {
                                            ForEach(0..<3, id: \.self) { i in
                                                Image(systemName: i < progress.stars ? "star.fill" : "star")
                                                    .font(.caption)
                                                    .foregroundColor(VGColors.secondary)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                if !isUnlocked {
                                    Image(systemName: "lock.fill").foregroundColor(.gray)
                                }
                            }
                            .padding(VGSpacing.sm)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isUnlocked)
                        .padding(.horizontal, VGSpacing.md)
                    }
                }
            }
        }
        .padding(.top, VGSpacing.lg)
    }

    // MARK: - Game Play Content

    private func gamePlayContent(session: GameSession) -> some View {
        VStack(spacing: 0) {
            GameHeaderView(
                progress: session.progress,
                current: session.currentIndex + 1,
                total: session.questions.count,
                score: session.score,
                combo: session.combo
            )
            .padding(.top, 8)

            Spacer()

            if let question = session.currentQuestion {
                questionView(question: question)
                    .padding(.horizontal, VGSpacing.md)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func questionView(question: Question) -> some View {
        VStack(spacing: VGSpacing.lg) {
            // Type label
            Text(questionTypeLabel(question.type))
                .font(.caption)
                .foregroundColor(VGColors.textSecondary)

            // Question prompt
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

                if showAnswerFeedback {
                    Text(isAnswerCorrect ? "✓ 正确!" : "✗ 正确答案: \(question.word.text)")
                        .font(.subheadline)
                        .foregroundColor(isAnswerCorrect ? VGColors.success : VGColors.error)
                }

                Button("提交") { submitSpelling() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(spelledAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Options grid (for selection types)
            if question.type != .spellWord {
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: VGSpacing.sm) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { _, option in
                        Button {
                            guard selectedAnswer == nil else { return }
                            selectAnswer(option, question: question)
                        } label: {
                            Text(option)
                                .font(.subheadline)
                                .foregroundColor(VGColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(optionBackground(option, question: question))
                                .cornerRadius(VGRadius.option)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VGRadius.option)
                                        .stroke(optionBorder(option, question: question), lineWidth: selectedAnswer == option ? 2 : 1)
                                )
                        }
                        .disabled(selectedAnswer != nil)
                    }
                }
            }
        }
    }

    // MARK: - Game Logic

    private func startLevel(_ lid: Int) {
        showingLevelPicker = false
        let words = app.wordRepo.words(forLevel: lid).shuffled()
        let allWords = app.wordRepo.allWords
        let selected = Array(words.prefix(10))

        guard !selected.isEmpty else {
            errorMessage = "暂无题目数据"
            showAlert = true
            return
        }

        var questions: [Question] = []
        for (i, word) in selected.enumerated() {
            let type: QuestionType
            switch i {
            case 0..<4: type = .selectMeaning
            case 4..<7: type = .selectWord
            case 7..<9: type = .listenAndSelect
            default: type = .spellWord
            }
            questions.append(Question.create(word: word, type: type, allWords: allWords))
        }

        session = GameSession.create(mode: .adventure, levelId: lid, questions: questions)
        app.progressRepo.saveActiveSession(session)
    }

    private func resumeSession(_ s: GameSession) {
        showingLevelPicker = false
        session = s
    }

    private func startMistakeReview() {
        showingLevelPicker = false
        let mistakes = app.progressRepo.mistakeWords()
        let allWords = app.wordRepo.allWords
        var questions: [Question] = []
        for wp in mistakes.prefix(10) {
            guard let word = allWords.first(where: { $0.id == wp.wordId }) else { continue }
            questions.append(Question.create(word: word, type: .selectMeaning, allWords: allWords))
        }
        if !questions.isEmpty {
            session = GameSession.create(mode: .mistakeReview, questions: questions)
        } else {
            errorMessage = "暂无错题"
            showAlert = true
        }
    }

    private func selectAnswer(_ answer: String, question: Question) {
        guard var s = session else { return }
        selectedAnswer = answer

        switch question.type {
        case .selectMeaning:
            isAnswerCorrect = answer == question.word.meaning
        case .selectWord, .listenAndSelect:
            isAnswerCorrect = answer == question.word.text
        case .spellWord:
            return
        }

        showAnswerFeedback = true
        s.questions[s.currentIndex].isCorrect = isAnswerCorrect

        if isAnswerCorrect {
            s.score += 100 + s.combo * 20
            s.combo += 1
            s.maxCombo = max(s.maxCombo, s.combo)
            AudioService.shared.play(.correct)
            if s.combo >= 3 { AudioService.shared.play(.combo) }
        } else {
            s.combo = 0
            AudioService.shared.play(.wrong)
        }

        session = s
        app.progressRepo.saveActiveSession(s)
        updateWordProgress(wordId: question.word.id, isCorrect: isAnswerCorrect)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { advanceToNext() }
    }

    private func submitSpelling() {
        guard var s = session, let question = s.currentQuestion else { return }
        let normalized = spelledAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isAnswerCorrect = normalized == question.word.text.lowercased()
        showAnswerFeedback = true
        s.questions[s.currentIndex].isCorrect = isAnswerCorrect

        if isAnswerCorrect {
            s.score += 100 + s.combo * 20
            s.combo += 1
            s.maxCombo = max(s.maxCombo, s.combo)
            AudioService.shared.play(.correct)
        } else {
            s.combo = 0
            AudioService.shared.play(.wrong)
        }

        session = s
        app.progressRepo.saveActiveSession(s)
        updateWordProgress(wordId: question.word.id, isCorrect: isAnswerCorrect)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { advanceToNext() }
    }

    private func advanceToNext() {
        guard var s = session else { return }
        selectedAnswer = nil
        spelledAnswer = ""
        showAnswerFeedback = false

        s.currentIndex += 1
        if s.currentIndex >= s.questions.count {
            s.isCompleted = true
            isShowingResult = true
            app.progressRepo.clearActiveSession()
        } else {
            app.progressRepo.saveActiveSession(s)
        }
        session = s
    }

    private func saveResult(_ s: GameSession) {
        if let levelId = s.levelId {
            let stars = StarRating.stars(forScore: s.score)
            var lp = app.progressRepo.levelProgress(for: levelId)
            lp.isCompleted = true
            lp.stars = max(lp.stars, stars)
            lp.bestScore = max(lp.bestScore, s.score)
            app.progressRepo.updateLevelProgress(lp)
        }

        // Award coins
        let coinsEarned = max(s.score / 100, 1) + (s.maxCombo >= 5 ? 5 : 0)
        app.progressRepo.updateProfile { p in
            p.coins += coinsEarned
        }

        let expGained = s.score / 10 + s.maxCombo * 5
        let didLevelUp = app.petRepo.addExp(expGained)

        app.progressRepo.recordPlay()

        // Check if pet should be excited
        let isExcited = didLevelUp || s.maxCombo >= 5
        if isExcited {
            app.petRepo.updateMood(.excited)
        }
    }

    // MARK: - Helpers

    private func questionTypeLabel(_ type: QuestionType) -> String {
        switch type {
        case .selectMeaning: return "选择正确的释义"
        case .selectWord: return "选择对应的单词"
        case .listenAndSelect: return "听发音选择单词"
        case .spellWord: return "拼写单词"
        }
    }

    private func correctAnswer(for question: Question) -> String {
        switch question.type {
        case .selectMeaning: return question.word.meaning
        case .selectWord, .listenAndSelect: return question.word.text
        case .spellWord: return question.word.text
        }
    }

    private func optionBackground(_ option: String, question: Question) -> Color {
        guard showAnswerFeedback else {
            return selectedAnswer == option ? VGColors.primary.opacity(0.1) : Color.white
        }
        let correct = correctAnswer(for: question)
        if option == correct { return VGColors.success.opacity(0.2) }
        if selectedAnswer == option { return VGColors.error.opacity(0.2) }
        return Color.white
    }

    private func optionBorder(_ option: String, question: Question) -> Color {
        guard showAnswerFeedback else {
            return selectedAnswer == option ? VGColors.primary : Color.gray.opacity(0.3)
        }
        let correct = correctAnswer(for: question)
        if option == correct { return VGColors.success }
        if selectedAnswer == option { return VGColors.error }
        return Color.gray.opacity(0.3)
    }

    private func updateWordProgress(wordId: Int, isCorrect: Bool) {
        var wp = app.progressRepo.wordProgress(for: wordId)
        wp = SpacedRepetitionService.updateProgress(wp, isCorrect: isCorrect)
        app.progressRepo.updateWordProgress(wp)
    }
}
