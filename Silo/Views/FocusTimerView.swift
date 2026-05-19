import SwiftUI
import SwiftData

struct FocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var timerVM: TimerViewModel
    var progressVM: UserProgressViewModel

    var body: some View {
        HStack(spacing: 0) {
            mainPanel
            Divider()
            sidePanel
        }
        .sheet(isPresented: $timerVM.showIntention) {
            IntentionSheet(timerVM: timerVM)
        }
        .sheet(isPresented: $timerVM.showReflection) {
            if let session = timerVM.pendingReflection {
                ReflectionSheet(session: session, timerVM: timerVM)
            }
        }
        .onAppear { timerVM.setModelContext(modelContext) }
    }

    // MARK: - Main Panel (timer + tasks)

    var mainPanel: some View {
        VStack(spacing: 0) {
            timerSection
            Divider()
            tasksSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    var timerSection: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.top, 20)

            if timerVM.currentMode == .custom && timerVM.state == .idle {
                customDurationControls.padding(.top, 8)
            }

            ZStack {
                CircularProgressRing(
                    progress: timerVM.progress,
                    lineWidth: 12,
                    size: 220,
                    isBreak: timerVM.isOnBreak
                )

                VStack(spacing: 5) {
                    Text(timerVM.isOnBreak ? "Break" : "Focus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(timerVM.timeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("Session \(timerVM.sessionCount + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 16)

            if !timerVM.intention.isEmpty && timerVM.state != .idle {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timerVM.intention)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if timerVM.selectedSubject != "Miscellaneous" {
                        Text("· \(timerVM.selectedSubject)")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 8)
            }

            controls
                .padding(.bottom, 12)
        }
    }

    var tasksSection: some View {
        InlineTasksView(progressVM: progressVM)
    }

    // MARK: - Timer Controls

    var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([TimerMode.pomodoro, .deepWork, .shortBreak, .longBreak, .custom], id: \.self) { mode in
                    Button {
                        timerVM.selectMode(mode)
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(timerVM.currentMode == mode ? Color.blue : Color.clear)
                            .foregroundStyle(timerVM.currentMode == mode ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(timerVM.currentMode == mode ? Color.clear : Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(timerVM.state != .idle)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    var customDurationControls: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus").font(.caption).foregroundStyle(.secondary)
                Stepper("\(timerVM.customFocusMinutes) min", value: $timerVM.customFocusMinutes, in: 10...120, step: 5)
                    .onChange(of: timerVM.customFocusMinutes) { _, _ in timerVM.resetTimerIfIdle() }
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Break").font(.caption).foregroundStyle(.secondary)
                Stepper("\(timerVM.customBreakMinutes) min", value: $timerVM.customBreakMinutes, in: 1...30)
                    .onChange(of: timerVM.customBreakMinutes) { _, _ in timerVM.resetTimerIfIdle() }
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
    }

    var controls: some View {
        HStack(spacing: 12) {
            if timerVM.state != .idle {
                Button { timerVM.reset() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 15))
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                switch timerVM.state {
                case .idle:    timerVM.startSession()
                case .running: timerVM.pause()
                case .paused:  timerVM.resume()
                case .break_:  timerVM.resume()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: timerVM.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(primaryButtonLabel)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(timerVM.isOnBreak ? Color.green : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: (timerVM.isOnBreak ? Color.green : Color.blue).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            if timerVM.isOnBreak && timerVM.state == .running {
                Button { timerVM.skipBreak() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15))
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    var primaryButtonLabel: String {
        switch timerVM.state {
        case .idle:    return timerVM.isOnBreak ? "Start Break" : "Start Focus"
        case .running: return "Pause"
        case .paused:  return "Resume"
        case .break_:  return "Resume"
        }
    }

    // MARK: - Side Panel

    var sidePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Focus Tools")
                    .font(.headline)
                    .padding(.top, 20)

                // General Notes
                VStack(alignment: .leading, spacing: 6) {
                    Label("General Notes", systemImage: "note.text")
                        .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    TextEditor(text: $timerVM.brainDump)
                        .font(.system(size: 13))
                        .frame(height: 140)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }

                // Session Settings
                VStack(alignment: .leading, spacing: 8) {
                    Label("Session Settings", systemImage: "slider.horizontal.3")
                        .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    Toggle("Auto-start breaks", isOn: $timerVM.autoStartBreaks)
                        .font(.system(size: 13))
                    Toggle("Auto-start focus", isOn: $timerVM.autoStartFocus)
                        .font(.system(size: 13))
                }

                BibleVerseCard()

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 230)
        .background(Color(nsColor: .controlBackgroundColor))
    }

}

// MARK: - Bible Verse Card

struct BibleVerseCard: View {
    @State private var verseText: String = ""
    @State private var verseRef: String = ""
    @State private var isLoading: Bool = false

    private let motivatingVerses: [(book: String, chapter: Int, verse: Int)] = [
        ("philippians", 4, 13), ("joshua", 1, 9), ("isaiah", 40, 31),
        ("psalms", 46, 1), ("romans", 8, 28), ("proverbs", 3, 5),
        ("matthew", 11, 28), ("john", 16, 33), ("2corinthians", 12, 9),
        ("hebrews", 12, 1), ("psalms", 23, 4), ("romans", 8, 37),
        ("galatians", 6, 9), ("psalms", 121, 1), ("isaiah", 41, 10),
        ("jeremiah", 29, 11), ("matthew", 6, 34), ("1corinthians", 10, 13),
        ("psalms", 37, 4), ("colossians", 3, 23)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Daily Verse", systemImage: "book.closed")
                    .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await fetchVerse() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            if isLoading {
                ProgressView().scaleEffect(0.6).frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if verseText.isEmpty {
                Text("Tap ↻ to load a verse")
                    .font(.caption).foregroundStyle(.tertiary).italic()
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{201C}\(verseText)\u{201D}")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(verseRef)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
            }
        }
        .onAppear { Task { await fetchVerse() } }
    }

    func fetchVerse() async {
        guard let ref = motivatingVerses.randomElement() else { return }
        isLoading = true
        let url = URL(string: "https://raw.githubusercontent.com/wldeh/bible-api/main/bibles/en-asv/books/\(ref.book)/chapters/\(ref.chapter)/verses/\(ref.verse).json")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                verseText = text
                verseRef = "\(ref.book.capitalized) \(ref.chapter):\(ref.verse) (ASV)"
            }
        } catch {}
        isLoading = false
    }
}

// MARK: - Inline Tasks

@MainActor
struct InlineTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppTask.sortOrder) private var tasks: [AppTask]
    var progressVM: UserProgressViewModel

    @State private var showAddTask = false
    @State private var showEditTask: AppTask? = nil

    var todayTasks: [AppTask] {
        tasks.filter { !$0.isCompleted }.prefix(10).map { $0 }
        + tasks.filter { $0.isCompleted }.prefix(5).map { $0 }
    }

    var completedCount: Int { tasks.filter { $0.isCompleted }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Today's Tasks")
                    .font(.system(size: 16, weight: .semibold))
                if !tasks.isEmpty {
                    Text("\(completedCount)/\(tasks.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                Spacer()
                Button {
                    showAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.blue).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if tasks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.dashed")
                        .font(.system(size: 36)).foregroundStyle(.secondary.opacity(0.4))
                    Text("No tasks yet").font(.system(size: 15)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                List {
                    ForEach(tasks) { task in
                        InlineTaskRow(task: task) {
                            completeTask(task)
                        } onEdit: {
                            showEditTask = task
                        } onDelete: {
                            modelContext.delete(task)
                            try? modelContext.save()
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showAddTask) { AddTaskSheet() }
        .sheet(item: $showEditTask) { task in EditTaskSheet(task: task) }
    }

    func completeTask(_ task: AppTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
            progressVM.recordTaskComplete(difficulty: task.difficulty, context: modelContext)
        } else {
            task.completedAt = nil
        }
        try? modelContext.save()
    }
}

struct InlineTaskRow: View {
    var task: AppTask
    var onComplete: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 2)
                    .frame(width: 26, height: 26)
                if task.isCompleted {
                    Circle().fill(Color.blue).frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { onComplete() }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                if !task.subjectName.isEmpty && task.subjectName != "General" {
                    Text(task.subjectName)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13)).foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 11)
        .opacity(task.isCompleted ? 0.55 : 1.0)
    }
}

// MARK: - Intention Sheet

struct IntentionSheet: View {
    @Bindable var timerVM: TimerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var subjects: [StudySubject]
    @Query(sort: \SavedDeepWorkTask.useCount, order: .reverse) private var savedTasks: [SavedDeepWorkTask]

    @State private var editingTask: SavedDeepWorkTask? = nil
    @State private var editingTitle: String = ""
    @State private var showEditField = false

    var isDeepWork: Bool { timerVM.currentMode == .deepWork }

    var subjectNames: [String] {
        let stored = subjects.map { $0.name }
        let base = stored.isEmpty ? ["Mathematics", "Physics", "English", "History", "General"] : stored
        return ["Miscellaneous"] + base
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: isDeepWork ? "brain.head.profile" : "target")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                    Text(isDeepWork ? "Deep Work Session" : "Start Focus")
                        .font(.title3).fontWeight(.semibold)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Subject Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subject")
                            .font(.subheadline).fontWeight(.semibold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(subjectNames, id: \.self) { name in
                                    Button {
                                        timerVM.selectedSubject = name
                                    } label: {
                                        Text(name)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 14).padding(.vertical, 7)
                                            .background(timerVM.selectedSubject == name ? Color.blue : Color.secondary.opacity(0.1))
                                            .foregroundStyle(timerVM.selectedSubject == name ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Intention / Task
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isDeepWork ? "What specific task?" : "What are you focusing on?")
                            .font(.subheadline).fontWeight(.semibold)
                        TextField(isDeepWork ? "e.g., Finish Chapter 5 problem set" : "e.g., Study for physics exam", text: $timerVM.intention)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }

                    // Saved Deep Work Tasks
                    if isDeepWork && !savedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Previously used")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            ForEach(savedTasks) { task in
                                HStack(spacing: 10) {
                                    Button {
                                        timerVM.intention = task.title
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                            Text(task.title)
                                                .font(.system(size: 13))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("×\(task.useCount)")
                                                .font(.system(size: 11)).foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(timerVM.intention == task.title ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            timerVM.intention == task.title
                                                ? RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                : nil
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    // Edit button
                                    Button {
                                        editingTask = task
                                        editingTitle = task.title
                                        showEditField = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12)).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)

                                    // Delete button
                                    Button {
                                        if timerVM.intention == task.title { timerVM.intention = "" }
                                        modelContext.delete(task)
                                        try? modelContext.save()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12)).foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Inline edit field
                            if showEditField, let editing = editingTask {
                                HStack {
                                    TextField("Edit task name", text: $editingTitle)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 13))
                                    Button("Save") {
                                        editing.title = editingTitle
                                        try? modelContext.save()
                                        showEditField = false
                                        editingTask = nil
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(editingTitle.isEmpty)
                                    Button("Cancel") {
                                        showEditField = false
                                        editingTask = nil
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Start Session") {
                    if isDeepWork && !timerVM.intention.isEmpty {
                        saveDeepWorkTask(title: timerVM.intention)
                    }
                    timerVM.confirmIntentionAndStart()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 460, height: isDeepWork && !savedTasks.isEmpty ? 560 : 400)
    }

    func saveDeepWorkTask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing = savedTasks.first(where: { $0.title.lowercased() == trimmed.lowercased() }) {
            existing.useCount += 1
            existing.lastUsed = Date()
        } else {
            let newTask = SavedDeepWorkTask(title: trimmed)
            modelContext.insert(newTask)
        }
        try? modelContext.save()
    }
}

// MARK: - Reflection Sheet

struct ReflectionSheet: View {
    var session: FocusSession
    @Bindable var timerVM: TimerViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var focusRating: Int = 3
    @State private var interruptions: String = ""
    @State private var completed: String = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36)).foregroundStyle(.green)
                Text("Session Complete!")
                    .font(.title2).fontWeight(.bold)
                Text("+\(session.xpEarned) XP earned")
                    .font(.subheadline).foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How focused were you?")
                        .font(.subheadline).fontWeight(.medium)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { i in
                            Button { focusRating = i } label: {
                                Image(systemName: i <= focusRating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(i <= focusRating ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Any interruptions?").font(.subheadline).fontWeight(.medium)
                    TextField("e.g., Phone notifications", text: $interruptions)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("What did you complete?").font(.subheadline).fontWeight(.medium)
                    TextField("e.g., Finished problem set 3", text: $completed)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Button("Save Reflection") { saveReflection() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(32)
        .frame(width: 420)
    }

    func saveReflection() {
        let reflection = SessionReflection(
            sessionID: session.id,
            focusRating: focusRating,
            interruptions: interruptions,
            completed: completed
        )
        modelContext.insert(reflection)
        try? modelContext.save()
        dismiss()
    }
}
