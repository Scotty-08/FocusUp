import SwiftUI

struct TasksView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @State private var newTaskTitle = ""
    @State private var hasDueDate = false
    @State private var newTaskDueDate = Date()

    var body: some View {
        ZStack {
            HunterBackground(topRight: false)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        TextField("", text: $newTaskTitle, prompt: Text("New quest, e.g. Apply to 3 internships").foregroundStyle(HunterTheme.textMuted))
                            .foregroundStyle(HunterTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .hudPanel()

                        Button {
                            manager.addTask(title: newTaskTitle, dueDate: hasDueDate ? newTaskDueDate : nil)
                            newTaskTitle = ""
                            hasDueDate = false
                            newTaskDueDate = Date()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(HunterTheme.cyan)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .hudPanel()
                    }

                    HStack(spacing: 8) {
                        Toggle("", isOn: $hasDueDate.animation())
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(HunterTheme.cyan)
                        Text("Deadline")
                            .font(.system(size: 11))
                            .foregroundStyle(HunterTheme.textMuted)

                        if hasDueDate {
                            DatePicker("", selection: $newTaskDueDate, displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                        } else {
                            Text("None — undated quests rank lowest")
                                .font(.system(size: 10))
                                .foregroundStyle(HunterTheme.textMuted)
                        }
                        Spacer()
                    }
                }
                .padding(20)

                if manager.tasks.isEmpty {
                    Spacer()
                    Text("No quests yet. Add one above.")
                        .foregroundStyle(HunterTheme.textMuted)
                    Spacer()
                } else {
                    List {
                        ForEach(manager.tasks) { task in
                            questRow(task)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        }
                        .onDelete { offsets in
                            manager.deleteTasks(at: offsets)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }

                Text("Quests are auto-ordered by due date -- earliest first, same-day ties broken randomly, no date = least urgent. Whatever quest is active stays active until it's cleared, even if something else becomes due sooner. Tap \"Set Active\" to override which one comes first.")
                    .font(.system(size: 10))
                    .foregroundStyle(HunterTheme.textMuted)
                    .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Quest Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.refreshTasks()
        }
    }

    private func questRow(_ task: FocusTask) -> some View {
        let isActive = manager.activeTaskID == task.id
        return HStack(spacing: 12) {
            Button {
                manager.toggleTaskCompletion(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.green : HunterTheme.textMuted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? HunterTheme.textMuted : HunterTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                if let due = task.dueDate {
                    Text("DEADLINE \(due.formatted(date: .abbreviated, time: .omitted).uppercased())\(task.isCompleted ? " · CLEARED" : (isActive ? " · IN PROGRESS" : ""))")
                        .font(.system(size: 10))
                        .foregroundStyle(isPastDue(due) && !task.isCompleted ? HunterTheme.danger : (isActive ? HunterTheme.cyan : HunterTheme.textMuted))
                } else {
                    Text(task.isCompleted ? "NO DEADLINE · CLEARED" : "NO DEADLINE")
                        .font(.system(size: 10))
                        .foregroundStyle(HunterTheme.textMuted)
                }
            }

            Spacer()

            if task.isCompleted {
                EmptyView()
            } else if isActive {
                Text("ACTIVE")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(HunterTheme.bg)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(HunterTheme.cyan)
            } else {
                Button {
                    manager.setActiveTask(task.id)
                } label: {
                    Text("SET ACTIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HunterTheme.cyan)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().strokeBorder(HunterTheme.cyanDim, lineWidth: 1))
            }
        }
        .padding(12)
        .opacity(task.isCompleted ? 0.55 : 1)
        .hudPanel(
            borderColor: isActive && !task.isCompleted ? HunterTheme.cyanDim : Color.white.opacity(0.06),
            cornerAccent: isActive && !task.isCompleted ? HunterTheme.cyan : .clear
        )
    }

    private func isPastDue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

#Preview {
    NavigationStack { TasksView() }
}
