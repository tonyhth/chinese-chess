import XCTest
@testable import ChineseChess

/// Bug 4 审查修复测试（commit f56b44a）
///
/// 修复内容：
/// - P0：fallbackId 注释与实现不一致 → 更新注释
/// - P1：FENDecoder 死代码移除 → fallbackCounter 参数和 if id < 0 分支已删除
/// - P2：编码因子不变量保护 → 加了 assert(PieceKind.allCases.count <= 9)
///
/// 测试重点：
/// 1. FENDecoder 解析正确性不受死代码移除影响
/// 2. FENDecoder 解析非开局位置 FEN 时所有 ID 都 >= 10000（不再有 fallbackCounter=100+）
/// 3. FENDecoder round-trip 编解码一致性
/// 4. assert 保护验证（PieceKind 数量在安全范围内）
/// 5. 边界场景：残局 FEN、非标准 FEN
final class Bug4ReviewFixTests: XCTestCase {

    // MARK: - P1: FENDecoder 死代码移除后功能不受影响

    /// 标准开局 FEN 解析后棋子数量和 ID 正确
    func testStandardFENParsesCorrectly() {
        let result = FENDecoder.parse(fen: FENDecoder.standardInitial)
        XCTAssertNotNil(result, "标准开局 FEN 应解析成功")
        XCTAssertEqual(result!.pieces.count, 32, "应有 32 个棋子")
        XCTAssertEqual(result!.currentTurn, .red, "行走方应为红方")

        // 所有开局棋子的 ID 应在 0-31 范围
        for piece in result!.pieces {
            XCTAssertGreaterThanOrEqual(piece.id, 0, "\(piece.kind) \(piece.side) id=\(piece.id) 应 >= 0")
            XCTAssertLessThanOrEqual(piece.id, 31, "\(piece.kind) \(piece.side) id=\(piece.id) 应 <= 31")
        }
    }

    /// 非开局位置 FEN 解析后所有 ID 都来自直接编码（>= 10000 或精确开局 ID 0-31）
    func testNonStandardFENIdsAreDirectEncoded() {
        // 残局：红帅 + 红车 vs 黑将，棋子在非开局位置
        // 红帅(8,4) — 非开局, 红车(5,3) — 非开局, 黑将(1,5) — 非开局
        let fen = "4k4/9/9/9/9/3R5/9/9/4K4/9 w - - 0 1"
        let result = FENDecoder.parse(fen: fen)
        XCTAssertNotNil(result, "残局 FEN 应解析成功")

        guard let pieces = result?.pieces else { return }

        for piece in pieces {
            if piece.id >= 0 && piece.id <= 31 {
                // 如果 ID 在 0-31 范围，必须是精确开局位置
                let initialPieces = Board.initialPieces()
                let match = initialPieces.first { $0.id == piece.id }
                XCTAssertNotNil(match,
                    "ID=\(piece.id) 在 0-31 范围但无对应开局棋子: \(piece.kind) \(piece.side) @ \(piece.position)")
            } else {
                XCTAssertGreaterThanOrEqual(piece.id, 10000,
                    "\(piece.kind) \(piece.side) @ \(piece.position) id=\(piece.id) 应 >= 10000")
                XCTAssertLessThanOrEqual(piece.id, 16198,
                    "\(piece.kind) \(piece.side) @ \(piece.position) id=\(piece.id) 应 <= 16198")
            }
        }
    }

    /// 死代码移除后不再产生 100-199 范围的 ID（旧 fallbackCounter 路径）
    func testNoFallbackCounterIdsExist() {
        // 扫描所有可能的棋子位置，确保没有 ID 在 32-9999 范围
        let kinds: [PieceKind] = [.general, .advisor, .elephant, .horse, .chariot, .cannon, .soldier]

        for kind in kinds {
            for side in [Side.red, .black] {
                for row in 0...9 {
                    for col in 0...8 {
                        let pos = Position(row: row, col: col)
                        let id = Piece.fallbackId(kind: kind, side: side, position: pos)
                        // ID 应该要么在 0-31（开局），要么在 10000-16198（直接编码）
                        // 32-9999 范围不应出现
                        if id > 31 {
                            XCTAssertGreaterThanOrEqual(id, 10000,
                                "非开局 ID 不应在 32-9999 范围: \(kind) \(side) @ (\(row),\(col)) → \(id)")
                        }
                    }
                }
            }
        }
    }

    /// FENDecoder 解析的棋子 ID 与直接调用 Piece.fallbackId 一致
    func testFENDecoderIdsMatchFallbackId() {
        let fen = "4k4/9/9/9/9/3R5/9/9/4K4/9 w - - 0 1"
        let result = FENDecoder.parse(fen: fen)
        XCTAssertNotNil(result)

        for piece in result!.pieces {
            let expectedId = Piece.fallbackId(kind: piece.kind, side: piece.side, position: piece.position)
            XCTAssertEqual(piece.id, expectedId,
                "FENDecoder 产生的 ID 与 fallbackId 不一致: \(piece.kind) \(piece.side) @ \(piece.position) → decoder=\(piece.id), fallback=\(expectedId)")
        }
    }

    // MARK: - P2: assert 保护验证

    /// PieceKind 数量在安全范围内（assert 不触发）
    /// 当前有 7 种，远低于 9 的上限
    func testPieceKindCountWithinInvariant() {
        let count = PieceKind.allCases.count
        XCTAssertLessThanOrEqual(count, 9,
            "PieceKind 数量 \(count) 超过直接编码不变量上限 9，ID 方案需要重新设计")
        XCTAssertEqual(count, 7, "当前应有 7 种棋子类型")
    }

