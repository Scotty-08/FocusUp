import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// One user-defined window of the day during which a Limit-rule group's
/// apps are always accessible. A group can have several (see
/// GroupRule.maxWindows). What happens OUTSIDE the windows depends on
/// whether the group also has a daily budget (see GroupRule's doc
/// comment): with one, each additional window splits the rest of the
/// day into more disjoint budget-tracking segments, each with its own
/// independently-resetting cumulative counter (see activateLimit in
/// FamilyControlsManager.swift for why that's an accepted approximation,
/// not a bug, and why the window count is capped rather than unlimited);
/// without one, windows work standalone as a pure access schedule --
/// accessible only inside them, blocked outside.
struct ScheduleWindow: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    var startComponents: DateComponents { DateComponents(hour: startHour, minute: startMinute) }
    var endComponents: DateComponents { DateComponents(hour: endHour, minute: endMinute) }

    var label: String {
        let calendar = Calendar.current
        let start = calendar.date(from: startComponents) ?? Date()
        let end = calendar.date(from: endComponents) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start))\u{2013}\(formatter.string(from: end))"
    }

    /// Whether `date`'s time-of-day (ignoring the actual calendar day)
    /// falls inside this window. Used only to compute the CORRECT
    /// initial shield state at activation time, in case "now" already
    /// falls inside or outside a window before any DeviceActivity
    /// interval callback has fired -- those callbacks aren't guaranteed
    /// to fire retroactively for an interval already in progress at
    /// registration time (unverified platform behavior, see the plan).
    func contains(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return false }
        let minuteOfDay = hour * 60 + minute
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        return minuteOfDay >= start && minuteOfDay < end
    }
}

enum RuleKind: String, Codable {
    case block
    case limit
}

/// Exactly two rule shapes, kept as one flat struct rather than a
/// Codable enum-with-associated-values -- matches this codebase's
/// existing preference for simple, hand-decodable shapes (see
/// FocusTask). Limit-only fields are ignored when kind == .block.
///
/// dailyBudgetMinutes is OPTIONAL: nil means "no daily limit" -- the
/// group stays accessible all day (reminders still fire if a task is
/// linked, but nothing ever auto-blocks it). When it IS set, `windows`
/// are the free-access exceptions to that budget; with no windows, the
/// budget just applies to the whole day.
struct GroupRule: Codable, Equatable {
    /// Registering N windows means up to N+1 independent budget-tracking
    /// DeviceActivityNames plus N window-boundary ones, on top of a
    /// possible reminder activity -- this app has never tested a
    /// concurrent-registration count anywhere near that. Capped at 5
    /// (matching the "+4 more" scale of typical reference examples) to
    /// keep the worst case bounded until that's verified on device; see
    /// the plan's Step 0.
    static let maxWindows = 5

    var kind: RuleKind
    var dailyBudgetMinutes: Int?
    var windows: [ScheduleWindow] = []
    var reminderIntervalMinutes: Int = 5

    /// Platform floor for a DeviceActivitySchedule's length -- the
    /// cooldown below is implemented as a one-off schedule, so it can't
    /// be shorter than this.
    static let minReshieldMinutes = 15

    /// Limit-mode OPTIONAL extra: nil = off; a value = "also check in
    /// when I open the app," re-armed that many minutes after each
    /// tap-through. (Optional so groups saved before this existed still
    /// decode, as "off".) iOS has no signal for "the user left the
    /// app," so a wall-clock cooldown (see GroupCooldown) is the closest
    /// thing to "check in on every open" the platform allows. The
    /// while-you-use-it reminder (reminderIntervalMinutes) is separate
    /// and always on.
    var reshieldMinutes: Int? = nil

    /// Limit-mode OPTIONAL extra, all in seconds: nil = off; a value =
    /// "when I tap Dismiss, hold the shield and count down this long
    /// before letting me in." Each further pause the same day is
    /// longer by `pauseStepSeconds` (nil/0 = same length every time).
    /// Both optional so groups saved before this existed still decode
    /// (a missing non-optional key would fail the whole groups array).
    /// See ShieldActionExtension.startOrCheckPause for the mechanics.
    var pauseSeconds: Int? = nil
    var pauseStepSeconds: Int? = nil

    /// Upper bound on any single pause, so a big step can't escalate a
    /// pause into something absurd over a long day.
    static let maxPauseSeconds = 3600

    var checkInOnOpen: Bool { reshieldMinutes != nil }

