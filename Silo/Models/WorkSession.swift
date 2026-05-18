import Foundation
import SwiftData

@Model
final class WorkSession {
    var id: UUID
    var label: String
    var clockInTime: Date
    var clockOutTime: Date?
    var isActive: Bool

    var duration: TimeInterval {
        let end = clockOutTime ?? Date()
        return max(0, end.timeIntervalSince(clockInTime))
    }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    init(label: String = "", clockInTime: Date = Date()) {
        self.id = UUID()
        self.label = label
        self.clockInTime = clockInTime
        self.clockOutTime = nil
        self.isActive = true
    }
}
