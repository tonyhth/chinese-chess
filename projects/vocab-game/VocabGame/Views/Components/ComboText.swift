import SwiftUI

// MARK: - Combo Text Floating Animation

struct ComboText: View {
    let text: String
    let color: Color
    @State private var appeared = false

    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.5), radius: 8)
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? -40 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.4), value: appeared)
            .onAppear {
                appeared = true
            }
    }
}

// MARK: - Score Float Animation ("+100" flies up)

struct ScoreFloatView: View {
    let points: Int
    @State private var appeared = false
    @State private var completed = false

    var body: some View {
        Text("+\(points)")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(VGColors.secondary)
            .shadow(color: VGColors.secondary.opacity(0.4), radius: 4)
            .offset(y: appeared ? -60 : 0)
            .opacity(completed ? 0 : (appeared ? 1 : 0))
            .animation(.easeOut(duration: 0.3), value: appeared)
            .animation(.easeOut(duration: 0.3).delay(0.6), value: completed)
            .onAppear {
                appeared = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.9))
                    completed = true
                }
            }
    }
}

// MARK: - Mini Pet Reaction (corner)

struct MiniPetReaction: View {
    let isHappy: Bool
    @State private var bounce = false
    @State private var appeared = false
    @State private var squish = false
    @State private var jumpOffset: CGFloat = 0
    @State private var showReactionEmoji = false
    @State private var reactionEmojiDisappeared = false

    var body: some View {
        ZStack {
            // Pet egg
            Circle()
                .fill(
                    LinearGradient(
                        colors: isHappy
                            ? [Color(hex: "FFE0B2"), Color(hex: "FFCC80")]
                            : [Color(hex: "E0E0E0"), Color(hex: "BDBDBD")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 40, height: squish ? 32 : 40)
                .overlay(
                    VStack(spacing: 1) {
                        // Eyes
                        HStack(spacing: 6) {
                            if isHappy {
                                // Squinting happy eyes
                                Capsule()
                                    .fill(Color.black)
                                    .frame(width: 6, height: 2)
                                    .rotationEffect(.degrees(-10))
                                Capsule()
                                    .fill(Color.black)
                                    .frame(width: 6, height: 2)
                                    .rotationEffect(.degrees(10))
                            } else {
                                // Sad round eyes
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        // Mouth
                        if isHappy {
                            Text("▽")
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: "FF8A65"))
                        } else {
                            Text("‿")
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: "FF8A65"))
                                .rotationEffect(.degrees(180))
                        }
                    }
                    .padding(.top, 4)
                )
                .scaleEffect(bounce ? 1.15 : 1.0)
                .offset(y: jumpOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: bounce)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: squish)

            // Reaction emoji
            if showReactionEmoji {
                Text(isHappy ? "✨" : "💧")
                    .font(.caption)
                    .offset(y: reactionEmojiDisappeared ? -30 : -10)
                    .opacity(reactionEmojiDisappeared ? 0 : 1)
                    .animation(.easeOut(duration: 1.0), value: reactionEmojiDisappeared)
            }

            // Heart particle when happy
            if isHappy {
                Text("❤️")
                    .font(.caption)
                    .offset(y: appeared ? -30 : -10)
                    .opacity(appeared ? 0 : 1)
                    .animation(.easeOut(duration: 1.0), value: appeared)
            }
        }
        .onAppear {
            if isHappy {
                // Happy: jump + bounce
                bounce = true
                showReactionEmoji = true
                jumpOffset = -8
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.15))
                    jumpOffset = 0
                    bounce = false
                    try? await Task.sleep(for: .seconds(0.1))
                    bounce = true
                    appeared = true
                    try? await Task.sleep(for: .seconds(0.3))
                    reactionEmojiDisappeared = true
                }
            } else {
                // Sad: squish flat
                squish = true
                showReactionEmoji = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    squish = false
                    appeared = true
                    try? await Task.sleep(for: .seconds(0.3))
                    reactionEmojiDisappeared = true
                }
            }
        }
    }
}

// MARK: - Gold Particle Burst (for 8x+ combo)

struct GoldParticleBurst: View {
    @State private var particles: [GoldParticle] = []
    @State private var triggered = false

    struct GoldParticle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let delay: Double
        let size: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: p.size, height: p.size)
                    .offset(
                        x: triggered ? cos(p.angle) * p.distance : 0,
                        y: triggered ? sin(p.angle) * p.distance : 0
                    )
                    .opacity(triggered ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.8).delay(p.delay),
                        value: triggered
                    )
            }
        }
        .onAppear {
            particles = (0..<20).map { _ in
                GoldParticle(
                    angle: Double.random(in: 0...(2 * .pi)),
                    distance: CGFloat.random(in: 40...120),
                    delay: Double.random(in: 0...0.3),
                    size: CGFloat.random(in: 4...8)
                )
            }
            triggered = true
        }
    }
}

// MARK: - Legendary Celebration (10x combo, pet jumps to center)

struct LegendaryCelebration: View {
    @State private var petAtCenter = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(petAtCenter ? 0.2 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: petAtCenter)

            if petAtCenter {
                VStack(spacing: 12) {
                    // Big egg
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFE0B2"), Color(hex: "FFCC80")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 4) {
                                HStack(spacing: 10) {
                                    Circle().fill(Color.black).frame(width: 6, height: 6)
                                    Circle().fill(Color.black).frame(width: 6, height: 6)
                                }
                                Text("▽")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "FF8A65"))
                            }
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 16)

                    Text("🎉 太厉害了！")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(hex: "FFD700"))
                        .cornerRadius(20)
                }
                .scaleEffect(appeared ? 1.0 : 0.3)
                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: appeared)
            }
        }
        .onAppear {
            petAtCenter = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                appeared = true
                try? await Task.sleep(for: .seconds(2.0))
                appeared = false
                petAtCenter = false
            }
        }
    }
}

// MARK: - Shake Effect Modifier

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Screen Shake Modifier

struct ScreenShake: GeometryEffect {
    var amount: CGFloat = 3
    var shakesPerUnit = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        let y = amount * cos(animatableData * .pi * CGFloat(shakesPerUnit) * 1.3)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}
