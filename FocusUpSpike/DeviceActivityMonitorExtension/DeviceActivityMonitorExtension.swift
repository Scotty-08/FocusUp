//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

/// Fires when cumulative usage of the selected app(s) crosses one of the
/// pre-registered minute marks (see FocusUpActivity in GoalStore.swift).
/// Re-applies the shield to the full saved selection, which forces the
/// block screen back over the app even mid-use -- the "time to lock
/// back in" check-in Scott asked for.
///
/// Also records the check-in (StatsStore.recordCheckIn) and fires a
/// local notification, the same "can't open the host app directly from
/// an extension, so make tapping a notification the way back in" pattern
/// ShieldActionExtension already uses. Tapping it drops the user back
/// into FocusUp, where ContentView shows the System Check-In screen --
/// full custom "flare" for what would otherwise be a silent re-seal.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard UserDefaults(suiteName: FocusUpShared.appGroupID)?.bool(forKey: "focusUp.checkInsEnabled") == true,
              activity == FocusUpActivity.name,
              let selection = SelectionStore.load(),
              !selection.applicationTokens.isEmpty else { return }

        let store = ManagedSettingsStore(named: FocusUpShared.storeName)
        store.shield.applications = selection.applicationTokens
        StatsStore.recordCheckIn()
        scheduleCheckInNotification()
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    /// Silently does nothing if notification permission was never
    /// granted -- requested from the main app, see
    /// FamilyControlsManager.requestNotificationPermission.
    private func scheduleCheckInNotification() {
        let content = UNMutableNotificationContent()
        content.title = "System Check-In \u{26A1}"
        content.body = "Your seal has been reapplied. Tap to check in."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
