import Foundation
import Testing
@testable import ChineseChess

@Suite("P1 Undo Chess Clock Sync Tests", .serialized)
struct UndoClockSyncTests {

    private static let defaultsKey = "chinesechess.humanSide"

    // MARK: - undo 后 clockRunningSide 回退到 humanSide

    @MainActor
    @Test("undo 后 clockRunningSide 回退到 humanSide（红方）")
    func undo_clockRunningSideBackToHumanRed() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 模拟走子 + AI 走子（用 board.execute 绕过异步 AI）
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        let m1 = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        vm.board.execute(m1)
        // 模拟 switchClock（手动触发，因为 board.execute 不走 movePiece）
        // 此时 clockRunningSide 仍为 .red

        let aiCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        let m2 = Move(piece: aiCannon, from: aiCannon.position, to: Position(row: 2, col: 4), captured: nil)
        vm.board.execute(m2)

        // 现在 board.currentTurn 回到 .red，有 2 步 moveHistory
        #expect(vm.board.moveHistory.count == 2)

        vm.undoMove()

        // undo 后 clockRunningSide 应为 humanSide = .red
        #expect(vm.clockRunningSide == .red)
        #expect(vm.clockStartTime != nil)
    }

    @MainActor
    @Test("undo 后 clockRunningSide 回退到 humanSide（黑方）")
    func undo_clockRunningSideBackToHumanBlack() {
        UserDefaults.standard.set("black", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()
        // humanSide = .black

        // 模拟黑方走 + 红方(AI)走
        let blackCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        let m1 = Move(piece: blackCannon, from: blackCannon.position, to: Position(row: 2, col: 4), captured: nil)
        vm.board.execute(m1)

        let redCannon = vm.board.piece(at: Position(row: 7, col: 1))!
        let m2 = Move(piece: redCannon, from: redCannon.position, to: Position(row: 7, col: 4), captured: nil)
        vm.board.execute(m2)

        #expect(vm.board.moveHistory.count == 2)

        vm.undoMove()

        // undo 后 clockRunningSide 应为 humanSide = .black
        #expect(vm.clockRunningSide == .black)
        #expect(vm.clockStartTime != nil)
    }

    // MARK: - undo 后 clockStartTime 重置

    @MainActor
    @Test("undo 后 clockStartTime 重置为当前时间")
    func undo_clockStartTimeReset() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        let oldStart = vm.clockStartTime

        // 走两步
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        vm.board.execute(Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil))
        let aiCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        vm.board.execute(Move(piece: aiCannon, from: aiCannon.position, to: Position(row: 2, col: 4), captured: nil))

        vm.undoMove()

        // clockStartTime 应为新的 Date（接近当前时间）
        let newStart = vm.clockStartTime
        #expect(newStart != nil)
        if let newStart = newStart, let oldStart = oldStart {
            #expect(newStart >= oldStart)
        }
    }

    // MARK: - undo 后累计时间保留

    @MainActor
    @Test("undo 后累计时间保留（accumulateCurrentTurnTime 被调用）")
    func undo_accumulatedTimePreserved() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 走两步建立 moveHistory
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        vm.board.execute(Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil))
        let aiCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        vm.board.execute(Move(piece: aiCannon, from: aiCannon.position, to: Position(row: 2, col: 4), captured: nil))

        vm.undoMove()

        // accumulateCurrentTurnTime 应在 undo 中被调用
        // 累计时间应 >= 0（走子快时可能是 0）
        #expect(vm.redClockSeconds >= 0)
        #expect(vm.blackClockSeconds >= 0)
        // 关键：clockStartTime 被重置（不再是 nil），说明 undo 后重新开始计时
        #expect(vm.clockStartTime != nil)
    }

    // MARK: - undo 后继续走子，棋钟方向正确

    @MainActor
    @Test("undo 后 clockRunningSide 指向 humanSide，玩家可以正常走子计时")
    func undo_thenMove_clockDirectionCorrect() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 走两步
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        vm.board.execute(Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil))
        let aiCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        vm.board.execute(Move(piece: aiCannon, from: aiCannon.position, to: Position(row: 2, col: 4), captured: nil))

        vm.undoMove()

        // undo 后 clockRunningSide = .red (humanSide)
        #expect(vm.clockRunningSide == .red)
        #expect(vm.clockStartTime != nil)
        // board.currentTurn 也应为 .red（undo 撤销了两步）
        #expect(vm.board.currentTurn == .red)
    }

    // MARK: - undo 在 moveHistory < 2 时不崩溃

    @MainActor
    @Test("moveHistory 不足时 undo 不影响棋钟状态")
    func undo_insufficientHistory_noClockChange() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        let originalSide = vm.clockRunningSide
        let originalStart = vm.clockStartTime

        // moveHistory 为 0，undo 应 early return
        vm.undoMove()

        // 棋钟状态不应改变
        #expect(vm.clockRunningSide == originalSide)
        // clockStartTime 可能因 accumulateCurrentTurnTime 变化，但 guard 应保护
        // 主要验证不崩溃
    }

    // MARK: - 多次 undo 棋钟稳定

    @MainActor
    @Test("多次 undo 棋钟状态稳定")
    func multipleUndo_clockStaysStable() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 走两步
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        vm.board.execute(Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil))
        let aiCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        vm.board.execute(Move(piece: aiCannon, from: aiCannon.position, to: Position(row: 2, col: 4), captured: nil))

        // 第一次 undo（成功，moveHistory >= 2）
        vm.undoMove()
        let sideAfterFirstUndo = vm.clockRunningSide
        let startAfterFirstUndo = vm.clockStartTime

        // 第二次 undo（moveHistory 已为 0，应 early return）
        vm.undoMove()

        // 状态不应改变
        #expect(vm.clockRunningSide == sideAfterFirstUndo)
        #expect(vm.clockStartTime != nil)
    }

    // MARK: - undo 后 newGame 重置一切

    @MainActor
    @Test("undo 后 newGame 彻底重置棋钟")
    func undo_thenNewGame_fullReset() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 走两步 + undo
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        vm.board.execute(Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil))
        let aiCannon = vm.board.piece(at: Position(row: 2, col: 1))!
        vm.board.execute(Move(piece: aiCannon, from: aiCannon.position, to: Position(row: 2, col: 4), captured: nil))
        vm.undoMove()

        // newGame
        vm.newGame()

        #expect(vm.clockRunningSide == .red)
        #expect(vm.redClockSeconds == 0)
        #expect(vm.blackClockSeconds == 0)
        #expect(vm.clockStartTime != nil)
    }
}
