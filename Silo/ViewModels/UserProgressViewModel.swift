import SwiftUI
import SwiftData

@MainActor
@Observable
class UserProgressViewModel {
    var profile: UserProfile?
    var showLevelUp: Bool = false
    var levelUpTitle: String = ""

    func loadOrCreate(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? context.fetch(descriptor)) ?? []
        if let existing = profiles.first {
            profile = existing
        } else {
            let p = UserProfile()
            context.insert(p)
            try? context.save()
            profile = p
        }
        updateStreak(context: context)
    }

    func award(xp: Int, context: ModelContext) {
        guard let p = profile else { return }
        let didLevelUp = p.addXP(xp)
        if didLevelUp {
            levelUpTitle = p.rankTitle
            showLevelUp = true
        }
        try? context.save()
    }

    func recordSessionComplete(duration: TimeInterval, context: ModelContext) {
        guard let p = profile else { return }
        p.totalFocusTime += duration
        p.totalSessionsCompleted += 1
        p.lastActiveDate = Date()
        award(xp: 30, context: context)
        updateStreak(context: context)
    }

    func recordTaskComplete(difficulty: TaskDifficulty, context: ModelContext) {
        guard let p = profile else { return }
        p.totalTasksCompleted += 1
        p.lastActiveDate = Date()
        award(xp: difficulty.xpReward, context: context)
        updateStreak(context: context)
    }

    private func updateStreak(context: ModelContext) {
        guard let p = profile else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = p.lastActiveDate {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDateInToday(lastDay) { return }
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                p.currentStreak += 1
            } else if diff > 1 {
                p.currentStreak = 1
            }
        } else {
            p.currentStreak = 1
        }
        if p.currentStreak > p.longestStreak {
            p.longestStreak = p.currentStreak
        }
        try? context.save()
    }
}
