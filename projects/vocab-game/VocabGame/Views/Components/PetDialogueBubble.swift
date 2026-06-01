import SwiftUI

struct PetDialogueBubble: View {
    let text: String
    @State private var opacity: Double = 0

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(VGColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
            )
            .overlay(
                // Bubble tail
                Triangle()
                    .fill(Color.white)
                    .frame(width: 12, height: 8)
                    .offset(y: 4)
                    .rotationEffect(.degrees(180)),
                alignment: .bottom
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = 1
                }
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
