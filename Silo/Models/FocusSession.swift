import Foundation
import SwiftData

enum TimerMode: String, Codable, CaseIterable {
    case pomodoro = "Pomodoro"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case deepWork = "Deep Work"
    case custom = "Custom"

    var focusDuration: TimeInterval {
        switch self {
        case .pomodoro: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        case .deepWork: return 50 * 60
        case .custom: return 25 * 60
        }
    }

    var breakDuration: TimeInterval {
        switch self {
        case .pomodoro: return 5 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        case .deepWork: return 10 * 60
        case .custom: return 5 * 60
        }
    }

    var isBreak: Bool {
        self == .shortBreak || self == .longBreak
    }
}

@Model
final class FocusSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var modeRaw: String
    var intention: String
    var subjectName: String
    var wasCompleted: Bool
    var xpEarned: Int

    var mode: TimerMode {
        get { TimerMode(rawValue: modeRaw) ?? .pomodoro }
        set { modeRaw = newValue.rawValue }
    }

    init(
        startTime: Date = Date(),
        duration: TimeInterval = 0,
        mode: TimerMode = .pomodoro,
        intention: String = "",
        subjectName: String = "General"
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = nil
        self.duration = duration
        self.modeRaw = mode.rawValue
        self.intention = intention
        self.subjectName = subjectName
        self.wasCompleted = false
        self.xpEarned = 0
    }
}
