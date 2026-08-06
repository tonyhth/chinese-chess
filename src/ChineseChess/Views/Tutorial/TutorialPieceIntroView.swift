import SwiftUI

// MARK: - TutorialPieceIntroView — 课1：认识棋子专用视图

/// 课1：用 PieceBadge 卡片式布局展示 7 种棋子，分组（主力/辅助/将帅）
struct TutorialPieceIntroView: View {
    private let l10n = L10n.shared

    // 棋子口诀数据
    private let mainPieces: [(kind: PieceKind, titleKey: String)] = [
        (.chariot, "tutorial.piece.chariot"),
        (.horse, "tutorial.piece.horse"),
        (.cannon, "tutorial.piece.cannon"),
    ]
    private let supportPieces: [(kind: PieceKind, titleKey: String)] = [
        (.advisor, "tutorial.piece.advisor"),
        (.elephant, "tutorial.piece.elephant"),
        (.soldier, "tutorial.piece.soldier"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 标题
                Text(l10n.t("tutorial.lesson1.title"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(l10n.t("tutorial.lesson1.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // 主力棋子组
                pieceGroup(
                    title: l10n.t("tutorial.lesson1.group.main"),
                    pieces: mainPieces
                )

                // 辅助棋子组
                pieceGroup(
                    title: l10n.t("tutorial.lesson1.group.support"),
                    pieces: supportPieces
                )

                // 将帅组
                generalCard

                // 底部引导
                Text(l10n.t("tutorial.lesson1.footer"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .padding()
            .frame(maxWidth: 560)
        }
    }

    // MARK: - 棋子分组

    @ViewBuilder
    private func pieceGroup(title: String, pieces: [(kind: PieceKind, titleKey: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(pieces, id: \.kind) { piece in
                    pieceCard(kind: piece.kind, titleKey: piece.titleKey)
                }
            }
        }
    }

    // MARK: - 棋子卡片

    private func pieceCard(kind: PieceKind, titleKey: String) -> some View {
        let l10nText = l10n.t(titleKey)
        let parts = l10nText.components(separatedBy: "·")
        let name = parts.first ?? l10nText
        let hint = parts.count > 1 ? parts[1] : ""

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                PieceBadge(kind: kind, side: .red, size: 40)
                PieceBadge(kind: kind, side: .black, size: 40)
            }

            Text(name)
                .font(.caption)
                .fontWeight(.medium)

            if !hint.isEmpty {
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 将帅卡片

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t("tutorial.lesson1.group.general"))
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                PieceBadge(kind: .general, side: .red, size: 48)
                Text("VS")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                PieceBadge(kind: .general, side: .black, size: 48)

                Spacer()

                let parts = l10n.t("tutorial.piece.general").components(separatedBy: "·")
                VStack(alignment: .leading, spacing: 2) {
                    Text(parts.first ?? "")
                        .font(.caption)
                        .fontWeight(.medium)
                    if parts.count > 1 {
                        Text(parts[1])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
