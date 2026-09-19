import ActivityKit
import Foundation

/// Live Activity shown in the Dynamic Island / Lock Screen while a
/// focus session is active (see FamilyControlsManager.applyShield /
/// clearShield). Duplicated identically into the FocusUpActivity
/// widget extension target -- this project's targets don't share files
/// via target-membership, only by identical copies, same pattern
/// GoalStore/TaskStore/StatsStore already use for anything needed in
/// more than one target.
///
/// ContentState counts UP (elapsed time since the session started),
/// not down to a re-lock instant: FocusUp's actual re-shield timing is
/// usage-based (see the periodic check-in system in GoalStore.swift),
/// not a fixed wall-clock window, so a countdown to "when this re-
/// locks" would just be guessing at a time that isn't really enforced.
/// An elapsed counter is honest about what's actually happening -- a
/// focus session in progress -- without pretending to a precision we
/// don't have.
struct FocusUpActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var questTitle: String?
        var streak: Int
    }

    /// When the current focus session (Apply Shield) began. Fixed for
    /// the life of the Activity -- ContentState updates never change
    /// this, only questTitle/streak.
    var startedAt: Date
}