    var effectiveReshieldMinutes: Int {
        max(reshieldMinutes ?? Self.minReshieldMinutes, Self.minReshieldMinutes)
    }

    var pauseEnabled: Bool { (pauseSeconds ?? 0) > 0 }

    /// Length of the next pause, given how many pauses already started
    /// today: base + step x count, capped at maxPauseSeconds.
    func pauseLength(afterPausesToday count: Int) -> Int {
        guard let base = pauseSeconds, base > 0 else { return 0 }
        let step = max(pauseStepSeconds ?? 0, 0)
        return min(base + step * max(count, 0), Self.maxPauseSeconds)
    }
}

/// A named set of apps plus the one rule that governs all of them
/// together. Each group gets its own ManagedSettingsStore identity (see
/// GroupIdentity) so multiple groups with different rules can be active
/// at once, independently -- unlike the single fixed store this app used
/// before groups existed. No per-group task link: every group is
/// connected to the WHOLE quest list instead (see both shield
/// extensions' quest-list display, and
/// GroupStore.unshieldAllBlockGroups below for how Block groups release).
struct AppGroup: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var selection: FamilyActivitySelection
    var rule: GroupRule
    var createdAt: Date = Date()

    /// Plain-language summary for the group card. Deliberately doesn't
    /// depend on the current quest count for Block -- blocking has to
    /// keep meaning the same thing whether there are 0 quests or 10 (see
    /// unshieldAllBlockGroups's doc comment for why), so the rule
    /// description shouldn't imply otherwise.
    func summaryText() -> String {
        switch rule.kind {
        case .block:
            return "Blocked until you complete a quest."
        case .limit:
            var parts: [String] = []
            if let minutes = rule.dailyBudgetMinutes {
                parts.append("\(minutes) min/day")
            } else {
                parts.append("No daily limit")
            }
            let sortedWindows = rule.windows.sorted { ($0.startHour, $0.startMinute) < ($1.startHour, $1.startMinute) }
            if let first = sortedWindows.first {
                let extra = sortedWindows.count - 1
                parts.append(extra > 0 ? "No limits \(first.label), +\(extra) more" : "No limits \(first.label)")
            }
            parts.append("Reminder every \(rule.reminderIntervalMinutes) min of use")
            if rule.checkInOnOpen {
                parts.append("First-open check-in, again after \(rule.effectiveReshieldMinutes) min")
            }
            if rule.pauseEnabled, let base = rule.pauseSeconds {
                let step = rule.pauseStepSeconds ?? 0
                parts.append(step > 0 ? "\(base)s pause on dismiss, +\(step)s each time" : "\(base)s pause on dismiss")
            }
            return parts.joined(separator: ". ") + "."
        }
    }
}

/// App-Group-backed list of AppGroups -- same load/save shape as
/// TaskStore.loadTasks/saveTasks.
enum GroupStore {
    private static let groupsKey = "focusUp.groups"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    static func loadGroups() -> [AppGroup] {
        guard let data = defaults?.data(forKey: groupsKey),
              let groups = try? JSONDecoder().decode([AppGroup].self, from: data) else {
            return []
        }
        return groups
    }

    static func saveGroups(_ groups: [AppGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults?.set(data, forKey: groupsKey)
    }

    static func group(for id: UUID) -> AppGroup? {
        loadGroups().first { $0.id == id }
    }

    /// Reverse lookup from a shielded token back to the group that owns
    /// it -- called from the extensions, which only ever see a bare
    /// ApplicationToken, never a group id. O(groups) scan; this app's
    /// group count is small enough that this is fine.
    static func group(containing token: ApplicationToken) -> AppGroup? {
        loadGroups().first { $0.selection.applicationTokens.contains(token) }
    }

    /// Releases every Block-rule group -- called once, from
    /// FamilyControlsManager.toggleTaskCompletion, exactly when a quest
    /// transitions to completed. Deliberately an EVENT trigger, not a
    /// "the quest list happens to be empty" STATE check: with no
    /// per-group task link anymore, completing any one quest unlocks
    /// every Block group at once (there's no way to tell them apart
    /// well enough to unlock selectively). Critically, this also means
    /// blocking still works correctly with zero quests -- there's simply
    /// no completion event to fire, so a Block group with nothing to
    /// complete stays blocked, rather than an "unlock when the list is
    /// empty" rule silently opening it. activateBlock always shields
    /// unconditionally for the same reason -- re-saving a group (even
    /// unedited) re-arms it.
    static func unshieldAllBlockGroups() {
        for group in loadGroups() where group.rule.kind == .block {
            ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id)).shield.applications = nil
            GroupRuntimeState.setShieldReason(nil, for: group.id)
        }
    }
}

