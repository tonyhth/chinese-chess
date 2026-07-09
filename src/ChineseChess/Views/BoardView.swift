import SwiftUI

/// BoardView 保留为薄包装，内部使用 ChessBoardView
struct BoardView: View {
    let viewModel: GameViewModel
    var theme: ThemeColors? = nil

    var body: some View {
        ChessBoardView(mode: .playGame(viewModel), overrideTheme: theme, isFlipped: viewModel.humanSide == .black)
            // v4.0 Phase 5: 挑战模式 UI 反馈
            .alert(L10n.shared.t("challenge.ruleViolation"), isPresented: Binding(
                get: { viewModel.showChallengeRuleViolation },
                set: { if !$0 { viewModel.showChallengeRuleViolation = false } }
            )) {
                Button(L10n.shared.t("common.ok"), role: .cancel) {}
            }
            .alert(L10n.shared.t("challenge.unavailable"), isPresented: Binding(
                get: { viewModel.showChallengeUnavailable },
                set: { if !$0 { viewModel.showChallengeUnavailable = false } }
            )) {
                Button(L10n.shared.t("common.ok"), role: .cancel) {}
            }
            // v4.1 Phase 2: 挑战结果提示
            .alert(
                viewModel.challengeResult == .success
                    ? L10n.shared.t("challenge.success")
                    : L10n.shared.t("challenge.failure"),
                isPresented: Binding(
                    get: { viewModel.challengeResult != nil },
                    set: { if !$0 { viewModel.challengeResult = nil } }
                )
            ) {
                Button(L10n.shared.t("common.ok"), role: .cancel) {}
            }
    }
}
