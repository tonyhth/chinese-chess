import ArgumentParser
import Foundation
import EvtCore

struct AlertCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alert", abstract: "Manage event alerts",
        subcommands: [AlertAddCommand.self, AlertRemoveCommand.self, AlertListCommand.self]
    )
}

struct AlertAddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add", abstract: "Add an alert to an event"
    )

    @Argument(help: "Event title (fuzzy match) or ID (with --id)")
    var query: String

    @Flag(help: "Treat query as event ID")
    var id = false

    @Option(help: "Alert time, e.g. 15m, 1h, @2026-04-19 08:30")
    var time: String

    func run() throws {
        let store: EventStoreProtocol = EventStore()
        let item = try store.addAlert(query: query, isId: id, time: time)
        if EvtCLI.outputJSON {
            printJSON(item)
        } else {
            let check = Color.wrap("✓", with: Color.green)
            print("\(check) Alert added to \"\(item.title)\"")
        }
    }
}

struct AlertRemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove", abstract: "Remove an alert from an event"
    )

    @Argument(help: "Event title (fuzzy match) or ID (with --id)")
    var query: String

    @Flag(help: "Treat query as event ID")
    var id = false

    @Option(help: "Alert index (1-based, from `calcli alert list`)")
    var index: Int

    @Flag(help: "Skip confirmation")
    var force = false

    func run() throws {
        let store: EventStoreProtocol = EventStore()

        if !force && !EvtCLI.outputJSON {
            let item = try store.show(query: query, isId: id)
            if !item.alerts.isEmpty {
                print("Current alerts:")
                for a in item.alerts {
                    if a.type == "relative" {
                        print("  #\(a.index + 1) 🔔 \(a.offset ?? "?") before")
                    } else {
                        print("  #\(a.index + 1) 🔔 at \(a.absoluteDate ?? "?")")
                    }
                }
            }
            print("Remove alert #\(index)? (y/N): ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
        }

        let item = try store.removeAlert(query: query, isId: id, index: index)
        if EvtCLI.outputJSON {
            printJSON(item)
        } else {
            let check = Color.wrap("✓", with: Color.green)
            print("\(check) Alert #\(index) removed from \"\(item.title)\"")
        }
    }
}

struct AlertListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "List alerts for an event"
    )

    @Argument(help: "Event title (fuzzy match) or ID (with --id)")
    var query: String

    @Flag(help: "Treat query as event ID")
    var id = false

    func run() throws {
        let store: EventStoreProtocol = EventStore()
        let item = try store.show(query: query, isId: id)

        if EvtCLI.outputJSON {
            printJSON(item.alerts)
            return
        }

        print("Alerts for \"\(Color.wrap(item.title, with: Color.bold))\":")
        if item.alerts.isEmpty {
            print("  (none)")
        } else {
            for a in item.alerts {
                if a.type == "relative" {
                    print("  #\(a.index + 1) 🔔 \(a.offset ?? "?") before")
                } else {
                    print("  #\(a.index + 1) 🔔 at \(a.absoluteDate ?? "?")")
                }
            }
        }
    }
}
