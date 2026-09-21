import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import Combine
import UIKit
import ActivityKit

/// Owns every AppGroup's enforcement. Each group gets its own
/// ManagedSettingsStore (see GroupIdentity in GroupStore.swift) so a
/// Block group and a Limit group -- or several of either -- can be
/// independently active at the same time. Do NOT derive a group's
/// store/activity names from anything but its `id` (see GroupIdentity's
/// doc comment); the legacy single fixed store this app used before
/// groups existed is kept only long enough to migrate off of it, see
/// runLegacyMigrationIfNeeded below.
@MainActor
final class FamilyControlsManager: ObservableObject {
    static let shared = FamilyControlsManager()

    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    /// The Dynamic Island / Lock Screen Live Activity for the current
    /// focus session, if one is running -- tracks "at least one group
    /// exists," not any single group's state (Live Activity content
    /// isn't per-group yet, see startFocusActivity below).
    private var focusActivity: Activity<FocusUpActivityAttributes>?

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var groups: [AppGroup] = []
    @Published var lastError: String?
    @Published var completedCount: Int = 0
    @Published var ignoreCount: Int = 0
    @Published var currentStreak: Int = 0
    @Published var justCompletedStreak: Int?
    @Published var justClearedQuestTitle: String?
    @Published var justCheckedIn = false
    @Published var tasks: [FocusTask] = []
    @Published var activeTaskID: UUID?
    private var lastKnownCompletedCount: Int = 0
    private var lastKnownCheckInCount: Int = 0

    var activeTask: FocusTask? {
        guard let id = activeTaskID else { return nil }
        return tasks.first { $0.id == id }
    }

    private init() {
        authorizationStatus = center.authorizationStatus
        lastKnownCompletedCount = StatsStore.completedCount
        lastKnownCheckInCount = StatsStore.checkInCount
        refreshTasks()
        runLegacyMigrationIfNeeded()
        refreshGroups()
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

    /// So a shield's own buttons can notify their way back into the app
    /// (extensions can't open the host app directly). Safe to call
    /// repeatedly; the system only prompts once.
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

        // Same "compare against last-seen count" pattern as the streak
        // check above, but deliberately never fires alongside it --
        // ContentView only shows the check-in screen when a quest
        // wasn't ALSO just cleared, so the two custom screens never
        // stack on top of each other.
        let newCheckInCount = StatsStore.checkInCount
        if newCheckInCount > lastKnownCheckInCount && justCompletedStreak == nil {
            justCheckedIn = true
        }
        lastKnownCheckInCount = newCheckInCount
        updateFocusActivity()
    }

    func dismissStreakAnimation() {
        justCompletedStreak = nil
        justClearedQuestTitle = nil
    }

    func dismissCheckIn() {
        justCheckedIn = false
    }

    // MARK: - Tasks

    /// Re-reads tasks from the shared App Group store. Needed because
    /// ShieldActionExtension (a separate process) can complete tasks on
    /// its own -- call this whenever the app becomes active.
    func refreshTasks() {
        tasks = TaskStore.loadTasks()
        activeTaskID = TaskStore.activeTaskID
        if activeTaskID == nil {
            activeTaskID = TaskStore.advanceActiveTask(using: tasks)
        }
    }

    func addTask(title: String, dueDate: Date? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = tasks
        let newTask = FocusTask(title: trimmed, dueDate: dueDate)
        updated.append(newTask)
        tasks = updated
        TaskStore.saveTasks(updated)
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
        for id in removedIDs {
            GroupStore.unlinkGroups(fromDeletedTask: id)
        }
        if let activeTaskID, removedIDs.contains(activeTaskID) {
            self.activeTaskID = TaskStore.advanceActiveTask(using: updated)
        }
        refreshGroups()
    }

    /// Checking off a task from here (not a shield) releases every
    /// Block-rule group linked to it too, same as tapping a Block
    /// shield's primary button does from ShieldActionExtension.
    func toggleTaskCompletion(_ task: FocusTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        TaskStore.saveTasks(tasks)
        if tasks[idx].isCompleted {
            GroupStore.unshieldGroups(linkedToCompletedTask: task.id)
            refreshGroups()
        }
        if tasks[idx].isCompleted && activeTaskID == task.id {
            activeTaskID = TaskStore.advanceActiveTask(using: tasks)
        }
    }

