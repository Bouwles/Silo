import SwiftUI
import SwiftData

@MainActor
struct StudyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyBlock.startTime) private var blocks: [StudyBlock]
    @Query private var subjects: [StudySubject]
    @State private var showAddBlock = false
    @State private var showAddSubject = false
    @State private var selectedDay: Date = Date()

    var todayBlocks: [StudyBlock] {
        blocks.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDay) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                planHeader
                Divider()
                daySelector
                Divider()
                blockList
            }
            .frame(maxWidth: .infinity)

            Divider()

            subjectsPanel
        }
        .sheet(isPresented: $showAddBlock) {
            AddStudyBlockSheet(selectedDay: selectedDay)
        }
        .sheet(isPresented: $showAddSubject) {
            AddSubjectSheet()
        }
        .onAppear { seedSubjectsIfNeeded() }
    }

    var planHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Schedule")
                    .font(.title2).fontWeight(.bold)
                Text("Specific study sessions by date")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showAddBlock = true } label: {
                Label("Add Block", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.blue).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(-3...7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDay)
                    let isToday = Calendar.current.isDateInToday(date)

                    Button { selectedDay = date } label: {
                        VStack(spacing: 4) {
                            Text(weekdayString(date))
                                .font(.caption2).fontWeight(.medium)
                                .foregroundStyle(isSelected ? .white : .secondary)
                            Text(dayNumber(date))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
                        }
                        .frame(width: 44, height: 56)
                        .background(isSelected ? Color.blue : isToday ? Color.blue.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(isToday && !isSelected ?
                            RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1) : nil)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
    }

    var blockList: some View {
        Group {
            if todayBlocks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 44)).foregroundStyle(.secondary.opacity(0.4))
                    Text("No study blocks planned")
                        .font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
                    Button { showAddBlock = true } label: {
                        Text("Plan a session").font(.subheadline).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(todayBlocks) { block in
                        StudyBlockRow(block: block) {
                            StudyNotificationManager.shared.cancel(id: block.notificationID)
                            modelContext.delete(block)
                            try? modelContext.save()
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    var subjectsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subjects")
                    .font(.headline)
                Spacer()
                Button { showAddSubject = true } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)

            if subjects.isEmpty {
                Text("No subjects yet")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(subjects) { subject in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: subject.colorHex) ?? .blue)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: subject.icon)
                                    .font(.system(size: 12)).foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subject.name).font(.system(size: 13, weight: .medium))
                            Text("Daily goal: \(subject.dailyGoalMinutes) min")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    func weekdayString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }

    func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }

    func seedSubjectsIfNeeded() {
        guard subjects.isEmpty else { return }
        for s in StudySubject.defaults { modelContext.insert(s) }
        try? modelContext.save()
    }
}

@MainActor
struct StudyBlockRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: StudyBlock
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                block.isCompleted.toggle()
                try? modelContext.save()
            } label: {
                ZStack {
                    Circle()
                        .stroke(block.isCompleted ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if block.isCompleted {
                        Circle().fill(Color.blue).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.blue)
                .frame(width: 4)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 4) {
                Text(block.subjectName)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 8) {
                    Text(block.startTime, format: .dateTime.hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·")
                    Text("\(block.durationMinutes) min")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !block.notes.isEmpty {
                    Text(block.notes)
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(block.isCompleted ? 0.5 : 1.0)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

@MainActor
struct AddStudyBlockSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var subjects: [StudySubject]
    var selectedDay: Date

    @State private var selectedSubject = "General"
    @State private var startTime = Date()
    @State private var durationMinutes = 50
    @State private var notes = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Study Block").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Add") { save() }.buttonStyle(.borderedProminent)
            }
            .padding(20)
            Divider()
            Form {
                Picker("Subject", selection: $selectedSubject) {
                    ForEach(subjectNames, id: \.self) { Text($0) }
                }
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 15...180, step: 5)
                TextField("Notes", text: $notes)
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 340)
    }

    var subjectNames: [String] {
        subjects.isEmpty ? ["General"] : subjects.map { $0.name }
    }

    func save() {
        let cal = Calendar.current
        let components = cal.dateComponents([.hour, .minute], from: startTime)
        var blockStart = cal.startOfDay(for: selectedDay)
        blockStart = cal.date(byAdding: components, to: blockStart) ?? blockStart
        let block = StudyBlock(subjectName: selectedSubject, startTime: blockStart, durationMinutes: durationMinutes, notes: notes)
        modelContext.insert(block)
        try? modelContext.save()
        StudyNotificationManager.shared.schedule(block: block)
        dismiss()
    }
}

@MainActor
struct AddSubjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dailyGoal = 60
    @State private var selectedIcon = "book.fill"
    @State private var selectedColor = "4A90D9"

    let icons = ["book.fill", "function", "atom", "text.book.closed", "scroll", "globe", "music.note", "paintbrush.fill"]
    let colors = ["4A90D9", "5856D6", "FF6B35", "34C759", "FF9500", "AF52DE", "FF2D55", "8E8E93"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Subject").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Add") { save() }.buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
            .padding(20)
            Divider()
            Form {
                TextField("Subject Name", text: $name)
                Stepper("Daily Goal: \(dailyGoal) min", value: $dailyGoal, in: 15...300, step: 15)
                Picker("Icon", selection: $selectedIcon) {
                    ForEach(icons, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 300)
    }

    func save() {
        let subject = StudySubject(name: name, colorHex: selectedColor, icon: selectedIcon, dailyGoalMinutes: dailyGoal)
        modelContext.insert(subject)
        try? modelContext.save()
        dismiss()
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: return nil
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
