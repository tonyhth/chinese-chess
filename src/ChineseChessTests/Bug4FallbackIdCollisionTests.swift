import XCTest
@testable import ChineseChess

/// Bug 4 修复测试：Piece.fallbackId() ID 碰撞
///
/// 当前实现（commit 2cd2b7c）：非开局位置使用直接编码
/// ID = 10000 + kindIndex*1000 + sideBit*100 + row*10 + col
/// 范围 10000-16198，与开局 ID 0-31 完全隔离，天然唯一
///
/// 验证要点：
/// 1. fallbackId 在非开局位置返回唯一 ID（不再返回 -1）
/// 2. 开局 ID（0-31）保持不变
/// 3. 非开局 ID 在 10000-16198 范围，与开局 ID 完全隔离
/// 4. 直接编码零碰撞：不同棋子不同位置产生不同 ID
/// 5. 确定性：相同输入返回相同 ID
/// 6. 旧存档兼容性：Codable 解码后 ID 正确
final class Bug4FallbackIdCollisionTests: XCTestCase {

    // MARK: - 1. 开局 ID 保持不变（0-31）

    /// 验证所有 32 个开局位置的 fallbackId 与 Board.initialPieces() 的 ID 一致
    func testOpeningIdsMatchInitialPieces() {
        let initialPieces = Board.initialPieces()
        XCTAssertEqual(initialPieces.count, 32, "开局应有 32 个棋子")

        for piece in initialPieces {
            let fallbackId = Piece.fallbackId(kind: piece.kind, side: piece.side, position: piece.position)
            XCTAssertEqual(fallbackId, piece.id,
                "开局位置 fallbackId 不匹配: \(piece.kind) \(piece.side) @ \(piece.position) → fallback=\(fallbackId), expected=\(piece.id)")
        }
    }

