import SwiftUI
import SwiftData
import EventKit

// MARK: - Subject data

struct IBDPSubjectEntry: Identifiable {
    let id = UUID()
    let name: String
    let group: Int
}

let ibdpSubjects: [IBDPSubjectEntry] = [
    // Group 1 — Language A
    .init(name: "English A: Literature", group: 1),
    .init(name: "English A: Language & Literature", group: 1),
    .init(name: "French A: Literature", group: 1),
    .init(name: "Spanish A: Literature", group: 1),
    .init(name: "Mandarin A: Literature", group: 1),
    // Group 2 — Language B
    .init(name: "English B", group: 2),
    .init(name: "French B", group: 2),
    .init(name: "Spanish B", group: 2),
    .init(name: "Mandarin B", group: 2),
    .init(name: "German B", group: 2),
    .init(name: "Japanese B", group: 2),
    .init(name: "Arabic B", group: 2),
    .init(name: "Latin", group: 2),
    // Group 3 — Individuals & Societies
    .init(name: "History", group: 3),
    .init(name: "Geography", group: 3),
    .init(name: "Economics", group: 3),
    .init(name: "Psychology", group: 3),
    .init(name: "Philosophy", group: 3),
    .init(name: "Business Management", group: 3),
    .init(name: "Global Politics", group: 3),
    .init(name: "Social & Cultural Anthropology", group: 3),
    .init(name: "ITGS", group: 3),
    // Group 4 — Sciences
    .init(name: "Biology", group: 4),
    .init(name: "Chemistry", group: 4),
    .init(name: "Physics", group: 4),
    .init(name: "Computer Science", group: 4),
    .init(name: "Environmental Systems & Societies", group: 4),
    .init(name: "Sports, Exercise & Health Science", group: 4),
    // Group 5 — Mathematics
    .init(name: "Math: Analysis & Approaches HL", group: 5),
    .init(name: "Math: Analysis & Approaches SL", group: 5),
    .init(name: "Math: Applications & Interpretation HL", group: 5),
    .init(name: "Math: Applications & Interpretation SL", group: 5),
    // Group 6 — The Arts
    .init(name: "Visual Arts", group: 6),
    .init(name: "Music", group: 6),
    .init(name: "Theatre", group: 6),
    .init(name: "Film", group: 6),
    .init(name: "Dance", group: 6),
]

let ibdpGroupNames: [Int: String] = [
    1: "Language A", 2: "Language B", 3: "Individuals & Societies",
    4: "Sciences", 5: "Mathematics", 6: "The Arts"
]

func ibdpGroupColorHex(_ group: Int) -> String {
    switch group {
    case 1: return "FF6B6B"
    case 2: return "4ECDC4"
    case 3: return "45B7D1"
    case 4: return "52C77A"
    case 5: return "AF52DE"
    case 6: return "FF9F43"
    default: return "4A90D9"
    }
}

// MARK: - ExamSeasonView

