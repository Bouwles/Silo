import Foundation
import SwiftData

enum TaskDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var xpReward: Int {
        switch self {
        case .easy: return 10
        case .medium: return 25
        case .hard: return 50
        }
    }
}

@Model
final class AppTask {
    var id: UUID
    var title: String
    var taskDescription: String
    var subjectName: String
    var difficultyRaw: String
    var isCompleted: Bool
    var dueTime: Date?
    var repeatDaily: Bool
    var createdAt: Date
    var completedAt: Date?
    var sortOrder: Int

    var difficulty: TaskDifficulty {
        get { TaskDifficulty(rawValue: difficultyRaw) ?? .medium }
        set { difficultyRaw = newValue.rawValue }
    }

    init(
        title: String,
        taskDescription: String = "",
        subjectName: String = "General",
        difficulty: TaskDifficulty = .medium,
        dueTime: Date? = nil,
        repeatDaily: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.subjectName = subjectName
        self.difficultyRaw = difficulty.rawValue
        self.isCompleted = false
        self.dueTime = dueTime
        self.repeatDaily = repeatDaily
        self.createdAt = Date()
        self.completedAt = nil
        self.sortOrder = sortOrder
    }
}
