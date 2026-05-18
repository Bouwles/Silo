import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

@MainActor
struct AIChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var subjects: [StudySubject]
    @Query(filter: #Predicate<AppTask> { !$0.isCompleted }) private var pendingTasks: [AppTask]

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var selectedModel: String = ""
    @State private var availableModels: [String] = []
    @State private var isLoading: Bool = false
    @State private var ollamaRunning: Bool = false

    private let service = OllamaService.shared

    var systemPrompt: String {
        var parts = ["You are a helpful study assistant built into Silo, a macOS productivity app."]
        if !subjects.isEmpty {
            let subjectList = subjects.map { "\($0.name) (goal: \($0.dailyGoalMinutes) min/day)" }.joined(separator: ", ")
            parts.append("The user studies: \(subjectList).")
        }
        if !pendingTasks.isEmpty {
            let taskList = pendingTasks.prefix(10).map { $0.title }.joined(separator: ", ")
            parts.append("Current pending tasks: \(taskList).")
        }
        parts.append("Be concise and practical.")
        return parts.joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("AI Assistant")
                    .font(.headline)
                Spacer()
                if ollamaRunning && !availableModels.isEmpty {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if !ollamaRunning {
                notRunningBanner
            } else {
                chatArea
            }
        }
        .onAppear { Task { await checkOllama() } }
    }

    var notRunningBanner: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Ollama Not Running")
                .font(.title2).fontWeight(.semibold)
            Text("Install Ollama and start it to use the AI assistant.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Download from **ollama.com**")
                Text("2. Run in Terminal: `ollama pull llama3.2`")
                Text("3. Then: `ollama serve`")
            }
            .font(.system(size: 13, design: .monospaced))
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Button("Check Again") {
                Task { await checkOllama() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var chatArea: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            emptyState
                        }
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 10) {
                Button {
                    Task { await suggestTasks() }
                } label: {
                    Label("Suggest Tasks", systemImage: "lightbulb")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || selectedModel.isEmpty)

                TextField("Ask anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { Task { await sendMessage() } }

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.blue.opacity(0.5))
            Text("Ask me anything about your studies")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    func checkOllama() async {
        ollamaRunning = await service.isRunning()
        if ollamaRunning {
            let models = (try? await service.listModels()) ?? []
            availableModels = models
            if selectedModel.isEmpty, let first = models.first {
                selectedModel = first
            }
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !selectedModel.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: "user", content: text))
        await callOllama()
    }

    func suggestTasks() async {
        guard !selectedModel.isEmpty else { return }
        let subjectList = subjects.isEmpty
            ? "general subjects"
            : subjects.map { $0.name }.joined(separator: ", ")
        let prompt = "Suggest 5 specific, actionable study tasks for today based on my subjects: \(subjectList). Format as a numbered list with just the task title and subject in parentheses. Be concise."
        messages.append(ChatMessage(role: "user", content: "Suggest tasks for today"))
        _ = prompt
        await callOllama(overrideUserContent: prompt)
    }

    func callOllama(overrideUserContent: String? = nil) async {
        isLoading = true
        var history: [OllamaMessage] = [OllamaMessage(role: "system", content: systemPrompt)]
        let msgsToSend = messages
        for (i, msg) in msgsToSend.enumerated() {
            let content: String
            if i == msgsToSend.count - 1, let override = overrideUserContent {
                content = override
            } else {
                content = msg.content
            }
            history.append(OllamaMessage(role: msg.role, content: content))
        }
        do {
            let reply = try await service.chat(model: selectedModel, messages: history)
            messages.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
        }
        isLoading = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            Text(message.content)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isUser { Spacer(minLength: 60) }
        }
    }
}
