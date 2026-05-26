import SwiftUI

struct LevelNodeView: View {
    let definition: LevelDefinition
    let progress: LevelProgress
    let isUnlocked: Bool
    let onTap: () -> Void

    @State private var isPulsing = false
    @State private var showStars = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Level circle with glow
                ZStack {
                    if isUnlocked && !progress.isCompleted {
                        Circle()
                            .fill(VGColors.primary.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .scaleEffect(isPulsing ? 1.15 : 1.0)
                    }

                    Circle()
                        .fill(
                            isUnlocked
                            ? LinearGradient(
                                colors: progress.isCompleted
                                    ? [VGColors.success, Color(hex: "5BB86A")]
                                    : [VGColors.primary, Color(hex: "FF8CAE")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(
                            color: isUnlocked ? VGColors.primary.opacity(0.3) : Color.clear,
                            radius: 6, y: 3
                        )

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    } else {
                        Text("\(definition.id)")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .font(.system(size: 18))
                    }
                }

                // Level name
                Text(definition.name)
                    .font(.system(size: 11))
                    .foregroundColor(isUnlocked ? VGColors.textPrimary : Color.gray)
                    .lineLimit(1)

                // Stars
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < progress.stars ? "star.fill" : "star")
                            .foregroundColor(i < progress.stars ? VGColors.secondary : Color.gray.opacity(0.3))
                            .font(.system(size: 10))
                    }
                }
                .opacity(progress.isCompleted ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isUnlocked)
        .onAppear {
            if isUnlocked && !progress.isCompleted {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}
