import SwiftUI
import SwiftData

@MainActor
struct DailyTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppTask.sortOrder) private var tasks: [AppTask]
    var progressVM: UserProgressViewModel

    @State private var showAddTask = false
    @State private var showEditTask: AppTask? = nil
    @State private var filterSubject: String = "All"
    @State private var showCompleted: Bool = true

    var subjects: [String] {
        let names = Set(tasks.map { $0.subjectName })
        return ["All"] + Array(names).sorted()
    }

    var filteredTasks: [AppTask] {
        tasks.filter { task in
            let subjectMatch = filterSubject == "All" || task.subjectName == filterSubject
            let completedMatch = showCompleted || !task.isCompleted
            return subjectMatch && completedMatch
        }
    }

    var completedToday: Int { tasks.filter { $0.isCompleted }.count }
    var totalToday: Int { tasks.count }
    var totalXPToday: Int { tasks.filter { $0.isCompleted }.reduce(0) { $0 + $1.difficulty.xpReward } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolbar
            Divider()
            taskList
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet()
        }
        .sheet(item: $showEditTask) { task in
            EditTaskSheet(task: task)
        }
    }

    var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Tasks").font(.title2).fontWeight(.bold)
                    Text(Date(), style: .date).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(completedToday)/\(totalToday)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Completed").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("+\(totalXPToday)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                        Text("XP Earned").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button {
                    showAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.blue).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, totalToday > 0 ? 8 : 16)

            if totalToday > 0 {
                ProgressView(value: Double(completedToday), total: Double(totalToday))
                    .tint(.blue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
        }
    }

    var toolbar: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(subjects, id: \.self) { subject in
                        Button {
                            filterSubject = subject
                        } label: {
                            Text(subject)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(filterSubject == subject ? Color.blue : Color.secondary.opacity(0.1))
                                .foregroundStyle(filterSubject == subject ? .white : .secondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
            Toggle("Show Completed", isOn: $showCompleted)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
    }

    var taskList: some View {
        Group {
            if filteredTasks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredTasks) { task in
                        TaskRowView(task: task) {
                            completeTask(task)
                        } onDelete: {
                            deleteTask(task)
                        } onEdit: {
                            showEditTask = task
                        }
                    }
                    .onMove { from, to in
                        guard filterSubject == "All" else { return }
                        moveTasks(from: from, to: to)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: 48)).foregroundStyle(.secondary.opacity(0.4))
            Text("No tasks today").font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
            Button {
                showAddTask = true
            } label: {
                Text("Add your first task").font(.subheadline).foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    func deleteTask(_ task: AppTask) {
        modelContext.delete(task)
        try? modelContext.save()
    }

    func moveTasks(from: IndexSet, to: Int) {
        var ordered = filteredTasks
        ordered.move(fromOffsets: from, toOffset: to)
        for (index, task) in ordered.enumerated() {
            task.sortOrder = index
        }
        try? modelContext.save()
    }
}

@MainActor
struct AddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var subjects: [StudySubject]

    @State private var title = ""
    @State private var description = ""
    @State private var selectedSubject = "General"
    @State private var difficulty: TaskDifficulty = .medium
    @State private var hasDueTime = false
    @State private var dueTime = Date()
    @State private var repeatDaily = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Task").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Add Task") { saveTask() }.buttonStyle(.borderedProminent).disabled(title.isEmpty)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldGroup("Title") {
                        TextField("e.g., Finish Chapter 5", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldGroup("Description (optional)") {
                        TextField("Add more detail...", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldGroup("Subject") {
                        Picker("", selection: $selectedSubject) {
                            ForEach(subjectNames, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    fieldGroup("Difficulty") {
                        HStack(spacing: 10) {
                            ForEach(TaskDifficulty.allCases, id: \.self) { d in
                                Button {
                                    difficulty = d
                                } label: {
                                    Text("\(d.rawValue) +\(d.xpReward)XP")
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(difficulty == d ? Color.blue : Color.secondary.opacity(0.1))
                                        .foregroundStyle(difficulty == d ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set due time", isOn: $hasDueTime)
                        if hasDueTime {
                            DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        Toggle("Repeat daily", isOn: $repeatDaily)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 420, height: 480)
    }

    @ViewBuilder
    func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    var subjectNames: [String] {
        let stored = subjects.map { $0.name }
        return stored.isEmpty ? ["General", "Mathematics", "Physics", "English", "History"] : stored
    }

    func saveTask() {
        let task = AppTask(
            title: title,
            taskDescription: description,
            subjectName: selectedSubject,
            difficulty: difficulty,
            dueTime: hasDueTime ? dueTime : nil,
            repeatDaily: repeatDaily
        )
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}

@MainActor
struct EditTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var subjects: [StudySubject]
    @Bindable var task: AppTask

    @State private var title: String
    @State private var description: String
    @State private var selectedSubject: String
    @State private var difficulty: TaskDifficulty
    @State private var hasDueTime: Bool
    @State private var dueTime: Date
    @State private var repeatDaily: Bool

    init(task: AppTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.taskDescription)
        _selectedSubject = State(initialValue: task.subjectName)
        _difficulty = State(initialValue: task.difficulty)
        _hasDueTime = State(initialValue: task.dueTime != nil)
        _dueTime = State(initialValue: task.dueTime ?? Date())
        _repeatDaily = State(initialValue: task.repeatDaily)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Task").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Save") { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldGroup("Title") {
                        TextField("Task title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldGroup("Description (optional)") {
                        TextField("Add more detail...", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldGroup("Subject") {
                        Picker("", selection: $selectedSubject) {
                            ForEach(subjectNames, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    fieldGroup("Difficulty") {
                        HStack(spacing: 10) {
                            ForEach(TaskDifficulty.allCases, id: \.self) { d in
                                Button {
                                    difficulty = d
                                } label: {
                                    Text("\(d.rawValue) +\(d.xpReward)XP")
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(difficulty == d ? Color.blue : Color.secondary.opacity(0.1))
                                        .foregroundStyle(difficulty == d ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set due time", isOn: $hasDueTime)
                        if hasDueTime {
                            DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        Toggle("Repeat daily", isOn: $repeatDaily)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 420, height: 480)
    }

    @ViewBuilder
    func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    var subjectNames: [String] {
        let stored = subjects.map { $0.name }
        return stored.isEmpty ? ["General", "Mathematics", "Physics", "English", "History"] : stored
    }

    func save() {
        task.title = title
        task.taskDescription = description
        task.subjectName = selectedSubject
        task.difficulty = difficulty
        task.dueTime = hasDueTime ? dueTime : nil
        task.repeatDaily = repeatDaily
        try? modelContext.save()
        dismiss()
    }
}
