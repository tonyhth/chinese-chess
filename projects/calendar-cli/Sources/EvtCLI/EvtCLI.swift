import ArgumentParser
import Foundation
import EvtCore

/// macOS Calendar CLI — manage events from the terminal.
@main
struct EvtCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calcli",
        abstract: "macOS Calendar CLI",
        version: "1.0.0",
        subcommands: [
            AddCommand.self, ListCommand.self, ShowCommand.self,
            UpdateCommand.self, DeleteCommand.self, AlertCommand.self
        ]
    )

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    /// Forwards the global `--json` flag to subcommands.
    static var outputJSON = false

    func validate() throws {
        EvtCLI.outputJSON = json
    }
}

// MARK: - Color support

/// ANSI color helpers. Respects `NO_COLOR` (no-color.org) and TTY detection.
enum Color {
    static let bold = "\u{001B}[1m"
    static let reset = "\u{001B}[0m"
    static let cyan = "\u{001B}[36m"
    static let green = "\u{001B}[32m"
    static let red = "\u{001B}[31m"

    /// `true` when stdout is a TTY **and** `NO_COLOR` is unset.
    static var enabled: Bool {
        isatty(STDOUT_FILENO) == 1 && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    }

    /// Wraps `text` with an ANSI escape code when colors are enabled.
    static func wrap(_ text: String, with code: String) -> String {
        enabled ? "\(code)\(text)\(reset)" : text
    }
}

// MARK: - Output helpers

/// Encodes and prints an `Encodable` value as pretty-printed, snake_case JSON.
func printJSON<T: Encodable>(_ items: T) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.keyEncodingStrategy = .convertToSnakeCase
    guard let data = try? enc.encode(items) else { return }
    print(String(data: data, encoding: .utf8)!)
}

/// Prints an error message in plain or JSON format.
func printError(_ message: String, json: Bool) {
    if json {
        printJSON(["error": message])
    } else {
        print("\(Color.wrap("❌", with: Color.red)) \(message)")
    }
}

/// Resolves a `MatchResult` into a single `EventItem`, or throws on ambiguity / no match.
func resolveMatch(_ result: MatchResult<EventItem>, query: String) throws -> EventItem {
    switch result {
    case .found(let item):
        return item
    case .multiple(let items):
        throw EventError.multipleMatch(query: query, items: items)
    case .none:
        throw EventError.noMatch(query: query)
    }
}
