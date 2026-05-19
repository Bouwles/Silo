import SwiftUI
import SwiftData

enum SidebarTab: String, CaseIterable, Identifiable {
    case timer = "Focus"
    case weeklySchedule = "Weekly Schedule"
    case overallSchedule = "Schedule"
    case analytics = "Analytics"
    case stats = "Stats"
    case rewards = "Rewards"
    case workLog = "Work Log"
    case habits = "Habits"
    case examSeason = "Exam Season"
    case friends = "Friends"
    case aiAssistant = "AI Assistant"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timer:           return "timer"
        case .weeklySchedule:  return "repeat"
        case .overallSchedule: return "calendar"
        case .analytics:       return "chart.pie"
        case .stats:           return "chart.bar"
        case .rewards:         return "star.circle"
        case .workLog:         return "clock.badge.checkmark"
        case .habits:          return "checkmark.seal"
        case .examSeason:      return "graduationcap.fill"
        case .friends:         return "person.2.fill"
        case .aiAssistant:     return "sparkles"
        case .settings:        return "gearshape"
        }
    }
}

@MainActor
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerViewModel.self) private var timerVM
    @State private var selectedTab: SidebarTab = .timer
    @State private var progressVM = UserProgressViewModel()

    var preferredScheme: ColorScheme? {
        switch progressVM.profile?.selectedTheme {
        case "Graphite Dark", "Midnight Blue": return .dark
        case "Classic Light", "Forest Study", "Warm Paper": return .light
        default: return nil
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab, progressVM: progressVM)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            switch selectedTab {
            case .timer:           FocusTimerView(timerVM: timerVM, progressVM: progressVM)
            case .weeklySchedule:  WeeklyScheduleView()
            case .overallSchedule: StudyPlanView()
            case .analytics:       AnalyticsView()
            case .stats:           StatsView()
            case .rewards:         RewardsView(progressVM: progressVM)
            case .workLog:         WorkClockView()
            case .habits:          HabitTrackerView(progressVM: progressVM)
            case .examSeason:      ExamSeasonView(progressVM: progressVM)
            case .friends:         FriendsView(progressVM: progressVM)
            case .aiAssistant:     AIChatView()
            case .settings:        SettingsView(timerVM: timerVM)
            }
        }
        .preferredColorScheme(preferredScheme)
        .onAppear {
            progressVM.loadOrCreate(context: modelContext)
            timerVM.setModelContext(modelContext)
            timerVM.setProgressVM(progressVM)
        }
    }
}

@MainActor
struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    var progressVM: UserProgressViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Silo")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            if let profile = progressVM.profile {
                VStack(spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level \(profile.level) · \(profile.rankTitle)")
                                .font(.caption).fontWeight(.semibold)
                            Text("🔥 \(profile.currentStreak) day streak")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    XPProgressBar(
                        progress: profile.levelProgress,
                        currentXP: profile.xpProgressInLevel,
                        neededXP: profile.xpNeededForNextLevel
                    )
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal, 14).padding(.bottom, 8)

            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon).tag(tab)
            }
            .listStyle(.sidebar)
        }
        .background(.windowBackground)
    }
}
