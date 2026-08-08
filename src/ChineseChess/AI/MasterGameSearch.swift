import Foundation

// MARK: - Phase B3 Step 4: 大师对局搜索

/// 搜索结果类型
enum MasterSearchResult: Identifiable {
    case player(MasterStatsFile.PlayerStat, score: Int)
    case event(MasterStatsFile.EventStat, score: Int)

    var id: String {
        switch self {
        case .player(let p, _): return "player:\(p.stableId)"
        case .event(let e, _):  return "event:\(e.stableId)"
        }
    }

    /// 搜索得分（前缀200/包含100 + 对局数）
    var score: Int {
        switch self {
        case .player(_, let s): return s
        case .event(_, let s):  return s
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .player(let p, _): return p.localizedName
        case .event(let e, _):  return e.localizedName
        }
    }

    /// 副标题
    var subtitle: String? {
        switch self {
        case .player(let p, _):
            if let cn = p.nameCN, !cn.isEmpty, cn != p.name {
                return p.name
            }
            return nil
        case .event(let e, _):  return e.year.map { "\($0)" }
        }
    }

    /// 对局数
    var count: Int {
        switch self {
        case .player(let p, _): return p.count
        case .event(let e, _):  return e.count
        }
    }
}

/// 大师对局内存搜索
///
/// 策略：前缀匹配（200分） + 包含匹配（100分），同分按对局数降序
/// 搜索范围：棋手中文名 + 英文名 + 赛事中文名
/// 防抖：300ms debounce（由调用方通过 Task.sleep + Task.cancel 实现）
struct MasterGameSearch {

    let store: MasterGameStore

    /// 搜索棋手/赛事，返回匹配结果（已排序）
    ///
    /// - Parameter query: 搜索关键词，空字符串返回空数组
    /// - Returns: 按相关性 + 对局数排序的结果列表
    @MainActor
    func search(query: String) -> [MasterSearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [MasterSearchResult] = []

        // 棋手匹配
        let players = store.stats?.players ?? []
        for player in players {
            if let cn = player.nameCN, cn.hasPrefix(query) {
                results.append(.player(player, score: 200 + player.count))
            } else if player.name.hasPrefix(query) {
                results.append(.player(player, score: 150 + player.count))
            } else if let cn = player.nameCN, cn.contains(query) {
                results.append(.player(player, score: 100 + player.count))
            } else if player.name.contains(query) {
                results.append(.player(player, score: 50 + player.count))
            }
        }

        // 赛事匹配
        let events = store.stats?.events ?? []
        for event in events {
            if let cn = event.nameCN, cn.hasPrefix(query) {
                results.append(.event(event, score: 200 + event.count))
            } else if event.name.hasPrefix(query) {
                results.append(.event(event, score: 150 + event.count))
            } else if let cn = event.nameCN, cn.contains(query) {
                results.append(.event(event, score: 100 + event.count))
            }
        }

        return results.sorted { $0.score > $1.score }
    }
}
