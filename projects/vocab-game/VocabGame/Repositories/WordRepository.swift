import Foundation

enum AppError: LocalizedError {
    case dataLoadFailed(String)
    case dataSaveFailed(String)
    case dataCorrupted
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .dataLoadFailed(let msg): return "数据加载失败: \(msg)"
        case .dataSaveFailed(let msg): return "数据保存失败: \(msg)"
        case .dataCorrupted: return "数据损坏，已恢复默认"
        case .fileNotFound: return "文件未找到"
        }
    }
}

class WordRepository {
    private(set) var allWords: [Word] = []
    private(set) var wordsByGroup: [Int: [Word]] = [:]

    /// 测试用：直接注入单词列表
    convenience init(words: [Word]) {
        self.init()
        self.allWords = words
        self.wordsByGroup = Dictionary(grouping: words, by: { $0.group })
    }

    func loadWords() throws {
        guard let url = Bundle.main.url(forResource: "wordlist", withExtension: "json") else {
            throw AppError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        allWords = try JSONDecoder().decode([Word].self, from: data)
        wordsByGroup = Dictionary(grouping: allWords, by: { $0.group })
    }

    func words(forGroup group: Int) -> [Word] {
        wordsByGroup[group] ?? []
    }

    func words(forLevel levelId: Int) -> [Word] {
        words(forGroup: levelId)
    }

    func randomDistractors(excluding word: Word, count: Int) -> [Word] {
        allWords
            .filter { $0.id != word.id }
            .shuffled()
            .prefix(count)
            .map { $0 }
    }
}
