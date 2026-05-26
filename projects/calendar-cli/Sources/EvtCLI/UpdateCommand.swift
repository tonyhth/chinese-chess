import ArgumentParser
import EvtCore

struct UpdateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update", abstract: "Update an event"
    )

    @Argument(help: "Event title (fuzzy match) or ID (with --id)")
    var query: String

    @Flag(help: "Treat query as event ID")
    var id = false

    @Option(help: "New title")
    var title: String?

    @Option(help: "New start time")
    var start: String?

    @Option(help: "New end time")
    var end: String?

    @Option(name: [.short, .long], help: "Move to calendar")
    var calendar: String?

    @Option(name: [.short, .long], help: "New location (empty string to clear)")
    var location: String?

    @Option(name: [.short, .long], help: "New notes (empty string to clear)")
    var notes: String?

    @Option(help: "New URL (empty string to clear)")
    var url: String?

    @Flag(help: "Set as all-day event")
    var allDay = false

    @Flag(help: "Remove all-day flag")
    var noAllDay = false

    func run() throws {
        let store: EventStoreProtocol = EventStore()
        let item = try store.update(
            query: query, isId: id, title: title, start: start, end: end,
            calendar: calendar, location: location, notes: notes, url: url,
            allDay: allDay ? true : nil, noAllDay: noAllDay ? true : nil
        )
        if EvtCLI.outputJSON {
            printJSON(item)
        } else {
            let check = Color.wrap("✓", with: Color.green)
            print("\(check) Updated: \(item.title) [\(item.calendar)]")
        }
    }
}
