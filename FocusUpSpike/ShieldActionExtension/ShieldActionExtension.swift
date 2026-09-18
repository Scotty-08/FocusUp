//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//

import ManagedSettings

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
            StatsStore.recordCompleted()
            TaskStore.markActiveTaskCompleted()
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
}
