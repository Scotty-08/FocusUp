import ManagedSettings
import UserNotifications

/// Navigation never clears shields or records completion/override.
class ShieldActionExtension: ShieldActionDelegate {
    private func respond(to action: ShieldAction, completion: @escaping (ShieldActionResponse) -> Void) {
        guard case .primaryButtonPressed = action else {
            completion(.close)
            return
        }
        QuestRoute.request()
        if #available(iOS 26.5, *) {
            completion(.openParentalControlsApp)
        } else {
            let content = UNMutableNotificationContent()
            content.title = "Open your quest in FocusUp"
            content.body = "Your apps stay blocked until you finish or end focus."
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: "focusUp.openQuest", content: content, trigger: nil))
            completion(.close)
        }
    }
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completion: completionHandler)
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completion: completionHandler)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completion: completionHandler)
    }
}
