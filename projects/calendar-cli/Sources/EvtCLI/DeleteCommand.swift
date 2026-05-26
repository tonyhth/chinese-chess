import ArgumentParser
import Foundation
import EvtCore

struct DeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete", abstract: "Delete an event"
    )

    @Argument(help: "Event title (fuzzy match) or ID (with --id)")
    var query: String

    @Flag(help: "Treat query as event ID")
    var id = false

    @Flag(help: "Skip confirmation")
    var force = false

    func run() throws {
        let store: EventStoreProtocol = EventStore()

        if !force && !EvtCLI.outputJSON {
            let item = try store.show(query: query, isId: id)
            print("Delete \"\(item.title)\" [\(item.calendar)]? (y/N): ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
        }

        let item = try store.delete(query: query, isId: id)
        if EvtCLI.outputJSON {
            struct DeleteOutput: Encodable {
                let deleted = true
                let title: String
            }
            printJSON(DeleteOutput(title: item.title))
        } else {
            let check = Color.wrap("✓", with: Color.green)
            print("\(check) Deleted: \(item.title)")
        }
    }
}
