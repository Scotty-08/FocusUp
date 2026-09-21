import SwiftUI

struct TasksView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @State private var isCreatingQuest = false
    @State private var editingTask: FocusTask?

    /// Every quest is equally active (see TaskStore) -- this is purely a
    /// DISPLAY order, not persisted or used to pick anything. Incomplete
    /// quests first (highest priority, earliest deadline first; undated
    /// quests rank behind dated ones), completed quests after.
    private var sortedTasks: [FocusTask] {
        manager.tasks.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted && b.isCompleted }
            if a.priority != b.priority { return a.priority > b.priority }
            switch (a.dueDate, b.dueDate) {
            case let (da?, db?): return da < db
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    var body: some View {
        ZStack {
            HunterBackground(topRight: false)
            VStack(spacing: 0) {
                Button {
                    isCreatingQuest = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("MAKE A NEW QUEST")
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(HunterTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(.plain)
                .hudPanel()
                .shadow(color: HunterTheme.cyan.opacity(0.18), radius: 12)
                .padding(20)

                if manager.tasks.isEmpty {
                    Spacer()
                    Text("No quests yet. Tap Make a New Quest above.")
                        .foregroundStyle(HunterTheme.textMuted)
                    Spacer()
                } else {
                    List {
                        ForEach(sortedTasks) { task in
                            questRow(task)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTask = task }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        }
                        .onDelete { offsets in
                            manager.deleteTasks(withIDs: offsets.map { sortedTasks[$0].id })
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }

                Text("Every quest is active -- all of them show on your groups' shields, there's no single quest to pick. Sorted here by priority, then deadline. Tap a quest to edit it.")
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
        .sheet(isPresented: $isCreatingQuest) {
            QuestDetailView(existingTask: nil)
        }
        .sheet(item: $editingTask) { task in
            QuestDetailView(existingTask: task)
        }
    }

    private func questRow(_ task: FocusTask) -> some View {
        HStack(spacing: 12) {
            Button {
                manager.toggleTaskCompletion(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.green : HunterTheme.textMuted)
            }
            .buttonStyle(.plain)

            priorityDot(task.priority)
                .opacity(task.isCompleted ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? HunterTheme.textMuted : HunterTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                if let due = task.dueDate {
                    Text("DEADLINE \(due.formatted(date: .abbreviated, time: .omitted).uppercased())\(task.isCompleted ? " · CLEARED" : "")")
                        .font(.system(size: 10))
                        .foregroundStyle(isPastDue(due) && !task.isCompleted ? HunterTheme.danger : HunterTheme.textMuted)
                } else {
                    Text(task.isCompleted ? "NO DEADLINE · CLEARED" : "NO DEADLINE")
                        .font(.system(size: 10))
                        .foregroundStyle(HunterTheme.textMuted)
                }
            }

            Spacer()
        }
        .padding(12)
        .opacity(task.isCompleted ? 0.55 : 1)
        .hudPanel()
    }

    private func priorityDot(_ priority: TaskPriority) -> some View {
        Circle()
            .fill(priorityColor(priority))
            .frame(width: 8, height: 8)
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return HunterTheme.danger
        case .medium: return HunterTheme.gold
        case .low: return HunterTheme.cyan
        }
    }

    private func isPastDue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

#Preview {
    NavigationStack { TasksView() }
}
