import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity

/// Identifiers shared across the main app and all three extensions.
/// Do NOT change these strings independently in one target only --
/// the App Group id and the store name must match everywhere or the
/// extensions silently see no data / no shield.
enum FocusUpShared {
    static let appGroupID = "group.com.scottgray.FocusUpSpike"

    /// LEGACY / migration-only. This was the app's one fixed shield
    /// store before AppGroup existed (see GroupStore.swift) -- every
    /// group now gets its own store via GroupIdentity.storeName(for:).
    /// Kept only so FamilyControlsManager.runLegacyMigrationIfNeeded()
    /// can clear it once and for all on upgrade; nothing should write a
    /// new shield under this name again.
    static let storeName = ManagedSettingsStore.Name("com.scottgray.FocusUpSpike.mainStore")
}

/// Counters for the shield's two exit paths, written from the
/// ShieldActionExtension process and read back in the main app.
///
/// currentStreak is a SESSION streak, not a calendar-day streak like
/// Duolingo's: it counts consecutive "I finished it" taps with no
/// "Ignore" in between, and resets to 0 on any Ignore. A real
/// day-based streak (what counts as a day, timezones, grace periods)
/// is a product decision, not plumbing -- flagged, not guessed at.
enum StatsStore {
    private static let ignoreKey = "focusUp.ignoreCount"
    private static let completedKey = "focusUp.completedCount"
    private static let streakKey = "focusUp.currentStreak"
    private static let lastClearedQuestTitleKey = "focusUp.lastClearedQuestTitle"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    static var ignoreCount: Int { defaults?.integer(forKey: ignoreKey) ?? 0 }
    static var completedCount: Int { defaults?.integer(forKey: completedKey) ?? 0 }
    static var currentStreak: Int { defaults?.integer(forKey: streakKey) ?? 0 }

    /// The title of whichever quest was completed, captured before the
    /// completing code advances to whatever's next. Lets the in-app
    /// celebration screen say what was actually just cleared, instead of
    /// whatever quest happens to be active by the time the user returns.
    static var lastClearedQuestTitle: String? { defaults?.string(forKey: lastClearedQuestTitleKey) }

    static func recordIgnore() {
        defaults?.set(ignoreCount + 1, forKey: ignoreKey)
        defaults?.set(0, forKey: streakKey)
    }

    static func recordCompleted(questTitle: String?) {
        defaults?.set(completedCount + 1, forKey: completedKey)
        defaults?.set(currentStreak + 1, forKey: streakKey)
        if let questTitle {
            defaults?.set(questTitle, forKey: lastClearedQuestTitleKey)
        }
    }
}

/// LEGACY / migration-only. Persisted the app's single global
/// FamilyActivitySelection before AppGroup existed (see
/// GroupStore.swift) -- each group now carries its own `selection`
/// directly. Kept only so FamilyControlsManager's one-time migration can
/// read a pre-groups install's selection; `save` should never be called
/// again.
enum SelectionStore {
    private static let key = "focusUpSpike.selection"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    static func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}

/// LEGACY / migration-only. Named the app's one global periodic check-in
/// before AppGroup existed -- Limit-rule groups now register their own
/// reminder/budget DeviceActivityNames directly (see GroupIdentity and
/// GroupActivityMarks in GroupStore.swift, which generalizes the
/// cumulative-threshold trick this enum's now-removed marks()/
/// eventName()/components() helpers pioneered). Kept only so
/// FamilyControlsManager's one-time migration can stop monitoring `name`
/// on upgrade; nothing should start monitoring it again.
enum FocusUpActivity {
    static let name = DeviceActivityName("focusUp.checkIn")
}

/// A shield tap requests presentation only. Never carries app identities.
enum QuestRoute {
    private static let key = "focusUp.pendingQuestRoute"
    static func request() {
        UserDefaults(suiteName: FocusUpShared.appGroupID)?.set(true, forKey: key)
    }
    static func consume() -> Bool {
        guard let defaults = UserDefaults(suiteName: FocusUpShared.appGroupID),
              defaults.bool(forKey: key) else { return false }
        defaults.removeObject(forKey: key)
        return true
    }
}
