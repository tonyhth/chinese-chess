import SwiftUI

// MARK: - TutorialBoardIntroView — 课0：认识棋盘专用视图

/// 课0：用简化棋盘示意图展示棋盘关键概念（九宫格、楚河汉界、网格）
struct TutorialBoardIntroView: View {
    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text(l10n.t("tutorial.lesson0.title"))
                .font(.title)
                .fontWeight(.bold)

            Text(l10n.t("tutorial.lesson0.subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 简化棋盘示意图
            boardDiagram
                .frame(maxWidth: 360)

            // 3 个要点卡片
            HStack(spacing: 12) {
                infoCard(
                    icon: "grid",
                    title: l10n.t("tutorial.lesson0.point.grid"),
                    desc: l10n.t("tutorial.lesson0.point.gridDesc")
                )
                infoCard(
                    icon: "square.dashed",
                    title: l10n.t("tutorial.lesson0.point.palace"),
                    desc: l10n.t("tutorial.lesson0.point.palaceDesc")
                )
                infoCard(
                    icon: "water.waves",
                    title: l10n.t("tutorial.lesson0.point.river"),
                    desc: l10n.t("tutorial.lesson0.point.riverDesc")
                )
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - 棋盘示意图（纯 Canvas 绘制，避免对齐问题）

    private var boardDiagram: some View {
        Canvas { context, size in
            let cols = 9
            let rows = 10
            let cellW = size.width / CGFloat(cols - 1)
            let cellH = size.height / CGFloat(rows - 1)

            // 棋盘线
            let lineColor = Color.primary.opacity(0.3)
            // 横线
            for row in 0..<rows {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: CGFloat(row) * cellH))
                path.addLine(to: CGPoint(x: size.width, y: CGFloat(row) * cellH))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            // 竖线（楚河汉界处只画边线）
            for col in 0..<cols {
                var path = Path()
                let x = CGFloat(col) * cellW
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: CGFloat(4) * cellH))
                path.move(to: CGPoint(x: x, y: CGFloat(5) * cellH))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }

            // 九宫格对角线 — 红方（下方）
            let redPalaceLeft = CGFloat(3) * cellW
            let redPalaceRight = CGFloat(5) * cellW
            let redPalaceTop = CGFloat(7) * cellH
            let redPalaceBottom = CGFloat(9) * cellH
            var redPalacePath = Path()
            redPalacePath.move(to: CGPoint(x: redPalaceLeft, y: redPalaceTop))
            redPalacePath.addLine(to: CGPoint(x: redPalaceRight, y: redPalaceBottom))
            redPalacePath.move(to: CGPoint(x: redPalaceRight, y: redPalaceTop))
            redPalacePath.addLine(to: CGPoint(x: redPalaceLeft, y: redPalaceBottom))
            context.stroke(redPalacePath, with: .color(lineColor), lineWidth: 0.5)

            // 九宫格对角线 — 黑方（上方）
            let blackPalaceLeft = CGFloat(3) * cellW
            let blackPalaceRight = CGFloat(5) * cellW
            let blackPalaceTop = CGFloat(0) * cellH
            let blackPalaceBottom = CGFloat(2) * cellH
            var blackPalacePath = Path()
            blackPalacePath.move(to: CGPoint(x: blackPalaceLeft, y: blackPalaceTop))
            blackPalacePath.addLine(to: CGPoint(x: blackPalaceRight, y: blackPalaceBottom))
            blackPalacePath.move(to: CGPoint(x: blackPalaceRight, y: blackPalaceTop))
            blackPalacePath.addLine(to: CGPoint(x: blackPalaceLeft, y: blackPalaceBottom))
            context.stroke(blackPalacePath, with: .color(lineColor), lineWidth: 0.5)

            // 楚河汉界文字
            let riverY = CGFloat(4.5) * cellH
            let center = CGPoint(x: size.width / 2, y: riverY)
            context.draw(
                Text("楚河")
                    .font(.system(size: cellH * 0.6))
                    .foregroundColor(.secondary.opacity(0.5)),
                at: CGPoint(x: size.width * 0.25, y: center.y)
            )
            context.draw(
                Text("汉界")
                    .font(.system(size: cellH * 0.6))
                    .foregroundColor(.secondary.opacity(0.5)),
                at: CGPoint(x: size.width * 0.75, y: center.y)
            )
        }
        .aspectRatio(9.0/11.0, contentMode: .fit)
        .background(Color.controlBackground)
        .cornerRadius(8)
    }

    // MARK: - 要点卡片

    private func infoCard(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(desc)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
