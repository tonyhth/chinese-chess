import ArgumentParser
import RemCore

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List reminders (default: incomplete only)"
    )

    @Flag(help: "Include completed reminders")
    var all = false

    @Option(name: .long, help: "Filter by list name")
    var list: String?

    @Flag(help: "Output as JSON")
    var json = false

    func run() throws {
        let store: RemStoreProtocol = RemStore()
        var items = try store.allReminders(in: list)
        if !all {
            items = items.filter { !$0.completed }
        }
        if json {
            printJSON(items)
        } else {
            printPlain(items)
        }
    }
}
