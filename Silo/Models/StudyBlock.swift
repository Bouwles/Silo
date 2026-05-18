import Foundation
import SwiftData

@Model
final class StudyBlock {
    var id: UUID
    var notificationID: String
    var subjectName: String
    var startTime: Date
    var durationMinutes: Int
    var notes: String
    var isCompleted: Bool

    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    init(subjectName: String, startTime: Date, durationMinutes: Int = 50, notes: String = "") {
        self.id = UUID()
        self.notificationID = UUID().uuidString
        self.subjectName = subjectName
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.isCompleted = false
    }
}
