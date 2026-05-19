import SwiftUI
import SwiftData

@MainActor
struct HabitTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    var progressVM: UserProgressViewModel

    @State private var showAddSheet = false

    var completedToday: Int { habits.filter { $0.isCompletedToday }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Habits")
                        .font(.title2).fontWeight(.bold)
                    if !habits.isEmpty {
                        Text("\(completedToday) of \(habits.count) done today")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !habits.isEmpty {
                    progressPill
                }
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            if habits.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit) {
                            completeHabit(habit)
                        } onDelete: {
                            modelContext.delete(habit)
                            try? modelContext.save()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear { checkStreakBreaks() }
        .sheet(isPresented: $showAddSheet) {
            AddHabitSheet()
        }
    }

    var progressPill: some View {
        let pct = habits.isEmpty ? 0.0 : Double(completedToday) / Double(habits.count)
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 28, height: 28)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No habits yet")
                .font(.title3).fontWeight(.semibold)
            Text("Add daily habits to track streaks and earn XP.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add First Habit") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func completeHabit(_ habit: Habit) {
        let wasCompleted = habit.isCompletedToday
        habit.toggle()
        try? modelContext.save()
        if !wasCompleted {
            progressVM.award(xp: 10, context: modelContext)
        }
    }

    func checkStreakBreaks() {
        let cal = Calendar.current
        var changed = false
        for habit in habits {
            guard let last = habit.lastCompletedDate else { continue }
            if habit.isCompletedToday { continue }
            let daysSince = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day ?? 0
            if daysSince > 1 && habit.currentStreak > 0 {
                habit.currentStreak = 0
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }
}

struct HabitRow: View {
    @Bindable var habit: Habit
    var onComplete: () -> Void
    var onDelete: () -> Void

    var accentColor: Color {
        Color(hex: habit.colorHex) ?? .blue
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(habit.isCompletedToday ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 40, height: 40)
                if habit.isCompletedToday {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 40, height: 40)
                }
                Text(habit.emoji)
                    .font(.system(size: 18))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { onComplete() }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(habit.isCompletedToday, color: .secondary)
                    .foregroundStyle(habit.isCompletedToday ? .secondary : .primary)
                HStack(spacing: 8) {
                    if habit.currentStreak > 0 {
                        Text("🔥 \(habit.currentStreak) day streak")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No streak yet")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("+10 XP")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.blue)
                }
            }

            Spacer()

            if habit.longestStreak > 0 {
                VStack(spacing: 1) {
                    Text("\(habit.longestStreak)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("best")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "✅"
    @State private var selectedColorHex = "4A90D9"

    let presetColors: [(String, String)] = [
        ("4A90D9", "Blue"), ("34C759", "Green"), ("FF9500", "Orange"),
        ("FF3B30", "Red"), ("AF52DE", "Purple"), ("FF2D55", "Pink")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Habit")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
                Button("Add") {
                    let habit = Habit(name: name.trimmingCharacters(in: .whitespaces),
                                     emoji: emoji,
                                     colorHex: selectedColorHex)
                    modelContext.insert(habit)
                    try? modelContext.save()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)

            Divider()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Drink water, Exercise, Read", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("EMOJI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Emoji", text: $emoji)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(presetColors, id: \.0) { hex, _ in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(width: 360, height: 320)
    }
}

