import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

/// Owns the one fixed ManagedSettingsStore identity for this spike.
/// Do NOT rename `storeName` later — a renamed store orphans any shields
/// already applied under the old name (see REVIEW.md, "fixed store identity").
@MainActor
final class FamilyControlsManager: ObservableObject {
    static let shared = FamilyControlsManager()

    static let storeName = ManagedSettingsStore.Name("com.scottgray.FocusUpSpike.mainStore")

    private let store = ManagedSettingsStore(named: FamilyControlsManager.storeName)
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selection = FamilyActivitySelection()
    // isShielded reflects what we last ASKED the system to do, not confirmed
    // enforcement. Per REVIEW.md: "store assignments alone are not proof of
    // enforcement" -- actually tapping the app on-device is the real check.
    @Published var isShielded = false
    @Published var lastError: String?
    @Published var goalText: String = ""
    @Published var completedCount: Int = 0
    @Published var ignoreCount: Int = 0
    @Published var currentStreak: Int = 0
    @Published var justCompletedStreak: Int?
    @Published var checkInIntervalSeconds: Int = 1800
    @Published var isPeriodicCheckInActive = false
    private var lastKnownCompletedCount: Int = 0

    private init() {
        authorizationStatus = center.authorizationStatus
        loadSelection()
        lastKnownCompletedCount = StatsStore.completedCount
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = center.authorizationStatus
            lastError = nil
        } catch {
            lastError = "Authorization failed: \(error.localizedDescription)"
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = center.authorizationStatus
    }

    func refreshStats() {
        let newCompleted = StatsStore.completedCount
        let newStreak = StatsStore.currentStreak
        if newCompleted > lastKnownCompletedCount {
            justCompletedStreak = newStreak
        }
        lastKnownCompletedCount = newCompleted
        completedCount = newCompleted
        ignoreCount = StatsStore.ignoreCount
        currentStreak = newStreak
    }

    func dismissStreakAnimation() {
        justCompletedStreak = nil
    }

    func applyShield() {
        guard !selection.applicationTokens.isEmpty else {
            lastError = "Select at least one app first."
            return
        }
        let trimmedGoal = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmedGoal.isEmpty ? "Finish your focus task in FocusUp to unlock this app." : trimmedGoal
        GoalStore.setGoal(text, for: selection.applicationTokens)
        store.shield.applications = selection.applicationTokens
        isShielded = true
        lastError = nil
    }

    func clearShield() {
        store.shield.applications = nil
        isShielded = false
    }

    func saveSelection() {
        SelectionStore.save(selection)
    }

    private func loadSelection() {
        guard let saved = SelectionStore.load() else { return }
        selection = saved
    }

    /// Registers a stack of cumulative-usage thresholds (see
    /// FocusUpActivity) so the DeviceActivityMonitor extension re-shows
    /// the block screen roughly every `checkInIntervalMinutes` of actual
    /// use of the selected app(s), even mid-session. New today --
    /// reliability needs on-device verification.
    func startPeriodicCheckIns() {
        guard !selection.applicationTokens.isEmpty else {
            lastError = "Select at least one app first."
            return
        }
        SelectionStore.save(selection)

        let marks = FocusUpActivity.marks(intervalSeconds: checkInIntervalSeconds)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for mark in marks {
            events[FocusUpActivity.eventName(forMark: mark)] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: FocusUpActivity.components(forSeconds: mark)
            )
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        activityCenter.stopMonitoring([FocusUpActivity.name])
        do {
            try activityCenter.startMonitoring(FocusUpActivity.name, during: schedule, events: events)
            isPeriodicCheckInActive = true
            lastError = nil
        } catch {
            isPeriodicCheckInActive = false
            lastError = "Couldn't start check-ins: \(error.localizedDescription)"
        }
    }

    func stopPeriodicCheckIns() {
        activityCenter.stopMonitoring([FocusUpActivity.name])
        isPeriodicCheckInActive = false
    }
}
