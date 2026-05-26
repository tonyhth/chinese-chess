import Foundation

public enum DateParser {
    public static func parse(_ input: String) -> DateComponents? {
        let cal = Calendar.current

        // +Nd format (supports +3, +3d, +0 = today)
        if input.hasPrefix("+") {
            let rest = input.dropFirst()
            let numStr = rest.hasSuffix("d") ? String(rest.dropLast()) : String(rest)
            guard let days = Int(numStr), days >= 0 else { return nil }
            let target = cal.date(byAdding: .day, value: days, to: Date())!
            return cal.dateComponents([.year, .month, .day], from: target)
        }

        // Relative keywords
        switch input.lowercased() {
        case "today":
            return cal.dateComponents([.year, .month, .day], from: Date())
        case "tomorrow":
            let target = cal.date(byAdding: .day, value: 1, to: Date())!
            return cal.dateComponents([.year, .month, .day], from: target)
        default:
            break
        }

        // Absolute formats
        let fmts = ["yyyy-MM-dd", "yyyy/MM/dd"]
        for fmt in fmts {
            let f = DateFormatter()
            f.dateFormat = fmt
            if let d = f.date(from: input) {
                return cal.dateComponents([.year, .month, .day], from: d)
            }
        }

        return nil
    }
}
