import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// One user-defined window of the day during which a Limit-rule group's
/// apps are always accessible, regardless of its daily budget. MVP caps
/// this at one window per group -- a second window would fragment the
/// day into more disjoint budget schedules, each with its own
/// independently-resetting cumulative counter (see activateLimit in
/// FamilyControlsManager.swift for why that's already an accepted
/// approximation with just one window).
struct ScheduleWindow: Codable, Equatable {
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
}

enum RuleKind: String, Codable {
    case block
    case limit
}

/// Exactly two rule shapes, kept as one flat struct rather than a
/// Codable enum-with-associated-values -- matches this codebase's
/// existing preference for simple, hand-decodable shapes (see
/// FocusTask). Limit-only fields are ignored when kind == .block.
struct GroupRule: Codable, Equatable {
    var kind: RuleKind
    var dailyBudgetMinutes: Int = 30
    var window: ScheduleWindow?
    var reminderIntervalMinutes: Int = 5
}

/// A named set of apps plus the one rule that governs all of them
/// together. Each group gets its own ManagedSettingsStore identity (see
/// GroupIdentity) so multiple groups with different rules can be active
/// at once, independently -- unlike the single fixed store this app used
/// before groups existed.
struct AppGroup: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var selection: FamilyActivitySelection
    var rule: GroupRule
    var taskID: UUID?
    var createdAt: Date = Date()

    /// Plain-language summary for the group card. Reads the linked
    /// task's title live rather than caching it, so an edited task
    /// title shows up immediately without re-saving every group that
    /// references it.
    func summaryText(taskTitle: String?) -> String {
        switch rule.kind {
        case .block:
            if let taskTitle, !taskTitle.isEmpty {
                return "Blocked until \u{201C}\(taskTitle)\u{201D} is done."
            }
            return "Blocked until its linked quest is done."
        case .limit:
            var parts = ["\(rule.dailyBudgetMinutes) min/day"]
            if let window = rule.window {
                parts.append("No limits \(window.label)")
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

    /// Releases every Block-rule group linked to this task -- called
    /// whenever a task is completed, from ANY path (a shield's own
    /// primary button, or the Tasks tab), so two different Block groups
    /// that both point at the same task both release, not just whichever
    /// group's shield happened to be tapped.
    static func unshieldGroups(linkedToCompletedTask taskID: UUID) {
        for group in loadGroups() where group.taskID == taskID && group.rule.kind == .block {
            ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id)).shield.applications = nil
            GroupRuntimeState.setShieldReason(nil, for: group.id)
        }
    }

    /// Called when a task is deleted so groups don't keep pointing at a
    /// task that no longer exists.
    static func unlinkGroups(fromDeletedTask taskID: UUID) {
        var groups = loadGroups()
        var changed = false
        for i in groups.indices where groups[i].taskID == taskID {
            groups[i].taskID = nil
            changed = true
        }
        if changed { saveGroups(groups) }
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

    static func budgetPreActivityName(for groupID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).budgetPre")
    }

    static func budgetPostActivityName(for groupID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).budgetPost")
    }

    static func windowActivityName(for groupID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).window")
    }

    static func reminderActivityName(for groupID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(groupID.uuidString).reminder")
    }

    static func eventName(groupID: UUID, kind: String, mark: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(activityPrefix)\(groupID.uuidString).\(kind).\(mark)")
    }

    /// Inverse of the activity-name builders above: given whatever
    /// DeviceActivityName the monitor extension was invoked with,
    /// recover which group it belongs to and which of the four roles
    /// (budgetPre/budgetPost/window/reminder) it plays. Pure string
    /// parsing -- deliberately independent of any device behavior so it
    /// can be trusted without on-device testing.
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

    static func setShieldReason(_ reason: ShieldReason?, for groupID: UUID) {
        if let reason {
            defaults?.set(reason.rawValue, forKey: reasonPrefix + groupID.uuidString)
        } else {
            defaults?.removeObject(forKey: reasonPrefix + groupID.uuidString)
        }
    }

    static func clear(_ groupID: UUID) {
        defaults?.removeObject(forKey: exceededPrefix + groupID.uuidString)
        defaults?.removeObject(forKey: reasonPrefix + groupID.uuidString)
    }
}

/// Cumulative-usage mark math shared by the Limit-rule daily budget and
/// its reminder cadence -- generalizes the single-purpose
/// FocusUpActivity.marks(intervalSeconds:) this app used before groups
/// existed (that one is now legacy/migration-only, see GoalStore.swift).
/// Capped at maxCount marks for the same reason as before: a short demo
/// interval shouldn't try to register hundreds of events.
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
