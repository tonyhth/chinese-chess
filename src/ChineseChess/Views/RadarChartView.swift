import SwiftUI

// MARK: - v6.0 Phase 5: 六维雷达图

/// 五维 + 总评的雷达图可视化
struct RadarChartView: View {
    let scores: [(label: String, value: Double)]  // 0-100

    private let maxScore: Double = 100

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 30
            let count = scores.count

            guard count >= 3 else { return }

            // 网格（5 层多边形）
            for layer in stride(from: 0.2, through: 1.0, by: 0.2) {
                let pts = polygonPath(center: center, radius: radius * layer, sides: count)
                let path = Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.closeSubpath()
                }
                context.stroke(path, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
            }

            // 轴线（从中心到顶点）
            for i in 0..<count {
                let angle = angleFor(index: i, total: count)
                let end = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                var linePath = Path()
                linePath.move(to: center)
                linePath.addLine(to: end)
                context.stroke(linePath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
            }

            // 数据多边形
            let dataPoints = scores.enumerated().map { i, kv in
                let angle = angleFor(index: i, total: count)
                let r = radius * (kv.value / maxScore)
                return CGPoint(
                    x: center.x + r * cos(angle),
                    y: center.y + r * sin(angle)
                )
            }
            let dataPath = Path { p in
                p.move(to: dataPoints[0])
                for pt in dataPoints.dropFirst() { p.addLine(to: pt) }
                p.closeSubpath()
            }
            context.fill(dataPath, with: .color(.accentColor.opacity(0.25)))
            context.stroke(dataPath, with: .color(.accentColor), lineWidth: 2)

            // 数据点
            for point in dataPoints {
                let pointRect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: pointRect), with: .color(.accentColor))
            }

            // 标签
            for (i, kv) in scores.enumerated() {
                let angle = angleFor(index: i, total: count)
                let labelR = radius + 18
                let pos = CGPoint(
                    x: center.x + labelR * cos(angle),
                    y: center.y + labelR * sin(angle)
                )
                let text = Text(kv.label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                context.draw(text, at: pos)

                // 分值标签
                let scorePos = CGPoint(x: pos.x, y: pos.y + 14)
                let scoreText = Text("\(Int(kv.value))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                context.draw(scoreText, at: scorePos)
            }
        }
        .frame(width: 240, height: 240)
    }

    // MARK: - 辅助

    private func angleFor(index: Int, total: Int) -> Double {
        -Double.pi / 2 + Double(index) * 2 * .pi / Double(total)
    }

    private func polygonPath(center: CGPoint, radius: Double, sides: Int) -> [CGPoint] {
        (0..<sides).map { i in
            let angle = angleFor(index: i, total: sides)
            return CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
    }
}
