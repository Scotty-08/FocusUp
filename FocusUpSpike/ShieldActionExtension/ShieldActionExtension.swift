import FamilyControls
import ManagedSettings
import UserNotifications

/// Handles taps on the shield's own two buttons -- this is the ONLY
/// block screen FocusUp shows. What each button does now depends on
/// which group owns the tapped app, and for Limit-rule groups, WHY the
/// shield is currently up (GroupRuntimeState.shieldReason):
///
/// - Block shield: primary button ("Open Quests") does NOT release
///   anything -- Block groups aren't tied to one specific task (see
///   AppGroup), so there's nothing here to complete. It routes to the
///   Quests tab instead (see routeToQuests below); the group unblocks
///   itself once a quest is actually completed there (see
///   GroupStore.unshieldAllBlockGroups, called from
///   FamilyControlsManager.toggleTaskCompletion), which also releases
///   every OTHER active Block group at once, matching SHIELD_DESIGN.md's
///   documented intent of a completion ending "the full focus session,"
///   just generalized from one group to all of them since there's no
///   per-group link left to distinguish by. Secondary ("give up") still
///   only releases the one app being looked at, and doesn't touch any
///   quest.
/// - Limit reminder nudge: if any quest is open, the primary button is
///   relabeled "Open Quests" (see ShieldConfigurationExtension) and
///   routes the user into FocusUp's Quests tab via routeToQuests below,
///   since they're leaving this app, not continuing to use it. Otherwise
///   (no open quests, or the secondary "Dismiss" button) either button
///   just dismisses the nudge and returns `.none` (not `.close`), which
///   drops the user back into the app they were already using instead of
///   kicking them out -- no task completion, no ignore recorded. If the
///   group's rule has `interruptOnOpen` set, dismissing does NOT remove
///   the token from the store (see handleLimit) -- the shield reappears
///   on the next open, giving "shown before every open" instead of
///   "shown periodically."
/// - Limit budget-exceeded lockout: neither button releases the app --
///   the token is deliberately left in the store so the restriction
///   survives the tap. This is one of two behaviors in this file that
///   are unverified on-device; confirm both before relying on them for
///   the demo (the other is routeToQuests's iOS 26.5+ path below).
///
/// Note on "why routeToQuests" exists as its own thing rather than a
/// plain `.close`: this codebase already tried, on iOS 26.5+,
/// `ShieldActionResponse.openParentalControlsApp` -- a real case, not a
/// gap in the SDK as an earlier version of this comment claimed -- to
/// open the host app directly instead of going through a notification
/// tap. It was added in "Redo: Blocker" (git 6db3424) and reverted same
/// day in "Back to ShieldAction" (git 13c3ccd) for an unrecorded reason,
/// plausibly because despite its name it opens the SYSTEM Screen Time
/// settings, not the app that owns the shield. Re-added in routeToQuests
/// below behind the same availability check, falling back to the
/// notification-tap pattern (proven back to iOS 16) on earlier versions
/// -- see that function's doc comment for what still needs confirming on
/// a real 26.5+ device.
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
            // "Open Quests" -- Block groups aren't tied to one specific
            // task anymore (see AppGroup), so there's nothing for a
            // shield tap to complete directly. The store is deliberately
            // left untouched: this group unblocks only when a quest is
            // actually completed from the Quests tab (see
            // FamilyControlsManager.toggleTaskCompletion ->
            // GroupStore.unshieldAllBlockGroups), which is exactly what
            // this button routes the user to.
            routeToQuests(completionHandler: completionHandler)
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
        case .limitReminder where action == .primaryButtonPressed && TaskStore.loadTasks().contains(where: { !$0.isCompleted }):
            // "Open Quests" (ShieldConfigurationExtension relabels the
            // primary button this way whenever any quest is open) --
            // the user is leaving this app for FocusUp's Quests tab, not
            // continuing to use it, so the shield's token is left
            // exactly as it is either way (whether it stays because of
            // interruptOnOpen is irrelevant on this path).
            routeToQuests(completionHandler: completionHandler)
        case .limitReminder where group.rule.interruptOnOpen:
            // Secondary ("Dismiss"), or primary with no open quests to
            // route to -- this group wants the interruption on EVERY
            // open, so leave the token in the store so the shield
            // reappears the next time the app is (re)opened. .none just
            // lets the CURRENT attempt through without touching
            // enforcement at all; no task completion or ignore recorded
            // either way.
            completionHandler(.none)
        default:
            // .limitReminder in periodic mode (or an unexpected nil) --
            // just a nudge, dismiss it without recording completion or
            // ignore. The next reminder mark will reshield it. .none
            // (not .close) is what drops the user back into the app they
            // were already using, rather than kicking them out to the
            // home screen -- "Continue" should actually continue.
            let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            GroupRuntimeState.setShieldReason(nil, for: group.id)
            completionHandler(.none)
        }
    }

    /// Routes the user to FocusUp's Quests tab. On iOS 26.5+,
    /// ShieldActionResponse exposes .openParentalControlsApp, a real
    /// case this codebase tried once before (git history: added in
    /// "Redo: Blocker" 6db3424, reverted same day in "Back to
    /// ShieldAction" 13c3ccd) and then backed away from for an
    /// unrecorded reason -- possibly because, despite the name
    /// suggesting otherwise, it opens the SYSTEM Screen Time settings
    /// rather than the app that owns the shield, which wouldn't land the
    /// user in FocusUp's Quests tab at all. Re-added here behind the
    /// same availability check with QuestRoute still set beforehand (in
    /// case it DOES route into this app), but its actual destination on
    /// a real 26.5+ device is unverified and must be confirmed before
    /// relying on it -- if it turns out to open Settings instead, revert
    /// this and keep only the notification-tap fallback below, which is
    /// proven to work back to iOS 16.
    private func routeToQuests(completionHandler: @escaping (ShieldActionResponse) -> Void) {
        QuestRoute.request()
        if #available(iOS 26.5, *) {
            completionHandler(.openParentalControlsApp)
        } else {
            scheduleReturnNotification(
                title: "Your quests are waiting",
                body: "Tap to jump back into FocusUp and see your list."
            )
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
