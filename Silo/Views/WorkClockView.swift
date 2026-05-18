import SwiftUI
import SwiftData

@MainActor
struct WorkClockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkSession.clockInTime, order: .reverse) private var sessions: [WorkSession]

    @State private var elapsedSeconds: Int = 0
    @State private var labelText: String = ""
    @State private var tickTask: Task<Void, Never>? = nil

    var activeSession: WorkSession? {
        sessions.first { $0.isActive }
    }

    var isClockedIn: Bool { activeSession != nil }

    var body: some View {
        HStack(spacing: 0) {
            mainPanel
            Divider()
            historyPanel
        }
        .onAppear { resumeIfActive() }
        .onDisappear { tickTask?.cancel() }
    }

    // MARK: - Main Panel

    var mainPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            // Clock display
            VStack(spacing: 12) {
                Text(isClockedIn ? "Clocked In" : "Clocked Out")
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(isClockedIn ? .green : .secondary)

                Text(timeString(elapsedSeconds))
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isClockedIn ? Color.primary : Color.secondary.opacity(0.5))

                if isClockedIn, let session = activeSession {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Since \(session.clockInTime, style: .time)")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer().frame(height: 40)

            // Label field
            VStack(alignment: .leading, spacing: 6) {
                TextField(isClockedIn ? "What are you working on?" : "Label (optional)", text: $labelText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .frame(width: 320)
                    .disabled(isClockedIn)
                    .opacity(isClockedIn ? 0.6 : 1.0)
            }

            Spacer().frame(height: 32)

            // Clock In / Clock Out button
            Button {
                if isClockedIn {
                    clockOut()
                } else {
                    clockIn()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isClockedIn ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text(isClockedIn ? "Clock Out" : "Clock In")
                        .font(.system(size: 17, weight: .semibold))
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(isClockedIn ? Color.red : Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: (isClockedIn ? Color.red : Color.green).opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            // Today summary
            if !todaySessions.isEmpty {
                HStack(spacing: 24) {
                    summaryPill("Sessions", value: "\(todaySessions.count)")
                    summaryPill("Total Today", value: totalTodayString)
                }
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    func summaryPill(_ label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - History Panel

    var historyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Session History")
                    .font(.headline)
                Spacer()
                if !sessions.isEmpty {
                    Button {
                        clearAll()
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            Divider()

            if sessions.filter({ !$0.isActive }).isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36)).foregroundStyle(.secondary.opacity(0.4))
                    Text("No sessions yet")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessions.filter { !$0.isActive }) { session in
                        WorkSessionRow(session: session) {
                            modelContext.delete(session)
                            try? modelContext.save()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    func clockIn() {
        let session = WorkSession(label: labelText)
        modelContext.insert(session)
        try? modelContext.save()
        elapsedSeconds = 0
        startTicking()
    }

    func clockOut() {
        guard let session = activeSession else { return }
        session.clockOutTime = Date()
        session.isActive = false
        try? modelContext.save()
        tickTask?.cancel()
        tickTask = nil
        labelText = ""
    }

    func clearAll() {
        for s in sessions.filter({ !$0.isActive }) {
            modelContext.delete(s)
        }
        try? modelContext.save()
    }

    func resumeIfActive() {
        if let session = activeSession {
            elapsedSeconds = Int(Date().timeIntervalSince(session.clockInTime))
            startTicking()
        }
    }

    func startTicking() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self.elapsedSeconds += 1 }
            }
        }
    }

    // MARK: - Computed

    var todaySessions: [WorkSession] {
        sessions.filter {
            !$0.isActive && Calendar.current.isDateInToday($0.clockInTime)
        }
    }

    var totalTodayString: String {
        let total = Int(todaySessions.reduce(0) { $0 + $1.duration })
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    func timeString(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Session Row

struct WorkSessionRow: View {
    var session: WorkSession
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.label.isEmpty ? "Work Session" : session.label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(session.clockInTime, style: .time)
                        .font(.caption).foregroundStyle(.secondary)
                    if let out = session.clockOutTime {
                        Text("→")
                            .font(.caption2).foregroundStyle(.tertiary)
                        Text(out, style: .time)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !Calendar.current.isDateInToday(session.clockInTime) {
                    Text(session.clockInTime, style: .date)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(session.formattedDuration)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
