import ArgumentParser
import Foundation
import RemCore

@main
struct RemCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rem",
        abstract: "Apple Reminders CLI",
        version: "1.0.0",
        subcommands: [
            ListCommand.self, ListsCommand.self, AddCommand.self,
            CompleteCommand.self, UncompleteCommand.self,
            UpdateCommand.self, DeleteCommand.self, SearchCommand.self
        ]
    )
}

// MARK: - Output helpers

func printJSON<T: Encodable>(_ items: T) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.keyEncodingStrategy = .convertToSnakeCase
    guard let data = try? enc.encode(items) else { return }
    print(String(data: data, encoding: .utf8)!)
}

func printPlain(_ items: [RemItem]) {
    if items.isEmpty {
        print("(empty)")
        return
    }
    for item in items {
        let check = item.completed ? "✅" : "⬜"
        let shortId = String(item.id.prefix(8))
        let due = item.dueDate.map { " \($0)" } ?? " -no date-"
        let pri = item.priority != 0 ? " [\(item.priorityName)]" : ""
        print("\(check) \(shortId) | \(item.list) | \(item.title)\(pri)\(due)")
    }
}

func printPlainLists(_ lists: [ListInfo]) {
    for list in lists {
        print("\(list.name)\t\(list.pendingCount)\t\(list.totalCount)")
    }
}

func resolveMatch(_ result: MatchResult<RemItem>, query: String) throws -> RemItem {
    switch result {
    case .found(let item):
        return item
    case .multiple(let items):
        throw RemError.multipleMatch(query: query, items: items)
    case .none:
        throw RemError.noMatch(query: query)
    }
}
