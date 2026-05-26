import ArgumentParser
import RemCore

struct CompleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete", abstract: "Mark a reminder as completed"
    )

    @Argument(help: "Reminder ID or keyword")
    var query: String

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        let result = try store.match(query, completed: false)
        let item = try resolveMatch(result, query: query)
        try store.complete(item)
        print("✓ Completed: \(item.title)")
    }
}
