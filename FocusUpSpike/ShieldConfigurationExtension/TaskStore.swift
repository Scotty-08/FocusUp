import Foundation

/// A user-created focus task. Multiple can exist; one is "active" at a
/// time -- the active task's title is what gets shown on the block
/// screen and what gets checked off when the user taps "I finished it".
struct FocusTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
}

/// Shared (App Group) task list + which one is "active" for shielding.
/// Written from three different processes today: the main app (add/
/// edit/choose), and the ShieldActionExtension (marks the active task
/// done when the user taps "I finished it" on the block screen).
enum TaskStore {
    private static let tasksKey = "focusUp.tasks"
    private static let activeTaskKey = "focusUp.activeTaskID"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    static func loadTasks() -> [FocusTask] {
        guard let data = defaults?.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([FocusTask].self, from: data) else {
            return []
        }
        return tasks
    }

    static func saveTasks(_ tasks: [FocusTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults?.set(data, forKey: tasksKey)
    }

    static var activeTaskID: UUID? {
        get {
            guard let s = defaults?.string(forKey: activeTaskKey) else { return nil }
            return UUID(uuidString: s)
        }
        set {
            if let newValue {
                defaults?.set(newValue.uuidString, forKey: activeTaskKey)
            } else {
                defaults?.removeObject(forKey: activeTaskKey)
            }
        }
    }

    static var activeTask: FocusTask? {
        guard let id = activeTaskID else { return nil }
        return loadTasks().first { $0.id == id }
    }

    /// Called from the ShieldActionExtension when the user taps
    /// "I finished it". The extension can't open FocusUp directly to let
    /// the user check the task off themselves (Apple blocks that from
    /// this extension type), so this checks it off on their behalf --
    /// it's waiting done, already checked, the next time they open the
    /// app rather than requiring a second step.
    static func markActiveTaskCompleted() {
        guard let id = activeTaskID else { return }
        var tasks = loadTasks()
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isCompleted = true
        saveTasks(tasks)
    }
}