    /// 验证直接编码的最大值不超过声明范围
    /// kindIndex=6, sideBit=1, row=9, col=8 → 10000+6000+100+90+8 = 16198
    func testDirectEncodingMaxValue() {
        let maxId = Piece.fallbackId(kind: .soldier, side: .black, position: Position(row: 9, col: 8))
        XCTAssertEqual(maxId, 16198, "最大直接编码 ID 应为 16198")
    }

    /// 验证直接编码的最小非开局值
    /// general(kindIndex=0) 在 (0,0) 红方(sideBit=0) → 10000（但(0,0)是黑方车开局位置，会返回16）
    /// general 在非开局位置 (1,0) 红方 → 10000 + 0 + 0 + 10 + 0 = 10010
    func testDirectEncodingMinNonOpeningValue() {
        // 红帅在 (1,0) — 非开局
        let id = Piece.fallbackId(kind: .general, side: .red, position: Position(row: 1, col: 0))
        XCTAssertEqual(id, 10010, "红帅在 (1,0) 直接编码应为 10010")
    }

    // MARK: - FENDecoder round-trip

    /// FEN 解析 → generate → 重新解析，棋子位置一致
    func testFENRoundTrip() {
        let fen = "4k4/9/9/9/9/3R5/9/9/4K4/9 w - - 0 1"
        let result1 = FENDecoder.parse(fen: fen)
        XCTAssertNotNil(result1)

        let regenerated = FENDecoder.generate(pieces: result1!.pieces, currentTurn: result1!.currentTurn)
        let result2 = FENDecoder.parse(fen: regenerated)
        XCTAssertNotNil(result2, "重新生成的 FEN 应能解析")

        XCTAssertEqual(result2!.pieces.count, result1!.pieces.count, "棋子数量应一致")
        XCTAssertEqual(result2!.currentTurn, result1!.currentTurn, "行走方应一致")

        // 验证每个棋子位置一致
        for (p1, p2) in zip(result1!.pieces, result2!.pieces) {
            XCTAssertEqual(p1.kind, p2.kind)
            XCTAssertEqual(p1.side, p2.side)
            XCTAssertEqual(p1.position, p2.position)
            XCTAssertEqual(p1.id, p2.id, "ID 应在 round-trip 后保持一致")
        }
    }

    /// 标准开局 FEN round-trip 一致性
    func testStandardFENRoundTrip() {
        let result1 = FENDecoder.parse(fen: FENDecoder.standardInitial)
        XCTAssertNotNil(result1)

        let regenerated = FENDecoder.generate(pieces: result1!.pieces, currentTurn: result1!.currentTurn)
        let result2 = FENDecoder.parse(fen: regenerated)
        XCTAssertNotNil(result2)

        XCTAssertEqual(result2!.pieces.count, 32)
        XCTAssertEqual(result2!.currentTurn, .red)

        // 验证开局 ID round-trip 稳定
        let ids1 = Set(result1!.pieces.map(\.id))
        let ids2 = Set(result2!.pieces.map(\.id))
        XCTAssertEqual(ids1, ids2, "开局 ID 在 round-trip 后应一致")
    }

    // MARK: - 边界场景

    /// 极简 FEN：只有两个将/帅（红帅在 (8,4) 非开局位置）
    func testMinimalFENWithTwoGenerals() {
        // K 在 row 8, col 4 — 非开局位置（红帅开局在 row 9, col 4）
        let fen = "4k4/9/9/9/9/9/9/9/4K4/9 w - - 0 1"
        let result = FENDecoder.parse(fen: fen)
        XCTAssertNotNil(result, "只有两个将帅的 FEN 应解析成功")
        XCTAssertEqual(result!.pieces.count, 2)

        // 黑将在 (0,4) 是开局位置 → ID=24
        let blackGeneral = result!.pieces.first { $0.side == .black && $0.kind == .general }
        XCTAssertNotNil(blackGeneral)
        XCTAssertEqual(blackGeneral!.id, 24, "黑将在 (0,4) 应返回开局 ID=24")

        // 红帅在 (8,4) 非开局位置 → 直接编码 ID >= 10000
        let redGeneral = result!.pieces.first { $0.side == .red && $0.kind == .general }
        XCTAssertNotNil(redGeneral)
        XCTAssertGreaterThanOrEqual(redGeneral!.id, 10000,
            "红帅在 (8,4) 非开局位置应返回直接编码 ID >= 10000，实际 id=\(redGeneral!.id)")
    }

    /// 无效 FEN 返回 nil（不是崩溃）
    func testInvalidFENReturnsNil() {
        let invalidFENs = [
            "",                           // 空字符串
            "rnbakabnr",                  // 只有局面部分，缺行走方
            "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR",  // 缺行走方
            "invalid fen string",         // 完全无效
            "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR x - - 0 1", // 无效行走方
        ]

        for fen in invalidFENs {
            XCTAssertNil(FENDecoder.parse(fen: fen), "无效 FEN 应返回 nil: \(fen)")
        }
    }

    /// 多棋子在同一非开局位置（通过 FEN 不可能出现，但验证 fallbackId 直接编码无碰撞）
    func testDifferentPiecesSamePositionDifferentIds() {
        let pos = Position(row: 5, col: 4)
        let kinds: [PieceKind] = [.general, .advisor, .elephant, .horse, .chariot, .cannon, .soldier]
        var ids = Set<Int>()

        for kind in kinds {
            for side in [Side.red, .black] {
                let id = Piece.fallbackId(kind: kind, side: side, position: pos)
                XCTAssertFalse(ids.contains(id),
                    "同一位置不同棋子 ID 碰撞: \(kind) \(side) @ \(pos) → \(id)")
                ids.insert(id)
            }
        }
        XCTAssertEqual(ids.count, 14, "7 种棋子 × 2 方 = 14 个唯一 ID")
    }
}
