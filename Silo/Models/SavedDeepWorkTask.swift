import Foundation
import SwiftData

@Model
final class SavedDeepWorkTask {
    var id: UUID
    var title: String
    var useCount: Int
    var lastUsed: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.useCount = 1
        self.lastUsed = Date()
    }
}
