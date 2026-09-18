import SwiftUI

struct TasksView: View {
    @StateObject private var manager = FamilyControlsManager.shared
    @State private var newTaskTitle = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Add a task, e.g. Apply to 3 internships", text: $newTaskTitle)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(white: 0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        manager.addTask(title: newTaskTitle)
                        newTaskTitle = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(.blue)
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

                Text("Pick which task is \"Active\" to control what shows on the block screen when you Apply Shield. Only one task can be active at a time in this spike.")
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
}

#Preview {
    NavigationStack { TasksView() }
}
