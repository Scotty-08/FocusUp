import Foundation
import FamilyControls
import ManagedSettings

/// A user-created focus task. Multiple can exist; one is "active" at a
/// time -- the active task's title is what gets shown on the block
/// screen and what gets checked off when the user taps "I finished it".
///
/// dueDate is optional ("none" is a valid choice). When set, it drives
/// auto-ordering (see TaskStore.autoPickNextTask): tasks with a due date
/// are always picked before ones without, earliest date first.
struct FocusTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
}

/// Shared (App Group) task list + which one is "active" for shielding.
/// Written from three different processes today: the main app (add/
/// edit/choose), and the ShieldActionExtension (marks the active task
/// done, and auto-advances to the next one, when the user taps
/// "I finished it" on the block screen).
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

    /// Picks which incomplete task should be active, by due date:
    /// earliest due date wins. Tasks due on the same calendar day are
    /// tied and one is picked at random (Scott's call -- no other signal
    /// to break the tie with). Tasks with no due date are treated as
    /// least urgent: they're only picked once every dated task is done,
    /// and among those, in the order they were added. Returns nil when
    /// nothing incomplete is left.
    static func autoPickNextTask(from tasks: [FocusTask]) -> FocusTask? {
        let incomplete = tasks.filter { !$0.isCompleted }
        guard !incomplete.isEmpty else { return nil }

        let dated = incomplete.filter { $0.dueDate != nil }
        if !dated.isEmpty {
            let calendar = Calendar.current
            let earliestDay = dated
                .map { calendar.startOfDay(for: $0.dueDate!) }
                .min()!
            let tied = dated.filter { calendar.startOfDay(for: $0.dueDate!) == earliestDay }
            return tied.randomElement()
        }

        return incomplete.first
    }

    /// Auto-advances the active task to whatever autoPickNextTask picks.
    /// This is the "no manual pick" path; an explicit override from the
    /// Tasks list goes straight through the activeTaskID setter instead
    /// and is left alone here. (Before groups existed, this also kept a
    /// single global shield's goal text in sync -- that's now each
    /// group's own responsibility, since a group's linked task and the
    /// due-date-auto-picked "active" task are independent concepts.)
    @discardableResult
    static func advanceActiveTask(using tasks: [FocusTask]) -> UUID? {
        let next = autoPickNextTask(from: tasks)?.id
        activeTaskID = next
        return next
    }

    /// Marks a SPECIFIC task complete, regardless of whether it's the
    /// globally "active" one shown on the Tasks tab -- a group's linked
    /// task can be any task, not just the auto-picked active one. Only
    /// auto-advances the active task if the completed one happened to be
    /// it.
    static func markTaskCompleted(id: UUID) {
        var tasks = loadTasks()
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isCompleted = true
        saveTasks(tasks)
        if activeTaskID == id {
            advanceActiveTask(using: tasks)
        }
    }
}
