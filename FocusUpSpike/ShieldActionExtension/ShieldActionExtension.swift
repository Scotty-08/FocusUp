//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//

import ManagedSettings
import UserNotifications

/// Handles taps on the shield overlay's two buttons.
///
/// Primary ("Ignore"): the user gives in and wants in anyway. Unblocks
/// the app for now (no re-block scheduling yet -- that's still open,
/// see REVIEW.md on recovery/re-application) but records an ignore
/// event so FocusUp can show "you've ignored this N times" -- this is
/// the accountability signal, not a way to quietly bypass with no trace.
///
/// Secondary ("I finished it"): legitimate override. Also unblocks, but
/// records it as a completion instead of an ignore, and clears the goal
/// text for that token. Still no proof required -- matches
/// PROJECT_SPEC's MVP default of self-reported-only completion.
///
/// Both paths currently unblock identically at the OS level; the only
/// difference today is which counter moves. A real distinction (e.g.
/// ignore counts against a streak, completion doesn't) is a product
/// decision for the full app, not something decided here.
///
/// Note on "why a notification": this extension runs in its own process
/// and Apple's SDK marks UIApplication.shared (and any way to open/
/// foreground the host app) unavailable to extensions -- there is no
/// supported way to jump the user back into FocusUp directly from here.
/// A local notification is the closest equivalent: tapping IT is a real
/// user action, so iOS is allowed to launch FocusUp from that tap, and
/// by then the streak/completed-task state is already saved and waiting.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let store = ManagedSettingsStore(named: FocusUpShared.storeName)

        switch action {
        case .primaryButtonPressed:
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            StatsStore.recordIgnore()
            completionHandler(.close)
        case .secondaryButtonPressed:
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            GoalStore.removeGoal(for: application)
            // Capture the quest title BEFORE markActiveTaskCompleted() advances
            // the active task to the next one -- otherwise by the time the app
            // reads this back, it'd show the *next* quest, not the one just cleared.
            let clearedQuestTitle = TaskStore.activeTask?.title
            StatsStore.recordCompleted(questTitle: clearedQuestTitle)
            TaskStore.markActiveTaskCompleted()
            scheduleFinishedNotification()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    /// Fires immediately so tapping it is the fastest path back into
    /// FocusUp -- tapping opens the app, which refreshes stats/tasks on
    /// appear and shows the streak animation + checked-off task right away.
    /// Does nothing (silently) if the user never granted notification
    /// permission -- requested from the main app, see FamilyControlsManager.
    private func scheduleFinishedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Task complete 🔥"
        content.body = "Tap to jump back into FocusUp and see your streak."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
