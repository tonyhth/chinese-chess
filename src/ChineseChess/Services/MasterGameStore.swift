import Foundation
import CryptoKit

// MARK: - 大师对局数据管理器

/// 大师对局索引加载 + 倒排索引 + 按需解析
@MainActor
class MasterGameStore: ObservableObject {
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
        let head = pgnData.prefix(1024)
        let hash = SHA256.hash(data: head).compactMap { String(format: "%02x", $0) }.joined()
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
            } else {
                playerIndex[game.blackNameCN, default: []].append(game)
            }
            // 按赛事
            eventIndex[game.event, default: []].append(game)
            // 按开局
            if !game.firstMove.isEmpty {
                openingIndex[game.firstMove, default: []].append(game)
            }
        }
    }

    /// 构建二级开局分类倒排索引
    private func buildSubcategoryIndices() {
        let allCategories = OpeningCategories.categories
        for category in allCategories {
            for sub in category.subcategories {
                let candidates = openingIndex[category.firstMove] ?? []
                let matching = candidates.filter { game in
                    guard game.firstMoves.count >= sub.firstMoves.count else { return false }
                    return zip(game.firstMoves, sub.firstMoves).allSatisfy { $0 == $1 }
                }
                subcategoryIndex[sub.id] = matching
            }
        }
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
}