    /// 红方开局 ID 完整映射
    func testRedOpeningIds() {
        XCTAssertEqual(Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 9, col: 0)), 0)
        XCTAssertEqual(Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 9, col: 8)), 1)
        XCTAssertEqual(Piece.fallbackId(kind: .horse, side: .red, position: Position(row: 9, col: 1)), 2)
        XCTAssertEqual(Piece.fallbackId(kind: .horse, side: .red, position: Position(row: 9, col: 7)), 3)
        XCTAssertEqual(Piece.fallbackId(kind: .elephant, side: .red, position: Position(row: 9, col: 2)), 4)
        XCTAssertEqual(Piece.fallbackId(kind: .elephant, side: .red, position: Position(row: 9, col: 6)), 5)
        XCTAssertEqual(Piece.fallbackId(kind: .advisor, side: .red, position: Position(row: 9, col: 3)), 6)
        XCTAssertEqual(Piece.fallbackId(kind: .advisor, side: .red, position: Position(row: 9, col: 5)), 7)
        XCTAssertEqual(Piece.fallbackId(kind: .general, side: .red, position: Position(row: 9, col: 4)), 8)
        XCTAssertEqual(Piece.fallbackId(kind: .cannon, side: .red, position: Position(row: 7, col: 1)), 9)
        XCTAssertEqual(Piece.fallbackId(kind: .cannon, side: .red, position: Position(row: 7, col: 7)), 10)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 6, col: 0)), 11)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 6, col: 2)), 12)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 6, col: 4)), 13)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 6, col: 6)), 14)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 6, col: 8)), 15)
    }

    /// 黑方开局 ID 完整映射
    func testBlackOpeningIds() {
        XCTAssertEqual(Piece.fallbackId(kind: .chariot, side: .black, position: Position(row: 0, col: 0)), 16)
        XCTAssertEqual(Piece.fallbackId(kind: .chariot, side: .black, position: Position(row: 0, col: 8)), 17)
        XCTAssertEqual(Piece.fallbackId(kind: .horse, side: .black, position: Position(row: 0, col: 1)), 18)
        XCTAssertEqual(Piece.fallbackId(kind: .horse, side: .black, position: Position(row: 0, col: 7)), 19)
        XCTAssertEqual(Piece.fallbackId(kind: .elephant, side: .black, position: Position(row: 0, col: 2)), 20)
        XCTAssertEqual(Piece.fallbackId(kind: .elephant, side: .black, position: Position(row: 0, col: 6)), 21)
        XCTAssertEqual(Piece.fallbackId(kind: .advisor, side: .black, position: Position(row: 0, col: 3)), 22)
        XCTAssertEqual(Piece.fallbackId(kind: .advisor, side: .black, position: Position(row: 0, col: 5)), 23)
        XCTAssertEqual(Piece.fallbackId(kind: .general, side: .black, position: Position(row: 0, col: 4)), 24)
        XCTAssertEqual(Piece.fallbackId(kind: .cannon, side: .black, position: Position(row: 2, col: 1)), 25)
        XCTAssertEqual(Piece.fallbackId(kind: .cannon, side: .black, position: Position(row: 2, col: 7)), 26)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 3, col: 0)), 27)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 3, col: 2)), 28)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 3, col: 4)), 29)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 3, col: 6)), 30)
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 3, col: 8)), 31)
    }

    // MARK: - 2. 非开局位置不再返回 -1

    /// 非开局位置应返回 10000+ 的唯一 ID，不再返回 -1
    func testNonOpeningPositionDoesNotReturnMinusOne() {
        let nonOpeningPositions: [(PieceKind, Side, Position)] = [
            (.chariot, .red, Position(row: 5, col: 0)),
            (.horse, .red, Position(row: 5, col: 1)),
            (.cannon, .red, Position(row: 5, col: 1)),
            (.general, .red, Position(row: 5, col: 4)),
            (.soldier, .red, Position(row: 4, col: 4)),
            (.advisor, .red, Position(row: 8, col: 4)),
            (.elephant, .red, Position(row: 7, col: 4)),
        ]

        for (kind, side, pos) in nonOpeningPositions {
            let id = Piece.fallbackId(kind: kind, side: side, position: pos)
            XCTAssertNotEqual(id, -1, "\(kind) \(side) @ \(pos) 不应返回 -1")
            XCTAssertGreaterThanOrEqual(id, 10000, "\(kind) \(side) @ \(pos) ID 应 >= 10000，实际 \(id)")
            XCTAssertLessThanOrEqual(id, 16198, "\(kind) \(side) @ \(pos) ID 应 <= 16198，实际 \(id)")
        }
    }

    // MARK: - 3. 直接编码公式验证

    /// 验证直接编码公式：10000 + kindIndex*1000 + sideBit*100 + row*10 + col
    func testDirectEncodingFormula() {
        // 红车 (kindIndex=4, sideBit=0) 在 (5,3) → 10000 + 4000 + 0 + 50 + 3 = 14053
        XCTAssertEqual(Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 5, col: 3)), 14053)

        // 黑马 (kindIndex=3, sideBit=1) 在 (6,2) → 10000 + 3000 + 100 + 60 + 2 = 13162
        XCTAssertEqual(Piece.fallbackId(kind: .horse, side: .black, position: Position(row: 6, col: 2)), 13162)

        // 红炮 (kindIndex=5, sideBit=0) 在 (3,7) → 10000 + 5000 + 0 + 30 + 7 = 15037
        XCTAssertEqual(Piece.fallbackId(kind: .cannon, side: .red, position: Position(row: 3, col: 7)), 15037)

        // 黑将 (kindIndex=0, sideBit=1) 在 (1,5) → 10000 + 0 + 100 + 10 + 5 = 10115
        XCTAssertEqual(Piece.fallbackId(kind: .general, side: .black, position: Position(row: 1, col: 5)), 10115)

        // 红兵 (kindIndex=6, sideBit=0) 在 (2,5) → 10000 + 6000 + 0 + 20 + 5 = 16025
        XCTAssertEqual(Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 2, col: 5)), 16025)

        // 黑士 (kindIndex=1, sideBit=1) 在 (4,3) → 10000 + 1000 + 100 + 40 + 3 = 11143
        XCTAssertEqual(Piece.fallbackId(kind: .advisor, side: .black, position: Position(row: 4, col: 3)), 11143)

        // 红相 (kindIndex=2, sideBit=0) 在 (5,6) → 10000 + 2000 + 0 + 50 + 6 = 12056
        XCTAssertEqual(Piece.fallbackId(kind: .elephant, side: .red, position: Position(row: 5, col: 6)), 12056)
    }

    // MARK: - 4. 零碰撞验证：全量扫描

    /// 全量扫描：所有可能的棋子+位置组合，ID 互不重复
    func testZeroCollisionFullScan() {
        let kinds: [PieceKind] = [.general, .advisor, .elephant, .horse, .chariot, .cannon, .soldier]
        var idToKey: [Int: String] = [:]
        var collisions: [String] = []

        for kind in kinds {
            for side in [Side.red, .black] {
                for row in 0...9 {
                    for col in 0...8 {
                        let pos = Position(row: row, col: col)
                        let id = Piece.fallbackId(kind: kind, side: side, position: pos)
                        let key = "\(kind) \(side) @ (\(row),\(col))"
                        if let existingKey = idToKey[id] {
                            collisions.append("ID=\(id): \(existingKey) vs \(key)")
                        }
                        idToKey[id] = key
                    }
                }
            }
        }

        XCTAssertTrue(collisions.isEmpty,
            "发现 ID 碰撞（共 \(collisions.count) 对）:\n" + collisions.prefix(10).joined(separator: "\n"))
    }

    /// 非开局 ID 不与任何开局 ID（0-31）碰撞
    func testNonOpeningIdsDoNotCollideWithOpeningIds() {
        let kinds: [PieceKind] = [.general, .advisor, .elephant, .horse, .chariot, .cannon, .soldier]

        for kind in kinds {
            for side in [Side.red, .black] {
                for row in 0...9 {
                    for col in 0...8 {
                        let pos = Position(row: row, col: col)
                        let id = Piece.fallbackId(kind: kind, side: side, position: pos)
                        // 非0-31范围（直接编码保证 >= 10000，开局保证 0-31）
                        if id >= 0 && id <= 31 {
                            // 必须是精确的开局位置匹配
                            let initialPieces = Board.initialPieces()
                            let match = initialPieces.first { $0.id == id }
                            XCTAssertNotNil(match,
                                "ID=\(id) 在 0-31 范围但无对应开局棋子: \(kind) \(side) @ (\(row),\(col))")
                            if let match = match {
                                XCTAssertEqual(match.kind, kind)
                                XCTAssertEqual(match.side, side)
                                XCTAssertEqual(match.position, pos)
                            }
                        } else {
                            XCTAssertGreaterThanOrEqual(id, 10000,
                                "非开局 ID 应 >= 10000: \(kind) \(side) @ (\(row),\(col)) → \(id)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. 确定性

    /// 同一棋子在同一位置多次调用 fallbackId 结果一致
    func testDeterministicSameInputSameOutput() {
        let testCases: [(PieceKind, Side, Position)] = [
            (.chariot, .red, Position(row: 5, col: 3)),
            (.horse, .black, Position(row: 6, col: 2)),
            (.cannon, .red, Position(row: 3, col: 7)),
            (.general, .black, Position(row: 1, col: 5)),
            (.soldier, .red, Position(row: 2, col: 5)),
            (.advisor, .black, Position(row: 4, col: 3)),
            (.elephant, .red, Position(row: 5, col: 6)),
        ]

        for (kind, side, pos) in testCases {
            let id1 = Piece.fallbackId(kind: kind, side: side, position: pos)
            let id2 = Piece.fallbackId(kind: kind, side: side, position: pos)
            let id3 = Piece.fallbackId(kind: kind, side: side, position: pos)
            XCTAssertEqual(id1, id2, "\(kind) \(side) @ \(pos) 两次调用不一致: \(id1) vs \(id2)")
            XCTAssertEqual(id2, id3, "\(kind) \(side) @ \(pos) 三次调用不一致: \(id2) vs \(id3)")
        }
    }

    // MARK: - 6. 残局场景

    /// 典型残局：多棋子在非开局位置，所有 ID 互不重复
    func testEndgameScenarioNoIdCollision() {
        let pieces: [(PieceKind, Side, Position)] = [
            (.general, .red, Position(row: 9, col: 4)),   // 开局位置
            (.chariot, .red, Position(row: 5, col: 3)),    // 非开局
            (.general, .black, Position(row: 0, col: 4)),  // 开局位置
        ]

        var ids = Set<Int>()
        for (kind, side, pos) in pieces {
            let id = Piece.fallbackId(kind: kind, side: side, position: pos)
            XCTAssertFalse(ids.contains(id),
                "ID 碰撞: \(kind) \(side) @ \(pos) → ID=\(id)")
            ids.insert(id)
        }
    }

    /// 复杂残局：多棋子全部不在开局位置
    func testComplexEndgameNoCollision() {
        let pieces: [(PieceKind, Side, Position)] = [
            (.general, .red, Position(row: 8, col: 4)),
            (.chariot, .red, Position(row: 2, col: 5)),
            (.horse, .red, Position(row: 3, col: 6)),
            (.cannon, .red, Position(row: 1, col: 3)),
            (.soldier, .red, Position(row: 4, col: 4)),
            (.general, .black, Position(row: 1, col: 5)),
            (.chariot, .black, Position(row: 5, col: 0)),
        ]

        var ids = Set<Int>()
        var collisions: [(PieceKind, Side, Position, Int)] = []

        for (kind, side, pos) in pieces {
            let id = Piece.fallbackId(kind: kind, side: side, position: pos)
            if ids.contains(id) {
                collisions.append((kind, side, pos, id))
            }
            ids.insert(id)
        }

        XCTAssertTrue(collisions.isEmpty,
            "残局 ID 碰撞: \(collisions.map { "\($0.0) \($0.1) @ \($0.2) → \($0.3)" })")
    }

    // MARK: - 7. 旧存档兼容性

    /// Codable 解码：有 id 字段时直接使用
    func testCodableWithIdField() throws {
        let json = """
        {"id": 42, "kind": "chariot", "side": "red", "position": {"row": 5, "col": 3}}
        """
        let data = json.data(using: .utf8)!
        let piece = try JSONDecoder().decode(Piece.self, from: data)
        XCTAssertEqual(piece.id, 42, "有 id 字段时应直接使用 id=42")
        XCTAssertEqual(piece.kind, .chariot)
        XCTAssertEqual(piece.side, .red)
    }

    /// Codable 解码：无 id 字段时使用 fallbackId（开局位置）
    func testCodableWithoutIdField() throws {
        let json = """
        {"kind": "chariot", "side": "red", "position": {"row": 9, "col": 0}}
        """
        let data = json.data(using: .utf8)!
        let piece = try JSONDecoder().decode(Piece.self, from: data)
        XCTAssertEqual(piece.id, 0, "无 id 字段时应使用 fallbackId，红左车=0")
    }

    /// Codable 解码：无 id 字段时使用 fallbackId（非开局位置）
    func testCodableWithoutIdFieldNonOpening() throws {
        let json = """
        {"kind": "chariot", "side": "red", "position": {"row": 5, "col": 3}}
        """
        let data = json.data(using: .utf8)!
        let piece = try JSONDecoder().decode(Piece.self, from: data)
        XCTAssertGreaterThanOrEqual(piece.id, 10000, "非开局位置 fallbackId 应 >= 10000")
        XCTAssertNotEqual(piece.id, -1, "不应返回 -1")
    }

    /// Codable 解码：id 字段为 UUID String 时 decodeIfPresent(Int) 会 throw
    /// 这是 Codable 兼容代码的已知缺陷：String id 无法被 Int 解码，直接抛异常
    /// ⚠️ P1 Bug：UUID String fallback 分支不可达
    func testCodableWithUUIDStringId_Throws() {
        let json = """
        {"id": "550e8400-e29b-41d4-a716-446655440000", "kind": "horse", "side": "black", "position": {"row": 5, "col": 3}}
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Piece.self, from: data),
            "UUID String id 应导致解码抛异常（decodeIfPresent(Int) 不处理 String 类型）")
    }

    /// Codable 编解码 round-trip
    func testCodableRoundTrip() throws {
        let original = Piece(kind: .cannon, side: .red, position: Position(row: 5, col: 3), id: 14037)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Piece.self, from: encoded)
        XCTAssertEqual(decoded.id, original.id, "编解码后 ID 应一致")
        XCTAssertEqual(decoded.kind, original.kind)
        XCTAssertEqual(decoded.side, original.side)
        XCTAssertEqual(decoded.position, original.position)
    }

    // MARK: - 8. 开局位置 col 检查更严谨

    /// 开局位置 row 对但 col 错误，不应返回开局 ID
    func testOpeningRowWrongColReturnsNonOpeningId() {
        // 红帅在 (9,3) — row 对但 col 不对
        let id = Piece.fallbackId(kind: .general, side: .red, position: Position(row: 9, col: 3))
        XCTAssertNotEqual(id, 8, "帅在 (9,3) 不应返回开局 ID=8")
        XCTAssertGreaterThanOrEqual(id, 10000, "非开局位置应返回 >= 10000")

        // 黑将在 (0,3) — row 对但 col 不对
        let id2 = Piece.fallbackId(kind: .general, side: .black, position: Position(row: 0, col: 3))
        XCTAssertNotEqual(id2, 24, "将在 (0,3) 不应返回开局 ID=24")
        XCTAssertGreaterThanOrEqual(id2, 10000, "非开局位置应返回 >= 10000")

        // 红兵在 (6,1) — row 对但 col 不是合法兵位
        let id3 = Piece.fallbackId(kind: .soldier, side: .red, position: Position(row: 6, col: 1))
        XCTAssertGreaterThanOrEqual(id3, 10000, "兵在 (6,1) 不是开局位置")

        // 红车在 (9,4) — row 对但 col 不对
        let id4 = Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 9, col: 4))
        XCTAssertGreaterThanOrEqual(id4, 10000, "车在 (9,4) 不是开局位置")

        // 红马在 (9,3) — row 对但 col 不对
        let id5 = Piece.fallbackId(kind: .horse, side: .red, position: Position(row: 9, col: 3))
        XCTAssertGreaterThanOrEqual(id5, 10000, "马在 (9,3) 不是开局位置")
    }

    // MARK: - 9. ID 范围边界

    /// 最小非开局 ID：kindIndex=0(general), sideBit=0(red), row=0, col=0 → 10000
    func testMinNonOpeningId() {
        let id = Piece.fallbackId(kind: .general, side: .red, position: Position(row: 0, col: 0))
        XCTAssertGreaterThanOrEqual(id, 10000, "非开局 ID 最小值应 >= 10000")
    }

    /// 最大非开局 ID：kindIndex=6(soldier), sideBit=1(black), row=9, col=8 → 16198
    func testMaxNonOpeningId() {
        let id = Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 9, col: 8))
        XCTAssertLessThanOrEqual(id, 16198, "非开局 ID 最大值应 <= 16198")
    }

    /// 不同类型棋子同位置产生不同 ID（直接编码保证）
    func testDifferentKindSamePositionDifferentIds() {
        let pos = Position(row: 5, col: 3)
        let id1 = Piece.fallbackId(kind: .chariot, side: .red, position: pos)
        let id2 = Piece.fallbackId(kind: .horse, side: .red, position: pos)
        XCTAssertNotEqual(id1, id2, "不同类型棋子同位置应产生不同 ID: chariot=\(id1) vs horse=\(id2)")
    }

    /// 同类型同位置不同阵营产生不同 ID
    func testSameKindSamePositionDifferentSideDifferentIds() {
        let pos = Position(row: 5, col: 3)
        let id1 = Piece.fallbackId(kind: .chariot, side: .red, position: pos)
        let id2 = Piece.fallbackId(kind: .chariot, side: .black, position: pos)
        XCTAssertNotEqual(id1, id2, "同类型同位置不同阵营应产生不同 ID: red=\(id1) vs black=\(id2)")
    }

    /// 同类型同阵营不同位置产生不同 ID
    func testSameKindDifferentPositionDifferentIds() {
        let id1 = Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 5, col: 3))
        let id2 = Piece.fallbackId(kind: .chariot, side: .red, position: Position(row: 5, col: 5))
        XCTAssertNotEqual(id1, id2, "同类型同阵营不同位置应产生不同 ID")
    }
}
