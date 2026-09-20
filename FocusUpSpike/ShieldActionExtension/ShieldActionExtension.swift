import FamilyControls
import ManagedSettings
import UserNotifications

/// Handles taps on the shield's own two buttons -- this is the ONLY
/// block screen FocusUp shows. What each button does now depends on
/// which group owns the tapped app, and for Limit-rule groups, WHY the
/// shield is currently up (GroupRuntimeState.shieldReason):
///
/// - Block shield: primary button releases the WHOLE group and
///   completes its linked task (matches SHIELD_DESIGN.md's documented
///   intent -- "Completion... now ends the full focus session... rather
///   than releasing only the app whose shield button was pressed" --
///   the previous single-store implementation only released the tapped
///   app; this fixes that to match the documented behavior). Secondary
///   ("give up") still only releases the one app being looked at.
/// - Limit reminder nudge: either button just dismisses it -- no task
///   completion, no ignore recorded.
/// - Limit budget-exceeded lockout: neither button releases the app --
///   the token is deliberately left in the store so the restriction
///   survives the tap. This is the one behavior in this file that's
///   unverified on-device; confirm it before relying on it for the demo.
///
/// Note on "why a notification, not opening the app directly": there is
/// no supported way to open/foreground the host app from this extension
/// -- checked directly against Apple's own ShieldActionResponse cases
/// (.none / .defer / .close only; no case exists for opening the host
/// or parent app in any shipped SDK). A local notification is the
/// closest equivalent: tapping IT is a real user action, so iOS is
/// allowed to launch FocusUp from that tap.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard let group = GroupStore.group(containing: application) else {
            // Orphaned token with no owning group (shouldn't happen post-
            // migration) -- defensively unshield it from every group's
            // store rather than leave it stuck with nothing able to
            // release it.
            for candidate in GroupStore.loadGroups() {
                let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: candidate.id))
                var apps = store.shield.applications ?? []
                if apps.remove(application) != nil {
                    store.shield.applications = apps
                }
            }
            completionHandler(.close)
            return
        }

        switch group.rule.kind {
        case .block:
            handleBlock(group: group, application: application, action: action, completionHandler: completionHandler)
        case .limit:
            handleLimit(group: group, application: application, action: action, completionHandler: completionHandler)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    private func handleBlock(group: AppGroup, application: ApplicationToken, action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
        switch action {
        case .primaryButtonPressed:
            let clearedQuestTitle = group.taskID.flatMap { id in TaskStore.loadTasks().first { $0.id == id }?.title }
            store.shield.applications = nil
            for token in group.selection.applicationTokens {
                GoalStore.removeGoal(for: token)
            }
            GroupRuntimeState.setShieldReason(nil, for: group.id)
            StatsStore.recordCompleted(questTitle: clearedQuestTitle)
            if let taskID = group.taskID {
                TaskStore.markTaskCompleted(id: taskID)
                GroupStore.unshieldGroups(linkedToCompletedTask: taskID)
            }
            scheduleReturnNotification(
                title: "Quest complete \u{1F525}",
                body: "Tap to jump back into FocusUp and see your streak."
            )
            completionHandler(.close)
        case .secondaryButtonPressed:
            // "Give up" -- releases just the app being looked at; the
            // rest of the group stays blocked (an ignore is a per-app
            // bail, not a group-wide one).
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            StatsStore.recordIgnore()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private func handleLimit(group: AppGroup, application: ApplicationToken, action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let reason = GroupRuntimeState.shieldReason(for: group.id)
        switch reason {
        case .limitBudgetExceeded:
            // Deliberately do NOT touch the store -- the app stays
            // shielded after the sheet closes. See file-level doc
            // comment: unverified, must be device-tested first.
            scheduleReturnNotification(
                title: "Daily limit reached",
                body: "\u{201C}\(group.name)\u{201D} is locked for the rest of today's budget."
            )
            completionHandler(.close)
        default:
            // .limitReminder (or an unexpected nil) -- just a nudge,
            // dismiss it without recording completion or ignore. The
            // next reminder mark will reshield it.
            let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            GroupRuntimeState.setShieldReason(nil, for: group.id)
            completionHandler(.close)
        }
    }

    private func scheduleReturnNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
