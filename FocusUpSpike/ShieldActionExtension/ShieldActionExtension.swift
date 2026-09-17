//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//

import ManagedSettings

/// Handles taps on the shield overlay's two buttons.
/// Primary ("Close") just dismisses -- the app stays blocked.
/// Secondary ("Override") removes this one app's token from the shared
/// shield set, so the next time it's opened it is not blocked. This is
/// the self-reported override from PROJECT_SPEC's MVP default: no photo
/// or screenshot proof required, matches "self-reported completion only".
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            let store = ManagedSettingsStore(named: FocusUpShared.storeName)
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps
            GoalStore.removeGoal(for: application)
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
