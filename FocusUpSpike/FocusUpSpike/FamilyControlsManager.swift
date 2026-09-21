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
    @Published var tasks: [FocusTask] = []
    /// Non-nil while the shield-return "did you finish this?" prompt
    /// should be showing (see presentPressingQuestCheckIn/
    /// resolvePressingQuestPrompt and ContentView's overlay).
    @Published var pressingQuestPrompt: FocusTask?
    private var lastKnownCompletedCount: Int = 0

    private init() {
        authorizationStatus = center.authorizationStatus
        lastKnownCompletedCount = StatsStore.completedCount
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
        updateFocusActivity()
    }

    func dismissStreakAnimation() {
        justCompletedStreak = nil
        justClearedQuestTitle = nil
    }

    /// Call when the user returns to FocusUp specifically because they
    /// tapped a shield's "Open Quests" button (see ContentView's
    /// QuestRoute.consume() branch) -- NOT on every ordinary launch or
    /// foreground, so this only shows right after that specific
    /// interaction, not every time the app opens. Names the single most
    /// pressing incomplete quest (TaskStore.mostPressingTask: highest
    /// priority, then earliest deadline) and surfaces it via
    /// pressingQuestPrompt; ContentView's overlay shows
    /// MostPressingQuestView for it. No-ops (leaves the prompt nil) if
    /// there's nothing incomplete.
    func presentPressingQuestCheckIn() {
        refreshTasks()
        pressingQuestPrompt = TaskStore.mostPressingTask(from: tasks)
    }

    /// completed: true routes through the same toggleTaskCompletion path
    /// as checking a quest off in the Quest Log (stats, streak, and
    /// releasing Block groups all follow from that); false just dismisses
    /// the prompt without touching the quest.
    func resolvePressingQuestPrompt(completed: Bool) {
        guard let task = pressingQuestPrompt else { return }
        if completed {
            toggleTaskCompletion(task)
        }
        pressingQuestPrompt = nil
    }

    // MARK: - Tasks

    /// Re-reads tasks from the shared App Group store -- call whenever
    /// the app becomes active, in case anything changed while it wasn't
    /// in the foreground.
    func refreshTasks() {
        tasks = TaskStore.loadTasks()
    }

    func addTask(title: String, dueDate: Date? = nil, priority: TaskPriority = .medium) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = tasks
        updated.append(FocusTask(title: trimmed, dueDate: dueDate, priority: priority))
        tasks = updated
        TaskStore.saveTasks(updated)
    }

    /// Edits an existing quest's title/deadline/priority in place. Does
    /// NOT touch isCompleted -- that's toggleTaskCompletion's job, kept
    /// separate so editing a quest's details never accidentally
    /// completes or reopens it.
    func updateTask(_ task: FocusTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        TaskStore.saveTasks(tasks)
    }

    /// Takes explicit ids rather than an IndexSet -- TasksView sorts
    /// quests for display (priority, then deadline), so a swipe-to-delete
    /// offset from that sorted list would NOT map to the right item in
    /// `tasks`' own storage order. Deleting by id sidesteps that
    /// entirely, correct regardless of how the caller is displaying them.
    func deleteTasks(withIDs ids: [UUID]) {
        let idSet = Set(ids)
        let updated = tasks.filter { !idSet.contains($0.id) }
        tasks = updated
        TaskStore.saveTasks(updated)
    }

    /// Releases every Block-rule group, not just ones "about" this task
    /// -- there's no per-group link anymore, so completing ANY quest is
    /// what unlocks blocking, uniformly. See
    /// GroupStore.unshieldAllBlockGroups's doc comment for why this is
    /// an event, not a "quest list is empty" state check, and why that
    /// distinction is what keeps blocking meaningful with zero quests.
    func toggleTaskCompletion(_ task: FocusTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        TaskStore.saveTasks(tasks)
        if tasks[idx].isCompleted {
            StatsStore.recordCompleted(questTitle: task.title)
            refreshStats()
            GroupStore.unshieldAllBlockGroups()
            refreshGroups()
        }
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

    func createGroup(name: String, selection: FamilyActivitySelection, rule: GroupRule) {
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
        let group = AppGroup(name: trimmed, selection: selection, rule: rule)
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

    private func activateBlock(_ group: AppGroup) {
        GroupRuntimeState.setShieldReason(.block, for: group.id)
        ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id)).shield.applications = group.selection.applicationTokens
        lastError = nil
    }

    /// Limit-rule groups never lock you out just for existing -- the ONE
    /// real lockout is a daily budget, if one is set, being used up
    /// (that's an actual ManagedSettings shield the user can't dismiss,
    /// per "when you reach your daily limit it should block the app").
    /// Otherwise "limiting" means a dismissable interruption shield, via
    /// the SAME cumulative-usage-threshold mechanism either way --
    /// interruptOnOpen just forces the shortest interval (1 minute)
    /// instead of the user's chosen reminderIntervalMinutes. Both modes
    /// MUST release the token on dismiss (see ShieldActionExtension) --
    /// device-tested: leaving it shielded and returning
    /// ShieldActionResponse.none does NOT grant even momentary access,
    /// it just re-shows the shield with no way out. An earlier version
    /// of interruptOnOpen tried exactly that (permanently shielded,
    /// never released) on the theory that .none would let each attempt
    /// through -- confirmed wrong on-device, app became completely
    /// unreachable. There is no "let this one attempt through" signal in
    /// this API, so "shown on every single open" isn't literally
    /// achievable; the shortest-interval reminder is the honest
    /// approximation.
    /// Free-access windows suspend the reminder and budget tracking
    /// alike while they're active. See GroupIdentity (GroupStore.swift)
    /// for the DeviceActivityName scheme this depends on. Built only from
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

        let dayStart = DateComponents(hour: 0, minute: 0, second: 0)
        let dayEnd = DateComponents(hour: 23, minute: 59, second: 59)
        let sortedWindows = group.rule.windows
            .prefix(GroupRule.maxWindows)
            .sorted { ($0.startHour, $0.startMinute) < ($1.startHour, $1.startMinute) }

        // Always starts accessible -- device-tested (see git history):
        // leaving a token permanently shielded and relying on
        // ShieldActionResponse.none to grant "just this one attempt"
        // through does NOT work. .none with the token still present just
        // re-shows the shield -- there is no "let this one attempt
        // through" signal in this API, only "release the token" or
        // "don't." interruptOnOpen used to start pre-shielded on that
        // false assumption; see the reminder-registration comment below
        // for how it's actually built now.
        let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
        store.shield.applications = nil
        GroupRuntimeState.setShieldReason(nil, for: group.id)

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

        // Periodic reminder cadence -- unconditional for every Limit
        // group now (see this function's doc comment for why
        // interruptOnOpen no longer skips it): interruptOnOpen just
        // forces the shortest possible interval (1 minute -- the
        // numberField's own floor) instead of the user-chosen one, since
        // this proven cumulative-threshold mechanism is the only thing
        // that actually re-shields correctly on release. It's an honest
        // "checks in about as often as the platform allows," not a
        // literal "every single open" -- that promise can't be kept with
        // this API. Copy is built in ShieldConfigurationExtension: the
        // full open-quest list if there is one, otherwise a "why am I
        // checking this?" reflection prompt -- either way a dismissable
        // nudge, never a lock.
        let effectiveReminderMinutes = group.rule.interruptOnOpen ? 1 : group.rule.reminderIntervalMinutes
        // GroupActivityMarks.marks' default maxCount (30) was sized for
        // this codebase's original single check-in feature, where
        // intervals were tens of minutes -- at interruptOnOpen's forced
        // 1-minute interval, 30 marks would only cover 30 minutes of
        // cumulative daily use before silently going quiet for the rest
        // of the day (no threshold left registered to fire). Scaled up
        // here so interruptOnOpen keeps covering roughly the same total
        // daily use (~1 hour) a normal reminder interval already does.
        // Still a bounded, finite registration count, not "hundreds" --
        // but same caveat as the 30 default before it: Apple's actual
        // per-activity event ceiling isn't documented anywhere this
        // codebase has found, so watch for reminders drying out after an
        // hour of continuous use during rehearsal.
        let markCap = group.rule.interruptOnOpen ? 60 : 30
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for mark in GroupActivityMarks.marks(intervalMinutes: effectiveReminderMinutes, maxCount: markCap) {
            events[GroupIdentity.eventName(groupID: group.id, kind: "reminder", mark: mark)] =
                DeviceActivityEvent(applications: tokens, threshold: GroupActivityMarks.components(forMinutes: mark))
        }
        registerActivity(
            GroupIdentity.reminderActivityName(for: group.id),
            schedule: DeviceActivitySchedule(intervalStart: dayStart, intervalEnd: dayEnd, repeats: true),
            events: events
        )

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
                rule: GroupRule(kind: .block)
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
    /// a user-facing error. Shows the open-quest count + streak, not any
    /// particular group's or quest's state -- there's no single "active"
    /// quest anymore (every quest is equally active, see TaskStore) and
    /// representing N simultaneous groups here is out of scope for this
    /// pass, so a count is the honest summary rather than picking one.
    private func startFocusActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endFocusActivity()
        let attributes = FocusUpActivityAttributes(startedAt: Date())
        let state = FocusUpActivityAttributes.ContentState(questTitle: openQuestSummary, streak: currentStreak)
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
        let state = FocusUpActivityAttributes.ContentState(questTitle: openQuestSummary, streak: currentStreak)
        Task { await focusActivity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private var openQuestSummary: String? {
        let count = tasks.filter { !$0.isCompleted }.count
        guard count > 0 else { return nil }
        return count == 1 ? "1 quest open" : "\(count) quests open"
    }

    private func endFocusActivity() {
        guard let focusActivity else { return }
        Task { await focusActivity.end(nil, dismissalPolicy: .immediate) }
        self.focusActivity = nil
    }
}
