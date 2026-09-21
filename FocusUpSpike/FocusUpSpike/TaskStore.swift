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

/// A user-created focus quest. All quests are equally "active" -- there
/// is no single scarce "the active one" anymore (that concept predates
/// Groups, back when one quest's title drove the one global shield;
/// every group now shows the whole quest list instead, see
/// ShieldConfigurationExtension). dueDate and priority are both
/// optional-ish (priority always has a value, defaulting to medium;
/// dueDate is genuinely optional, "none" is a valid choice) and are
/// purely for the Quests tab's own display/sort order now, not for
/// picking anything.
struct FocusTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var priority: TaskPriority = .medium

    /// Set only for a quest imported from a Canvas assignment (nil for
    /// anything the user typed in themselves). This is Canvas's own
    /// `html_url` for the assignment -- already the right domain for
    /// whichever school's Canvas the quest came from, so opening it
    /// works the same for every Canvas instance, not just one school.
    /// Deliberately NOT touched by completing the quest (see
    /// FamilyControlsManager.toggleTaskCompletion) -- "Open in Canvas"
    /// is a separate action so checking a quest off in FocusUp never
    /// surprises someone by also leaving the app.
    var canvasURL: URL?

    /// Canvas's own id for the assignment this quest came from (nil for
    /// a quest the user typed in themselves). This, not the title or
    /// URL, is what CanvasClient.mergeCanvasAssignments matches on when
    /// re-syncing, so re-running a sync updates the existing quest in
    /// place instead of creating a duplicate.
    var canvasAssignmentID: Int?
}

/// Shared (App Group) quest list -- written from the main app (add/
/// edit/complete) and, indirectly, nowhere else now: shields no longer
/// complete a specific quest on their own (see ShieldActionExtension),
/// so this is main-app-only despite still living in the shared App
/// Group container (kept there so a future extension could read it, and
/// because it's duplicated alongside GoalStore/GroupStore which do need
/// cross-process access).
enum TaskStore {
    private static let tasksKey = "focusUp.tasks"

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

    /// Picks the single most pressing incomplete quest: highest priority
    /// first, then (within that tier) earliest due date -- same-day ties
    /// broken randomly (no other signal to break them with). Undated
    /// quests within a tier are least urgent, picked only once every
    /// dated quest at that tier is done, in the order they were added.
    /// Returns nil when nothing incomplete is left.
    ///
    /// Purely computed on demand, never persisted as a standing "active"
    /// pick. The Quest Log treats every quest as equally active (see
    /// FocusTask's doc comment); this only names the one quest the
    /// shield and the shield-return check-in prompt should show.
    static func mostPressingTask(from tasks: [FocusTask]) -> FocusTask? {
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
}
