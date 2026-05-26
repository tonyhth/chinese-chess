import ArgumentParser
import EvtCore

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add", abstract: "Add a calendar event"
    )

    @Argument(help: "Event title")
    var title: String

    @Option(help: "Start time (YYYY-MM-DD [HH:mm] / today / tomorrow / now / +Nd / +Nw)")
    var start: String

    @Option(help: "End time (same format as --start). Optional for all-day events.")
    var end: String?

    @Flag(help: "All-day event")
    var allDay = false

    @Option(name: [.short, .long], help: "Target calendar")
    var calendar: String?

    @Option(name: [.short, .long], help: "Location")
    var location: String?

    @Option(name: [.short, .long], help: "Notes")
    var notes: String?

    @Option(help: "Associated URL")
    var url: String?

    @Option(help: "Alert, e.g. 15m, 1h, @2026-04-19 08:30. Repeatable.")
    var alert: [String] = []

    func run() throws {
        let store: EventStoreProtocol = EventStore()
        let item = try store.add(
            title: title, start: start, end: end, isAllDay: allDay,
            calendar: calendar, location: location, notes: notes, url: url,
            alerts: alert
        )
        if EvtCLI.outputJSON {
            printJSON(item)
        } else {
            let check = Color.wrap("✓", with: Color.green)
            print("\(check) \(item.title) [\(item.calendar)] \(item.startDate)")
        }
    }
}
