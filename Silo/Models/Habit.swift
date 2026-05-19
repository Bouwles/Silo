import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var currentStreak: Int
    var longestStreak: Int
    var totalCompletions: Int
    var lastCompletedDate: Date?
    var createdAt: Date

    var isCompletedToday: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    init(name: String, emoji: String = "✅", colorHex: String = "4A90D9") {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalCompletions = 0
        self.lastCompletedDate = nil
        self.createdAt = Date()
    }

    func toggle() {
        let cal = Calendar.current
        if isCompletedToday {
            currentStreak = max(0, currentStreak - 1)
            totalCompletions = max(0, totalCompletions - 1)
            lastCompletedDate = nil
        } else {
            if let last = lastCompletedDate,
               cal.isDateInYesterday(last) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            if currentStreak > longestStreak { longestStreak = currentStreak }
            totalCompletions += 1
            lastCompletedDate = Date()
        }
    }
}
