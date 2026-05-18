import Foundation
import SwiftData

@Model
final class WeeklyEvent {
    var id: UUID
    var title: String
    var dayOfWeek: Int  // 0=Sun 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri 6=Sat
    var startMinutes: Int  // minutes from midnight
    var endMinutes: Int
    var colorHex: String
    var notes: String

    var durationMinutes: Int { max(0, endMinutes - startMinutes) }

    static let dayAbbr = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let dayFull = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    init(title: String, dayOfWeek: Int = 1, startMinutes: Int = 540, endMinutes: Int = 600, colorHex: String = "4A90D9", notes: String = "") {
        self.id = UUID()
        self.title = title
        self.dayOfWeek = dayOfWeek
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.colorHex = colorHex
        self.notes = notes
    }

    static func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let ampm = h >= 12 ? "PM" : "AM"
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", displayH, m, ampm)
    }

    var startTimeString: String { WeeklyEvent.formatMinutes(startMinutes) }
    var endTimeString: String { WeeklyEvent.formatMinutes(endMinutes) }
}
