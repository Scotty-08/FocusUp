//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//

import DeviceActivity
import ManagedSettings
import FamilyControls

/// Fires when cumulative usage of the selected app(s) crosses one of the
/// pre-registered minute marks (see FocusUpActivity in GoalStore.swift).
/// Re-applies the shield to the full saved selection, which forces the
/// block screen back over the app even mid-use -- the "time to lock
/// back in" check-in Scott asked for.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity == FocusUpActivity.name,
              let selection = SelectionStore.load(),
              !selection.applicationTokens.isEmpty else { return }

        let store = ManagedSettingsStore(named: FocusUpShared.storeName)
        store.shield.applications = selection.applicationTokens
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }
}