/// Deterministic identifiers derived ONLY from a group's `id`, never from
/// its name/rule/order. A ManagedSettingsStore's identity must never
/// change once a shield exists under it -- an established rule in this
/// codebase (see FamilyControlsManager's legacy fixed store name) that
/// now applies per-group instead of once globally: change how a name is
/// derived here and every existing group's shield becomes orphaned and
/// unclearable.
enum GroupIdentity {
    private static let storePrefix = "com.scottgray.FocusUpSpike.group."
    private static let activityPrefix = "focusUp.group."

    static func storeName(for groupID: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name("\(storePrefix)\(groupID.uuidString)")
    }

    /// `segment` indexes the gap between windows (0 = midnight to the
    /// first window's start, or the whole day if there are no windows;
    /// the last segment runs from the final window's end to 23:59:59).
    /// The index is embedded directly in `kind` (e.g. "budget0") rather
    /// than as a separate name component, so DeviceActivityMonitorExtension
    /// can branch on `kind.hasPrefix("budget")` for the shared
    /// lockout logic while still special-casing "budget0" for the
    /// midnight reset -- segment 0 is the only one guaranteed to always
    /// start exactly at midnight regardless of window count.
    static func budgetActivityName(for groupID: UUID, segment: Int) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).budget\(segment)")
    }

    static func windowActivityName(for groupID: UUID, index: Int) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).window\(index)")
    }

    static func reminderActivityName(for groupID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).reminder")
    }

    static func cooldownActivityName(for groupID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).cooldown")
    }

    static func eventName(groupID: UUID, kind: String, mark: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(activityPrefix)\(groupID.uuidString).\(kind).\(mark)")
    }

    /// Inverse of the activity-name builders above: given whatever
    /// DeviceActivityName the monitor extension was invoked with,
    /// recover which group it belongs to and its role, e.g. "budget0",
    /// "window2", "reminder". Pure string parsing -- deliberately
    /// independent of any device behavior so it can be trusted without
    /// on-device testing.
    static func parse(_ activity: DeviceActivityName) -> (groupID: UUID, kind: String)? {
        let raw = activity.rawValue
        guard raw.hasPrefix(activityPrefix) else { return nil }
        let rest = raw.dropFirst(activityPrefix.count)
        let comps = rest.split(separator: ".")
        guard comps.count >= 2, let id = UUID(uuidString: String(comps[0])) else { return nil }
        return (id, String(comps[1]))
    }
}

/// Tiny per-group runtime flags the monitor extension and shield
/// extensions both need to read/write, App-Group-backed like everything
/// else here. Separate from AppGroup itself (the user's saved
/// configuration) because this is transient state a background
/// extension process mutates outside of any user edit.
enum GroupRuntimeState {
    private static let exceededPrefix = "focusUp.group.exceededToday."
    private static let reasonPrefix = "focusUp.group.shieldReason."
    private static let pausePrefix = "focusUp.group.pause."
    private static let pauseCountPrefix = "focusUp.group.pauseCount."
    private static let pauseDayPrefix = "focusUp.group.pauseDay."

    /// A dismiss-pause in progress (see GroupRule.pauseSeconds). `id`
    /// lets a background waiter tell "my pause" from a newer one that
    /// replaced it, so a stale waiter never releases the wrong episode.
    struct Pause: Codable, Equatable {
        var id: UUID
        var endsAt: Date
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    /// Why a Limit-rule group's shield is currently up, if it is.
    /// `.block` covers Block-rule groups for symmetry even though they
    /// don't otherwise consult this enum.
    enum ShieldReason: String, Codable {
        case block
        case limitReminder
        case limitBudgetExceeded
    }

    static func exceededToday(_ groupID: UUID) -> Bool {
        defaults?.bool(forKey: exceededPrefix + groupID.uuidString) ?? false
    }

    static func setExceededToday(_ value: Bool, for groupID: UUID) {
        defaults?.set(value, forKey: exceededPrefix + groupID.uuidString)
    }

    static func shieldReason(for groupID: UUID) -> ShieldReason? {
        guard let raw = defaults?.string(forKey: reasonPrefix + groupID.uuidString) else { return nil }
        return ShieldReason(rawValue: raw)
    }

