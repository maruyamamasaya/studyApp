import Foundation

struct SearchConditions: Codable, Equatable {
    var query = ""
    var target = "すべて"
    var tag = ""
    var folder = ""
    var favorites = false
    var collection: UUID?
    var state = "すべて"
    var audioOnly = false
    var order = "標準"
}
struct SavedSearch: Codable, Identifiable {
    var id = UUID()
    var name: String
    var conditions: SearchConditions
}
struct SearchPreferences: Codable {
    var history: [SearchConditions] = []
    var saved: [SavedSearch] = []
    mutating func remember(_ conditions: SearchConditions) {
        guard !conditions.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        history.removeAll { $0 == conditions }
        history.insert(conditions, at: 0)
        history = Array(history.prefix(12))
    }
}
