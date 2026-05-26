import ArgumentParser
import RemCore

struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search", abstract: "Search reminders"
    )

    @Argument(help: "Search keyword")
    var keyword: String

    @Flag(help: "Include completed reminders")
    var all = false

    @Flag(help: "Output as JSON")
    var json = false

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        let items = try store.search(keyword: keyword, includeCompleted: all)
        if json {
            printJSON(items)
        } else {
            printPlain(items)
        }
    }
}
