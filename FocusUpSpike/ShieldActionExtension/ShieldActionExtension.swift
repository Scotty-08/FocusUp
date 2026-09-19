import ManagedSettings
import UserNotifications

/// Handles taps on the shield's own two buttons -- this is the ONLY
/// block screen FocusUp shows. (An earlier Shortcuts-automation-based
/// instant-redirect to a custom in-app screen was tried and removed --
/// it required per-app manual setup and had a real ping-pong loop risk
/// with no reliable fix found. This native shield is what's live.)
///
/// Primary ("Open Quest" per the shield's own label): treated as a
/// completion -- unblocks, records completed (not ignored), clears the
/// goal text for that token.
///
/// Secondary ("Give up"): treated as an ignore -- unblocks for
/// now (no re-block scheduling yet, see REVIEW.md) but records an
/// ignore event, the accountability signal, not a quiet bypass.
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
        let store = ManagedSettingsStore(named: FocusUpShared.storeName)
        switch action {
        case .primaryButtonPressed:
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            GoalStore.removeGoal(for: application)
            // Capture the quest title BEFORE markActiveTaskCompleted()
            // advances the active task to the next one -- otherwise by
            // the time the app reads this back, it'd show the *next*
            // quest, not the one just cleared.
            let clearedQuestTitle = TaskStore.activeTask?.title
            StatsStore.recordCompleted(questTitle: clearedQuestTitle)
            TaskStore.markActiveTaskCompleted()
            scheduleReturnNotification(
                title: "Quest complete 🔥",
                body: "Tap to jump back into FocusUp and see your streak."
            )
            completionHandler(.close)
        case .secondaryButtonPressed:
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            StatsStore.recordIgnore()
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

    private func scheduleReturnNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
