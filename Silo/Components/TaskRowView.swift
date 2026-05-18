import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: AppTask
    var onComplete: () -> Void
    var onDelete: () -> Void
    var onEdit: () -> Void

    var difficultyColor: Color {
        switch task.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if task.isCompleted {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { onComplete() }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    Label(task.subjectName, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 3) {
                        Circle()
                            .fill(difficultyColor)
                            .frame(width: 5, height: 5)
                        Text(task.difficulty.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("+\(task.difficulty.xpReward) XP")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            if task.repeatDaily {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let due = task.dueTime {
                Text(due, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete", role: .destructive) { onDelete() }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
