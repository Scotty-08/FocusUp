import ActivityKit
import Foundation

/// Live Activity shown in the Dynamic Island / Lock Screen while at
/// least one group is active (see FamilyControlsManager.createGroup /
/// deleteGroup, which start/end this). Duplicated identically into the
/// FocusUpActivity widget extension target -- this project's targets
/// don't share files via target-membership, only by identical copies,
/// same pattern GoalStore/TaskStore/GroupStore already use for anything
/// needed in more than one target.
///
/// Still shows the global active task + streak, not any particular
/// group's state -- representing N simultaneously-active groups here is
/// out of scope for now.
///
/// ContentState counts UP (elapsed time since the session started),
/// not down to a re-lock instant: a Limit-rule group's re-shield timing
/// is usage-based (see GroupIdentity/GroupActivityMarks in
/// GroupStore.swift), not a fixed wall-clock window, so a countdown to
/// "when this re-locks" would just be guessing at a time that isn't
/// really enforced. An elapsed counter is honest about what's actually
/// happening -- a focus session in progress -- without pretending to a
/// precision we don't have.
struct FocusUpActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var questTitle: String?
        var streak: Int
    }

    /// When the current focus session (first group created) began.
    /// Fixed for the life of the Activity -- ContentState updates never
    /// change this, only questTitle/streak.
    var startedAt: Date
}
