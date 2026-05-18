import SwiftUI
import SwiftData
import Charts

enum AnalyticsPeriod: String, CaseIterable {
    case week = "This Week"
    case month = "This Month"
    case allTime = "All Time"
}

@MainActor
struct AnalyticsView: View {
    @Query private var sessions: [FocusSession]
    @Query(sort: \SavedDeepWorkTask.useCount, order: .reverse) private var deepTasks: [SavedDeepWorkTask]
    @State private var period: AnalyticsPeriod = .week

    var filteredSessions: [FocusSession] {
        let cal = Calendar.current
        let now = Date()
        return sessions.filter { s in
            guard s.wasCompleted else { return false }
            switch period {
            case .week:
                let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
                return s.startTime >= start
            case .month:
                let start = cal.date(byAdding: .month, value: -1, to: now) ?? now
                return s.startTime >= start
            case .allTime:
                return true
            }
        }
    }

    var subjectData: [(subject: String, minutes: Double)] {
        var dict: [String: Double] = [:]
        for s in filteredSessions {
            let name = s.subjectName.isEmpty ? "Miscellaneous" : s.subjectName
            dict[name, default: 0] += s.duration / 60
        }
        return dict.sorted { $0.value > $1.value }.map { (subject: $0.key, minutes: $0.value) }
    }

    var totalMinutes: Double {
        filteredSessions.reduce(0) { $0 + $1.duration / 60 }
    }

    var subjectColors: [String: Color] {
        let palette: [Color] = [.blue, .indigo, .orange, .green, .purple, .red, .teal, .yellow]
        var result: [String: Color] = [:]
        for (i, pair) in subjectData.prefix(8).enumerated() {
            result[pair.subject] = palette[i % palette.count]
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                periodPicker
                if filteredSessions.isEmpty {
                    emptyState
                } else {
                    subjectChart
                    subjectRanking
                    if !deepTasks.isEmpty {
                        deepWorkSection
                    }
                }
            }
            .padding(24)
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Analytics")
                .font(.title2).fontWeight(.bold)
            Text("What you study most")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { p in
                Button {
                    period = p
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(period == p ? Color.blue : Color.secondary.opacity(0.1))
                        .foregroundStyle(period == p ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(String(format: "%.0f min total", totalMinutes))
                .font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48)).foregroundStyle(.secondary.opacity(0.4))
            Text("No sessions yet")
                .font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
            Text("Complete focus sessions to see your subject breakdown here.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    var subjectChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time by Subject")
                .font(.headline)

            Chart(subjectData.prefix(8), id: \.subject) { item in
                BarMark(
                    x: .value("Subject", item.subject),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(subjectColors[item.subject] ?? .blue)
                .cornerRadius(6)
                .annotation(position: .top, alignment: .center) {
                    if item.minutes >= 1 {
                        Text(item.minutes >= 60
                             ? String(format: "%.1fh", item.minutes / 60)
                             : String(format: "%.0fm", item.minutes))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 200)
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 11))
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    var subjectRanking: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Subject Ranking")
                .font(.headline)

            if subjectData.isEmpty {
                Text("No data").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(subjectData.prefix(8).enumerated()), id: \.offset) { rank, pair in
                    HStack(spacing: 12) {
                        Text("#\(rank + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(subjectColors[pair.subject] ?? .blue)
                            .frame(width: 6, height: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(pair.subject)
                                .font(.system(size: 13, weight: .semibold))
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill((subjectColors[pair.subject] ?? .blue).opacity(0.12))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(subjectColors[pair.subject] ?? .blue)
                                        .frame(width: totalMinutes > 0 ? geo.size.width * (pair.minutes / totalMinutes) : 0)
                                }
                            }
                            .frame(height: 5)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(pair.minutes >= 60
                                 ? String(format: "%.1fh", pair.minutes / 60)
                                 : String(format: "%.0fm", pair.minutes))
                                .font(.system(size: 13, weight: .semibold))
                            if totalMinutes > 0 {
                                Text(String(format: "%.0f%%", pair.minutes / totalMinutes * 100))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    var deepWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deep Work Topics")
                .font(.headline)
            Text("Tasks you've focused on most")
                .font(.subheadline).foregroundStyle(.secondary)

            ForEach(Array(deepTasks.prefix(10).enumerated()), id: \.offset) { i, task in
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Image(systemName: "doc.text")
                        .font(.system(size: 12)).foregroundStyle(.blue)
                    Text(task.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Spacer()
                    Text("×\(task.useCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 3)
                if i < min(deepTasks.count, 10) - 1 {
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
