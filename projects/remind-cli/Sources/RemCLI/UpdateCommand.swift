import ArgumentParser
import RemCore

struct UpdateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update", abstract: "Update a reminder"
    )

    @Argument(help: "Reminder ID or keyword")
    var query: String

    @Option(name: .long, help: "New title")
    var title: String?

    @Option(name: .long, help: "New due date (YYYY-MM-DD / today / tomorrow / +Nd)")
    var due: String?

    @Option(name: .long, help: "Move to list")
    var list: String?

    @Option(name: .long, help: "New priority (high/medium/low/none)")
    var priority: PriorityArgument?

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        let result = try store.match(query, completed: nil)
        let item = try resolveMatch(result, query: query)
        let updated = try store.update(
            item, title: title, due: due,
            list: list, priority: priority?.value.displayName
        )
        print("✓ Updated: \(updated.title)")
    }
}
