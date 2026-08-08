import Foundation

// MARK: - 大师对局索引条目

/// 大师对局的索引条目（离线预生成，不包含走法数据）
struct MasterGameIndex: Codable, Identifiable, Sendable, Equatable {
    let id: Int                  // 全局序号（0-based）
    let event: String            // 赛事名称（PGN 原始值，英文）
    let eventCN: String?
    let redName: String
    let blackName: String
    let redNameCN: String?
    let blackNameCN: String?
    let year: Int?
    let firstMove: String
    let firstMoves: [String]
    let moveCount: Int
    let pgnOffset: Int
    let pgnLength: Int

    enum CodingKeys: String, CodingKey {
        case id, event, eventCN, redName, blackName, redNameCN, blackNameCN
        case year, firstMove, firstMoves, moveCount, pgnOffset, pgnLength
    }
    
    // Memberwise init（测试用）
    init(id: Int, event: String, eventCN: String? = nil,
         redName: String, blackName: String,
         redNameCN: String? = nil, blackNameCN: String? = nil,
         year: Int? = nil, firstMove: String, firstMoves: [String],
         moveCount: Int, pgnOffset: Int, pgnLength: Int) {
        self.id = id; self.event = event; self.eventCN = eventCN
        self.redName = redName; self.blackName = blackName
        self.redNameCN = redNameCN; self.blackNameCN = blackNameCN
        self.year = year; self.firstMove = firstMove; self.firstMoves = firstMoves
        self.moveCount = moveCount; self.pgnOffset = pgnOffset; self.pgnLength = pgnLength
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        event = try c.decode(String.self, forKey: .event)
        eventCN = try c.decodeIfPresent(String.self, forKey: .eventCN)
        redName = try c.decode(String.self, forKey: .redName)
        blackName = try c.decode(String.self, forKey: .blackName)
        redNameCN = try c.decodeIfPresent(String.self, forKey: .redNameCN)
        blackNameCN = try c.decodeIfPresent(String.self, forKey: .blackNameCN)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        firstMove = try c.decode(String.self, forKey: .firstMove)
        firstMoves = try c.decode([String].self, forKey: .firstMoves)
        moveCount = try c.decode(Int.self, forKey: .moveCount)
        pgnOffset = try c.decode(Int.self, forKey: .pgnOffset)
        pgnLength = try c.decode(Int.self, forKey: .pgnLength)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(event, forKey: .event)
        try c.encodeIfPresent(eventCN, forKey: .eventCN)
        try c.encode(redName, forKey: .redName)
        try c.encode(blackName, forKey: .blackName)
        try c.encodeIfPresent(redNameCN, forKey: .redNameCN)
        try c.encodeIfPresent(blackNameCN, forKey: .blackNameCN)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encode(firstMove, forKey: .firstMove)
        try c.encode(firstMoves, forKey: .firstMoves)
        try c.encode(moveCount, forKey: .moveCount)
        try c.encode(pgnOffset, forKey: .pgnOffset)
        try c.encode(pgnLength, forKey: .pgnLength)
    }
}

extension MasterGameIndex {
    var localizedRedName: String { LocalizedNameResolver.display(en: redName, cn: redNameCN) }
    var localizedBlackName: String { LocalizedNameResolver.display(en: blackName, cn: blackNameCN) }
    var localizedEvent: String { LocalizedNameResolver.display(en: event, cn: eventCN) }
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

    struct PlayerStat: Codable, Sendable, Hashable {
        let name: String
        let nameCN: String?
        let count: Int
        let pinyin: String?
        var stableId: String { "\(name)|\(nameCN ?? "")" }
        enum CodingKeys: String, CodingKey { case name, nameCN, count, pinyin }
        init(name: String, nameCN: String? = nil, count: Int, pinyin: String? = nil) {
            self.name = name; self.nameCN = nameCN; self.count = count; self.pinyin = pinyin
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            nameCN = try c.decodeIfPresent(String.self, forKey: .nameCN)
            count = try c.decode(Int.self, forKey: .count)
            pinyin = try c.decodeIfPresent(String.self, forKey: .pinyin)
        }
        var localizedName: String { LocalizedNameResolver.display(en: name, cn: nameCN) }
    }

    struct EventStat: Codable, Sendable, Hashable {
        let name: String
        let nameCN: String?
        let year: Int?
        let count: Int
        var stableId: String { "\(name)|\(nameCN ?? "")|\(year ?? -1)" }
        enum CodingKeys: String, CodingKey { case name, nameCN, year, count }
        init(name: String, nameCN: String? = nil, year: Int? = nil, count: Int) {
            self.name = name; self.nameCN = nameCN; self.year = year; self.count = count
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            nameCN = try c.decodeIfPresent(String.self, forKey: .nameCN)
            year = try c.decodeIfPresent(Int.self, forKey: .year)
            count = try c.decode(Int.self, forKey: .count)
        }
        var localizedName: String { LocalizedNameResolver.display(en: name, cn: nameCN) }
    }
}
