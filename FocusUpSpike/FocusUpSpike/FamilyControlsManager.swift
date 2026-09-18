import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import Combine

/// Owns the one fixed ManagedSettingsStore identity for this spike.
/// Do NOT rename `storeName` later — a renamed store orphans any shields
/// already applied under the old name (see REVIEW.md, "fixed store identity").
@MainActor
final class FamilyControlsManager: ObservableObject {
    static let shared = FamilyControlsManager()

    static let storeName = ManagedSettingsStore.Name("com.scottgray.FocusUpSpike.mainStore")

    private let store = ManagedSettingsStore(named: FamilyControlsManager.storeName)
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selection = FamilyActivitySelection()
    // isShielded reflects what we last ASKED the system to do, not confirmed
    // enforcement. Per REVIEW.md: "store assignments alone are not proof of
    // enforcement" -- actually tapping the app on-device is the real check.
    @Published var isShielded = false
    @Published var lastError: String?
    @Published var completedCount: Int = 0
    @Published var ignoreCount: Int = 0
    @Published var currentStreak: Int = 0
    @Published var justCompletedStreak: Int?
    @Published var justClearedQuestTitle: String?
    @Published var checkInIntervalSeconds: Int = 1800
    @Published var isPeriodicCheckInActive = false
    @Published var tasks: [FocusTask] = []
    @Published var activeTaskID: UUID?
    private var lastKnownCompletedCount: Int = 0

    var activeTask: FocusTask? {
        guard let id = activeTaskID else { return nil }
        return tasks.first { $0.id == id }
    }

    private init() {
        authorizationStatus = center.authorizationStatus
        loadSelection()
        lastKnownCompletedCount = StatsStore.completedCount
        refreshTasks()
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = center.authorizationStatus
            lastError = nil
        } catch {
            lastError = "Authorization failed: \(error.localizedDescription)"
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = center.authorizationStatus
    }

    /// So the "I finished it" shield button can notify its way back into
    /// the app (extensions can't open the host app directly -- see
    /// ShieldActionExtension). Safe to call repeatedly; the system only
    /// prompts once.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func refreshStats() {
        let newCompleted = StatsStore.completedCount
        let newStreak = StatsStore.currentStreak
        if newCompleted > lastKnownCompletedCount {
            justCompletedStreak = newStreak
            justClearedQuestTitle = StatsStore.lastClearedQuestTitle
        }
        lastKnownCompletedCount = newCompleted
        completedCount = newCompleted
        ignoreCount = StatsStore.ignoreCount
        currentStreak = newStreak
    }

    func dismissStreakAnimation() {
        justCompletedStreak = nil
        justClearedQuestTitle = nil
    }

    // MARK: - Tasks

    /// Re-reads tasks from the shared App Group store. Needed because the
    /// ShieldActionExtension (a separate process) can check off the
    /// active task on its own -- call this whenever the app becomes
    /// active so a completion made from the block screen shows up here.
    func refreshTasks() {
        tasks = TaskStore.loadTasks()
        activeTaskID = TaskStore.activeTaskID
        // Covers first launch (nothing picked yet) and the case where
        // every task got deleted/finished and new ones were added
        // elsewhere -- always leave SOME task active if one exists.
        if activeTaskID == nil {
            activeTaskID = TaskStore.advanceActiveTask(using: tasks)
        }
    }

    /// dueDate is optional -- "none" is a valid, explicit choice, and
    /// undated tasks are treated as least urgent by the auto-picker.
    func addTask(title: String, dueDate: Date? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = tasks
        let newTask = FocusTask(title: trimmed, dueDate: dueDate)
        updated.append(newTask)
        tasks = updated
        TaskStore.saveTasks(updated)
        // Only auto-pick when nothing is active yet -- an already-active
        // task (auto-picked or manually overridden) stays put until it's
        // completed, even if this new task is due sooner.
        if activeTaskID == nil {
            activeTaskID = TaskStore.advanceActiveTask(using: updated)
        }
    }

    func deleteTasks(at offsets: IndexSet) {
        let removedIDs = offsets.map { tasks[$0].id }
        let updated = tasks.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map { $0.element }
        tasks = updated
        TaskStore.saveTasks(updated)
        if let activeTaskID, removedIDs.contains(activeTaskID) {
            self.activeTaskID = TaskStore.advanceActiveTask(using: updated)
        }
    }

    /// Checking off the currently-active task from here (not the shield)
    /// auto-advances the same way the shield's "I finished it" does, so
    /// the two paths behave identically.
    func toggleTaskCompletion(_ task: FocusTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        TaskStore.saveTasks(tasks)
        if tasks[idx].isCompleted && activeTaskID == task.id {
            activeTaskID = TaskStore.advanceActiveTask(using: tasks)
        }
    }

    /// Manual override: picking a task here always wins over the
    /// due-date auto-pick, immediately, and it stays active until it's
    /// completed -- after that, picking goes back to due-date order.
    func setActiveTask(_ id: UUID?) {
        activeTaskID = id
        TaskStore.activeTaskID = id
        TaskStore.syncShieldGoalTextToActiveTask()
    }

    // MARK: - Shield

    /// Applying the shield also starts the periodic check-in loop using
    /// whatever interval is currently configured -- per Scott, these
    /// shouldn't be two separate actions the user has to remember to hit.
    func applyShield() {
        guard !selection.applicationTokens.isEmpty else {
            lastError = "Select at least one app first."
            return
        }
        let text = activeTask?.title ?? "Finish your focus task in FocusUp to unlock this app."
        GoalStore.setGoal(text, for: selection.applicationTokens)
        store.shield.applications = selection.applicationTokens
        isShielded = true
        lastError = nil
        startPeriodicCheckIns()
    }

    func clearShield() {
        store.shield.applications = nil
        isShielded = false
        stopPeriodicCheckIns()
    }

    func saveSelection() {
        SelectionStore.save(selection)
    }

    private func loadSelection() {
        guard let saved = SelectionStore.load() else { return }
        selection = saved
    }

    // MARK: - Periodic check-ins

    /// Registers a stack of cumulative-usage thresholds (see
    /// FocusUpActivity) so the DeviceActivityMonitor extension re-shows
    /// the block screen roughly every `checkInIntervalSeconds` of actual
    /// use of the selected app(s), even mid-session. New today --
    /// reliability needs on-device verification.
    func startPeriodicCheckIns() {
        guard !selection.applicationTokens.isEmpty else {
            lastError = "Select at least one app first."
            return
        }
        SelectionStore.save(selection)

        let marks = FocusUpActivity.marks(intervalSeconds: checkInIntervalSeconds)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for mark in marks {
            events[FocusUpActivity.eventName(forMark: mark)] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: FocusUpActivity.components(forSeconds: mark)
            )
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        activityCenter.stopMonitoring([FocusUpActivity.name])
        do {
            try activityCenter.startMonitoring(FocusUpActivity.name, during: schedule, events: events)
            isPeriodicCheckInActive = true
            lastError = nil
        } catch {
            isPeriodicCheckInActive = false
            lastError = "Couldn't start check-ins: \(error.localizedDescription)"
        }
    }

    func stopPeriodicCheckIns() {
        activityCenter.stopMonitoring([FocusUpActivity.name])
        isPeriodicCheckInActive = false
    }
}
