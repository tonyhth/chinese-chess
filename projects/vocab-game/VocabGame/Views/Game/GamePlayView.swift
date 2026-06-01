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
    @State private var isProcessingAnswer = false
    @State private var answerTask: Task<Void, Never>? = nil
    @State private var showExitConfirmation = false

    // Animation states
    @State private var correctOptionScale: CGFloat = 1.0
    @State private var wrongOptionShake: CGFloat = 0
    @State private var correctOptionFlash = 0
    @State private var comboTextItem: (text: String, color: Color)? = nil
    @State private var scoreFloatPoints: Int? = nil
    @State private var showMiniPet = false
    @State private var miniPetHappy = true
    @State private var showGoldParticles = false
    @State private var showLegendary = false
    @State private var screenShakeAmount: CGFloat = 0

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
        .task {
            if mode == .adventure, let lid = levelId {
                startLevel(lid)
            } else if mode == .mistakeReview {
                startMistakeReview()
            } else if let active = app.progressRepo.activeSession {
                resumeSession(active)
            }
        }
        .confirmationDialog("确定退出吗？", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("继续游戏", role: .cancel) {}
            Button("退出", role: .destructive) { dismiss() }
        } message: {
            Text("当前进度将保存，下次可继续。")
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
                    ForEach(1...LevelDefinition.allLevels.count, id: \.self) { lid in
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
            // 退出按钮
            HStack {
                Button(action: { showExitConfirmation = true }) {
                    Image(systemName: "xmark")
                        .foregroundColor(VGColors.textSecondary)
                        .padding(8)
                }
                Spacer()
            }
            .padding(.horizontal, VGSpacing.md)

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
        .overlay(alignment: .topTrailing) {
            // Mini pet reaction (corner)
            if showMiniPet {
                MiniPetReaction(isHappy: miniPetHappy)
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay {
            // Combo text floating
            if let combo = comboTextItem {
                ComboText(text: combo.text, color: combo.color)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .center) {
            // Score float (+100)
            if let pts = scoreFloatPoints {
                ScoreFloatView(points: pts)
                    .transition(.opacity)
            }
        }
        .overlay {
            // Gold particles (8x+ combo)
            if showGoldParticles {
                GoldParticleBurst()
            }
        }
        .overlay {
            // Legendary celebration (10x)
            if showLegendary {
                LegendaryCelebration()
            }
        }
        .modifier(ScreenShake(animatableData: screenShakeAmount))
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
                    .onSubmit {
                        submitSpelling()
                    }

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
                            HStack(spacing: 4) {
                                Text(option)
                                    .font(.subheadline)
                                    .foregroundColor(VGColors.textPrimary)
                                    .multilineTextAlignment(.center)

                                // Checkmark for correct answer after feedback
                                if showAnswerFeedback, option == correctAnswer(for: question) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundColor(VGColors.success)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(optionBackground(option, question: question))
                            .cornerRadius(VGRadius.option)
                            .overlay(
                                RoundedRectangle(cornerRadius: VGRadius.option)
                                    .stroke(optionBorder(option, question: question), lineWidth: selectedAnswer == option ? 2 : 1)
                            )
                            // Correct answer bounce
                            .scaleEffect(
                                showAnswerFeedback && option == correctAnswer(for: question) ? correctOptionScale : 1.0,
                                anchor: .center
                            )
                            // Wrong answer shake
                            .modifier(ShakeEffect(animatableData: wrongOptionShake))
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
        let types: [QuestionType] = [.selectMeaning, .selectWord, .spellWord]
        for (i, wp) in mistakes.prefix(10).enumerated() {
            guard let word = allWords.first(where: { $0.id == wp.wordId }) else { continue }
            let type = types[i % types.count]
            questions.append(Question.create(word: word, type: type, allWords: allWords))
        }
        if !questions.isEmpty {
            session = GameSession.create(mode: .mistakeReview, questions: questions)
        } else {
            errorMessage = "暂无错题"
            showAlert = true
        }
    }

    private func selectAnswer(_ answer: String, question: Question) {
        guard var s = session, !isProcessingAnswer else { return }
        isProcessingAnswer = true
        selectedAnswer = answer

        switch question.type {
        case .selectMeaning:
            isAnswerCorrect = answer == question.word.meaning
        case .selectWord, .listenAndSelect:
            isAnswerCorrect = answer == question.word.text
        case .spellWord:
            isProcessingAnswer = false
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

            // Correct answer bounce animation
            correctOptionScale = 1.0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                correctOptionScale = 1.08
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    correctOptionScale = 1.0
                }
            }

            // Mini pet happy reaction
            showMiniPet = true
            miniPetHappy = true

            // Score float
            let earned = 100 + (s.combo - 1) * 20
            scoreFloatPoints = earned

            // Combo milestones
            if s.combo == 3 {
                comboTextItem = ("Nice!", Color(hex: "FFD700"))
            } else if s.combo == 5 {
                comboTextItem = ("Amazing!", Color(hex: "FF6B35"))
                // Screen shake
                withAnimation(.easeInOut(duration: 0.3)) {
                    screenShakeAmount = 3
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    screenShakeAmount = 0
                }
            } else if s.combo == 8 {
                comboTextItem = ("Perfect!", Color(hex: "FF1493"))
                showGoldParticles = true
            } else if s.combo >= 10 && s.combo % 10 == 0 {
                comboTextItem = ("Legendary!", Color(hex: "FF0000"))
                showLegendary = true
            }
            // Phase 4: easter egg + achievement
            app.easterEgg.checkComboEasterEgg(combo: s.combo)
            app.achievementRepo.record(.comboReached(count: s.combo))
        } else {
            s.combo = 0
            AudioService.shared.play(.wrong)

            // Wrong answer shake
            withAnimation(.easeInOut(duration: 0.4)) {
                wrongOptionShake = 2
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                wrongOptionShake = 0
            }

            // Mini pet sad reaction
            showMiniPet = true
            miniPetHappy = false
        }

        session = s
        app.progressRepo.saveActiveSession(s)
        updateWordProgress(wordId: question.word.id, isCorrect: isAnswerCorrect)

        answerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            advanceToNext()
            isProcessingAnswer = false
        }
    }

    private func submitSpelling() {
        guard var s = session, let question = s.currentQuestion, !isProcessingAnswer else { return }
        let trimmed = spelledAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }  // 防空提交
        let normalized = trimmed.lowercased()
        isAnswerCorrect = normalized == question.word.text.lowercased()
        showAnswerFeedback = true
        s.questions[s.currentIndex].isCorrect = isAnswerCorrect
        isProcessingAnswer = true

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

        answerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            advanceToNext()
            isProcessingAnswer = false
        }
    }

    private func advanceToNext() {
        guard var s = session else { return }
        selectedAnswer = nil
        spelledAnswer = ""
        showAnswerFeedback = false

        // Reset animation states
        correctOptionScale = 1.0
        wrongOptionShake = 0
        comboTextItem = nil
        scoreFloatPoints = nil
        showMiniPet = false
        showGoldParticles = false
        showLegendary = false
        screenShakeAmount = 0

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
            let correctCount = s.questions.filter { $0.isCorrect == true }.count
            let stars = StarRating.stars(correctCount: correctCount, totalCount: s.questions.count)
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
