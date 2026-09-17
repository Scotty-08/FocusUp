import Foundation
import FamilyControls
import ManagedSettings
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
    private let defaults = UserDefaults.standard
    private let selectionKey = "focusUpSpike.selection"

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selection = FamilyActivitySelection()
    // isShielded reflects what we last ASKED the system to do, not confirmed
    // enforcement. Per REVIEW.md: "store assignments alone are not proof of
    // enforcement" -- actually tapping the app on-device is the real check.
    @Published var isShielded = false
    @Published var lastError: String?
    @Published var goalText: String = ""

    private init() {
        authorizationStatus = center.authorizationStatus
        loadSelection()
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
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: selectionKey)
    }

    private func loadSelection() {
        guard let data = defaults.data(forKey: selectionKey),
              let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        selection = saved
    }
}
