import ArgumentParser
import EvtCore

struct ShowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show", abstract: "Show event details"
    )

    @Argument(help: "Event title (fuzzy match) or ID (with --id)")
    var query: String

    @Flag(help: "Treat query as event ID")
    var id = false

    func run() throws {
        let store: EventStoreProtocol = EventStore()
        let item = try store.show(query: query, isId: id)

        if EvtCLI.outputJSON {
            printJSON(item)
            return
        }

        let labelWidth = 12
        func row(_ label: String, _ value: String) {
            let padded = label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
            print("\(padded)\(value)")
        }

        let title = Color.wrap(item.title, with: Color.bold)
        row("Title:", title)
        row("Calendar:", "\(Color.wrap(item.calendar, with: Color.cyan)) (\(item.calendarType))")

        if item.isAllDay {
            row("Start:", Color.wrap(item.startDate, with: Color.green) + " (all day)")
            if item.startDate != item.endDate {
                row("End:", Color.wrap(item.endDate, with: Color.green) + " (all day)")
            }
        } else {
            row("Start:", Color.wrap(item.startDate, with: Color.green))
            row("End:", Color.wrap(item.endDate, with: Color.green))
        }
        row("Location:", item.location ?? "(none)")
        row("Notes:", item.notes ?? "(none)")
        row("URL:", item.url ?? "(none)")
        print()
        if item.alerts.isEmpty {
            row("Alerts:", "(none)")
        } else {
            row("Alerts:", "")
            for a in item.alerts {
                switch a.type {
                case "relative":
                    print("  🔔 \(a.offset ?? "?") before")
                case "absolute":
                    print("  🔔 at \(a.absoluteDate ?? "?")")
                default:
                    print("  🔔 \(a.type)")
                }
            }
        }
    }
}
