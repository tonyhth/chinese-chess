import Foundation

struct Word: Codable, Identifiable, Equatable {
    let id: Int
    let text: String
    let meaning: String
    let group: Int
}
