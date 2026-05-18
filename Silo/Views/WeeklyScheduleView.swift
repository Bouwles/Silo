import SwiftUI
import SwiftData

@MainActor
struct WeeklyScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [WeeklyEvent]
    @State private var showAddEvent = false
    @State private var selectedDay: Int = currentDayOfWeek()
    @State private var editingEvent: WeeklyEvent? = nil

    static func currentDayOfWeek() -> Int {
        (Calendar.current.component(.weekday, from: Date()) - 1)  // 0=Sun
    }

    var eventsForSelectedDay: [WeeklyEvent] {
        events.filter { $0.dayOfWeek == selectedDay }
              .sorted { $0.startMinutes < $1.startMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            dayPicker
            Divider()
            eventList
        }
        .sheet(isPresented: $showAddEvent) {
            AddWeeklyEventSheet(preselectedDay: selectedDay)
        }
        .sheet(item: $editingEvent) { event in
            EditWeeklyEventSheet(event: event)
        }
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Weekly Schedule")
                    .font(.title2).fontWeight(.bold)
                Text("Recurring events that repeat every week")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showAddEvent = true
            } label: {
                Label("Add Event", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.blue).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    var dayPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { day in
                let isSelected = day == selectedDay
                let isToday = day == WeeklyScheduleView.currentDayOfWeek()
                let count = events.filter { $0.dayOfWeek == day }.count

                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: 4) {
                        Text(WeeklyEvent.dayAbbr[day])
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(isSelected ? .white : .secondary)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
                        } else {
                            Text("—")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isSelected ? .white.opacity(0.5) : .secondary.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(isSelected ? Color.blue : isToday ? Color.blue.opacity(0.06) : Color.clear)
                    .overlay(isToday && !isSelected ?
                        Rectangle().frame(height: 2).foregroundStyle(Color.blue.opacity(0.4)).frame(maxHeight: .infinity, alignment: .bottom) : nil)
                }
                .buttonStyle(.plain)

                if day < 6 { Divider() }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var eventList: some View {
        Group {
            if eventsForSelectedDay.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 44)).foregroundStyle(.secondary.opacity(0.4))
                    Text("No events on \(WeeklyEvent.dayFull[selectedDay])")
                        .font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
                    Text("Add recurring events like tutoring, classes, or study sessions.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        showAddEvent = true
                    } label: {
                        Text("Add Event").font(.subheadline).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(eventsForSelectedDay) { event in
                        WeeklyEventRow(event: event) {
                            editingEvent = event
                        } onDelete: {
                            modelContext.delete(event)
                            try? modelContext.save()
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct WeeklyEventRow: View {
    var event: WeeklyEvent
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: event.colorHex) ?? .blue)
                .frame(width: 4)
                .frame(height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("\(event.startTimeString) – \(event.endTimeString)")
                        .font(.caption).foregroundStyle(.secondary)
                    if event.durationMinutes > 0 {
                        Text("· \(event.durationMinutes)m")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }

            Spacer()

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

@MainActor
struct AddWeeklyEventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var preselectedDay: Int
    @State private var title = ""
    @State private var selectedDay: Int
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 10
    @State private var endMinute = 0
    @State private var notes = ""
    @State private var selectedColor = "4A90D9"

    let colors = ["4A90D9", "5856D6", "FF6B35", "34C759", "FF9500", "AF52DE", "FF2D55", "8E8E93"]

    init(preselectedDay: Int) {
        self.preselectedDay = preselectedDay
        _selectedDay = State(initialValue: preselectedDay)
    }

    var startMinutes: Int { startHour * 60 + startMinute }
    var endMinutes: Int { endHour * 60 + endMinute }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Weekly Event").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Add") { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty)
            }
            .padding(20)
            Divider()
            Form {
                Section("Event") {
                    TextField("Title (e.g. Tutoring, Math Class)", text: $title)
                    TextField("Notes (optional)", text: $notes)
                }
                Section("Schedule") {
                    Picker("Day", selection: $selectedDay) {
                        ForEach(0..<7) { i in
                            Text(WeeklyEvent.dayFull[i]).tag(i)
                        }
                    }
                    HStack {
                        Text("Start")
                        Spacer()
                        Picker("", selection: $startHour) {
                            ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
                        }
                        .frame(width: 60)
                        Text(":")
                        Picker("", selection: $startMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                        }
                        .frame(width: 60)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        Picker("", selection: $endHour) {
                            ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
                        }
                        .frame(width: 60)
                        Text(":")
                        Picker("", selection: $endMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                        }
                        .frame(width: 60)
                    }
                }
                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) { c in
                            Button {
                                selectedColor = c
                            } label: {
                                Circle()
                                    .fill(Color(hex: c) ?? .blue)
                                    .frame(width: 26, height: 26)
                                    .overlay(selectedColor == c ? Circle().stroke(.white, lineWidth: 2) : nil)
                                    .shadow(color: .black.opacity(0.15), radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 480)
    }

    func save() {
        let event = WeeklyEvent(
            title: title,
            dayOfWeek: selectedDay,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            colorHex: selectedColor,
            notes: notes
        )
        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}

@MainActor
struct EditWeeklyEventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var event: WeeklyEvent

    @State private var title: String
    @State private var selectedDay: Int
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var notes: String
    @State private var selectedColor: String

    let colors = ["4A90D9", "5856D6", "FF6B35", "34C759", "FF9500", "AF52DE", "FF2D55", "8E8E93"]

    init(event: WeeklyEvent) {
        self.event = event
        _title = State(initialValue: event.title)
        _selectedDay = State(initialValue: event.dayOfWeek)
        _startHour = State(initialValue: event.startMinutes / 60)
        _startMinute = State(initialValue: event.startMinutes % 60)
        _endHour = State(initialValue: event.endMinutes / 60)
        _endMinute = State(initialValue: event.endMinutes % 60)
        _notes = State(initialValue: event.notes)
        _selectedColor = State(initialValue: event.colorHex)
    }

    var startMinutesTotal: Int { startHour * 60 + startMinute }
    var endMinutesTotal: Int { endHour * 60 + endMinute }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Event").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Save") { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty)
            }
            .padding(20)
            Divider()
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes)
                }
                Section("Schedule") {
                    Picker("Day", selection: $selectedDay) {
                        ForEach(0..<7) { i in
                            Text(WeeklyEvent.dayFull[i]).tag(i)
                        }
                    }
                    HStack {
                        Text("Start")
                        Spacer()
                        Picker("", selection: $startHour) {
                            ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
                        }
                        .frame(width: 60)
                        Text(":")
                        Picker("", selection: $startMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                        }
                        .frame(width: 60)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        Picker("", selection: $endHour) {
                            ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
                        }
                        .frame(width: 60)
                        Text(":")
                        Picker("", selection: $endMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                        }
                        .frame(width: 60)
                    }
                }
                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) { c in
                            Button {
                                selectedColor = c
                            } label: {
                                Circle()
                                    .fill(Color(hex: c) ?? .blue)
                                    .frame(width: 26, height: 26)
                                    .overlay(selectedColor == c ? Circle().stroke(.white, lineWidth: 2) : nil)
                                    .shadow(color: .black.opacity(0.15), radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 480)
    }

    func save() {
        event.title = title
        event.dayOfWeek = selectedDay
        event.startMinutes = startMinutesTotal
        event.endMinutes = endMinutesTotal
        event.notes = notes
        event.colorHex = selectedColor
        try? modelContext.save()
        dismiss()
    }
}
