import Foundation
@testable import ChineseChess

// MARK: - 基线污染单2 · 环境注入预检（Alex L2 意见单 §2）
//
// 根因：pikafish.nnue 是 gitignored 资产，隔离 worktree / 新生 DerivedData 不携带
// （主树常规 build 会从 tools/pikafish/ 拷入 app bundle——真缺场景 = worktree 源头缺，
//  gating 脚本起跑前预检拦第一道，本 helper 拦漏网第二道）。
// 缺失时引擎静默返回 nil → 引擎依赖用例显示为 nil-failure，与真实断言债同屏红，污染归因。
// （Tina dc4653d §五.2 实证：PositionAnalyzer 3 用例 nil-fail 系环境伪影）
//
// 形态（Alex 裁定，双件）：in-test 显式 XCTSkip（第三态，非红非绿，stdout 可见可审计）
// + gating 脚本起跑前资产预检（~/DevTeam/scripts/preflight-test-assets.sh）。
// ⚠️ 门规：gating/baseline 批次有效性判据 = NNUE skip 计数 == 0；skip>0 = 环境破缺、批次作废——防静默绿。
// skip reason 固定含 "NNUE" 关键字，供脚本比对（与 flaky 治理类 skip 区分）。
//
// 用法（body 首行 guard 形态，无 unreachable warning）：
//   guard TestEnvPreflight.nnuePresent else { throw XCTSkip(TestEnvPreflight.nnueSkipReason) }

/// 环境预检：gitignored 资产缺失时显式 skip 引擎依赖用例
enum TestEnvPreflight {
    /// nnue 存在性（TEST_HOST=app → Bundle.main 即 app bundle，nnue 由 build phase 拷入 Resources）
    static var nnuePresent: Bool {
        Bundle.main.url(forResource: "pikafish", withExtension: "nnue") != nil
    }

    /// skip reason（含 NNUE 关键字供 gating 门规比对）
    static let nnueSkipReason = "NNUE 资产缺失：引擎不可用，环境破缺 skip（门规：批次 NNUE skip 计数必须为 0，gating 脚本起跑前预检应拦住此类批次）"
}
