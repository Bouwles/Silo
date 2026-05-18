import SwiftUI
import SwiftData
import UserNotifications

@main
struct SiloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var timerVM = TimerViewModel()

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

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
