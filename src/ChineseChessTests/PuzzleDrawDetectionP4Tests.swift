import Testing
import Foundation
@testable import ChineseChess

// MARK: - T-1023-OC-01 P4-A4：Puzzle 侧和局检测真驱动（X-碰撞回归 + 三次重复）
// 依据：dim2 P1-N1 四件标准（Puzzle 侧换完整 FEN + 真驱动用例）；
// 历史盲区：Puzzle 侧 checkDraw/boardFingerprint 全测试目录零触达（DrawDetectionRealTests TODO 自留）。

@MainActor
@Suite("Puzzle 和局检测 P4-A4")
struct PuzzleDrawDetectionP4Tests {

    private func makeVM(fen: String) -> PuzzleViewModel {
        let puzzle = Puzzle(
            id: "p4-a4-test", name: "P4-A4 驱动局", category: "test", difficulty: 1,
            stars: 1, description: "测试局", playerSide: "red", initialFEN: fen,
            solution: [], hints: nil, maxMoves: 100
        )
        return PuzzleViewModel(puzzle: puzzle)
    }

    @Test("X-碰撞回归：同位异型（马/炮）在完整 FEN 下指纹必须不同")
    func xCollisionRegression() {
        // 原 X-粗编码：马/炮/卒同符 'X'——红马(5,4) 与 红炮(5,4) 两个异型局面指纹同纹，
        // 叠加三次重复计数即误判和局；P4-A4 换完整 FEN 后种类全量编码 → 异型异纹。
        let vm = makeVM(fen: "4k4/9/9/9/9/9/9/9/9/4K4 w")

        vm.board = Board(fen: "4k4/9/9/9/9/4N4/9/9/9/4K4 w")
        let fpHorse = vm.testBoardFingerprint()

        vm.board = Board(fen: "4k4/9/9/9/9/4C4/9/9/9/4K4 w")
        let fpCannon = vm.testBoardFingerprint()

        #expect(fpHorse != fpCannon, "马/炮同位异型指纹必须不同（X-碰撞回归钉，P4-A4）")

        // 正向对照：同局面指纹稳定
        vm.board = Board(fen: "4k4/9/9/9/9/4N4/9/9/9/4K4 w")
        #expect(vm.testBoardFingerprint() == fpHorse, "同局面指纹必须一致")
    }

    @Test("三次重复真驱动：局面三现（含 init 预记录）→ checkDraw")
    func threefoldDriven() {
        // 红车 (5,4) 往返：(5,4)→(5,5)→(5,4)→(5,5)→(5,4)
        // init 预记录初始指纹（PuzzleViewModel.init positionHistory = [boardFingerprint()]）
        // 初始局面指纹计数：init(1) → 半着1(2) → 半着3(3) → checkDraw 在半着 3 后为真
        let vm = makeVM(fen: "4k4/9/9/9/9/4R4/9/9/9/4K4 w")

        let rook = vm.board.piece(at: Position(row: 5, col: 4))
        #expect(rook != nil, "夹具红车应在位")

        // 半着 1：车 (5,4)→(5,5)
        var move = Move(piece: rook!, from: Position(row: 5, col: 4), to: Position(row: 5, col: 5), captured: nil)
        vm.board.execute(move)
        vm.testRecordMove(captured: nil, movedPiece: rook!)
        #expect(vm.testCheckDrawNow() == false, "指纹计数 2 时不判和")

        // 半着 2：车 (5,5)→(5,4)（回到初始局面，走子方红）
        move = Move(piece: rook!, from: Position(row: 5, col: 5), to: Position(row: 5, col: 4), captured: nil)
        vm.board.execute(move)
        vm.testRecordMove(captured: nil, movedPiece: rook!)
        #expect(vm.testCheckDrawNow() == false, "指纹计数 3 未到（当前 2+重复前历史）不判和")

        // 半着 3：车 (5,4)→(5,5)
        move = Move(piece: rook!, from: Position(row: 5, col: 4), to: Position(row: 5, col: 5), captured: nil)
        vm.board.execute(move)
        vm.testRecordMove(captured: nil, movedPiece: rook!)
        #expect(vm.testCheckDrawNow() == false)

        // 半着 4：车 (5,5)→(5,4)——初始局面指纹第三现 → 三次重复判和
        move = Move(piece: rook!, from: Position(row: 5, col: 5), to: Position(row: 5, col: 4), captured: nil)
        vm.board.execute(move)
        vm.testRecordMove(captured: nil, movedPiece: rook!)
        #expect(vm.testCheckDrawNow() == true, "同一局面+走子方三现应判和（完整 FEN 指纹）")
    }

    @Test("自然限着：Puzzle 侧消费 DrawDetectionRules 单源常量（120 半着语义）")
    func naturalDrawThresholdSingleSource() {
        // A1 阈值单源：PuzzleViewModel.checkDraw 消费 DrawDetectionRules.naturalDrawHalfmoveLimit
        // （120 边界行为由 Game 侧 testNaturalDraw_Boundary119NoDraw_120Draw 钉住，此处钉单源引用存在性）
        #expect(DrawDetectionRules.naturalDrawHalfmoveLimit == 120, "自然限着阈值单源应为 120 半着（60 回合）")
    }

    @Test("无进攻子力判和：双侧仅剩将/士/象 → checkDraw 直真（P3-N2 残面）")
    func insufficientOffensiveMaterialDraw() {
        // checkDraw 第三分支（dim2 :197 登记的两侧不对称面）：历史零覆盖——
        // 黑：士 (0,3) + 将 (0,5)；红：帅 (9,3) + 士 (9,5)——全盘无车马炮卒
        // 摆位纪律①：FEN 行宽必须恰 9 列（FENDecoder :70 col==9 guard，超宽即拒）——
        //   失败迭代实录（P3-2 申报纪律：逐次列明）：
        //   迭代1（主日志 :88:9 失败）：行0 3a1k4=10 列被拒，Board 静默回退标准开局
        //   迭代2（tests2 :89:9 失败）：行9 3K1A4=10 列仍被拒（彼时误判对脸为根因，未中）
        //   迭代3：双行 9 列（3a1k3/3K1A3）→ 绿
        // 摆位纪律②：双将异列（col5/col3）避对脸（棋规洁面，非本次败因）
        let vm = makeVM(fen: "3a1k3/9/9/9/9/9/9/9/9/3K1A3 w")
        #expect(vm.testCheckDrawNow() == true, "双侧无进攻子力应直真判和（无进攻子力分支）")

        // 负对照：补一匹马恢复进攻子力 → 分支转假（非和局）
        vm.board = Board(fen: "3a1k3/9/9/9/9/9/9/4N4/9/3K1A3 w")
        #expect(vm.testCheckDrawNow() == false, "补马后存在进攻子力，不得判和")
    }
}
