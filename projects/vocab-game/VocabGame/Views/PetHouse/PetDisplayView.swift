import SwiftUI

struct PetDisplayView: View {
    let petState: PetState
    @State private var isBouncing = false
    @State private var blinkTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    @State private var isBlinking = false

    private var bodyColor: Color {
        switch petState.level {
        case 1: return VGColors.primary
        case 2: return Color(hex: "FF8C42")
        case 3: return Color(hex: "4ECDC4")
        case 4: return Color(hex: "A78BFA")
        case 5: return Color(hex: "FFD700")
        default: return VGColors.primary
        }
    }

    var body: some View {
        ZStack {
            // Glow for level 5
            if petState.level >= 5 {
                Circle()
                    .fill(Color(hex: "FFD700").opacity(0.3))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isBouncing ? 1.1 : 0.9)
            }

            // Cape (behind body)
            if let acc = petState.currentAccessory, acc.contains("cape") {
                Text("🦸")
                    .font(.system(size: 30))
                    .offset(y: 20)
            }

            // Body
            Ellipse()
                .fill(bodyColor)
                .frame(width: 120, height: 140)
                .overlay(
                    VStack(spacing: 8) {
                        HStack(spacing: 16) { eyeView; eyeView }
                        HStack(spacing: 30) {
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 18, height: 12)
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 18, height: 12)
                        }
                        RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 14, height: 6)
                    }
                    .padding(.top, 30)
                )
                .overlay(
                    // Hat overlay (top of body)
                    Group {
                        if let acc = petState.currentAccessory {
                            accessoryTopOverlay(acc)
                        } else if petState.level >= 2 {
                            // Default hat
                            VStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "FFD93D"))
                                    .frame(width: 30, height: 20)
                                    .offset(y: -10)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, -8)
                        }
                    }
                )
                .overlay(
                    // Glasses/face overlay
                    Group {
                        if let acc = petState.currentAccessory, acc.contains("glasses") {
                            Text("👓")
                                .font(.system(size: 20))
                                .offset(y: 25)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 30)
                        }
                    }
                )
                .overlay(
                    // Scarf overlay (neck area)
                    Group {
                        if let acc = petState.currentAccessory, acc.contains("scarf") {
                            Text("🧣")
                                .font(.system(size: 18))
                                .offset(y: 50)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 30)
                        }
                    }
                )
                .overlay(
                    // Bow overlay (top-left)
                    Group {
                        if let acc = petState.currentAccessory, acc.contains("bow") {
                            Text("🎀")
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.top, -4)
                                .padding(.leading, 30)
                        }
                    }
                )

            // Wings (level 4+)
            if petState.level >= 4 {
                HStack {
                    wingView(side: .left)
                    Spacer().frame(width: 120)
                    wingView(side: .right)
                }
                .offset(y: 10)
            }
        }
        .offset(y: isBouncing ? -5 : 0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBouncing)
        .onAppear { isBouncing = true }
        .onReceive(blinkTimer) { _ in
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isBlinking = false }
        }
    }

    @ViewBuilder
    private func accessoryTopOverlay(_ accessoryId: String) -> some View {
        if accessoryId.contains("hat") {
            VStack {
                Text("🎩")
                    .font(.system(size: 22))
                    .offset(y: -14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, -8)
        }
    }

    private var eyeView: some View {
        ZStack {
            Circle().fill(.white).frame(width: 16, height: 16)
            Circle()
                .fill(VGColors.textPrimary)
                .frame(width: isBlinking ? 16 : 8, height: isBlinking ? 3 : 8)
                .animation(.easeInOut(duration: 0.15), value: isBlinking)
        }
    }

    private func wingView(side: HorizontalDirection) -> some View {
        Ellipse()
            .fill(Color.white.opacity(0.6))
            .frame(width: 25, height: 40)
            .rotationEffect(.degrees(side == .left ? -20 : 20))
            .offset(x: side == .left ? -10 : 10)
    }
}

private enum HorizontalDirection {
    case left, right
}
