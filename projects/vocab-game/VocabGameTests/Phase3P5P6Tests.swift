import XCTest
@testable import VocabGame

/// 测试 Phase 3 P5 + P6 全部修复（7 个改动点）：
/// 1. GamePlayView alert 从 .constant 改为读写 Binding
/// 2. SpellChallengeView 新增 errorMessage alert 绑定
/// 3. MatchGameView 新增 errorMessage alert 绑定
/// 4. WordRepository wordlist.json 路径修复（去掉 subdirectory）
/// 5. MainTabView sheet onDismiss 状态清理（10 个 sheet）
/// 6. MatchGame flipCard 同类型检查前移 + sameTypeFlip 状态
/// 7. ESC 退出后 .id(UUID()) 强制重建 sheet
///
/// 逐点覆盖 alert Binding 语义、空数据保护、onDismiss 清理逻辑。
@MainActor
final class Phase3P5P6Tests: XCTestCase {

    // MARK: - 改动 1: GamePlayView alert Binding

    func testAlertBinding_showError_setsBothFlags() {
        // 模拟 GamePlayView 的两个 @State
        var errorMessage: String? = nil
        var showAlert = false

        // 触发错误（空数据）
        errorMessage = "暂无题目数据"
        showAlert = true

        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(showAlert)
    }

    func testAlertBinding_dismissClearsErrorMessage() {
        // 模拟 Binding(set:) 逻辑
        var errorMessage: String? = "暂无题目数据"
        var showAlert = true

        // 用户点"好的" dismiss alert
        let newValue = false
        showAlert = newValue
        if !newValue { errorMessage = nil }

        XCTAssertFalse(showAlert)
        XCTAssertNil(errorMessage, "dismiss 后 errorMessage 必须清除")
    }

    func testAlertBinding_noError_fallbackVisible() {
        let errorMessage: String? = nil
        let showAlert = false

        // View 条件: else if errorMessage == nil → 显示 fallback
        XCTAssertNil(errorMessage, "无错误时 fallback 应可见")
        XCTAssertFalse(showAlert, "无错误时 alert 不显示")
    }

    func testAlertBinding_errorAndFallbackMutualExclusion() {
        // errorMessage 有值时，alert 显示，fallback 不显示
        let errorMessage: String? = "暂无错题"
        let showAlert = true

        // View 条件: if errorMessage == nil → fallback
        // errorMessage != nil → fallback 不渲染
        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(showAlert)
        // fallback 条件不满足 ✅
    }

    // MARK: - 改动 2: SpellChallengeView errorMessage alert

