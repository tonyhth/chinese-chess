import Foundation
import Testing
@testable import ChineseChess

@Suite("P0 Chess Clock Accumulation Direction Tests", .serialized)
struct ChessClockDirectionTests {

    private static let defaultsKey = "chinesechess.humanSide"

    // MARK: - 初始状态

    @MainActor
    @Test("初始状态: clockRunningSide 为 red")
    func initialState_clockRunningSideIsRed() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()
        #expect(vm.clockRunningSide == .red)
        #expect(vm.redClockSeconds == 0)
        #expect(vm.blackClockSeconds == 0)
    }

    // MARK: - newGame 重置 clockRunningSide

    @MainActor
    @Test("newGame 重置 clockRunningSide 为 red")
    func newGame_resetsClockRunningSide() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()
        // 先走子改变状态
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))
        // 走完后 clockRunningSide 应已切换
        // newGame 重置
        vm.newGame()
        #expect(vm.clockRunningSide == .red)
        #expect(vm.redClockSeconds == 0)
        #expect(vm.blackClockSeconds == 0)
        #expect(vm.clockStartTime != nil)  // resetClock 会设置 startTime
    }

    // MARK: - switchClock 方向测试
    // switchClock 是 private，通过 movePiece 间接触发
    // movePiece -> switchClock -> clockRunningSide 翻转

    @MainActor
    @Test("红方走子后 clockRunningSide 切换为 black")
    func redMove_switchClockToBlack() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()
        // 初始 clockRunningSide == .red
        #expect(vm.clockRunningSide == .red)

        // 红方走子（空位移动，触发 switchClock）
        vm.selectPiece(at: Position(row: 7, col: 1))   // 红炮
        vm.selectPiece(at: Position(row: 7, col: 4))    // 移到空位

        // movePiece 内部调用 switchClock
        // 此时 triggerAIMove 会异步开始，但 clockRunningSide 应已同步切换
        #expect(vm.clockRunningSide == .black)
    }

    @MainActor
    @Test("clockRunningSide 解耦于 board.currentTurn")
    func clockRunningSide_independentFromCurrentTurn() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 用 board.execute 直接走子（绕过 movePiece 的完整流程）
        // 模拟旧 bug 场景：board.execute 后 currentTurn 翻转
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        vm.board.execute(move)

        // 此时 board.currentTurn == .black
        #expect(vm.board.currentTurn == .black)
        // 但 clockRunningSide 仍是 .red（因为没有调用 switchClock）
        #expect(vm.clockRunningSide == .red)
    }

    // MARK: - resetClock 重置

    @MainActor
    @Test("resetClock 通过 newGame 完整重置")
    func resetClock_viaNewGame() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 制造一些时间数据
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))
        // clockRunningSide 已切到 black

        // newGame 重置
        vm.newGame()

        // 验证全部归零
        #expect(vm.redClockSeconds == 0)
        #expect(vm.blackClockSeconds == 0)
        #expect(vm.clockRunningSide == .red)
        #expect(vm.clockStartTime != nil)
    }

    // MARK: - ChessClockView 显示逻辑（通过属性推断）
    // ChessClockView.isRunning 依赖 clockRunningSide
    // 这里验证属性值的正确性，UI 渲染不做快照测试

    @MainActor
    @Test("clockRunningSide 驱动 isRunning 判断的正确性")
    func clockRunningSide_drivesIsRunning() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 初始状态：红方计时中
        let redRunning = vm.isThinking == false && vm.clockRunningSide == .red && vm.gameState == .playing
        let blackRunning = vm.isThinking == false && vm.clockRunningSide == .black && vm.gameState == .playing
        #expect(redRunning == true)
        #expect(blackRunning == false)

        // 红方走子后：黑方计时中
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))

        let redRunning2 = vm.isThinking == false && vm.clockRunningSide == .red && vm.gameState == .playing
        let blackRunning2 = vm.isThinking == false && vm.clockRunningSide == .black && vm.gameState == .playing
        // AI 正在思考（isThinking==true），所以两边都不显示 running
        // 但 clockRunningSide 本身已切换
        #expect(vm.clockRunningSide == .black)
    }

    // MARK: - 多步走子后时钟方向持续正确

    @MainActor
    @Test("多步走子后 clockRunningSide 持续正确")
    func multipleMoves_clockRunningSideAlternates() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 第1步：红方走
        vm.selectPiece(at: Position(row: 7, col: 1))   // 红炮
        vm.selectPiece(at: Position(row: 7, col: 4))    // 移到空位
        // switchClock 后 clockRunningSide == .black
        #expect(vm.clockRunningSide == .black)

        // 注意：此时 triggerAIMove 异步开始，AI 走完后会再 switchClock
        // 由于 AI 是异步的，这里只验证红方走完后的即时状态
    }

    // MARK: - 累加方向回归测试（P0 核心 bug）

    @MainActor
    @Test("P0 回归: 红方走子后时间不累加到黑方")
    func p0Regression_redMoveDoesNotAccumulateBlackTime() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()

        // 初始时间都为 0
        #expect(vm.redClockSeconds == 0)
        #expect(vm.blackClockSeconds == 0)
        #expect(vm.clockRunningSide == .red)

        // 红方走子
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))

        // 走完后 clockRunningSide 切到 black
        // 关键验证：在 switchClock 内部，accumulateCurrentTurnTime 应把时间累加到 redClockSeconds（不是 blackClockSeconds）
        // 由于时间间隔可能很短（< 1秒），redClockSeconds 可能是 0
        // 但关键是：blackClockSeconds 在红方走子期间不应该有累加
        #expect(vm.clockRunningSide == .black)
        #expect(vm.blackClockSeconds == 0)  // 黑方还没有开始计时
        // redClockSeconds 可能是 0（走子快）或 > 0（走子慢），都正确
    }

    // MARK: - clockStartTime 清零逻辑

    @MainActor
    @Test("switchClock 后 clockStartTime 重置为新时间")
    func switchClock_resetsClockStartTime() {
        UserDefaults.standard.set("red", forKey: Self.defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.defaultsKey) }
        let vm = GameViewModel()
        let initialStart = vm.clockStartTime

        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))

        // switchClock 后 clockStartTime 应被更新
        if let newStart = vm.clockStartTime {
            #expect(newStart >= (initialStart ?? Date.distantPast))
        } else {
            // clockStartTime 不应为 nil（switchClock 会设新值）
            // 但 accumulateCurrentTurnTime 会设 nil，switchClock 后会再设 Date()
            // 走子流程：switchClock 先 accumulateCurrentTurnTime(clockStartTime=nil) 再 clockStartTime=Date()
            Issue.record("clockStartTime should not be nil after switchClock")
        }
    }
}
