import ArgumentParser
import RemCore

struct ListsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lists", abstract: "List all reminder lists"
    )

    @Flag(help: "Output as JSON")
    var json = false

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        let lists = try store.allLists()
        if json {
            printJSON(lists)
        } else {
            printPlainLists(lists)
        }
    }
}
