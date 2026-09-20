//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

/// Fires on Limit-rule groups' registered DeviceActivityNames --
/// GroupIdentity.parse(activity) recovers which group and which of the
/// four possible roles (budgetPre/budgetPost/window/reminder) a given
/// callback belongs to; see FamilyControlsManager.activateLimit for how
/// those get registered. Block-rule groups never appear here at all
/// (they register no DeviceActivityName).
///
/// This is the first time this app has run more than one simultaneous
/// named activity -- the previous single-purpose check-in used exactly
/// one DeviceActivityName for the whole app. Needs on-device
/// verification that independently-scheduled activities for different
/// groups (and, for one group with a window, its own three activities)
/// actually fire independently and on time, not just that this code
/// compiles.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let (groupID, kind) = GroupIdentity.parse(activity),
              let group = GroupStore.group(for: groupID) else { return }

        switch kind {
        case "budgetPre", "budgetPost":
            GroupRuntimeState.setExceededToday(true, for: groupID)
            GroupRuntimeState.setShieldReason(.limitBudgetExceeded, for: groupID)
            ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = group.selection.applicationTokens
            scheduleNotification(
                title: "Daily limit reached \u{26A1}",
                body: "\u{201C}\(group.name)\u{201D} is locked for the rest of today's budget."
            )
        case "reminder":
            GroupRuntimeState.setShieldReason(.limitReminder, for: groupID)
            ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = group.selection.applicationTokens
            scheduleNotification(
                title: "Quick check-in \u{26A1}",
                body: "Still working on your quest? Tap to check in."
            )
        default:
            break
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let (groupID, kind) = GroupIdentity.parse(activity) else { return }
        switch kind {
        case "window":
            // The unrestricted window has begun -- open access regardless
            // of today's budget state.
            ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = nil
            GroupRuntimeState.setShieldReason(nil, for: groupID)
        case "budgetPre":
            // This schedule's intervalStart is midnight -- a new day has
            // begun, reset the exceeded flag. (budgetPost's own
            // intervalStart is mid-day, after the window, so it must NOT
            // also reset the flag -- only budgetPre marks the day
            // boundary.)
            GroupRuntimeState.setExceededToday(false, for: groupID)
        default:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let (groupID, kind) = GroupIdentity.parse(activity), kind == "window",
              GroupRuntimeState.exceededToday(groupID),
              let group = GroupStore.group(for: groupID) else { return }
        // The unrestricted window just ended and today's budget was
        // already used up before it started -- re-lock for the
        // remainder of the day (budgetPost is registered starting
        // exactly at this same boundary and will keep tracking usage
        // from here).
        ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = group.selection.applicationTokens
        GroupRuntimeState.setShieldReason(.limitBudgetExceeded, for: groupID)
    }

    /// Silently does nothing if notification permission was never
    /// granted -- requested from the main app, see
    /// FamilyControlsManager.requestNotificationPermission.
    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
