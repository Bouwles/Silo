import SwiftUI
import SwiftData
import UserNotifications

@main
struct SiloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var timerVM = TimerViewModel()
    @StateObject private var supabaseService = SupabaseService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppTask.self,
            FocusSession.self,
            UserProfile.self,
            StudySubject.self,
            StudyBlock.self,
            SessionReflection.self,
            WeeklyEvent.self,
            SavedDeepWorkTask.self,
            WorkSession.self,
            Habit.self,
            IBDPExamSeason.self,
            IBDPExam.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environment(timerVM)
                .environmentObject(supabaseService)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarView()
                .modelContainer(sharedModelContainer)
                .environment(timerVM)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: timerVM.state == .running
                      ? "timer.circle.fill"
                      : (timerVM.isOnBreak && timerVM.state != .idle ? "cup.and.saucer.fill" : "timer"))
                    .symbolRenderingMode(.monochrome)
                if timerVM.state != .idle {
                    Text(timerVM.timeString)
                        .monospacedDigit()
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
