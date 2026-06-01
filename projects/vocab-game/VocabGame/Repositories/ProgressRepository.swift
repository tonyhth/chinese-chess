import Foundation

/// Manages all persisted state: word progress, level progress, active session, player profile.
/// Uses atomic writes (tmp + replaceItem) with .bak backup.
class ProgressRepository {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Storage model
    struct ProgressData: Codable {
        var version: Int = 17
        var wordProgress: [String: WordProgress] = [:]   // keyed by wordId string
        var levelProgress: [String: LevelProgress] = [:]  // keyed by levelId string
        var activeSession: GameSession? = nil
        var profile: PlayerProfile = PlayerProfile()
        var dailyChallengeRecords: [String: DailyRecord] = [:] // keyed by "yyyy-MM-dd"
    }

    struct DailyRecord: Codable {
        var isCompleted: Bool
        var bestScore: Int
    }

    // MARK: - State
    private(set) var data: ProgressData
    private let documentsDir: URL

    var wordProgress: [String: WordProgress] { data.wordProgress }
    var levelProgress: [String: LevelProgress] { data.levelProgress }
    var activeSession: GameSession? { data.activeSession }
    var profile: PlayerProfile {
        get { data.profile }
        set { data.profile = newValue }
    }

    // MARK: - Init

    init(documentsDir: URL? = nil) {
        self.documentsDir = documentsDir ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.data = ProgressData()
    }

    // MARK: - File paths

    private var progressFileURL: URL {
        documentsDir.appendingPathComponent("progress.json")
    }
    private var backupFileURL: URL {
        documentsDir.appendingPathComponent("progress.json.bak")
    }
    private var tempFileURL: URL {
        documentsDir.appendingPathComponent("progress.tmp.json")
    }

    // MARK: - Load

    func load() {
        // Migrate from UserDefaults if profile was stored there
        migrateFromUserDefaults()

        data = loadFromURL(progressFileURL) ?? loadFromURL(backupFileURL) ?? ProgressData()
        // Ensure all 25 levels have entries
        for id in 1...25 {
            let key = String(id)
            if data.levelProgress[key] == nil {
                data.levelProgress[key] = LevelProgress.initial(levelId: id)
            }
        }
        // Phase 4: daily goal reset check on load
        checkDailyGoalReset()
    }

