import Foundation

// MARK: - 残局数据加载

final class PuzzleStore {
    static let shared = PuzzleStore()

    private(set) var puzzles: [Puzzle] = []

    private let progressKey = "chinesechess.puzzle_progress"
    private let versionKey = "chinesechess.puzzle_version"

    /// 进度缓存，避免每次查询都解码 UserDefaults JSON
    private var _progressCache: [String: PuzzleProgress]?

    private init() {
        loadPuzzles()
    }

    // MARK: - 加载残局数据

    private func loadPuzzles() {
        // 1. 优先用 ResourceBundle（SPM bundle 根目录）
        var url = ResourceBundle.url(forResource: "puzzles", withExtension: "json")

        // 2. Fallback: .app 打包时资源可能在 Puzzles/ 子目录
        if url == nil {
            url = ResourceBundle.url(forResource: "puzzles", withExtension: "json", subdirectory: "Puzzles")
        }

        guard let puzzleURL = url else {
            AppLog.puzzleStore.error("puzzles.json not found in any location")
            return
        }

        guard let data = try? Data(contentsOf: puzzleURL) else {
            AppLog.puzzleStore.error("failed to read puzzles.json")
            return
        }

        do {
            let puzzleData = try JSONDecoder().decode(PuzzleData.self, from: data)
            puzzles = puzzleData.puzzles

            // 检查 version 变化，刷新缓存
            let currentVersion = puzzleData.version
            let savedVersion = UserDefaults.standard.integer(forKey: versionKey)
            if currentVersion > savedVersion {
                UserDefaults.standard.set(currentVersion, forKey: versionKey)
                // version 变化时不自动清除进度（puzzleId 保持兼容）
            }
        } catch {
            AppLog.puzzleStore.error("failed to decode puzzles.json - \(error)")
            return
        }
    }

    // MARK: - 查询

    func puzzle(byId id: String) -> Puzzle? {
        puzzles.first { $0.id == id }
    }

    func puzzles(byCategory category: String) -> [Puzzle] {
        puzzles.filter { $0.category == category }
    }

    var categories: [String] {
        Array(Set(puzzles.map { $0.category })).sorted()
    }

    // MARK: - 演示模式查询（Phase 1）

    /// 有 solution 的残局（过滤 freePlay 无 solution 的 17 局）
    var demoPuzzles: [Puzzle] {
        puzzles.filter { !$0.solution.isEmpty }
    }

    /// 演示残局 ID 集合（O(1) 查询，避免 demoPuzzles.contains 线性扫描）
    lazy var demoPuzzleIds: Set<String> = {
        Set(demoPuzzles.map { $0.id })
    }()

    /// 演示分类（只包含有 solution 的残局的分类）
    var demoCategories: [String] {
        Array(Set(demoPuzzles.map { $0.category })).sorted()
    }

    /// 演示模式：按分类查询（只返回有 solution 的）
    func demoPuzzles(byCategory category: String) -> [Puzzle] {
        demoPuzzles.filter { $0.category == category }
    }

    // MARK: - v2.2.6 新增查询

    /// 按难度筛选
    func puzzles(byDifficulty stars: Int) -> [Puzzle] {
        puzzles.filter { $0.stars == stars }
    }

    /// 搜索（name + description + category，中文匹配）
    func searchPuzzles(query: String) -> [Puzzle] {
        guard !query.isEmpty else { return puzzles }
        let q = query.lowercased()
        return puzzles.filter { p in
            p.name.lowercased().contains(q) ||
            p.description.lowercased().contains(q) ||
            p.category.lowercased().contains(q)
        }
    }

    /// 适情雅趣专用查询（全部残局都是适情雅趣来源）
    var shiqingyaquPuzzles: [Puzzle] {
        puzzles.filter { $0.source == "适情雅趣" }
    }

    /// 统计
    var totalPuzzles: Int { puzzles.count }

    var completedCount: Int {
        let prog = progress
        return puzzles.filter { prog[$0.id]?.isCompleted == true }.count
    }

    // MARK: - 进度持久化

    var progress: [String: PuzzleProgress] {
        if let cached = _progressCache { return cached }
        guard let data = UserDefaults.standard.data(forKey: progressKey) else {
            _progressCache = [:]
            return [:]
        }
        let decoded = (try? JSONDecoder().decode([String: PuzzleProgress].self, from: data)) ?? [:]
        _progressCache = decoded
        return decoded
    }

    func recordProgress(_ p: PuzzleProgress) {
        var all = progress
        let wasCompleted = all[p.puzzleId]?.isCompleted == true
        all[p.puzzleId] = p
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
        _progressCache = all

        // v3.0 gap fix P1-2: 残局完成时更新 PlayerProfile.puzzlesCompleted
        // 首次完成才计数，避免重复
        if p.isCompleted && !wasCompleted {
            PlayerProfileStore.shared.update { profile in
                // bonusPuzzlesUnlocked 激活时进度 ×2，让连续登录奖励有实际效果
                let increment = profile.bonusPuzzlesUnlocked ? 2 : 1
                profile.puzzlesCompleted += increment
            }
        }
    }

    func progress(for puzzleId: String) -> PuzzleProgress? {
        progress[puzzleId]
    }

    /// 全部进度（用于批量筛选/排序）
    var progressMap: [String: PuzzleProgress] {
        progress
    }

    /// 清除进度缓存（测试用）
    func invalidateProgressCache() {
        _progressCache = nil
    }
}
