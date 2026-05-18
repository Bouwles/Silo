import SwiftUI
import SwiftData
import Charts

@MainActor
struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FocusSession]
    @Query private var tasks: [AppTask]

    var todaySessions: [FocusSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startTime) && $0.wasCompleted }
    }

    var weekSessions: [FocusSession] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startTime >= start && $0.wasCompleted }
    }

    var todayFocusMinutes: Int {
        Int(todaySessions.reduce(0) { $0 + $1.duration } / 60)
    }

    var weekFocusMinutes: Int {
        Int(weekSessions.reduce(0) { $0 + $1.duration } / 60)
    }

    var completedTasksToday: Int {
        tasks.filter { t in
            guard let completed = t.completedAt else { return false }
            return t.isCompleted && Calendar.current.isDateInToday(completed)
        }.count
    }

    var weeklyChartData: [(String, Int)] {
        let cal = Calendar.current
        return (-6...0).map { offset -> (String, Int) in
            let date = cal.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let mins = sessions
                .filter { cal.isDate($0.startTime, inSameDayAs: date) && $0.wasCompleted }
                .reduce(0) { $0 + $1.duration / 60 }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return (formatter.string(from: date), Int(mins))
        }
    }

    var subjectData: [(String, Double)] {
        var dict: [String: Double] = [:]
        for s in weekSessions {
            dict[s.subjectName, default: 0] += s.duration / 60
        }
        return dict.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var sortedSessions: [FocusSession] {
        sessions.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                weeklyChart
                subjectBreakdown
                sessionHistory
            }
            .padding(24)
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Focus Stats").font(.title2).fontWeight(.bold)
            Text("Track your study performance").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
            StatCard(title: "Today's Focus", value: "\(todayFocusMinutes)m", icon: "timer", color: .blue)
            StatCard(title: "This Week", value: "\(weekFocusMinutes)m", icon: "calendar.badge.clock", color: .indigo)
            StatCard(title: "Pomodoros", value: "\(todaySessions.count)", subtitle: "today", icon: "checkmark.seal", color: .green)
            StatCard(title: "Tasks Done", value: "\(completedTasksToday)", subtitle: "today", icon: "checkmark.circle", color: .orange)
        }
    }

    var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Minutes — Last 7 Days").font(.headline)
            Chart(weeklyChartData, id: \.0) { item in
                BarMark(x: .value("Day", item.0), y: .value("Minutes", item.1))
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(5)
            }
            .frame(height: 160)
            .chartYAxis { AxisMarks(position: .leading) }
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    var subjectBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subject Breakdown — This Week").font(.headline)

            if subjectData.isEmpty {
                Text("No data yet. Complete some focus sessions first.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                let total = subjectData.reduce(0.0) { $0 + $1.1 }
                ForEach(Array(subjectData.prefix(5).enumerated()), id: \.offset) { _, pair in
                    let (subject, minutes) = pair
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subject).font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(Int(minutes))m").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4).fill(Color.blue)
                                    .frame(width: total > 0 ? geo.size.width * (minutes / total) : 0)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions").font(.headline)

            if sessions.isEmpty {
                Text("No sessions recorded yet.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(sortedSessions.prefix(10).enumerated()), id: \.offset) { _, session in
                    HStack(spacing: 12) {
                        Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(session.wasCompleted ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.mode.rawValue).font(.system(size: 13, weight: .medium))
                            Text(session.intention.isEmpty ? "No intention set" : session.intention)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(session.duration / 60))m").font(.system(size: 13, weight: .semibold))
                            Text(session.startTime, style: .relative).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
