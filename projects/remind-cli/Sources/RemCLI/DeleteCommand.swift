import ArgumentParser
import RemCore

struct DeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete", abstract: "Delete a reminder"
    )

    @Argument(help: "Reminder ID or keyword")
    var query: String

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        let result = try store.match(query, completed: nil)
        let item = try resolveMatch(result, query: query)
        try store.delete(item)
        print("✓ Deleted: \(item.title)")
    }
}
