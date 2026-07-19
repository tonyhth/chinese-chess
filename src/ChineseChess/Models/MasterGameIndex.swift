import Foundation

// MARK: - 大师对局索引条目

/// 大师对局的索引条目（离线预生成，不包含走法数据）
struct MasterGameIndex: Codable, Identifiable, Sendable, Equatable {
    let id: Int                  // 全局序号（0-based）
    let event: String            // 赛事名称（PGN 原始值，英文）
    let redName: String          // 红方姓名（归一化后）
    let blackName: String        // 黑方姓名（归一化后）
    let redNameCN: String        // 红方中文名（来自 name_map，无映射则回退 redName）
    let blackNameCN: String      // 黑方中文名（来自 name_map，无映射则回退 blackName）
    let year: Int?               // 对局年份（从 Event 标签正则提取）
    let firstMove: String        // 第一步走法（ICCS，用于一级开局分类）
    let firstMoves: [String]     // 前 N 步走法（用于二级开局分类 + 开局树）
    let moveCount: Int           // 总步数
    let pgnOffset: Int           // PGN 文件中的字节偏移
    let pgnLength: Int           // 该局 PGN 文本的字节长度
}

// MARK: - 索引文件格式

/// 索引文件的顶层结构
struct MasterGameIndexFile: Codable, Sendable {
    let version: Int
    let pgnHash: String
    let totalGames: Int
    let games: [MasterGameIndex]
}

// MARK: - 统计文件格式

/// master-stats.json 的顶层结构
struct MasterStatsFile: Codable, Sendable {
    let totalGames: Int
    let players: [PlayerStat]
    let events: [EventStat]
    let openingDistribution: [String: Int]

    struct PlayerStat: Codable, Sendable {
        let name: String
        let nameCN: String
        let count: Int
    }

    struct EventStat: Codable, Sendable {
        let name: String
        let nameCN: String
        let year: Int?
        let count: Int
    }
}
