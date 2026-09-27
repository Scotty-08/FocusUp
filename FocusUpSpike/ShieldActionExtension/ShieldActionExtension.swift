import FamilyControls
import Foundation
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
///   completion, no ignore recorded. If the group has the optional
///   check-in-on-open, dismissing also starts its cooldown
///   (GroupCooldown). If the group has a dismiss pause
///   (GroupRule.pauseSeconds), dismissing first counts down on the
///   shield and only then lets the user in -- see startOrCheckPause.
///   The token is always removed on dismiss: an earlier version left it
///   shielded on the theory that `.none` would grant the current
///   attempt through anyway, which device testing proved false -- it
///   just made the app permanently unreachable.
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
            // exactly as it is.
            routeToQuests(completionHandler: completionHandler)
        default:
            // .limitReminder (or an unexpected nil) -- a while-you-use-it
            // reminder or, if the group has check-in-on-open, the
            // open check-in. Either way the user can tap through:
            // dismiss it without recording completion or ignore. The token IS always removed --
            // device-tested: leaving it shielded and returning .none
            // does NOT grant even momentary access, it just re-shows the
            // shield with no way out (see FamilyControlsManager.
            // activateLimit's doc comment). The next while-you-use-it
            // reminder mark brings the shield back, and so does the
            // check-in-on-open cooldown started here when that option is
            // on (GroupCooldown -- unverified that an extension may
            // register monitoring; confirm on device). .none (not .close) drops
            // the user back into the app instead of kicking them out.
            if group.rule.pauseEnabled {
                startOrCheckPause(group: group, application: application, completionHandler: completionHandler)
            } else {
                Self.release(group: group, application: application)
                completionHandler(.none)
            }
        }
    }

    /// Lets the user through: removes this app's token (the shield
    /// disappears and they're in the app they were already on), ends
    /// any pause, and arms the check-in-on-open cooldown if the group
    /// has one. Static so the pause waiter can call it without holding
    /// onto the extension instance.
    private static func release(group: AppGroup, application: ApplicationToken) {
        let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: group.id))
        var apps = store.shield.applications ?? []
        apps.remove(application)
        store.shield.applications = apps
        GroupRuntimeState.setShieldReason(nil, for: group.id)  // also clears the pause
        if group.rule.checkInOnOpen {
            GroupCooldown.start(for: group)
        }
    }

    /// The dismiss pause (GroupRule.pauseSeconds). The shield's own UI
    /// is a static system template -- it can't draw a ticking timer --
    /// so the pause is driven from here instead:
    ///
    /// - First Dismiss: record a pause ending N seconds from now (N
    ///   grows by the step for each pause already started today), keep
    ///   the token shielded, and answer `.defer`, which makes iOS
    ///   re-ask ShieldConfigurationExtension for the shield -- it now
    ///   shows the seconds left.
    /// - A background waiter (see PauseWaiter) then removes the token
    ///   the moment the pause ends, so the shield vanishes and the user
    ///   is dropped into the app they're already in -- no tap needed.
    /// - Dismiss again before it's over: just refreshes the seconds
    ///   shown (no penalty -- escalation is per pause, not per tap).
    /// - Dismiss after it's over: lets them straight in. This is also
    ///   the guaranteed fallback if iOS reclaimed the extension before
    ///   the waiter finished, so the user can never get stuck.
    ///
    /// UNVERIFIED on device: how long iOS keeps the extension alive for
    /// the waiter (performExpiringActivity grants an undocumented amount
    /// of time -- short pauses are likelier to auto-open than long ones),
    /// and whether `.defer` redraws the shield every time (there are
    /// long-standing forum reports of the configuration not refreshing).
    /// Neither can strand the user: the tap fallback always works.
    private func startOrCheckPause(group: AppGroup, application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let now = Date()
        if let pause = GroupRuntimeState.pause(for: group.id) {
            if now >= pause.endsAt {
                Self.release(group: group, application: application)
                completionHandler(.none)
            } else {
                // Still counting down. Re-arm a waiter in case the one
                // from the first tap was already reclaimed by iOS.
                PauseWaiter(group: group, application: application, pauseID: pause.id).start()
                completionHandler(.defer)
            }
            return
        }

        let seconds = group.rule.pauseLength(afterPausesToday: GroupRuntimeState.pausesToday(group.id, now: now))
        guard seconds > 0 else {
            Self.release(group: group, application: application)
            completionHandler(.none)
            return
        }
        let pause = GroupRuntimeState.Pause(id: UUID(), endsAt: now.addingTimeInterval(TimeInterval(seconds)))
        GroupRuntimeState.setPause(pause, for: group.id)
        GroupRuntimeState.recordPauseStarted(group.id, now: now)
        // Start the waiter BEFORE answering, so the extra-time request is
        // in place before iOS considers this extension done.
        PauseWaiter(group: group, application: application, pauseID: pause.id).start()
        completionHandler(.defer)
    }

    /// Waits out a dismiss pause in the background and releases the app
    /// when it ends. Uses ProcessInfo.performExpiringActivity -- the
    /// documented way for an app extension to ask for extra time after
    /// its callback returns. iOS decides how long that is; if it
    /// expires first, the waiter just stops and the Dismiss-after-zero
    /// tap handles it instead.
    ///
    /// Only releases if the stored pause is still THIS one (same id):
    /// if the user was already let in, or a newer pause replaced it,
    /// the waiter does nothing.
    private final class PauseWaiter: @unchecked Sendable {
        private let group: AppGroup
        private let application: ApplicationToken
        private let pauseID: UUID
        private let lock = NSLock()
        private var expired = false

        init(group: AppGroup, application: ApplicationToken, pauseID: UUID) {
            self.group = group
            self.application = application
            self.pauseID = pauseID
        }

        private var isExpired: Bool {
            lock.lock(); defer { lock.unlock() }
            return expired
        }

        func start() {
            ProcessInfo.processInfo.performExpiringActivity(withReason: "FocusUp dismiss pause") { didExpire in
                if didExpire {
                    self.lock.lock(); self.expired = true; self.lock.unlock()
                    return
                }
                while !self.isExpired {
                    guard let pause = GroupRuntimeState.pause(for: self.group.id), pause.id == self.pauseID else {
                        return  // already released, or replaced by a newer pause
                    }
                    let remaining = pause.endsAt.timeIntervalSinceNow
                    if remaining <= 0 {
                        ShieldActionExtension.release(group: self.group, application: self.application)
                        return
                    }
                    Thread.sleep(forTimeInterval: min(remaining, 0.5))
                }
            }
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
