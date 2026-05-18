import UserNotifications
import Foundation

struct StudyNotificationManager {
    static let shared = StudyNotificationManager()

    func schedule(block: StudyBlock) {
        guard block.startTime > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Study Block Starting"
        content.body = "Time to focus on \(block.subjectName) for \(block.durationMinutes) minutes"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: block.startTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: block.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
