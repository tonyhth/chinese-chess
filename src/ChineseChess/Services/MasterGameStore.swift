import Foundation
import CryptoKit

// MARK: - 大师对局数据管理器

/// 大师对局索引加载 + 倒排索引 + 按需解析
@MainActor
class MasterGameStore: ObservableObject {
    static let shared = MasterGameStore()

    private(set) var allGames: [MasterGameIndex] = []
    private(set) var stats: MasterStatsFile?
    private(set) var isLoaded = false
    private(set) var loadError: String?

    // 倒排索引（加载后构建，O(1) 查询）
    private var playerIndex: [String: [MasterGameIndex]] = [:]
    private var eventIndex: [String: [MasterGameIndex]] = [:]
    private var openingIndex: [String: [MasterGameIndex]] = [:]
    private var subcategoryIndex: [String: [MasterGameIndex]] = [:]

    // MARK: - 加载

    /// 首次进入演示功能时加载索引（lazy load）
    func loadIfNeeded() async {
        guard !isLoaded else { return }

        do {
            // 加载索引
            guard let indexURL = Bundle.main.url(forResource: "master-game-index", withExtension: "json") else {
                loadError = "索引文件缺失"
                return
            }
            let indexData = try Data(contentsOf: indexURL)
            let decoded = try JSONDecoder().decode(MasterGameIndexFile.self, from: indexData)

            // 校验 PGN 文件绑定（非阻塞，不匹配时仅警告）
            verifyPGNHash(expected: decoded.pgnHash)

            self.allGames = decoded.games

            // 加载统计
            if let statsURL = Bundle.main.url(forResource: "master-stats", withExtension: "json") {
                let statsData = try Data(contentsOf: statsURL)
                self.stats = try JSONDecoder().decode(MasterStatsFile.self, from: statsData)
            }

            // 构建倒排索引
            buildInvertedIndices()
            buildSubcategoryIndices()

            self.isLoaded = true
        } catch {
            loadError = "索引加载失败：\(error.localizedDescription)"
        }
    }

    // MARK: - PGN 哈希校验

    private func verifyPGNHash(expected: String) {
        guard let pgnURL = Bundle.main.url(
            forResource: "xqdb_masters_40711_UCI_games",
            withExtension: "pgn",
            subdirectory: "pgn-extracted"
        ) else { return }

        guard let pgnData = try? Data(contentsOf: pgnURL, options: .mappedIfSafe) else { return }
        let hash = SHA256.hash(data: pgnData).compactMap { String(format: "%02x", $0) }.joined()
        if hash != expected {
            #if DEBUG
            AppLog.puzzleStore.warning("PGN hash mismatch: index=\(expected.prefix(8))... actual=\(hash.prefix(8))...")
            #endif
        }
    }

    // MARK: - 倒排索引构建

    private func buildInvertedIndices() {
        for game in allGames {
            // 按棋手（红方和黑方都建索引）
            playerIndex[game.redNameCN, default: []].append(game)
            if game.redNameCN != game.blackNameCN {
                playerIndex[game.blackNameCN, default: []].append(game)
            }
            // 同名时已在上面 append 过，不重复
            // 按赛事
            eventIndex[game.event, default: []].append(game)
            // 按开局
            if !game.firstMove.isEmpty {
                openingIndex[game.firstMove, default: []].append(game)
            }
        }
    }

    /// 构建二级开局分类倒排索引（最长匹配优先，一对局只匹配第一个命中的子分类）
    private func buildSubcategoryIndices() {
        let allCategories = OpeningCategories.categories
        for category in allCategories {
            guard !category.subcategories.isEmpty else { continue }

            let candidates = openingIndex[category.firstMove] ?? []

            // 子分类按 firstMoves 长度降序排列（最长匹配优先）
            let sortedSubs = category.subcategories.sorted { $0.firstMoves.count > $1.firstMoves.count }

            var matchedGameIds = Set<Int>()

            for sub in sortedSubs {
                let matching = candidates.filter { game in
                    // 跳过已匹配的对局（排他）
                    if matchedGameIds.contains(game.id) { return false }
                    guard game.firstMoves.count >= sub.firstMoves.count else { return false }
                    let isMatch = zip(game.firstMoves, sub.firstMoves).allSatisfy { $0 == $1 }
                    if isMatch {
                        matchedGameIds.insert(game.id)
                    }
                    return isMatch
                }
                subcategoryIndex[sub.id] = matching
            }

            // 兜底：“其他应手”子分类 = 未被任何子分类匹配的对局
            let otherId = "\(category.id)_other"
            let unmatched = candidates.filter { game in
                !matchedGameIds.contains(game.id)
            }
            if !unmatched.isEmpty {
                subcategoryIndex[otherId] = unmatched
            }
        }
    }

    // MARK: - gameCount 查询

    /// 查询开局分类的对局数
    func gameCount(for opening: OpeningCategory) -> Int {
        if opening.firstMove.isEmpty {
            return byOpening("").count
        }
        return openingIndex[opening.firstMove]?.count ?? 0
    }

    /// 查询子分类的对局数
    func gameCount(for subcategory: OpeningSubcategory) -> Int {
        return subcategoryIndex[subcategory.id]?.count ?? 0
    }

    // MARK: - O(1) 查询

    func byOpening(_ firstMove: String) -> [MasterGameIndex] {
        if firstMove.isEmpty {
            // "其他"：不在预定义开局中的
            let known = Set(OpeningCategories.categories.compactMap { cat in
                cat.firstMove.isEmpty ? nil : cat.firstMove
            })
            return allGames.filter { !known.contains($0.firstMove) }
        }
        return openingIndex[firstMove] ?? []
    }

    func bySubcategory(_ subcategoryId: String) -> [MasterGameIndex] {
        subcategoryIndex[subcategoryId] ?? []
    }

    func byPlayer(_ name: String) -> [MasterGameIndex] {
        playerIndex[name] ?? []
    }

    func byEvent(_ event: String) -> [MasterGameIndex] {
        eventIndex[event] ?? []
    }

    // MARK: - Phase D: 走法序列匹配（开局探索与大师棋谱联动）

    /// 按走法序列前缀匹配对局
    /// - Parameter moves: UCI 走法序列（如 ["h2e2", "b9c7"]）
    /// - Returns: firstMoves 以给定序列开头的所有对局
    func games(matchingFirstMoves moves: [String]) -> [MasterGameIndex] {
        guard !moves.isEmpty else { return allGames }
        // 利用 openingIndex 做一级过滤（第一步走法），再精确匹配前缀
        let firstMove = moves[0]
        let candidates = openingIndex[firstMove] ?? allGames
        return candidates.filter { game in
            let fm = game.firstMoves
            guard fm.count >= moves.count else { return false }
            return zip(fm, moves).allSatisfy { $0 == $1 }
        }
    }
}
