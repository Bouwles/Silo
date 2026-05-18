import Foundation
import SwiftData

@Model
final class SessionReflection {
    var id: UUID
    var sessionID: UUID
    var focusRating: Int
    var interruptions: String
    var completed: String
    var createdAt: Date

    init(sessionID: UUID, focusRating: Int = 3, interruptions: String = "", completed: String = "") {
        self.id = UUID()
        self.sessionID = sessionID
        self.focusRating = focusRating
        self.interruptions = interruptions
        self.completed = completed
        self.createdAt = Date()
    }
}
