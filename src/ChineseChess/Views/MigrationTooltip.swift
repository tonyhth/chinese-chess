import SwiftUI

// MARK: - 迁移引导气泡

/// 升级后一次性引导气泡："残局和开局探索已移至'学棋'"
/// 自动显示，点击或 3s 后消失
struct MigrationTooltip: View {
    let text: String
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottom) {
                        Triangle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 6)
                            .offset(y: 6)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .onTapGesture { dismiss() }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            // 自驱动：出现后自动展示气泡
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    private func dismiss() {
        guard isVisible else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            isVisible = false
        }
        onDismiss()
    }
}

/// 向下小三角
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 迁移气泡管理器

enum MigrationTooltipManager {
    private static let tooltipKey = "chinesechess.studyHubTooltipShown"

    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: tooltipKey)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: tooltipKey)
    }
}
