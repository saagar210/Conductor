import Foundation
import SwiftData

@Model
final class SearchHistory: Sendable {
    @Attribute(.unique) var id: UUID
    var query: String
    var filterTypeRaw: String  // SearchFilterType as string
    var executedAt: Date
    var resultCount: Int
    var frequency: Int

    init(
        id: UUID = UUID(),
        query: String,
        filterType: SearchFilterType = .text,
        executedAt: Date = Date(),
        resultCount: Int = 0,
        frequency: Int = 1
    ) {
        self.id = id
        self.query = query
        self.filterTypeRaw = filterType.rawValue
        self.executedAt = executedAt
        self.resultCount = resultCount
        self.frequency = frequency
    }

    var filterType: SearchFilterType {
        get { SearchFilterType(rawValue: filterTypeRaw) ?? .text }
        set { filterTypeRaw = newValue.rawValue }
    }
}
