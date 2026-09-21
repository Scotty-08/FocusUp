//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

/// Fires on Limit-rule groups' registered DeviceActivityNames --
/// GroupIdentity.parse(activity) recovers which group and which role a
/// given callback plays: "budget<N>" (one per gap between windows, or
/// just "budget0" covering the whole day if there are no windows),
/// "window<N>" (one per free-access window, used only for its
/// start/end boundaries), "reminder", or "cooldown" (the one-off
/// "shield again after N minutes" timer, see GroupCooldown). See
/// FamilyControlsManager.activateLimit for how those get registered.
/// Block-rule groups never appear here at all (they register no
/// DeviceActivityName).
///
/// This is the first time this app has run more than one simultaneous
/// named activity -- the previous single-purpose check-in used exactly
/// one DeviceActivityName for the whole app, and a Limit-rule group can
/// now register up to 2 x GroupRule.maxWindows + 2 of them at once.
/// Needs on-device verification that independently-scheduled activities
/// for different groups (and, for one group with several windows, its
/// own several activities) actually fire independently and on time, not
/// just that this code compiles.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let (groupID, kind) = GroupIdentity.parse(activity),
              let group = GroupStore.group(for: groupID) else { return }

        if kind.hasPrefix("budget") {
            // Any budget segment reaching its threshold means today's
            // total is used up -- doesn't matter which segment index.
            GroupRuntimeState.setExceededToday(true, for: groupID)
            GroupRuntimeState.setShieldReason(.limitBudgetExceeded, for: groupID)
            ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = group.selection.applicationTokens
            scheduleNotification(
                title: "Daily limit reached \u{26A1}",
                body: "\u{201C}\(group.name)\u{201D} is locked for the rest of today's budget."
            )
        } else if kind == "reminder" {
            // Never downgrade a real lockout into a dismissable nudge --
            // if today's budget is already blown, leave the existing
            // .limitBudgetExceeded reason (and store assignment) alone.
            guard !GroupRuntimeState.exceededToday(groupID) else { return }
            // The reminder schedule runs all day (it isn't segmented
            // around windows the way budget tracking is), so it CAN fire
            // while inside a free-access window -- skip it there since a
            // window means no nagging at all, not even a dismissable one.
            let now = Date()
            guard !group.rule.windows.contains(where: { $0.contains(now) }) else { return }

            GroupRuntimeState.setShieldReason(.limitReminder, for: groupID)
            ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = group.selection.applicationTokens
            scheduleNotification(
                title: "Quick check-in \u{26A1}",
                body: "Tap to check in."
            )
        }
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let (groupID, kind) = GroupIdentity.parse(activity) else { return }
        if kind.hasPrefix("window") {
            // A free-access window has begun -- open access regardless
            // of today's budget state.
            ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID)).shield.applications = nil
            GroupRuntimeState.setShieldReason(nil, for: groupID)
        } else if kind == "budget0" {
            // Segment 0 is the only one guaranteed to always start
            // exactly at midnight, regardless of how many windows the
            // group has (see GroupIdentity.budgetActivityName) -- that's
            // the day boundary, so this is where the exceeded flag
            // resets. Any other "budget<N>" segment's intervalStart is
            // mid-day (right after a window ends) and must NOT also
            // reset the flag.
            GroupRuntimeState.setExceededToday(false, for: groupID)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let (groupID, kind) = GroupIdentity.parse(activity),
              let group = GroupStore.group(for: groupID) else { return }
        let store = ManagedSettingsStore(named: GroupIdentity.storeName(for: groupID))

        if kind.hasPrefix("window") {
            // A free-access window just ended. If today's budget was
            // already used up before it started, re-lock for the rest of
            // the day (the next budget segment is registered starting
            // exactly at this boundary and keeps tracking from here).
            // Otherwise the group is back to its normal Shield behavior:
            // the shield greets the user on their next open.
            if GroupRuntimeState.exceededToday(groupID) {
                GroupRuntimeState.setShieldReason(.limitBudgetExceeded, for: groupID)
            } else {
                GroupRuntimeState.setShieldReason(.limitReminder, for: groupID)
            }
            store.shield.applications = group.selection.applicationTokens
        } else if kind == "cooldown" {
            // The "shield again after N minutes" timer set when the user
            // last tapped through the shield (GroupCooldown.start, called
            // from ShieldActionExtension). Never touch a group that's
            // already shielded/locked, or inside a free-access window
            // (the window's own end re-shields it).
            guard !GroupRuntimeState.exceededToday(groupID),
                  GroupRuntimeState.shieldReason(for: groupID) == nil,
                  !group.rule.windows.contains(where: { $0.contains(Date()) }) else { return }
            GroupRuntimeState.setShieldReason(.limitReminder, for: groupID)
            store.shield.applications = group.selection.applicationTokens
        }
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