    /// Manual override for the Tasks tab's own due-date auto-pick;
    /// unrelated to which task any given group links to.
    func setActiveTask(_ id: UUID?) {
        activeTaskID = id
        TaskStore.activeTaskID = id
    }

    // MARK: - Groups

    func refreshGroups() {
        groups = GroupStore.loadGroups()
    }

    /// True once we've asked the system to shield this group's apps --
    /// not proof of confirmed on-device enforcement, same caveat this
    /// app has always used ("store assignments alone are not proof of
    /// enforcement," see REVIEW.md). For a Limit-rule group this is only
    /// true while a reminder/lockout shield happens to be up; most of
    /// the time a Limit group is correctly "not enforced" (accessible).
    func isEnforced(_ group: AppGroup) -> Bool {
        ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id)).shield.applications?.isEmpty == false
    }

    func createGroup(name: String, selection: FamilyActivitySelection, rule: GroupRule, taskID: UUID?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Give the group a name."
            return
        }
        guard !selection.applicationTokens.isEmpty else {
            lastError = "Select at least one app."
            return
        }
        let wasEmpty = groups.isEmpty
        let group = AppGroup(name: trimmed, selection: selection, rule: rule, taskID: taskID)
        var updated = groups
        updated.append(group)
        groups = updated
        GroupStore.saveGroups(updated)
        activate(group)
        if wasEmpty { startFocusActivity() }
    }

    func updateGroup(_ updated: AppGroup) {
        guard let existing = GroupStore.group(for: updated.id) else { return }
        deactivate(existing)
        var all = groups
        if let idx = all.firstIndex(where: { $0.id == updated.id }) {
            all[idx] = updated
        }
        groups = all
        GroupStore.saveGroups(all)
        activate(updated)
    }

    func deleteGroup(_ id: UUID) {
        guard let group = GroupStore.group(for: id) else { return }
        deactivate(group)
        let updated = groups.filter { $0.id != id }
        groups = updated
        GroupStore.saveGroups(updated)
        if updated.isEmpty { endFocusActivity() }
    }

    private func activate(_ group: AppGroup) {
        switch group.rule.kind {
        case .block: activateBlock(group)
        case .limit: activateLimit(group)
        }
    }

    /// Mirrors activate(_:) for both rule kinds at once -- clears the
    /// group's store and stops every possible DeviceActivityName up to
    /// the maxWindows ceiling (stopMonitoring on a name that was never
    /// registered is a no-op, same defensive pattern the old
    /// single-activity code already used), regardless of how many
    /// windows the group's CURRENT rule actually has -- so switching a
    /// group's rule kind on edit, or shrinking its window count, or
    /// deleting it, can never leave a higher-indexed registration
    /// stranded from a previous configuration.
    private func deactivate(_ group: AppGroup) {
        ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id)).clearAllSettings()
        var names: [DeviceActivityName] = [GroupIdentity.reminderActivityName(for: group.id)]
        for i in 0...GroupRule.maxWindows {
            names.append(GroupIdentity.budgetActivityName(for: group.id, segment: i))
        }
        for i in 0..<GroupRule.maxWindows {
            names.append(GroupIdentity.windowActivityName(for: group.id, index: i))
        }
        activityCenter.stopMonitoring(names)
        GroupRuntimeState.clear(group.id)
    }

    private func goalText(for group: AppGroup) -> String {
        if let taskID = group.taskID, let title = tasks.first(where: { $0.id == taskID })?.title, !title.isEmpty {
            return title
        }
        return "Finish your linked quest in FocusUp to unlock this app."
    }

    private func activateBlock(_ group: AppGroup) {
        GroupRuntimeState.setShieldReason(.block, for: group.id)
        GoalStore.setGoal(goalText(for: group), for: group.selection.applicationTokens)
        ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id)).shield.applications = group.selection.applicationTokens
        lastError = nil
    }

    /// Limit-rule groups never lock you out just for existing -- the ONE
    /// real lockout is a daily budget, if one is set, being used up
    /// (that's an actual ManagedSettings shield the user can't dismiss,
    /// per "when you reach your daily limit it should block the app").
    /// Otherwise "limiting" means a dismissable interruption shield, in
    /// one of two modes the user picks per group:
    ///   - Periodic (default): nags every reminderIntervalMinutes of use.
    ///   - interruptOnOpen: shown on every single open attempt instead,
    ///     by simply never releasing the token from the shield on
    ///     dismiss -- a ManagedSettings shield naturally reappears each
    ///     time a shielded app is (re)opened, so this needs no
    ///     DeviceActivity threshold at all.
    /// Free-access windows suspend everything above (reminders, budget
    /// tracking, and interruptOnOpen's persistent shield alike) while
    /// they're active. See GroupIdentity (GroupStore.swift) for the
    /// DeviceActivityName scheme this depends on. Built only from
    /// primitives this codebase already used once for its single global
    /// check-in (cumulative DeviceActivityEvent thresholds,
    /// intervalStart/intervalEnd boundaries) -- registering more than a
    /// handful of DeviceActivityNames for one group is new, untested
    /// territory: this app has only ever run exactly one at a time
    /// before. Needs the device spikes in the plan (several simultaneous
    /// named stores/activities, a mid-day window boundary, a realistic
    /// multi-window count) before this is trusted, not just this code
    /// existing.
    private func activateLimit(_ group: AppGroup) {
        let tokens = group.selection.applicationTokens
        GroupRuntimeState.setExceededToday(false, for: group.id)
        GoalStore.setGoal(goalText(for: group), for: tokens)

        let dayStart = DateComponents(hour: 0, minute: 0, second: 0)
        let dayEnd = DateComponents(hour: 23, minute: 59, second: 59)
        let sortedWindows = group.rule.windows
            .prefix(GroupRule.maxWindows)
            .sorted { ($0.startHour, $0.startMinute) < ($1.startHour, $1.startMinute) }

        // Initial state: interruptOnOpen groups start already shielded --
        // friction from the very first open, not waiting on a usage
        // threshold -- UNLESS "now" already falls inside one of its
        // windows, which always wins. Never released from here on except
        // by a window opening (see intervalDidStart) or the group being
        // edited/deleted; see ShieldActionExtension.handleLimit for why
        // dismissing it doesn't remove the token. Everyone else (the
        // default periodic-reminder mode) always starts accessible.
        let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
        let now = Date()
        if group.rule.interruptOnOpen && !sortedWindows.contains(where: { $0.contains(now) }) {
            store.shield.applications = tokens
            GroupRuntimeState.setShieldReason(.limitReminder, for: group.id)
        } else {
            store.shield.applications = nil
            GroupRuntimeState.setShieldReason(nil, for: group.id)
        }

        // Window boundary activities register whenever there ARE windows,
        // independent of whether a daily budget is set -- a window always
        // means "no reminders, no budget tracking, fully free" (see
        // DeviceActivityMonitorExtension's guard on reminder events, and
        // the budget segments below which are scoped to skip window
        // spans entirely).
        var cursor = dayStart
        var segmentIndex = 0
        for window in sortedWindows {
            if let dailyBudgetMinutes = group.rule.dailyBudgetMinutes {
                registerActivity(
                    GroupIdentity.budgetActivityName(for: group.id, segment: segmentIndex),
                    schedule: DeviceActivitySchedule(intervalStart: cursor, intervalEnd: window.startComponents, repeats: true),
                    events: [GroupIdentity.eventName(groupID: group.id, kind: "budget\(segmentIndex)", mark: dailyBudgetMinutes):
                        DeviceActivityEvent(applications: tokens, threshold: GroupActivityMarks.components(forMinutes: dailyBudgetMinutes))]
                )
            }
            registerActivity(
                GroupIdentity.windowActivityName(for: group.id, index: segmentIndex),
                schedule: DeviceActivitySchedule(intervalStart: window.startComponents, intervalEnd: window.endComponents, repeats: true),
                events: [:]
            )
            cursor = window.endComponents
            segmentIndex += 1
        }
        // Final (or only, if no windows) budget-tracking segment, from
        // the last window's end (or midnight) through 23:59:59. Known
        // approximation, flagged not silently assumed away: each segment
        // resets its cumulative counter independently, so with N windows
        // a user could use up to (N+1) x dailyBudgetMinutes total across
        // the day -- there's no DeviceActivity primitive to share one
        // counter across disjoint schedules.
        if let dailyBudgetMinutes = group.rule.dailyBudgetMinutes {
            registerActivity(
                GroupIdentity.budgetActivityName(for: group.id, segment: segmentIndex),
                schedule: DeviceActivitySchedule(intervalStart: cursor, intervalEnd: dayEnd, repeats: true),
                events: [GroupIdentity.eventName(groupID: group.id, kind: "budget\(segmentIndex)", mark: dailyBudgetMinutes):
                    DeviceActivityEvent(applications: tokens, threshold: GroupActivityMarks.components(forMinutes: dailyBudgetMinutes))]
            )
        }

        // Periodic reminder cadence -- skipped entirely when
        // interruptOnOpen is on, since the shield is already up
        // continuously between window boundaries in that mode; a
        // threshold on top would be redundant and just adds more
        // DeviceActivity registrations for no behavioral difference.
        // Otherwise unconditional for every Limit group. Copy adapts in
        // ShieldConfigurationExtension: the linked task's title if there
        // is one, otherwise a "why am I checking this?" reflection
        // prompt -- either way it's a dismissable nudge, never a lock.
        if !group.rule.interruptOnOpen {
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for mark in GroupActivityMarks.marks(intervalMinutes: group.rule.reminderIntervalMinutes) {
                events[GroupIdentity.eventName(groupID: group.id, kind: "reminder", mark: mark)] =
                    DeviceActivityEvent(applications: tokens, threshold: GroupActivityMarks.components(forMinutes: mark))
            }
            registerActivity(
                GroupIdentity.reminderActivityName(for: group.id),
                schedule: DeviceActivitySchedule(intervalStart: dayStart, intervalEnd: dayEnd, repeats: true),
                events: events
            )
        }

        lastError = nil
    }

    private func registerActivity(_ name: DeviceActivityName, schedule: DeviceActivitySchedule, events: [DeviceActivityEvent.Name: DeviceActivityEvent]) {
        activityCenter.stopMonitoring([name])
        do {
            try activityCenter.startMonitoring(name, during: schedule, events: events)
        } catch {
            lastError = "Couldn't start monitoring: \(error.localizedDescription)"
        }
    }

    // MARK: - Legacy migration

    /// One-time move from the single-selection/single-fixed-store model
    /// this app used before groups existed to one AppGroup. Guarded so
    /// it only ever runs once; always clears the legacy store/activity
    /// afterward (whether or not there was anything to migrate) so
    /// neither can hold an orphaned shield going forward -- see
    /// REVIEW.md §6.3 and §5.1 for why that's a real risk, not a
    /// hypothetical one.
    func runLegacyMigrationIfNeeded() {
        let flagKey = "focusUp.migratedToGroupsV1"
        let defaults = UserDefaults(suiteName: FocusUpShared.appGroupID)
        guard defaults?.bool(forKey: flagKey) != true else { return }

        if GroupStore.loadGroups().isEmpty, let legacy = SelectionStore.load(), !legacy.applicationTokens.isEmpty {
            let group = AppGroup(
                name: "My Group",
                selection: legacy,
                rule: GroupRule(kind: .block),
                taskID: TaskStore.activeTaskID
            )
            GroupStore.saveGroups([group])
            activate(group)
        }

        ManagedSettingsStore(named: FocusUpShared.storeName).clearAllSettings()
        activityCenter.stopMonitoring([FocusUpActivity.name])
        defaults?.set(true, forKey: flagKey)
    }

    // MARK: - Live Activity (Dynamic Island / Lock Screen)

    /// Starts when the first group is created, ends when the last one is
    /// deleted -- best-effort: Live Activities require the user to have
    /// them enabled and can fail to start for reasons entirely outside
    /// our control, so a failure here is silent rather than surfaced as
    /// a user-facing error. Still shows the global active task + streak,
    /// not any particular group's state -- representing N simultaneous
    /// groups here is out of scope for this pass.
    private func startFocusActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endFocusActivity()
        let attributes = FocusUpActivityAttributes(startedAt: Date())
        let state = FocusUpActivityAttributes.ContentState(questTitle: activeTask?.title, streak: currentStreak)
        do {
            focusActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            focusActivity = nil
        }
    }

    private func updateFocusActivity() {
        guard let focusActivity else { return }
        let state = FocusUpActivityAttributes.ContentState(questTitle: activeTask?.title, streak: currentStreak)
        Task { await focusActivity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func endFocusActivity() {
        guard let focusActivity else { return }
        Task { await focusActivity.end(nil, dismissalPolicy: .immediate) }
        self.focusActivity = nil
    }
}
