import SwiftUI

/// Create/edit in one screen, same dual-purpose pattern as
/// GroupDetailView -- `existingTask == nil` means create; otherwise
/// every field seeds from the quest being edited and Save calls
/// `manager.updateTask`. Reuses PlayerTheme's HUD panel language, no new
/// visual style.
struct QuestDetailView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @Environment(\.dismiss) private var dismiss

    let existingTask: FocusTask?

    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: TaskPriority

    init(existingTask: FocusTask?) {
        self.existingTask = existingTask
        _title = State(initialValue: existingTask?.title ?? "")
        _hasDueDate = State(initialValue: existingTask?.dueDate != nil)
        _dueDate = State(initialValue: existingTask?.dueDate ?? Date())
        _priority = State(initialValue: existingTask?.priority ?? .medium)
    }

    var body: some View {
        ZStack {
            PlayerBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(existingTask == nil ? "New Quest" : "Edit Quest")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(PlayerTheme.textPrimary)

                    titleField
                    deadlineSection
                    prioritySection

                    saveButton
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HUDLabel(text: "Quest")
            TextField("", text: $title, prompt: Text("e.g. Apply to 3 internships").foregroundStyle(PlayerTheme.textMuted))
                .foregroundStyle(PlayerTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .hudPanel()
        }
    }

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HUDLabel(text: "Deadline")
            HStack(spacing: 8) {
                Toggle("", isOn: $hasDueDate.animation())
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(PlayerTheme.cyan)
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                } else {
                    Text("None -- undated quests rank lowest")
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
                Spacer()
            }
        }
        .padding(14)
        .hudPanel()
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HUDLabel(text: "Priority")
            HStack(spacing: 10) {
                ForEach(TaskPriority.allCases, id: \.self) { level in
                    priorityButton(level)
                }
            }
        }
        .padding(14)
        .hudPanel()
    }

    private func priorityButton(_ level: TaskPriority) -> some View {
        let selected = priority == level
        let color = priorityColor(level)
        return Button {
            priority = level
        } label: {
            Text(level.label.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? PlayerTheme.bg : color)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(selected ? color : color.opacity(0.12))
                .overlay(Rectangle().strokeBorder(color.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func priorityColor(_ level: TaskPriority) -> Color {
        switch level {
        case .high: return PlayerTheme.danger
        case .medium: return PlayerTheme.gold
        case .low: return PlayerTheme.cyan
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("SAVE QUEST")
                .font(.system(size: 13, weight: .heavy))
                .tracking(1)
                .foregroundStyle(PlayerTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .buttonStyle(.plain)
        .hudPanel()
        .shadow(color: PlayerTheme.cyan.opacity(0.18), radius: 12)
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
    }

    private func save() {
        let resolvedDueDate = hasDueDate ? dueDate : nil
        if let existingTask {
            manager.updateTask(FocusTask(
                id: existingTask.id,
                title: title,
                isCompleted: existingTask.isCompleted,
                dueDate: resolvedDueDate,
                priority: priority
            ))
        } else {
            manager.addTask(title: title, dueDate: resolvedDueDate, priority: priority)
        }
        dismiss()
    }
}

#Preview {
    QuestDetailView(existingTask: nil)
}
