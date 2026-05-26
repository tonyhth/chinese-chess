import ArgumentParser
import Foundation
import EvtCore

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List calendar events"
    )

    @Option(name: [.short, .long], help: "Filter by calendar")
    var calendar: String?

    @Option(help: "Start date (default: today)")
    var from: String?

    @Option(help: "End date (inclusive)")
    var to: String?

    @Option(help: "Number of days to show (default: 7)")
    var days: Int?

    @Option(name: [.short, .long], help: "Keyword filter (matches title)")
    var keyword: String?

    @Flag(help: "Keyword also matches location")
    var searchLocation = false

    @Flag(help: "Keyword also matches notes")
    var searchNotes = false

    @Option(help: "Max results (default: 100, max: 500)")
    var limit: Int = 100

    func run() throws {
        let store: EventStoreProtocol = EventStore()
        let effectiveLimit = min(max(limit, 1), 500)
        let result = try store.list(
            calendar: calendar, from: from, to: to, days: days,
            keyword: keyword, searchLocation: searchLocation,
            searchNotes: searchNotes, limit: effectiveLimit
        )

        if EvtCLI.outputJSON {
            struct ListOutput: Encodable {
                let events: [EventItem]
                let count: Int
                let truncated: Bool
            }
            printJSON(ListOutput(events: result.events, count: result.events.count, truncated: result.truncated))
        } else {
            printPlainList(result.events)
            if result.truncated {
                print("... (truncated, use --limit to show more)")
            }
        }
    }

    private func printPlainList(_ events: [EventItem]) {
        if events.isEmpty {
            print("(no events)")
            return
        }

        var grouped: [String: [EventItem]] = [:]
        var dateOrder: [String] = []

        for e in events {
            let dateKey = String(e.startDate.prefix(10))
            if grouped[dateKey] == nil {
                dateOrder.append(dateKey)
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(e)
        }

        let dateFormatter = DateFormatter()
        for dateKey in dateOrder {
            let items = grouped[dateKey]!
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let d = dateFormatter.date(from: dateKey) {
                dateFormatter.dateFormat = "yyyy-MM-dd (EEE)"
                let dateStr = Color.wrap(dateFormatter.string(from: d), with: Color.bold)
                print("📅 \(dateStr)")
            } else {
                print("📅 \(dateKey)")
            }

            for item in items {
                let calName = Color.wrap("[\(item.calendar)]", with: Color.cyan)
                if item.isAllDay {
                    let endStr = item.startDate != item.endDate ? " ~ \(item.endDate)" : ""
                    print("  All Day      \(item.title)\(endStr)  \(calName)")
                } else {
                    let start = String(item.startDate.suffix(5))
                    let end = String(item.endDate.suffix(5))
                    let timeRange = Color.wrap("\(start)-\(end)", with: Color.green)
                    print("  \(timeRange)  \(item.title)  \(calName)")
                }
            }
        }
    }
}
