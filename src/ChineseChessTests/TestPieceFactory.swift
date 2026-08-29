// TestPieceFactory.swift — 测试棋子工厂（结构性根治 id 越界，Luke 批准方案 2026-08-16 夜）
//
// 背景：on 态全量首跑两崩（21:01/21:05）根因 = 手写 fixture id 250/283/285 越出
// V2 槽位契约 0..31——36 测试文件存在同类字面量。逐处清偿不可收口，本工厂
// 消灭根因：测试从此不写 id 字面量，内部 id 池自动分配。
//
// 2026-08-29 SIGILL 案根治（v6.3，Eric）：池从 0..63 迁到 128..191。
// 根因：全量批单进程共享池，池轮转回落到 0..31 区段时与手写字面量 fixture
// （AIEngineTests id:8/24、MoveValidatorTests id:7/8/9/24 等）同盘撞 id →
// LegacySearchBoard.execute/undo 按 firstIndex(id) 错移棋子 → 车将同格 →
// isIronGate 空 Range trap（SIGILL，crash log ChineseChess-2026-08-29-110350.ips）。
// 迁到 128..191（Ruby 审查 P1 修正：64..127 带内存在 D5I18n 字面量 100..121），
// 全仓字面量实测最大 99999 但均不落入 128..191 带，同盘撞 id 机制封死。
//
// 防重置保护：id 池跨 suite 全局单调（进程生命周期），绝无两 suite 合并跑撞 id；
// resetPieces(after:) 显式化 API 仅限独立局面构造场景（见文档）。
//
// PieceID 强类型明确不做（决策记录）：工厂已消灭根因，强类型的 API 传染成本
// （存量 200+ Piece 构造点改造）远超收益，P5 后如有新需求再议。

import Foundation
@testable import ChineseChess

enum TestPieceFactory {
    /// 全局单调 id 池（128..191 区段——避开字面量带 0..31 与 100..121；
    /// 2× 棋子上限轮转余量，单局面内 32 子上限下永不冲突）
    private static let lock = NSLock()
    private static var nextId = 0
    private static let poolSize = 64   // 2× 棋子上限，轮转余量
    private static let poolBase = 128  // 区段基址：避开字面量带 0..31 与 100..121（Ruby P1）

    /// 标准棋子构造（id 自动分配）
    /// - Note: 同一测试函数内多次调用 id 各异；跨 suite 全局单调 + 轮转，
    ///   单局面 ≤32 子下同局面内必不冲突
    static func makePiece(kind: PieceKind, side: Side, position: Position) -> Piece {
        lock.lock()
        let id = poolBase + nextId % poolSize
        nextId += 1
        lock.unlock()
        return Piece(kind: kind, side: side, position: position, id: id)
    }

    /// 语义化快捷：红/黑将帅（id 固定 8/24——引擎槽位惯例，局面前提子）
    static func redGeneral(_ row: Int = 9, _ col: Int = 4) -> Piece {
        Piece(kind: .general, side: .red, position: Position(row: row, col: col), id: 8)
    }
    static func blackGeneral(_ row: Int = 0, _ col: Int = 4) -> Piece {
        Piece(kind: .general, side: .black, position: Position(row: row, col: col), id: 24)
    }

    /// 显式重置（仅限"构造全新独立局面、且旧局面 Piece 值不再被引用"的场景；
    /// 常规测试禁用——防两 suite 合并跑时撞 id，防重置保护的本体）
    static func resetForFreshPosition() {
        lock.lock()
        nextId = 0   // 归零后仍在 128..191 区段（poolBase 偏移），与字面量隔离不变
        lock.unlock()
    }
}
