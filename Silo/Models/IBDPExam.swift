import Foundation
import SwiftData

@Model final class IBDPExamSeason {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var city: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade) var exams: [IBDPExam] = []

    init(name: String, startDate: Date, endDate: Date, city: String = "", latitude: Double = 0, longitude: Double = 0) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
        self.exams = []
    }
}

@Model final class IBDPExam {
    var id: UUID = UUID()
    var subject: String = ""
    var subjectGroup: Int = 1
    var paperNumber: Int = 1
    var date: Date = Date()
    var durationMinutes: Int = 120
    var notes: String = ""
    var isCompleted: Bool = false
    var season: IBDPExamSeason?

    init(subject: String, subjectGroup: Int, paperNumber: Int, date: Date, durationMinutes: Int, notes: String = "") {
        self.id = UUID()
        self.subject = subject
        self.subjectGroup = subjectGroup
        self.paperNumber = paperNumber
        self.date = date
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.isCompleted = false
    }

    var groupColorHex: String {
        switch subjectGroup {
        case 1: return "FF6B6B"
        case 2: return "4ECDC4"
        case 3: return "45B7D1"
        case 4: return "52C77A"
        case 5: return "AF52DE"
        case 6: return "FF9F43"
        default: return "4A90D9"
        }
    }

    var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: date) ?? date
    }

    var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if m == 0 { return "\(h)h" }
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}
