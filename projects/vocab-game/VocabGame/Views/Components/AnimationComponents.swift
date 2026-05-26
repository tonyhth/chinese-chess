import SwiftUI

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    let count: Int = 40

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        let color: Color
        let x: CGFloat
        let delay: Double
        let size: CGFloat
        let rotation: Double
        var fallen: Bool = false
    }

    var body: some View {
        ZStack {
            ForEach($particles) { $p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.6)
                    .rotationEffect(.degrees(p.rotation))
                    .offset(x: p.x, y: p.fallen ? 400 : 0)
                    .opacity(p.fallen ? 0 : 1)
                    .animation(
                        .easeIn(duration: 2.0).delay(p.delay),
                        value: p.fallen
                    )
            }
        }
        .onAppear {
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            particles = (0..<count).map { _ in
                ConfettiParticle(
                    color: colors.randomElement()!,
                    x: CGFloat.random(in: -150...150),
                    delay: Double.random(in: 0...0.5),
                    size: CGFloat.random(in: 6...12),
                    rotation: Double.random(in: 0...360)
                )
            }
            // Trigger fall after a brief moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for i in particles.indices {
                    particles[i].fallen = true
                }
            }
        }
    }
}

// MARK: - Star Pop Animation

struct StarPopView: View {
    let filled: Bool
    let delay: Double
    @State private var scale: CGFloat = 0

    var body: some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: 36))
            .foregroundColor(filled ? VGColors.secondary : Color.gray.opacity(0.3))
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(delay)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isGlowing ? 0.6 : 0), radius: radius)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
    }
}
