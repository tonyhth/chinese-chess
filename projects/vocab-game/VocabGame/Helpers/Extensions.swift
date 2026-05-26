import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(VGColors.card)
            .cornerRadius(VGRadius.card)
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    func optionButtonStyle(isSelected: Bool = false, isCorrect: Bool? = nil) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(backgroundColor(for: isSelected, isCorrect: isCorrect))
            .cornerRadius(VGRadius.option)
            .overlay(
                RoundedRectangle(cornerRadius: VGRadius.option)
                    .stroke(borderColor(for: isSelected, isCorrect: isCorrect), lineWidth: isSelected ? 2 : 1)
            )
    }

    private func backgroundColor(for isSelected: Bool, isCorrect: Bool?) -> Color {
        if let correct = isCorrect {
            return correct ? VGColors.success.opacity(0.2) : VGColors.error.opacity(0.2)
        }
        return isSelected ? VGColors.primary.opacity(0.1) : VGColors.card
    }

    private func borderColor(for isSelected: Bool, isCorrect: Bool?) -> Color {
        if let correct = isCorrect {
            return correct ? VGColors.success : VGColors.error
        }
        return isSelected ? VGColors.primary : Color.gray.opacity(0.3)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
