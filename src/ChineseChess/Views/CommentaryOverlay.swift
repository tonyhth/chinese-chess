import SwiftUI

// MARK: - 点评气泡

/// 棋谱自动演示点评气泡
/// 消失时长与 DemoSpeed 联动
struct CommentaryOverlay: View {
    let commentary: CommentaryItem
    let speed: DemoSpeed

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: commentary.icon)
                .font(.caption)
                .foregroundStyle(.white)

            Text(commentary.text)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(bubbleColor.opacity(0.9))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: commentary.id)
    }

    private var bubbleColor: Color {
        switch commentary.type {
        case .check: return .orange
        case .checkmate: return .red
        case .keyMove: return .blue
        }
    }
}
