import Foundation

// MARK: - 残局数据加载

final class PuzzleStore {
    static let shared = PuzzleStore()

    private(set) var puzzles: [Puzzle] = []

    private let progressKey = "chinesechess.puzzle_progress"

    private init() {
        loadPuzzles()
    }

    // MARK: - 加载残局数据

    private func loadPuzzles() {
        guard let url = Bundle.module.url(forResource: "puzzles", withExtension: "json") else {
            print("[INFO] PuzzleStore: puzzles.json not found, using empty list")
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            print("[WARN] PuzzleStore: failed to read puzzles.json")
            return
        }

        guard let puzzleData = try? JSONDecoder().decode(PuzzleData.self, from: data) else {
            print("[WARN] PuzzleStore: failed to decode puzzles.json")
            return
        }

        puzzles = puzzleData.puzzles
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
        guard let data = UserDefaults.standard.data(forKey: progressKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: PuzzleProgress].self, from: data)) ?? [:]
    }

    func recordProgress(_ p: PuzzleProgress) {
        var all = progress
        all[p.puzzleId] = p
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    func progress(for puzzleId: String) -> PuzzleProgress? {
        progress[puzzleId]
    }
}
