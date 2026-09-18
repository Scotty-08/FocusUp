import SwiftUI

struct TasksView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @State private var newTaskTitle = ""
    @State private var hasDueDate = false
    @State private var newTaskDueDate = Date()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Add a task, e.g. Apply to 3 internships", text: $newTaskTitle)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(white: 0.15))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            manager.addTask(title: newTaskTitle, dueDate: hasDueDate ? newTaskDueDate : nil)
                            newTaskTitle = ""
                            hasDueDate = false
                            newTaskDueDate = Date()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .foregroundStyle(.blue)
                    }

                    HStack(spacing: 12) {
                        Toggle("Due date", isOn: $hasDueDate.animation())
                            .toggleStyle(.switch)
                            .tint(.orange)
                            .foregroundStyle(.gray)
                            .font(.footnote)
                            .fixedSize()

                        if hasDueDate {
                            DatePicker("", selection: $newTaskDueDate, displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                        } else {
                            Text("None — treated as least urgent")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }

                        Spacer()
                    }
                }
                .padding()

                if manager.tasks.isEmpty {
                    Spacer()
                    Text("No tasks yet. Add one above.")
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(manager.tasks) { task in
                            HStack {
                                Button {
                                    manager.toggleTaskCompletion(task)
                                } label: {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompleted ? .green : .gray)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .foregroundStyle(.white)
                                        .strikethrough(task.isCompleted)
                                    if let due = task.dueDate {
                                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption2)
                                            .foregroundStyle(isPastDue(due) && !task.isCompleted ? .red : .gray)
                                    } else {
                                        Text("No due date")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                    if manager.activeTaskID == task.id {
                                        Text("Active — shown on the block screen")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                Button {
                                    manager.setActiveTask(task.id)
                                } label: {
                                    Text(manager.activeTaskID == task.id ? "Active" : "Set Active")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(manager.activeTaskID == task.id ? Color.orange : Color(white: 0.2))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(Color(white: 0.1))
                        }
                        .onDelete { offsets in
                            manager.deleteTasks(at: offsets)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }

                Text("Tasks are auto-ordered by due date -- earliest first, same-day ties broken randomly, no date = least urgent. Whatever task is active stays active until it's finished, even if something else becomes due sooner. Tap \"Set Active\" to override which one comes first.")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .padding()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.refreshTasks()
        }
    }

    private func isPastDue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

#Preview {
    NavigationStack { TasksView() }
}