    /// Any change to why the shield is up (released, re-armed by a
    /// reminder or cooldown, locked by the budget) ends whatever pause
    /// was running -- the next dismiss starts a fresh one. This is the
    /// single place that guarantees a finished or abandoned pause from
    /// earlier never carries over onto a new shield.
    static func setShieldReason(_ reason: ShieldReason?, for groupID: UUID) {
        if let reason {
            defaults?.set(reason.rawValue, forKey: reasonPrefix + groupID.uuidString)
        } else {
            defaults?.removeObject(forKey: reasonPrefix + groupID.uuidString)
        }
        defaults?.removeObject(forKey: pausePrefix + groupID.uuidString)
    }

    // MARK: Dismiss pause

    static func pause(for groupID: UUID) -> Pause? {
        guard let data = defaults?.data(forKey: pausePrefix + groupID.uuidString) else { return nil }
        return try? JSONDecoder().decode(Pause.self, from: data)
    }

    static func setPause(_ pause: Pause?, for groupID: UUID) {
        if let pause, let data = try? JSONEncoder().encode(pause) {
            defaults?.set(data, forKey: pausePrefix + groupID.uuidString)
        } else {
            defaults?.removeObject(forKey: pausePrefix + groupID.uuidString)
        }
    }

    /// How many pauses this group has started today. Stored with the
    /// day it belongs to, so it resets at midnight on its own without
    /// relying on any DeviceActivity callback firing.
    static func pausesToday(_ groupID: UUID, now: Date = Date()) -> Int {
        let today = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        guard defaults?.double(forKey: pauseDayPrefix + groupID.uuidString) == today else { return 0 }
        return defaults?.integer(forKey: pauseCountPrefix + groupID.uuidString) ?? 0
    }

    static func recordPauseStarted(_ groupID: UUID, now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        let next = pausesToday(groupID, now: now) + 1
        defaults?.set(today, forKey: pauseDayPrefix + groupID.uuidString)
        defaults?.set(next, forKey: pauseCountPrefix + groupID.uuidString)
    }

    static func clear(_ groupID: UUID) {
        defaults?.removeObject(forKey: exceededPrefix + groupID.uuidString)
        defaults?.removeObject(forKey: reasonPrefix + groupID.uuidString)
        defaults?.removeObject(forKey: pausePrefix + groupID.uuidString)
        defaults?.removeObject(forKey: pauseCountPrefix + groupID.uuidString)
        defaults?.removeObject(forKey: pauseDayPrefix + groupID.uuidString)
    }
}

/// Cumulative-usage mark math shared by the Limit-rule daily budget and
/// its reminder cadence -- generalizes the same-shaped helper this app's
/// pre-Groups single global check-in used to use (GoalStore.swift's
/// FocusUpActivity, now stripped down to legacy/migration-only). Capped
/// at maxCount marks so a short interval doesn't try to register
/// hundreds of events -- see the call sites in
/// FamilyControlsManager.activateLimit for how that cap is chosen.
enum GroupActivityMarks {
    static func marks(intervalMinutes: Int, maxCount: Int = 30) -> [Int] {
        guard intervalMinutes > 0 else { return [] }
        return (1...maxCount).map { $0 * intervalMinutes }
    }

    static func components(forMinutes totalMinutes: Int) -> DateComponents {
        var c = DateComponents()
        c.hour = totalMinutes / 60
        c.minute = totalMinutes % 60
        return c
    }
}

/// The "shield again after N minutes" timer for Shield-mode (limit)
/// groups. When the user taps through the shield, ShieldActionExtension
/// calls start(for:), which registers a one-off, non-repeating
/// DeviceActivitySchedule ending `effectiveReshieldMinutes` from now;
/// DeviceActivityMonitorExtension.intervalDidEnd for the "cooldown" kind
/// then puts the shield back up. Minimum 15 minutes (the platform's
/// minimum schedule length). UNVERIFIED on device: that an extension
/// process may register monitoring, and that a non-repeating schedule
/// with full-date components fires intervalDidEnd on time.
enum GroupCooldown {
    static func start(for group: AppGroup, from now: Date = Date()) {
        let calendar = Calendar.current
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let end = now.addingTimeInterval(TimeInterval(group.rule.effectiveReshieldMinutes * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: now),
            intervalEnd: calendar.dateComponents(fields, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        let name = GroupIdentity.cooldownActivityName(for: group.id)
        center.stopMonitoring([name])
        try? center.startMonitoring(name, during: schedule)
    }

    static func stop(groupID: UUID) {
        DeviceActivityCenter().stopMonitoring([GroupIdentity.cooldownActivityName(for: groupID)])
    }
}
