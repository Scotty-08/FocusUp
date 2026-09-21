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
///   just dismisses the nudge, ALWAYS removes the token, and returns
///   `.none` (not `.close`), which drops the user back into the app they
///   were already using instead of kicking them out -- no task
///   completion, no ignore recorded. `interruptOnOpen` no longer changes
///   this dismiss behavior (see FamilyControlsManager.activateLimit's
///   doc comment): an earlier version left the token shielded for that
///   mode on the theory that `.none` would grant the current attempt
///   through anyway, which device testing proved false -- it just made
///   the app permanently unreachable. `interruptOnOpen` now only forces
///   a much shorter reminder cadence, it doesn't touch this code path.
/// - Limit budget-exceeded lockout: neither button releases the app --
///   the token is deliberately left in the store so the restriction
///   survives the tap. Still unverified on-device; confirm before
///   relying on it for the demo.
///
/// Note on "why routeToQuests" exists as its own thing rather than a
/// plain `.close`: on iOS 26.5+, `ShieldActionResponse.openParentalControlsApp`
/// opens the host app (FocusUp) directly -- device-confirmed on this
/// project's own hardware, landing straight on the Quests tab with no
/// notification-tap step needed. (This codebase tried it once before,
/// in "Redo: Blocker" (git 6db3424), then reverted it same day in "Back
/// to ShieldAction" (git 13c3ccd) for an unrecorded reason -- possibly
/// an unrelated issue with that attempt's full-screen QuestFocusView,
/// since the case itself now checks out.) Falls back to the
/// notification-tap pattern (proven back to iOS 16) on pre-26.5
/// versions, which still needs its own on-device confirmation on an
/// older-OS device since all verification so far has been on 26.5+.
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
        default:
            // .limitReminder (or an unexpected nil) -- just a nudge,
            // dismiss it without recording completion or ignore. The
            // token IS always removed here, regardless of interruptOnOpen
            // -- device-tested: leaving it shielded and returning .none
            // does NOT grant even momentary access, it just re-shows the
            // shield with no way out (see FamilyControlsManager.
            // activateLimit's doc comment for the full story). The next
            // reminder mark will reshield it -- interruptOnOpen just
            // forces that mark to fire roughly every minute instead of
            // the user's chosen interval, it doesn't change this dismiss
            // behavior at all anymore. .none (not .close) is what drops
            // the user back into the app they were already using, rather
            // than kicking them out to the home screen -- "Continue"
            // should actually continue.
            let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            GroupRuntimeState.setShieldReason(nil, for: group.id)
            completionHandler(.none)
        }
    }

    /// Routes the user to FocusUp's Quests tab. On iOS 26.5+,
    /// ShieldActionResponse.openParentalControlsApp opens FocusUp itself
    /// directly (device-confirmed on this project's hardware: lands on
    /// the Quests tab with no notification-tap step) -- despite the
    /// name, it does NOT open system Screen Time settings, which was the
    /// working assumption before this was tested. QuestRoute is still
    /// set beforehand so the app knows which tab to land on once it
    /// opens, exactly as it does for the notification-tap fallback path.
    /// That fallback (for pre-26.5 devices) hasn't itself been confirmed
    /// on an older-OS device yet -- everything verified so far has been
    /// on 26.5+, where the code never reaches the `else` branch.
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
