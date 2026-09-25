import SwiftUI

struct TasksView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @StateObject private var canvas = CanvasClient.shared
    @State private var isCreatingQuest = false
    @State private var editingTask: FocusTask?
    @State private var isShowingCanvasSettings = false
    @Environment(\.openURL) private var openURL

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

    /// " · GONE IN 5H" -- finished quests clear out of the log on their
    /// own (FamilyControlsManager.purgeClearedQuests).
    private func removalHint(_ task: FocusTask) -> String {
        guard let done = task.completedAt else { return "" }
        let remaining = FamilyControlsManager.clearCompletedAfter - Date().timeIntervalSince(done)
        let hours = Int((remaining / 3600).rounded(.up))
        return hours > 1 ? " · GONE IN \(hours)H" : " · GONE SOON"
    }

    var body: some View {
        ZStack {
            PlayerBackground(topRight: false)
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
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(.plain)
                .hudPanel()
                .shadow(color: PlayerTheme.cyan.opacity(0.18), radius: 12)
                .padding(20)

                if manager.tasks.isEmpty {
                    Spacer()
                    Text("No quests yet. Tap Make a New Quest above.")
                        .foregroundStyle(PlayerTheme.textMuted)
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

                Text("Open Canvas in Safari to refresh your quests.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PlayerTheme.textMuted)
                    .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Quest Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCanvasSettings = true
                } label: {
                    Image(systemName: canvas.isConnected ? "graduationcap.fill" : "graduationcap")
                        .foregroundStyle(canvas.isConnected ? PlayerTheme.cyan : PlayerTheme.textMuted)
                }
            }
        }
        .onAppear {
            manager.refreshTasks()
        }
        .sheet(isPresented: $isCreatingQuest) {
            QuestDetailView(existingTask: nil)
        }
        .sheet(item: $editingTask) { task in
            QuestDetailView(existingTask: task)
        }
        .sheet(isPresented: $isShowingCanvasSettings) {
            CanvasSettingsView()
        }
    }

    private func questRow(_ task: FocusTask) -> some View {
        HStack(spacing: 12) {
            Button {
                manager.toggleTaskCompletion(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.green : PlayerTheme.textMuted)
            }
            .buttonStyle(.plain)

            priorityDot(task.priority)
                .opacity(task.isCompleted ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? PlayerTheme.textMuted : PlayerTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                if let due = task.dueDate {
                    Text("DEADLINE \(due.formatted(date: .abbreviated, time: .omitted).uppercased())\(task.isCompleted ? " · CLEARED\(removalHint(task))" : "")")
                        .font(.system(size: 10))
                        .foregroundStyle(isPastDue(due) && !task.isCompleted ? PlayerTheme.danger : PlayerTheme.textMuted)
                } else {
                    Text(task.isCompleted ? "NO DEADLINE · CLEARED\(removalHint(task))" : "NO DEADLINE")
                        .font(.system(size: 10))
                        .foregroundStyle(PlayerTheme.textMuted)
                }
            }

            Spacer()

            if let canvasURL = task.canvasURL {
                Button {
                    openURL(canvasURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                        Text("CANVAS")
                    }
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(PlayerTheme.cyan)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .overlay(Rectangle().strokeBorder(PlayerTheme.cyan.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                // A plain Button already consumes its own tap without
                // triggering the row's onTapGesture (same as the
                // completion checkbox above) -- opening the assignment
                // never also opens the edit sheet or completes the quest.
            }
        }
        .padding(12)
        .opacity(task.isCompleted ? 0.55 : 1)
        .hudPanel()
    }

    private func priorityDot(_ priority: TaskPriority) -> some View {
        Circle()
            .fill(priority.color)
            .frame(width: 8, height: 8)
    }

    private func isPastDue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

#Preview {
    NavigationStack { TasksView() }
}