@MainActor
struct ExamSeasonView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IBDPExamSeason.createdAt, order: .reverse) private var seasons: [IBDPExamSeason]
    var progressVM: UserProgressViewModel

    @State private var showSetup = false
    @State private var showAddExam = false
    @State private var quizExam: IBDPExam? = nil
    @State private var weatherByDate: [String: WeatherDay] = [:]
    @State private var calendarMessage: String? = nil

    var activeSeason: IBDPExamSeason? { seasons.first }

    var body: some View {
        Group {
            if let season = activeSeason {
                seasonContent(season)
            } else {
                noSeasonState
            }
        }
        .sheet(isPresented: $showSetup) { SetupSeasonSheet() }
        .sheet(isPresented: $showAddExam) {
            if let s = activeSeason { AddExamSheet(season: s) }
        }
        .sheet(item: $quizExam) { exam in QuizSheet(exam: exam) }
    }

    // MARK: Season content

    func seasonContent(_ season: IBDPExamSeason) -> some View {
        VStack(spacing: 0) {
            header(season)
            toolbar(season)
            Divider()
            if season.exams.isEmpty {
                noExamsState
            } else {
                examList(season)
            }
        }
        .onAppear { Task { await loadWeather(season) } }
    }

    func header(_ season: IBDPExamSeason) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(season.name)
                    .font(.title2).fontWeight(.bold)
                Text(dateRange(season))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let total = season.exams.count
            let done = season.exams.filter(\.isCompleted).count
            if total > 0 { progressRing(done: done, total: total) }
            Button { showAddExam = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
    }

    func toolbar(_ season: IBDPExamSeason) -> some View {
        HStack(spacing: 10) {
            Button {
                exportToCalendar(season)
            } label: {
                Label("Export to Calendar", systemImage: "calendar.badge.plus")
                    .font(.caption).fontWeight(.medium)
            }
            .buttonStyle(.bordered).controlSize(.small)

            if let msg = calendarMessage {
                Text(msg).font(.caption2).foregroundStyle(.green)
            }

            Spacer()

            if !season.city.isEmpty {
                Label(season.city, systemImage: "location.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                modelContext.delete(season)
                try? modelContext.save()
            } label: {
                Image(systemName: "trash").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    // MARK: Exam list

    func examList(_ season: IBDPExamSeason) -> some View {
        let groups = groupedExams(season)
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "EEEE, MMMM d"
        let timeFmt = DateFormatter(); timeFmt.timeStyle = .short; timeFmt.dateStyle = .none
        let keyFmt  = DateFormatter(); keyFmt.dateFormat  = "yyyy-MM-dd"

        return List {
            ForEach(groups, id: \.0) { day, exams in
                Section {
                    ForEach(exams) { exam in
                        examRow(exam, timeFmt: timeFmt)
                    }
                } header: {
                    HStack {
                        Text(dateFmt.string(from: day))
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        Spacer()
                        if let w = weatherByDate[keyFmt.string(from: day)] {
                            Label(String(format: "%.0f°C", w.maxTempC), systemImage: w.icon)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    func examRow(_ exam: IBDPExam, timeFmt: DateFormatter) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: exam.groupColorHex) ?? .blue)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exam.subject)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(exam.isCompleted, color: .secondary)
                        .foregroundStyle(exam.isCompleted ? .secondary : .primary)
                    Text("P\(exam.paperNumber)")
                        .font(.caption2).fontWeight(.semibold)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background((Color(hex: exam.groupColorHex) ?? .blue).opacity(0.15))
                        .foregroundStyle(Color(hex: exam.groupColorHex) ?? .blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                HStack(spacing: 8) {
                    Text(timeFmt.string(from: exam.date))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(exam.durationText)
                        .font(.caption).foregroundStyle(.secondary)
                    if !exam.notes.isEmpty {
                        Text(exam.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Spacer()

            Button { quizExam = exam } label: {
                Image(systemName: "brain")
                    .font(.system(size: 13)).foregroundStyle(.purple.opacity(0.7))
            }
            .buttonStyle(.plain).help("Quiz me on \(exam.subject)")

            Button { toggleExam(exam) } label: {
                Image(systemName: exam.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(exam.isCompleted ? Color.green : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(exam)
                try? modelContext.save()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: Helpers

    func groupedExams(_ season: IBDPExamSeason) -> [(Date, [IBDPExam])] {
        let cal = Calendar.current
        var dict: [Date: [IBDPExam]] = [:]
        for exam in season.exams.sorted(by: { $0.date < $1.date }) {
            let day = cal.startOfDay(for: exam.date)
            dict[day, default: []].append(exam)
        }
        return dict.sorted { $0.key < $1.key }
    }

    func dateRange(_ season: IBDPExamSeason) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return "\(f.string(from: season.startDate)) \u{2013} \(f.string(from: season.endDate))"
    }

    func toggleExam(_ exam: IBDPExam) {
        let was = exam.isCompleted
        exam.isCompleted.toggle()
        try? modelContext.save()
        if !was { progressVM.award(xp: 25, context: modelContext) }
    }

    func loadWeather(_ season: IBDPExamSeason) async {
        guard season.latitude != 0, !season.exams.isEmpty else { return }
        let dates = season.exams.map(\.date)
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 15, to: now) ?? now
        let start = max(dates.min() ?? now, Calendar.current.startOfDay(for: now))
        let end   = min(dates.max() ?? now, horizon)
        guard start <= end else { return }
        do {
            let days = try await OpenMeteoService.shared.fetchWeather(
                latitude: season.latitude, longitude: season.longitude, startDate: start, endDate: end)
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            for d in days { weatherByDate[fmt.string(from: d.date)] = d }
        } catch {}
    }

    func exportToCalendar(_ season: IBDPExamSeason) {
        let examData = season.exams.map { e -> (String, Date, Date, String) in
            ("\(e.subject) Paper \(e.paperNumber)", e.date, e.endTime, e.notes.isEmpty ? "IB Exam" : e.notes)
        }
        let count = examData.count
        Task { @MainActor in
            let store = EKEventStore()
            guard (try? await store.requestWriteOnlyAccessToEvents()) == true else {
                calendarMessage = "Calendar access denied"
                return
            }
            guard let cal = store.defaultCalendarForNewEvents else { return }
            for (title, start, end, notes) in examData {
                let ev = EKEvent(eventStore: store)
                ev.title = title; ev.startDate = start; ev.endDate = end
                ev.notes = notes; ev.calendar = cal
                try? store.save(ev, span: .thisEvent)
            }
            calendarMessage = "\(count) exams exported"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            calendarMessage = nil
        }
    }

    func progressRing(done: Int, total: Int) -> some View {
        let pct = total > 0 ? Double(done) / Double(total) : 0
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            Circle().trim(from: 0, to: pct)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(total)").font(.system(size: 7, weight: .bold))
        }
        .frame(width: 34, height: 34)
    }

    // MARK: Empty states

    var noSeasonState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 44)).foregroundStyle(.secondary.opacity(0.4))
            Text("No Exam Season").font(.title3).fontWeight(.semibold)
            Text("Set up your IBDP exam season to track exams, get weather forecasts, and quiz yourself.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Set Up Exam Season") { showSetup = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var noExamsState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 36)).foregroundStyle(.secondary.opacity(0.4))
            Text("No exams added yet").font(.headline)
            Text("Add your exams with subject, paper, date, and duration.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Add First Exam") { showAddExam = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SetupSeasonSheet

struct SetupSeasonSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = "May 2026 Session"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var city = ""
    @State private var isSaving = false
    @State private var cityError = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Exam Season Setup").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                Button("Create") { Task { await create() } }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding(20)

            Divider()

            VStack(spacing: 20) {
                labeledField("SESSION NAME") {
                    TextField("e.g. May 2026 Session", text: $name).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 16) {
                    labeledField("START DATE") {
                        DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden()
                    }
                    labeledField("END DATE") {
                        DatePicker("", selection: $endDate, displayedComponents: .date).labelsHidden()
                    }
                }
                labeledField("CITY (for weather)") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("e.g. London, Dubai, New York", text: $city).textFieldStyle(.roundedBorder)
                        if cityError {
                            Text("City not found — weather will be unavailable")
                                .font(.caption2).foregroundStyle(.orange)
                        } else {
                            Text("Leave empty to skip weather forecasts")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(20)

            if isSaving {
                ProgressView("Looking up location...").padding(.bottom, 12)
            }

            Spacer()
        }
        .frame(width: 380, height: 320)
    }

    func labeledField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func create() async {
        isSaving = true
        cityError = false
        var lat = 0.0, lon = 0.0
        let trimCity = city.trimmingCharacters(in: .whitespaces)
        if !trimCity.isEmpty {
            do { (lat, lon) = try await OpenMeteoService.shared.geocode(city: trimCity) }
            catch { cityError = true }
        }
        let season = IBDPExamSeason(name: name.trimmingCharacters(in: .whitespaces),
                                    startDate: startDate, endDate: endDate,
                                    city: trimCity, latitude: lat, longitude: lon)
        modelContext.insert(season)
        try? modelContext.save()
        isSaving = false
        dismiss()
    }
}

// MARK: - AddExamSheet

struct AddExamSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var season: IBDPExamSeason

    @State private var selectedSubject: IBDPSubjectEntry? = nil
    @State private var subjectSearch = ""
    @State private var paperNumber = 1
    @State private var examDate = Date()
    @State private var durationMinutes = 120
    @State private var notes = ""
    @State private var books: [LibraryBook] = []
    @State private var isLoadingBooks = false

    let durations = [45, 60, 75, 90, 105, 120, 135, 150, 180]

    var filteredSubjects: [IBDPSubjectEntry] {
        subjectSearch.isEmpty ? ibdpSubjects : ibdpSubjects.filter {
            $0.name.localizedCaseInsensitiveContains(subjectSearch)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Exam").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                Button("Add") { save() }
                    .fontWeight(.semibold).disabled(selectedSubject == nil)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    subjectPicker
                    paperPicker
                    dateField
                    durationPicker
                    notesField
                    if isLoadingBooks {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Finding study guides...").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !books.isEmpty {
                        bookSuggestions
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 540)
    }

    var subjectPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SUBJECT").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if let sel = selectedSubject {
                HStack {
                    Circle().fill(Color(hex: ibdpGroupColorHex(sel.group)) ?? .blue)
                        .frame(width: 10, height: 10)
                    Text(sel.name).font(.system(size: 14, weight: .medium))
                    Spacer()
                    Button {
                        selectedSubject = nil; subjectSearch = ""; books = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                TextField("Search subject...", text: $subjectSearch).textFieldStyle(.roundedBorder)
                if !filteredSubjects.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(filteredSubjects.prefix(6)) { sub in
                            Button {
                                selectedSubject = sub
                                subjectSearch = ""
                                Task { await fetchBooks(sub.name) }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(Color(hex: ibdpGroupColorHex(sub.group)) ?? .blue)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(sub.name).font(.system(size: 13))
                                        Text(ibdpGroupNames[sub.group] ?? "")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6).padding(.horizontal, 10)
                            }
                            .buttonStyle(.plain)
                            if sub.id != filteredSubjects.prefix(6).last?.id {
                                Divider().padding(.horizontal, 10)
                            }
                        }
                    }
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    var paperPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PAPER").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Picker("Paper", selection: $paperNumber) {
                Text("Paper 1").tag(1)
                Text("Paper 2").tag(2)
                Text("Paper 3").tag(3)
            }
            .pickerStyle(.segmented)
        }
    }

    var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATE & TIME").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            DatePicker("", selection: $examDate).labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var durationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DURATION").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Picker("Duration", selection: $durationMinutes) {
                ForEach(durations, id: \.self) { d in
                    Text(fmtDuration(d)).tag(d)
                }
            }
            .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES (optional)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            TextField("e.g. Room 204, bring calculator", text: $notes).textFieldStyle(.roundedBorder)
        }
    }

    var bookSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STUDY GUIDES").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(books) { book in
                HStack(spacing: 10) {
                    Image(systemName: "book.fill").font(.system(size: 14)).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.shortTitle).font(.system(size: 12, weight: .medium))
                        Text(book.author).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func fmtDuration(_ minutes: Int) -> String {
        let h = minutes / 60; let m = minutes % 60
        if m == 0 { return "\(h)h" }
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }

    func fetchBooks(_ subject: String) async {
        isLoadingBooks = true
        do { books = try await OpenLibraryService.shared.searchBooks(subject: subject) }
        catch { books = [] }
        isLoadingBooks = false
    }

    func save() {
        guard let sub = selectedSubject else { return }
        let exam = IBDPExam(subject: sub.name, subjectGroup: sub.group,
                            paperNumber: paperNumber, date: examDate,
                            durationMinutes: durationMinutes, notes: notes)
        modelContext.insert(exam)
        exam.season = season
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - QuizSheet

@MainActor
struct QuizSheet: View {
    @Environment(\.dismiss) private var dismiss
    var exam: IBDPExam

    @State private var quizText = ""
    @State private var isLoading = false
    @State private var modelName = "llama3"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quiz: \(exam.subject)").font(.headline)
                    Text("Paper \(exam.paperNumber)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            ScrollView {
                Group {
                    if isLoading {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Generating questions...").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center).padding(40)
                    } else if quizText.isEmpty {
                        Text("Tap Generate Quiz to start.")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(40)
                    } else {
                        Text(quizText)
                            .font(.system(size: 14)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    }
                }
            }

            Divider()

            HStack {
                Picker("Model", selection: $modelName) {
                    Text("llama3").tag("llama3")
                    Text("mistral").tag("mistral")
                    Text("gemma").tag("gemma")
                    Text("phi3").tag("phi3")
                }
                .labelsHidden().frame(width: 110)
                Spacer()
                Button("Generate Quiz") { Task { await generateQuiz() } }
                    .buttonStyle(.borderedProminent).disabled(isLoading)
            }
            .padding(16)
        }
        .frame(width: 500, height: 460)
        .onAppear { Task { await generateQuiz() } }
    }

    func generateQuiz() async {
        isLoading = true
        quizText = ""
        let prompt = "Generate 5 challenging practice exam questions for IB \(exam.subject) Paper \(exam.paperNumber). Number them 1 through 5. After each question add a brief hint in parentheses. Do not provide answers."
        let messages = [
            OllamaMessage(role: "system", content: "You are an experienced IB examiner. Write realistic exam-style questions that reflect the IB assessment criteria."),
            OllamaMessage(role: "user", content: prompt)
        ]
        do {
            quizText = try await OllamaService.shared.chat(model: modelName, messages: messages)
        } catch {
            quizText = "Could not connect to Ollama. Make sure it is running on localhost:11434."
        }
        isLoading = false
    }
}