    private func loadFromURL(_ url: URL) -> ProgressData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ProgressData.self, from: data)
    }

    /// One-time migration from scattered UserDefaults keys to unified ProgressData
    private func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "didMigrateProfile") == false else { return }
        // If there's an existing progress file, don't overwrite
        let fileExists = fileManager.fileExists(atPath: progressFileURL.path)
        if fileExists {
            defaults.set(true, forKey: "didMigrateProfile")
            return
        }
        // Build profile from UserDefaults
        var profile = PlayerProfile()
        profile.currentStreak = defaults.integer(forKey: "currentStreak")
        profile.bestStreak = defaults.integer(forKey: "bestStreak")
        profile.lastPlayDate = defaults.object(forKey: "lastPlayDate") as? Date
        var pd = ProgressData()
        pd.profile = profile
        do {
            let jsonData = try encoder.encode(pd)
            try jsonData.write(to: progressFileURL, options: .atomic)
            defaults.set(true, forKey: "didMigrateProfile")
        } catch {
            print("[ProgressRepository] Migration failed: \(error)")
        }
    }

    // MARK: - Save (atomic)

    func save() {
        do {
            let jsonData = try encoder.encode(data)
            // Write to temp
            try jsonData.write(to: tempFileURL, options: .atomic)
            // Atomic replace
            if fileManager.fileExists(atPath: progressFileURL.path) {
                _ = try? fileManager.replaceItem(at: progressFileURL, withItemAt: tempFileURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                try fileManager.moveItem(at: tempFileURL, to: progressFileURL)
            }
            // Atomic backup: write new backup then replace old one
            let backupTemp = backupFileURL.appendingPathExtension("tmp")
            _ = try? fileManager.copyItem(at: progressFileURL, to: backupTemp)
            if fileManager.fileExists(atPath: backupFileURL.path) {
                _ = try? fileManager.replaceItem(at: backupFileURL, withItemAt: backupTemp, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                _ = try? fileManager.moveItem(at: backupTemp, to: backupFileURL)
            }
        } catch {
            print("[ProgressRepository] Save failed: \(error)")
        }
    }

    // MARK: - Word Progress

    func wordProgress(for wordId: Int) -> WordProgress {
        let key = String(wordId)
        if let wp = data.wordProgress[key] { return wp }
        return WordProgress.initial(wordId: wordId)
    }

    func updateWordProgress(_ wp: WordProgress) {
        let oldMastery = data.wordProgress[String(wp.wordId)]?.mastery ?? .new
        data.wordProgress[String(wp.wordId)] = wp
        // Phase 4: track daily goal (new → learning+)
        if oldMastery == .new && wp.mastery.rawValue > oldMastery.rawValue {
            incrementDailyGoalProgress()
        }
        save()
    }

    func wordsDueForReview(now: Date) -> [WordProgress] {
        data.wordProgress.values.filter {
            $0.nextReviewDate <= now && $0.mastery != .mastered
        }
    }

    /// Words where wrongCount > 0 and not yet "cleared" (consecutiveCorrect < 3)
    func mistakeWords() -> [WordProgress] {
        data.wordProgress.values.filter {
            $0.wrongCount > 0 && $0.consecutiveCorrect < 3
        }.sorted { $0.lastReviewed > $1.lastReviewed }
    }

    // MARK: - Level Progress

    func levelProgress(for levelId: Int) -> LevelProgress {
        data.levelProgress[String(levelId)] ?? LevelProgress.initial(levelId: levelId)
    }

    func updateLevelProgress(_ lp: LevelProgress) {
        data.levelProgress[String(lp.levelId)] = lp
        save()
    }

    func isLevelUnlocked(_ levelId: Int) -> Bool {
        if levelId == 1 { return true }
        let prevKey = String(levelId - 1)
        return data.levelProgress[prevKey]?.isCompleted ?? false
    }

    // MARK: - Active Session

    func saveActiveSession(_ session: GameSession?) {
        data.activeSession = session
        save()
    }

    func clearActiveSession() {
        data.activeSession = nil
        save()
    }

    // MARK: - Profile

    func updateProfile(_ update: (inout PlayerProfile) -> Void) {
        update(&data.profile)
        save()
    }

    func recordPlay() {
        let today = Date()
        let lastPlay = data.profile.lastPlayDate
        var streak = data.profile.currentStreak

        if let lastPlay = lastPlay {
            if Calendar.current.isDateInToday(lastPlay) { /* Already counted today */ }
            else if Calendar.current.isDateInYesterday(lastPlay) { streak += 1 }
            else { streak = 1 }
        } else {
            streak = 1
        }

        data.profile.lastPlayDate = today
        data.profile.currentStreak = streak
        data.profile.bestStreak = max(streak, data.profile.bestStreak)
        save()
    }

    // MARK: - Daily Challenge

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var isDailyCompleted: Bool {
        data.dailyChallengeRecords[todayKey]?.isCompleted ?? false
    }

    var dailyBestScore: Int {
        data.dailyChallengeRecords[todayKey]?.bestScore ?? 0
    }

    func recordDailyCompletion(score: Int) {
        let key = todayKey
        let prev = data.dailyChallengeRecords[key]
        let prevBest = prev?.bestScore ?? 0
        data.dailyChallengeRecords[key] = DailyRecord(
            isCompleted: true,
            bestScore: max(prevBest, score)
        )
        // Clean up records older than 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        data.dailyChallengeRecords = data.dailyChallengeRecords.filter { key, _ in
            guard let date = formatter.date(from: key) else { return true }
            return date >= cutoff
        }
        save()
    }

    // MARK: - Stats

    var totalWordsLearned: Int {
        data.wordProgress.values.filter { $0.mastery.rawValue >= MasteryLevel.learning.rawValue }.count
    }

    var totalStars: Int {
        data.levelProgress.values.reduce(0) { $0 + $1.stars }
    }

    /// Number of words reviewed/learned today
    var wordsReviewedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return data.wordProgress.values.filter { word in
            word.lastReviewed >= today && word.mastery != .new
        }.count
    }

    // MARK: - Daily Goal (Phase 4)

    /// Check if daily goal needs reset (new day)
    func checkDailyGoalReset() {
        if let lastReset = data.profile.dailyGoalLastResetDate,
           Calendar.current.isDateInToday(lastReset) {
            return // Same day, no reset needed
        }
        // New day — reset daily goal
        let wasCompleted = data.profile.dailyGoalCompletedCount >= data.profile.dailyGoalTarget
        if wasCompleted {
            data.profile.dailyGoalConsecutiveDays += 1
        } else {
            data.profile.dailyGoalConsecutiveDays = 0
        }
        data.profile.dailyGoalCompletedCount = 0
        data.profile.dailyGoalBonusClaimed = false
        data.profile.dailyGoalLastResetDate = Date()
        save()
    }

    /// Increment daily goal count (called when mastery upgrades from .new)
    func incrementDailyGoalProgress() {
        checkDailyGoalReset()
        data.profile.dailyGoalCompletedCount += 1
        if !data.profile.dailyGoalBonusClaimed &&
           data.profile.dailyGoalCompletedCount >= data.profile.dailyGoalTarget {
            data.profile.dailyGoalBonusClaimed = true
            data.profile.coins += 20 // daily goal bonus
        }
        save()
    }

    /// Daily goal info for display
    var dailyGoalProgress: (completed: Int, target: Int, isDone: Bool, consecutiveDays: Int) {
        return (
            data.profile.dailyGoalCompletedCount,
            data.profile.dailyGoalTarget,
            data.profile.dailyGoalBonusClaimed,
            data.profile.dailyGoalConsecutiveDays
        )
    }
}