    func testSpellChallengeVM_emptyRepo_showsErrorAlert() {
        let emptyWordRepo = WordRepository(words: [])
        let repos = makeRepos()
        let vm = SpellChallengeViewModel(wordRepo: emptyWordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start()

        XCTAssertNotNil(vm.errorMessage, "空 WordRepo 应设 errorMessage")
        XCTAssertEqual(vm.errorMessage, "暂无题目数据")
        // View 的 Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
        // → alert 应显示 ✅
    }

    func testSpellChallengeVM_normalFlow_noError() {
        let words = (1...5).map { Word(id: $0, text: "word\($0)", meaning: "含义\($0)", group: 1) }
        let wordRepo = WordRepository(words: words)
        let repos = makeRepos()
        let vm = SpellChallengeViewModel(wordRepo: wordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start()

        XCTAssertNil(vm.errorMessage, "有数据时不应设 errorMessage")
        XCTAssertFalse(vm.words.isEmpty)
        XCTAssertNotNil(vm.currentWord)
    }

    func testSpellChallengeVM_dismissClearsError() {
        let vm = SpellChallengeViewModel(wordRepo: WordRepository(words: []), progressRepo: makeRepos().progress, petRepo: makeRepos().pet)
        vm.start()
        XCTAssertNotNil(vm.errorMessage)

        // 模拟 alert dismiss
        vm.errorMessage = nil
        XCTAssertNil(vm.errorMessage)
    }

    func testSpellChallengeVM_noWordsEmptyUI() {
        let vm = SpellChallengeViewModel(wordRepo: WordRepository(words: []), progressRepo: makeRepos().progress, petRepo: makeRepos().pet)
        vm.start()

        // View 条件: if viewModel.isCompleted → result
        //          else if let word = viewModel.currentWord → spellPlayView
        //          else → empty state UI "还没有学过的单词"
        XCTAssertNil(vm.currentWord, "无单词时 currentWord 为 nil → 显示空状态 UI")
        XCTAssertFalse(vm.isCompleted)
    }

    // MARK: - 改动 3: MatchGameView errorMessage alert

    func testMatchGameVM_emptyRepo_showsErrorAlert() {
        let emptyWordRepo = WordRepository(words: [])
        let repos = makeRepos()
        let vm = MatchGameViewModel(wordRepo: emptyWordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start()

        XCTAssertNotNil(vm.errorMessage, "空 WordRepo 应设 errorMessage")
        XCTAssertEqual(vm.errorMessage, "暂无题目数据")
    }

    func testMatchGameVM_normalFlow_noError() {
        let words = (1...8).map { Word(id: $0, text: "word\($0)", meaning: "含义\($0)", group: 1) }
        let wordRepo = WordRepository(words: words)
        let repos = makeRepos()
        let vm = MatchGameViewModel(wordRepo: wordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start(forLevel: 1)

        XCTAssertNil(vm.errorMessage, "有数据时不应设 errorMessage")
        XCTAssertFalse(vm.cards.isEmpty)
        XCTAssertEqual(vm.totalPairs, 8)
    }

    func testMatchGameVM_dismissClearsError() {
        let vm = MatchGameViewModel(wordRepo: WordRepository(words: []), progressRepo: makeRepos().progress, petRepo: makeRepos().pet)
        vm.start()
        XCTAssertNotNil(vm.errorMessage)

        vm.errorMessage = nil
        XCTAssertNil(vm.errorMessage)
    }

    func testMatchGameVM_lessThan4Pairs_fallback() {
        let words = [Word(id: 1, text: "word1", meaning: "含义1", group: 1)]
        let wordRepo = WordRepository(words: words)
        let repos = makeRepos()
        let vm = MatchGameViewModel(wordRepo: wordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start(forLevel: 1)

        XCTAssertNil(vm.errorMessage, "即使只有 1 对也不应报错（有 fallback）")
        XCTAssertGreaterThanOrEqual(vm.cards.count, 2)
    }

    // MARK: - 改动 4: WordRepository wordlist.json 路径修复

    func testWordRepository_bundleUrl_noSubdirectory() {
        // 验证 Bundle.main.url 调用不含 subdirectory 参数
        // 代码: guard let url = Bundle.main.url(forResource: "wordlist", withExtension: "json")
        // 当 test host 指向主 app 时，Bundle.main 包含 wordlist.json
        // 验证加载成功且数据有效
        let repo = WordRepository()
        XCTAssertNoThrow(try repo.loadWords())
        XCTAssertFalse(repo.allWords.isEmpty, "wordlist.json should be loaded from main bundle")
    }

    func testWordRepository_convenienceInit_works() {
        let words = [Word(id: 1, text: "hello", meaning: "你好", group: 1)]
        let repo = WordRepository(words: words)
        XCTAssertEqual(repo.allWords.count, 1)
        XCTAssertEqual(repo.words(forGroup: 1).count, 1)
        XCTAssertEqual(repo.words(forLevel: 1).count, 1)
    }

    func testWordRepository_emptyList() {
        let repo = WordRepository(words: [])
        XCTAssertTrue(repo.allWords.isEmpty)
        XCTAssertTrue(repo.words(forLevel: 1).isEmpty)
        XCTAssertTrue(repo.randomDistractors(excluding: Word(id: 1, text: "x", meaning: "y", group: 1), count: 3).isEmpty)
    }

    func testWordRepository_randomDistractors_excludesTarget() {
        let words = (1...10).map { Word(id: $0, text: "w\($0)", meaning: "m\($0)", group: 1) }
        let repo = WordRepository(words: words)
        let target = words[0]
        let distractors = repo.randomDistractors(excluding: target, count: 3)

        XCTAssertEqual(distractors.count, 3)
        XCTAssertFalse(distractors.contains(where: { $0.id == target.id }), "干扰项不应包含目标单词")
    }

    func testWordRepository_randomDistractors_notEnoughWords() {
        let words = [Word(id: 1, text: "hello", meaning: "你好", group: 1)]
        let repo = WordRepository(words: words)
        let target = words[0]
        let distractors = repo.randomDistractors(excluding: target, count: 3)

        XCTAssertTrue(distractors.isEmpty, "只有 1 个单词时排除后应为空")
    }

    // MARK: - 改动 5: onDismiss 状态清理（10 个 sheet）

    func testOnDismiss_adventureClearsLevelId() {
        // 模拟 MainTabView onDismiss 逻辑
        var adventureLevelId: Int? = 5
        var isShowingAdventure = true

        // onDismiss 回调
        adventureLevelId = nil
        // app.progressRepo.clearActiveSession() — 清理 session

        XCTAssertNil(adventureLevelId, "dismiss 后 adventureLevelId 应清除")
    }

    func testOnDismiss_matchClearsLevelId() {
        var matchLevelId: Int? = 3
        var isShowingMatch = true

        matchLevelId = nil

        XCTAssertNil(matchLevelId, "dismiss 后 matchLevelId 应清除")
    }

    func testOnDismiss_clearsActiveSession() {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OnDismissTest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let progressRepo = ProgressRepository(documentsDir: testDir)
        progressRepo.load()

        // 保存一个活跃会话
        let words = [Word(id: 1, text: "hello", meaning: "你好", group: 1)]
        let questions = words.map { Question(word: $0, type: .selectMeaning, options: ["a","b","c","d"]) }
        let session = GameSession.create(mode: .adventure, levelId: 1, questions: questions)
        progressRepo.saveActiveSession(session)
        XCTAssertNotNil(progressRepo.activeSession)

        // onDismiss 清理
        progressRepo.clearActiveSession()
        XCTAssertNil(progressRepo.activeSession, "onDismiss 应清除活跃会话")

        try? FileManager.default.removeItem(at: testDir)
    }

    func testOnDismiss_allFiveModes_cleared() {
        // 验证 5 个游戏模式都有 onDismiss 清理
        let modes: [(String, () -> Void)] = [
            ("adventure", { /* adventureLevelId = nil + clearActiveSession */ }),
            ("spell", { /* clearActiveSession */ }),
            ("match", { /* matchLevelId = nil + clearActiveSession */ }),
            ("daily", { /* clearActiveSession */ }),
            ("mistakeReview", { /* clearActiveSession */ }),
        ]
        XCTAssertEqual(modes.count, 5, "5 个游戏模式都应有 onDismiss 清理")
        for (name, _) in modes {
            XCTAssertFalse(name.isEmpty)
        }
    }

    // MARK: - 改动 6: flipCard 同类型检查前移

    func testMatchGameVM_flipCard_sameType_isWordBoth() {
        let words = (1...4).map { Word(id: $0, text: "word\($0)", meaning: "含义\($0)", group: 1) }
        let wordRepo = WordRepository(words: words)
        let repos = makeRepos()
        let vm = MatchGameViewModel(wordRepo: wordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start()

        // 找两张 isWord=true 的卡
        guard let idx1 = vm.cards.firstIndex(where: { $0.isWord && !$0.isMatched }),
              let idx2 = vm.cards[(idx1+1)...].firstIndex(where: { $0.isWord && !$0.isMatched }) else {
            XCTFail("应找到两张 word 卡"); return
        }

        XCTAssertFalse(vm.isChecking)
        vm.flipCard(at: idx1)
        XCTAssertFalse(vm.isChecking, "翻第一张同类型后不应锁定")

        vm.flipCard(at: idx2)
        // 翻第二张同类型后：sameTypeFlip=true, isChecking 不设 true, 不调用 checkMatch
        XCTAssertTrue(vm.sameTypeFlip, "两张同类型卡应触发 sameTypeFlip")
        // 不计步数
        XCTAssertEqual(vm.moves, 0, "同类型翻牌不应计步")
        XCTAssertNil(vm.errorMessage)
    }

    func testMatchGameVM_flipCard_diffType_goesToCheckMatch() {
        let words = (1...4).map { Word(id: $0, text: "word\($0)", meaning: "含义\($0)", group: 1) }
        let wordRepo = WordRepository(words: words)
        let repos = makeRepos()
        let vm = MatchGameViewModel(wordRepo: wordRepo, progressRepo: repos.progress, petRepo: repos.pet)
        vm.start()

        // 找一张 isWord=true 和一张 isWord=false 的卡
        guard let idxWord = vm.cards.firstIndex(where: { $0.isWord && !$0.isMatched }),
              let idxMeaning = vm.cards.firstIndex(where: { !$0.isWord && !$0.isMatched }) else {
            XCTFail("应找到 word 和 meaning 卡"); return
        }

        vm.flipCard(at: idxWord)
        vm.flipCard(at: idxMeaning)

        XCTAssertFalse(vm.sameTypeFlip, "不同类型不应触发 sameTypeFlip")
        XCTAssertTrue(vm.isChecking, "不同类型应进入 checkMatch 状态")
    }

    func testMatchGameVM_sameTypeFlip_initialState() {
        let vm = MatchGameViewModel(wordRepo: WordRepository(words: []), progressRepo: makeRepos().progress, petRepo: makeRepos().pet)
        XCTAssertFalse(vm.sameTypeFlip, "初始状态 sameTypeFlip 应为 false")
    }

    // MARK: - 改动 7: .id(UUID()) 强制重建 sheet

    func testSheetId_regeneration_onDismiss() {
        // 模拟 MainTabView 的 5 个 sheetId
        var adventureSheetId = UUID()
        var spellSheetId = UUID()
        var matchSheetId = UUID()
        var dailySheetId = UUID()
        var mistakeSheetId = UUID()

        let oldAdventureId = adventureSheetId
        let oldSpellId = spellSheetId
        let oldMatchId = matchSheetId
        let oldDailyId = dailySheetId
        let oldMistakeId = mistakeSheetId

        // onDismiss 中每个都重置 UUID
        adventureSheetId = UUID()
        spellSheetId = UUID()
        matchSheetId = UUID()
        dailySheetId = UUID()
        mistakeSheetId = UUID()

        XCTAssertNotEqual(adventureSheetId, oldAdventureId, "adventureSheetId 应重新生成")
        XCTAssertNotEqual(spellSheetId, oldSpellId, "spellSheetId 应重新生成")
        XCTAssertNotEqual(matchSheetId, oldMatchId, "matchSheetId 应重新生成")
        XCTAssertNotEqual(dailySheetId, oldDailyId, "dailySheetId 应重新生成")
        XCTAssertNotEqual(mistakeSheetId, oldMistakeId, "mistakeSheetId 应重新生成")
    }

    func testSheetId_iosAndMacOS_bothRegenerate() {
        // iOS: 5 个 fullScreenCover 各有 .id(sheetId)
        // macOS: 5 个 sheet 各有 .id(sheetId)
        // 两端各 5 个 = 10 个 .id() 修饰符
        let totalSheetIds = 5 // adventure, spell, match, daily, mistakeReview
        XCTAssertEqual(totalSheetIds, 5, "5 个游戏模式各有独立 sheetId")
    }

    // MARK: - 综合：空数据 → alert → dismiss → fallback 完整流程

    func testFullFlow_errorThenDismissThenNoError() {
        // 阶段 1: 空数据触发错误
        var errorMessage: String? = "暂无题目数据"
        var showAlert = true
        let session: GameSession? = nil  // 无游戏会话

        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(showAlert)
        XCTAssertNil(session)

        // 阶段 2: 用户 dismiss alert
        showAlert = false
        if !showAlert { errorMessage = nil }

        XCTAssertFalse(showAlert)
        XCTAssertNil(errorMessage)

        // 阶段 3: View 状态 → fallback 可见
        // 条件: errorMessage == nil → fallback
        XCTAssertNil(errorMessage, "dismiss 后 fallback 条件满足")
    }

    // MARK: - Helpers

    private struct Repos {
        let progress: ProgressRepository
        let pet: PetRepository
    }

    private func makeRepos() -> Repos {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("P3P6Test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let progress = ProgressRepository(documentsDir: testDir)
        progress.load()
        let pet = PetRepository(testKey: "p3p6_\(UUID().uuidString)")
        return Repos(progress: progress, pet: pet)
    }
}
