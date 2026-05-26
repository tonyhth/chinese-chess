import ArgumentParser
import RemCore

struct UncompleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uncomplete", abstract: "Mark a reminder as incomplete"
    )

    @Argument(help: "Reminder ID or keyword")
    var query: String

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        let result = try store.match(query, completed: true)
        let item = try resolveMatch(result, query: query)
        try store.uncomplete(item)
        print("✓ Uncompleted: \(item.title)")
    }
}
