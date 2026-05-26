import ArgumentParser
import RemCore

struct PriorityArgument: ExpressibleByArgument {
    let value: Priority

    init?(argument: String) {
        guard let p = Priority(stringValue: argument) else { return nil }
        self.value = p
    }

    static var allValueStrings: [String] {
        Priority.allCases.map { $0.displayName }
    }
}
