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
            print("[WARN] PuzzleStore: puzzles.json not found in any location")
            return
        }

        guard let data = try? Data(contentsOf: puzzleURL) else {
            print("[WARN] PuzzleStore: failed to read puzzles.json")
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
            print("[WARN] PuzzleStore: failed to decode puzzles.json - \(error)")
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
        all[p.puzzleId] = p
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
        _progressCache = all
    }

    func progress(for puzzleId: String) -> PuzzleProgress? {
        progress[puzzleId]
    }

    /// 清除进度缓存（测试用）
    func invalidateProgressCache() {
        _progressCache = nil
    }
}
