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

    /// Auto-advances the active task to whatever autoPickNextTask picks
    /// and keeps the block screen's goal text in sync (in case a shield
    /// is already up -- otherwise the NEXT block screen would still show
    /// the task that just got finished). This is the "no manual pick"
    /// path; an explicit override from the Tasks list goes straight
    /// through the activeTaskID setter instead and is left alone here.
    @discardableResult
    static func advanceActiveTask(using tasks: [FocusTask]) -> UUID? {
        let next = autoPickNextTask(from: tasks)?.id
        activeTaskID = next
        syncShieldGoalTextToActiveTask()
        return next
    }

    /// Re-points the goal text shown on the block screen at whichever
    /// task is active right now, for whatever app(s) are currently
    /// selected. Safe to call even when nothing is selected/shielded --
    /// it's just a no-op then.
    static func syncShieldGoalTextToActiveTask() {
        guard let selection = SelectionStore.load(), !selection.applicationTokens.isEmpty else { return }
        let text = activeTask?.title ?? "Finish your focus task in FocusUp to unlock this app."
        GoalStore.setGoal(text, for: selection.applicationTokens)
    }

    /// Called from the ShieldActionExtension when the user taps
    /// "I finished it". The extension can't open FocusUp directly to let
    /// the user check the task off themselves (Apple blocks that from
    /// this extension type), so this checks it off on their behalf, then
    /// auto-advances to whichever task is next by due date so the very
    /// next block screen already shows the right thing.
    static func markActiveTaskCompleted() {
        guard let id = activeTaskID else { return }
        var tasks = loadTasks()
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isCompleted = true
        saveTasks(tasks)
        advanceActiveTask(using: tasks)
    }
}
