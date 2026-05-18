import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var totalXP: Int
    var level: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
    var totalFocusTime: TimeInterval
    var totalSessionsCompleted: Int
    var totalTasksCompleted: Int
    var unlockedThemesList: String
    var selectedTheme: String
    var selectedAccentColor: String

    var rankTitle: String {
        switch level {
        case 1...4: return "Starter"
        case 5...9: return "Focus Builder"
        case 10...14: return "Deep Worker"
        case 15...19: return "Study Warrior"
        case 20...24: return "Exam Grinder"
        case 25...29: return "Flow Master"
        case 30...: return "Study Monk"
        default: return "Starter"
        }
    }

    var xpForCurrentLevel: Int { xpThreshold(for: level) }
    var xpForNextLevel: Int { xpThreshold(for: level + 1) }
    var xpProgressInLevel: Int { totalXP - xpForCurrentLevel }
    var xpNeededForNextLevel: Int { xpForNextLevel - xpForCurrentLevel }
    var levelProgress: Double {
        guard xpNeededForNextLevel > 0 else { return 1.0 }
        return min(1.0, Double(xpProgressInLevel) / Double(xpNeededForNextLevel))
    }

    func xpThreshold(for lvl: Int) -> Int {
        guard lvl > 0 else { return 0 }
        return (lvl - 1) * (lvl - 1) * 50 + (lvl - 1) * 100
    }

    func addXP(_ amount: Int) -> Bool {
        totalXP += amount
        let newLevel = computeLevel(for: totalXP)
        let didLevelUp = newLevel > level
        level = newLevel
        return didLevelUp
    }

    func computeLevel(for xp: Int) -> Int {
        var lvl = 1
        while xpThreshold(for: lvl + 1) <= xp { lvl += 1 }
        return lvl
    }

    init() {
        self.id = UUID()
        self.totalXP = 0
        self.level = 1
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActiveDate = nil
        self.totalFocusTime = 0
        self.totalSessionsCompleted = 0
        self.totalTasksCompleted = 0
        self.unlockedThemesList = "Classic Light,Graphite Dark"
        self.selectedTheme = "Classic Light"
        self.selectedAccentColor = "blue"
    }
}
