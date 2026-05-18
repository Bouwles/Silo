import SwiftUI
import SwiftData

private struct TaskExport: Codable {
    var title: String; var subject: String; var difficulty: String
    var isCompleted: Bool; var createdAt: Date
}
private struct SessionExport: Codable {
    var mode: String; var intention: String; var duration: TimeInterval
    var startTime: Date; var wasCompleted: Bool; var xpEarned: Int
}
private struct AppDataExport: Codable {
    var tasks: [TaskExport]; var sessions: [SessionExport]; var exportedAt: Date
}

@MainActor
struct SettingsView: View {
    @Bindable var timerVM: TimerViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showResetConfirm = false

    @AppStorage("pomodoroDuration") private var pomodoroDuration: Int = 25
    @AppStorage("shortBreakDuration") private var shortBreakDuration: Int = 5
    @AppStorage("longBreakDuration") private var longBreakDuration: Int = 15
    @AppStorage("deepWorkDuration") private var deepWorkDuration: Int = 50
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("xpDifficulty") private var xpDifficulty: String = "Normal"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.title2).fontWeight(.bold)
                    .padding(.top, 4)

                settingSection("Timer Durations") {
                    VStack(spacing: 0) {
                        DurationRow(label: "Pomodoro", value: $pomodoroDuration, range: 10...60)
                        Divider().padding(.leading, 20)
                        DurationRow(label: "Short Break", value: $shortBreakDuration, range: 3...20)
                        Divider().padding(.leading, 20)
                        DurationRow(label: "Long Break", value: $longBreakDuration, range: 10...30)
                        Divider().padding(.leading, 20)
                        DurationRow(label: "Deep Work", value: $deepWorkDuration, range: 30...120)
                    }
                }

                settingSection("Timer Behavior") {
                    VStack(spacing: 0) {
                        ToggleRow(label: "Auto-start Breaks", isOn: $timerVM.autoStartBreaks)
                        Divider().padding(.leading, 20)
                        ToggleRow(label: "Auto-start Focus", isOn: $timerVM.autoStartFocus)
                    }
                }

                settingSection("Notifications & Sound") {
                    VStack(spacing: 0) {
                        ToggleRow(label: "Session Notifications", isOn: $notificationsEnabled)
                        Divider().padding(.leading, 20)
                        ToggleRow(label: "Ambient Sounds", isOn: $soundEnabled)
                    }
                }

                settingSection("Progression") {
                    HStack {
                        Text("XP Difficulty")
                            .font(.system(size: 14))
                        Spacer()
                        Picker("", selection: $xpDifficulty) {
                            Text("Easy").tag("Easy")
                            Text("Normal").tag("Normal")
                            Text("Hard").tag("Hard")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }

                settingSection("Data") {
                    VStack(spacing: 0) {
                        Button {
                            exportData()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up").foregroundStyle(.blue)
                                Text("Export Data").font(.system(size: 14))
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 20)

                        Button {
                            showResetConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise").foregroundStyle(.red)
                                Text("Reset All Progress").font(.system(size: 14)).foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 40)

                Text("Silo 1.0 — Built with SwiftUI")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(24)
        }
        .alert("Reset All Progress?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetProgress() }
        } message: {
            Text("This will delete all tasks, sessions, XP, and streaks. This cannot be undone.")
        }
    }

    @ViewBuilder
    func settingSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            content()
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    func exportData() {
        let allTasks = (try? modelContext.fetch(FetchDescriptor<AppTask>())) ?? []
        let allSessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []

        let payload = AppDataExport(
            tasks: allTasks.map {
                TaskExport(title: $0.title, subject: $0.subjectName, difficulty: $0.difficultyRaw,
                           isCompleted: $0.isCompleted, createdAt: $0.createdAt)
            },
            sessions: allSessions.map {
                SessionExport(mode: $0.modeRaw, intention: $0.intention, duration: $0.duration,
                              startTime: $0.startTime, wasCompleted: $0.wasCompleted, xpEarned: $0.xpEarned)
            },
            exportedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let json = try? encoder.encode(payload) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Silo-Export.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? json.write(to: url)
        }
    }

    func resetProgress() {
        do {
            try modelContext.delete(model: AppTask.self)
            try modelContext.delete(model: FocusSession.self)
            try modelContext.delete(model: UserProfile.self)
            try modelContext.delete(model: StudyBlock.self)
            try modelContext.delete(model: SessionReflection.self)
            try modelContext.save()
        } catch {
            print("Reset failed: \(error)")
        }
    }
}

struct DurationRow: View {
    var label: String
    @Binding var value: Int
    var range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label).font(.system(size: 14))
            Spacer()
            Stepper("\(value) min", value: $value, in: range)
                .fixedSize()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct ToggleRow: View {
    var label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .font(.system(size: 14))
            .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
