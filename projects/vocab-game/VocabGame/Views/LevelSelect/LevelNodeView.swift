import SwiftUI

struct LevelNodeView: View {
    let definition: LevelDefinition
    let progress: LevelProgress
    let isUnlocked: Bool
    let onTap: () -> Void

    @State private var isPulsing = false
    @State private var glowOpacity: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Island/cloud node
                ZStack {
                    // Pulse glow for current level
                    if isUnlocked && !progress.isCompleted {
                        // Outer expanding ring
                        Circle()
                            .stroke(VGColors.primary.opacity(0.5), lineWidth: 2)
                            .frame(width: 64, height: 64)
                            .scaleEffect(isPulsing ? 1.35 : 1.0)
                            .opacity(isPulsing ? 0.0 : 0.7)
                            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: isPulsing)

                        // Inner soft glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VGColors.primary.opacity(0.3), VGColors.primary.opacity(0)],
                                    center: .center, startRadius: 25, endRadius: 45
                                )
                            )
                            .frame(width: 90, height: 90)
                            .opacity(glowOpacity)
                    }

                    // Cloud/island shape
                    ZStack {
                        // Base cloud shape
                        cloudShape
                            .fill(
                                isUnlocked
                                ? LinearGradient(
                                    colors: progress.isCompleted
                                        ? [VGColors.secondary, Color(hex: "FFCA28")]
                                        : [VGColors.primary, Color(hex: "FF8CAE")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.25)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 58, height: 48)
                            .shadow(
                                color: isUnlocked
                                    ? (progress.isCompleted ? VGColors.secondary.opacity(0.3) : VGColors.primary.opacity(0.3))
                                    : Color.clear,
                                radius: 6, y: 3
                            )

                        // Content
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 14))
                        } else {
                            Text("\(definition.id)")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.system(size: 18, design: .rounded))
                                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        }

                        // Completed: gold star
                        if progress.isCompleted {
                            VStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(VGColors.secondary)
                                    .font(.system(size: 10))
                                    .shadow(color: .black.opacity(0.1), radius: 1)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(x: 4, y: -2)
                        }
                    }
                }

                // Level name
                Text(definition.name)
                    .font(.system(size: 10))
                    .foregroundColor(isUnlocked ? VGColors.textPrimary : Color.gray)
                    .lineLimit(1)

                // Stars
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < progress.stars ? "star.fill" : "star")
                            .foregroundColor(i < progress.stars ? VGColors.secondary : Color.gray.opacity(0.3))
                            .font(.system(size: 9))
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
                isPulsing = true
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
        }
    }

    /// Cloud/island shape composed of overlapping circles
    private var cloudShape: some Shape {
        CloudShape()
    }
}

/// Custom cloud shape: a rounded blob that looks like an island or cloud
private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Main ellipse body
        path.addEllipse(in: CGRect(x: w * 0.1, y: h * 0.15, width: w * 0.8, height: h * 0.7))

        // Left bump
        path.addEllipse(in: CGRect(x: 0, y: h * 0.2, width: w * 0.4, height: h * 0.5))

        // Right bump
        path.addEllipse(in: CGRect(x: w * 0.6, y: h * 0.2, width: w * 0.4, height: h * 0.5))

        // Top bump
        path.addEllipse(in: CGRect(x: w * 0.25, y: 0, width: w * 0.5, height: h * 0.4))

        return path
    }
}
