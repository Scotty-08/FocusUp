import Foundation

/// Simple 3-tier priority, ordered so `.high > .medium > .low` via raw
/// value for sorting.
enum TaskPriority: Int, Codable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

/// A user-created focus quest. dueDate is optional ("none" is a valid
/// choice); priority always has a value (defaulting to medium). Both
/// drive the Quest Log's display order AND the active-quest auto-pick
/// below.
struct FocusTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var priority: TaskPriority = .medium
}

/// Shared (App Group) quest list + which one is "active" -- Codex's
/// original single-active-quest concept, restored on top of the
/// priority-aware UI built this session (it's a Quest Log display/
/// organization feature now, not a shield-driving one: every group's
/// shield still shows the WHOLE quest list regardless of which one is
/// marked active here, see ShieldConfigurationExtension).
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

    /// Picks which incomplete quest should be active: highest priority
    /// first, then (within that priority tier) earliest due date: tasks
    /// due on the same calendar day are tied and one is picked at
    /// random (no other signal to break the tie with -- priority
    /// already didn't distinguish them, and neither does the date).
    /// Undated tasks within a priority tier are least urgent: only
    /// picked once every dated task at that tier is done, and among
    /// those, in the order they were added. Returns nil when nothing
    /// incomplete is left.
    static func autoPickNextTask(from tasks: [FocusTask]) -> FocusTask? {
        let incomplete = tasks.filter { !$0.isCompleted }
        guard let highestPriority = incomplete.map(\.priority).max() else { return nil }
        let topTier = incomplete.filter { $0.priority == highestPriority }

        let dated = topTier.filter { $0.dueDate != nil }
        if !dated.isEmpty {
            let calendar = Calendar.current
            let earliestDay = dated
                .map { calendar.startOfDay(for: $0.dueDate!) }
                .min()!
            let tied = dated.filter { calendar.startOfDay(for: $0.dueDate!) == earliestDay }
            return tied.randomElement()
        }

        return topTier.first
    }

    /// Auto-advances the active task to whatever autoPickNextTask picks.
    /// This is the "no manual pick" path; an explicit override from the
    /// Quest Log goes straight through the activeTaskID setter instead
    /// and is left alone here.
    @discardableResult
    static func advanceActiveTask(using tasks: [FocusTask]) -> UUID? {
        let next = autoPickNextTask(from: tasks)?.id
        activeTaskID = next
        return next
    }
}
