import Foundation
import SwiftData

@Model
final class StudySubject {
    var id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var weeklyGoalMinutes: Int
    var createdAt: Date

    var dailyGoalMinutes: Int {
        get { weeklyGoalMinutes }
        set { weeklyGoalMinutes = newValue }
    }

    init(name: String, colorHex: String = "4A90D9", icon: String = "book.fill", dailyGoalMinutes: Int = 60) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.weeklyGoalMinutes = dailyGoalMinutes
        self.createdAt = Date()
    }

    static var defaults: [StudySubject] {
        [
            StudySubject(name: "Mathematics", colorHex: "5856D6", icon: "function", dailyGoalMinutes: 60),
            StudySubject(name: "Physics", colorHex: "FF6B35", icon: "atom", dailyGoalMinutes: 45),
            StudySubject(name: "English", colorHex: "34C759", icon: "text.book.closed", dailyGoalMinutes: 30),
            StudySubject(name: "History", colorHex: "FF9500", icon: "scroll", dailyGoalMinutes: 30),
            StudySubject(name: "General", colorHex: "8E8E93", icon: "folder.fill", dailyGoalMinutes: 30),
        ]
    }
}
