import SwiftUI

/// v1.17: PetDisplayView — image-based character display with animation overlays
struct PetDisplayView: View {
    let petState: PetState
    var size: CGFloat = 160
    var showDizzy: Bool = false
    var specialOutfit: String? = nil

    // v1.16: level-up animation state
    var isLevelingUp: Bool = false
    var levelUpTrigger: Int = 0

    @State private var isBouncing = false
    @State private var levelUpGlow: CGFloat = 0
    @State private var levelUpRotation: Double = 0
    @State private var levelUpScale: CGFloat = 1.0
    @State private var levelUpFlashOpacity: CGFloat = 0
    @State private var levelUpTask: Task<Void, Never>? = nil
    @State private var blinkOpacity: Double = 0.0
    @State private var blinkTask: Task<Void, Never>? = nil

    // MARK: - Computed

    private var characterId: String {
        petState.currentCharacterId
    }

    private var imageName: String {
        let mood = showDizzy ? PetMood.sad : petState.mood
        return "\(characterId)_\(mood.assetSuffix)"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Level-up glow ring
            if isLevelingUp {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FFD700").opacity(0.6),
                                Color(hex: "FF6B9D").opacity(0.3),
                                Color.clear
                            ],
                            center: .center, startRadius: 10, endRadius: size * 0.9
                        )
                    )
                    .frame(width: size * 1.8, height: size * 1.8)
                    .scaleEffect(levelUpGlow)
                    .opacity(Double(levelUpGlow))
                    .animation(.easeOut(duration: 1.5), value: levelUpGlow)
            }

            // Flash overlay for level-up
            if levelUpFlashOpacity > 0 {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 1.2, height: size * 1.2)
                    .opacity(Double(levelUpFlashOpacity))
            }

            // Main character image + overlays
            ZStack {
                // Background glow for Lv.5+
                if petState.level >= 5 {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FFD700").opacity(0.4), Color(hex: "FFD700").opacity(0)],
                                center: .center, startRadius: 20, endRadius: size * 0.5
                            )
                        )
                        .frame(width: size * 1.5, height: size * 1.5)
                        .scaleEffect(isBouncing ? 1.08 : 0.95)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBouncing)
                }

                // Wings overlay (Lv.3+)
                if petState.level >= 3 {
                    wingsOverlay
                }

                // Character image
                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)

                // Blink overlay (closed eyes line)
                if blinkOpacity < 1.0 {
                    ZStack {
                        // Cover eyes area with body-colored bar to simulate blink
                        RoundedRectangle(cornerRadius: size * 0.04)
                            .fill(Color.black.opacity(0.15))
                            .frame(width: size * 0.32, height: size * 0.03)
                            .offset(y: -size * 0.08)
                    }
                    .opacity(blinkOpacity)
                    .allowsHitTesting(false)
                }

                // Accessories overlay
                accessoriesOverlay

                // Level feature overlay (crown Lv.5, sprout Lv.2+)
                levelOverlay

                // Dizzy stars
                if showDizzy {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(VGColors.secondary)
                                .rotationEffect(.degrees(Double(i) * 30))
                        }
                    }
                    .offset(y: -size * 0.48)
                    .transition(.opacity)
                }

                // Special outfit text placeholder
                if let outfit = specialOutfit {
                    Text(outfit)
                        .font(.system(size: size * 0.15))
                        .offset(y: -size * 0.48)
                }
            }
        }
        .rotationEffect(.degrees(levelUpRotation))
        .scaleEffect(levelUpScale)
        .offset(y: isBouncing ? -4 : 2)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBouncing)
        .onAppear {
            isBouncing = true
            runBlinkLoop()
            if isLevelingUp {
                runLevelUpAnimation()
            }
        }
        .onChange(of: levelUpTrigger) { _ in
            runLevelUpAnimation()
        }
        .onChange(of: isLevelingUp) { newValue in
            if newValue {
                runLevelUpAnimation()
            }
        }
        .onDisappear {
            levelUpTask?.cancel()
            blinkTask?.cancel()
        }
    }

    // MARK: - Wings Overlay (Lv.3+)

    private var wingsOverlay: some View {
        let wingOpacity = petState.level >= 4 ? 0.7 : 0.4
        let wingW = petState.level >= 4 ? size * 0.2 : size * 0.12
        let wingH = petState.level >= 4 ? size * 0.3 : size * 0.18

        return HStack {
            Ellipse()
                .fill(Color.white.opacity(wingOpacity))
                .frame(width: wingW, height: wingH)
                .rotationEffect(.degrees(-20))
                .offset(x: -size * 0.35, y: size * 0.02)

            Spacer()

            Ellipse()
                .fill(Color.white.opacity(wingOpacity))
                .frame(width: wingW, height: wingH)
                .rotationEffect(.degrees(20))
                .offset(x: size * 0.35, y: size * 0.02)
        }
    }

    // MARK: - Level Overlay

    @ViewBuilder
    private var levelOverlay: some View {
        // Lv.2-4: sprout
        if petState.level >= 2 && petState.level < 5 {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "6BCB77"))
                        .frame(width: 3, height: size * 0.07)
                        .offset(y: size * 0.015)
                    Ellipse()
                        .fill(Color(hex: "6BCB77"))
                        .frame(width: size * 0.07, height: size * 0.04)
                        .offset(y: -size * 0.015)
                        .rotationEffect(.degrees(-15))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: -size * 0.46)
        }

        // Lv.5+: crown
        if petState.level >= 5 {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "FFD700"))
                        .frame(width: size * 0.2, height: size * 0.05)
                    HStack(spacing: size * 0.05) {
                        Triangle()
                            .fill(Color(hex: "FFD700"))
                            .frame(width: size * 0.05, height: size * 0.05)
                        Triangle()
                            .fill(Color(hex: "FFE66D"))
                            .frame(width: size * 0.06, height: size * 0.06)
                        Triangle()
                            .fill(Color(hex: "FFD700"))
                            .frame(width: size * 0.05, height: size * 0.05)
                    }
                    .offset(y: -size * 0.03)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: -size * 0.5)
        }
    }

    // MARK: - Accessories Overlay

    @ViewBuilder
    private var accessoriesOverlay: some View {
        if let acc = petState.currentAccessory {
            if acc.contains("hat") {
                Text("🎩")
                    .font(.system(size: size * 0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .offset(y: -size * 0.46)
            }
            if acc.contains("glasses") {
                Text("👓")
                    .font(.system(size: size * 0.11))
                    .offset(y: -size * 0.06)
            }
            if acc.contains("scarf") {
                Text("🧣")
                    .font(.system(size: size * 0.1))
                    .offset(y: size * 0.18)
            }
            if acc.contains("bow") {
                Text("🎀")
                    .font(.system(size: size * 0.09))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: size * 0.12, y: -size * 0.34)
            }
            if acc.contains("cape") {
                Text("🦸")
                    .font(.system(size: size * 0.13))
                    .offset(y: size * 0.2)
            }
        }
    }

    // MARK: - Level-Up Animation

    private func runLevelUpAnimation() {
        levelUpTask?.cancel()
        levelUpTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                levelUpFlashOpacity = 0.8
                levelUpScale = 1.15
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.8)) {
                levelUpGlow = 1.5
            }
            withAnimation(.easeInOut(duration: 0.6)) {
                levelUpRotation += 360
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                levelUpFlashOpacity = 0
            }
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                levelUpGlow = 0
                levelUpScale = 1.0
            }
        }
    }
    // MARK: - Blink Loop

    private func runBlinkLoop() {
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                let wait = Double.random(in: 2.0...5.0)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.08)) {
                    blinkOpacity = 1.0
                }
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.08)) {
                    blinkOpacity = 0.0
                }
            }
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
