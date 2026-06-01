import Foundation
import SwiftUI

/// Manages surprise easter eggs
@MainActor
class EasterEggManager: ObservableObject {
    @Published var showPetDance: Bool = false
    @Published var showPetDizzy: Bool = false
    @Published var specialOutfit: String? = nil

    private var petTapCount: Int = 0
    private var petTapTask: Task<Void, Never>? = nil

    // MARK: - Special Date Outfits

    static func specialOutfitForToday() -> String? {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)

        // New Year
        if month == 1 && day == 1 { return "🧧" }
        // Valentine's
        if month == 2 && day == 14 { return "💕" }
        // Children's Day (CN)
        if month == 6 && day == 1 { return "🎈" }
        // Mid-Autumn — use Chinese lunar calendar
        if isMidAutumn(now) { return "🌕" }
        // Halloween
        if month == 10 && day == 31 { return "🎃" }
        // Christmas
        if month == 12 && day == 25 { return "🎄" }
        // Birthday (July 14 — app launch day)
        if month == 7 && day == 14 { return "🎂" }
        return nil
    }

    /// Check if today is Mid-Autumn Festival (15th day of 8th lunar month)
    private static func isMidAutumn(_ date: Date) -> Bool {
        let chineseCalendar = Calendar(identifier: .chinese)
        let month = chineseCalendar.component(.month, from: date)
        let day = chineseCalendar.component(.day, from: date)
        return month == 8 && day == 15
    }

    // MARK: - Pet Tap (tap 10x for dizzy)

    func onPetTapped() {
        petTapCount += 1
        petTapTask?.cancel()
        petTapTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            petTapCount = 0
        }
        if petTapCount >= 10 {
            petTapCount = 0
            triggerDizzy()
        }
    }

    private func triggerDizzy() {
        showPetDizzy = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            showPetDizzy = false
        }
    }

    // MARK: - Combo 20+ Easter Egg (pet dance)

    func checkComboEasterEgg(combo: Int) {
        if combo >= 20 && !showPetDance {
            showPetDance = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                showPetDance = false
            }
        }
    }
}
