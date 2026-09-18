import Foundation
import ManagedSettings

/// Identifiers shared across the main app and both shield extensions.
/// Do NOT change these strings independently in one target only --
/// the App Group id and the store name must match everywhere or the
/// extensions silently see no data / no shield.
enum FocusUpShared {
    static let appGroupID = "group.com.scottgray.FocusUpSpike"
    static let storeName = ManagedSettingsStore.Name("com.scottgray.FocusUpSpike.mainStore")
}

/// Maps each shielded app's opaque ApplicationToken to the goal text the
/// user typed for it, stored in the shared App Group container so the
/// Shield Configuration extension (a separate process) can read it when
/// it draws the block overlay.
enum GoalStore {
    private static let key = "focusUp.tokenGoalMap"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    static func loadAll() -> [ApplicationToken: String] {
        guard let data = defaults?.data(forKey: key),
              let map = try? JSONDecoder().decode([ApplicationToken: String].self, from: data) else {
            return [:]
        }
        return map
    }

    private static func save(_ map: [ApplicationToken: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults?.set(data, forKey: key)
    }

    static func goal(for token: ApplicationToken) -> String? {
        loadAll()[token]
    }

    static func setGoal(_ text: String, for token: ApplicationToken) {
        var map = loadAll()
        map[token] = text
        save(map)
    }

    /// Replace the whole map with exactly this selection's goal text --
    /// called on every Apply so stale entries for deselected apps don't
    /// linger.
    static func setGoal(_ text: String, for tokens: Set<ApplicationToken>) {
        var map = loadAll()
        map = map.filter { tokens.contains($0.key) }
        for token in tokens {
            map[token] = text
        }
        save(map)
    }

    static func removeGoal(for token: ApplicationToken) {
        var map = loadAll()
        map.removeValue(forKey: token)
        save(map)
    }
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

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FocusUpShared.appGroupID)
    }

    static var ignoreCount: Int { defaults?.integer(forKey: ignoreKey) ?? 0 }
    static var completedCount: Int { defaults?.integer(forKey: completedKey) ?? 0 }
    static var currentStreak: Int { defaults?.integer(forKey: streakKey) ?? 0 }

    static func recordIgnore() {
        defaults?.set(ignoreCount + 1, forKey: ignoreKey)
        defaults?.set(0, forKey: streakKey)
    }

    static func recordCompleted() {
        defaults?.set(completedCount + 1, forKey: completedKey)
        defaults?.set(currentStreak + 1, forKey: streakKey)
    }
}
