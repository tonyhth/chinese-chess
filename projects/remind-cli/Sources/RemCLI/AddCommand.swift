import ArgumentParser
import RemCore

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add", abstract: "Add a reminder (auto-dedup)"
    )

    @Argument(help: "Reminder title")
    var title: String

    @Option(name: .long, help: "Target list (default: system default list)")
    var list: String?

    @Option(name: .long, help: "Due date (YYYY-MM-DD / today / tomorrow / +Nd)")
    var due: String?

    @Option(name: .long, help: "Priority (high/medium/low/none)")
    var priority: PriorityArgument?

    @Option(name: .long, help: "Notes")
    var notes: String?

    @Flag(name: .long, help: "Skip duplicate check")
    var force = false

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        if !force {
            let dups = try store.findDuplicate(title: title, in: list)
            if !dups.isEmpty {
                throw RemError.duplicateFound(count: dups.count)
            }
        }
        let item = try store.add(
            title: title, list: list, due: due,
            priority: priority?.value.displayName, notes: notes
        )
        let dueStr = item.dueDate.map { " \($0)" } ?? ""
        print("✓ \(item.title) [\(item.list)]\(dueStr)")
    }
}
