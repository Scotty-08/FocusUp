import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let bg = UIColor(red: 14/255, green: 15/255, blue: 16/255, alpha: 1)  // almost-black, kept neutral (a little grey, no color tint)
    private let cyan = UIColor(red: 115/255, green: 191/255, blue: 202/255, alpha: 1)  // same hue, desaturated well off neon
    private let ink = UIColor(red: 226/255, green: 229/255, blue: 231/255, alpha: 1)
    private let inkDim = UIColor(red: 180/255, green: 184/255, blue: 187/255, alpha: 1)
    private let deadRust = UIColor(red: 146/255, green: 94/255, blue: 79/255, alpha: 1)  // pulled further toward grey -- duller, "deader" rust

    /// Every shield uses the same approved look (the blocker concept): a
    /// solid near-black background, the Shutter mark, "FocusUp" title,
    /// context + quest + streak in the subtitle, a cyan primary button with
    /// dark text, and a quiet secondary button. No `backgroundBlurStyle` --
    /// the system material blur is what made the shield read as flat grey
    /// on device instead of near-black. The system still owns the layout,
    /// fonts and pill-shaped buttons; only colors, text and icon are ours.
    private func shield(subtitle: String, primary: String, secondary: ShieldConfiguration.Label?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "FocusUp", color: ink),
            subtitle: .init(text: subtitle, color: inkDim),
            primaryButtonLabel: .init(text: primary, color: bg),
            primaryButtonBackgroundColor: cyan,
            secondaryButtonLabel: secondary
        )
    }

    /// Small filled/outline dot row, e.g. "●●●○○" for a 3-quest streak,
    /// capped visually at 5. Same "progress at a glance" visual language
    /// ScreenZen uses for its per-app check counter -- repurposed here
    /// for OUR actual stat (session streak, see StatsStore) since we
    /// don't track a per-app daily check limit the way it does.
    private func streakDots(_ streak: Int) -> String {
        let capped = min(max(streak, 0), 5)
        let filled = String(repeating: "●", count: capped)
        let empty = String(repeating: "○", count: 5 - capped)
        return filled + empty
    }

    private var streakLine: String {
        let streak = StatsStore.currentStreak
        return streak > 0 ? "\(streakDots(streak))  \(streak)-quest streak" : "Stay locked in."
    }

    /// The single most pressing open quest (TaskStore.mostPressingTask:
    /// highest priority, then earliest deadline) -- groups no longer
    /// link to one specific task (see AppGroup), so both blockShield and
    /// reminderShield name this same pick rather than a per-group one.
    /// Shown as one line rather than a list: the system controls the
    /// actual shield layout (SHIELD_DESIGN.md), and naming exactly the
    /// quest FocusUp itself will ask about next (see
    /// FamilyControlsManager.presentPressingQuestCheckIn) keeps the
    /// shield and the in-app check-in consistent about which quest is
    /// "the" one right now.
    private var pressingQuest: FocusTask? {
        TaskStore.mostPressingTask(from: TaskStore.loadTasks())
    }

    /// Every shield this app shows is one of exactly three shapes now:
    /// a Block-rule lockout gated on the most pressing quest, a
    /// Limit-rule reminder nudge (dismissable), or a Limit-rule budget
    /// lockout (not dismissable -- see ShieldActionExtension). `token`
    /// resolves back to the owning AppGroup; web-domain shields and
    /// orphaned tokens fall through to a neutral default since groups
    /// only ever select app tokens.
    private func brandedShield(for token: ApplicationToken?) -> ShieldConfiguration {
        guard let token, let group = GroupStore.group(containing: token) else {
            return defaultShield()
        }
        let reason = GroupRuntimeState.shieldReason(for: group.id)
        switch (group.rule.kind, reason) {
        case (.limit, .limitReminder):
            return reminderShield(group: group)
        case (.limit, .limitBudgetExceeded):
            return lockoutShield(group: group)
        default:
            // .block, or a Limit group with no reason recorded yet
            // (shouldn't happen -- defensive fallback to the block copy
            // rather than a blank shield).
            return blockShield()
        }
    }

    /// A real lockout -- unlike the Limit-rule shields below, neither
    /// button here releases anything (see ShieldActionExtension.
    /// handleBlock): "Open Quests" always just routes to the Quests tab,
    /// whether or not there's a quest to name right now, since that's
    /// also where you'd go add one. Blocking is deliberately NOT gated
    /// on a quest existing -- it stays blocked either way, only
    /// releasing when a quest is actually completed (see
    /// GroupStore.unshieldAllBlockGroups).
    private func blockShield() -> ShieldConfiguration {
        let headline: String
        if let task = pressingQuest {
            headline = "Complete this quest to unlock:\n\(task.title)"
        } else {
            headline = "No quests yet. Add one and complete it to unlock."
        }
        return shield(subtitle: "\(headline)\n\(streakLine)",
                      primary: "Open Quests",
                      secondary: .init(text: "Give up", color: deadRust))
    }

    /// A dismissable nudge, not a lockout. When there's an open quest,
    /// the primary button becomes "Open Quests" and routes to FocusUp's
    /// Quests tab instead of just dismissing (see
    /// ShieldActionExtension.handleLimit's matching primaryButtonPressed
    /// + open-quests case) -- "Dismiss" (secondary) always stays a plain
    /// dismiss either way. With no quests open at all, both buttons just
    /// dismiss, labeled "Continue"/"Dismiss" as before.
    ///
    /// Names the single most pressing quest (see `pressingQuest`), not a
    /// list -- the in-app check-in this leads to (see
    /// FamilyControlsManager.presentPressingQuestCheckIn) asks about
    /// that exact same quest, so the shield and the check-in always
    /// agree on which one is "the" quest right now.
    private func reminderShield(group: AppGroup) -> ShieldConfiguration {
        // Only while the pause is still running. A pause that's over
        // renders the ORIGINAL reminder -- that's what gets drawn in the
        // hand-off redraw right before the user is let in (see
        // ShieldActionExtension.finishPause), so it's the screen iOS
        // keeps for the next reminder instead of the pause screen.
        if let pause = GroupRuntimeState.pause(for: group.id), pause.endsAt > Date() {
            return pauseShield(endsAt: pause.endsAt)
        }
        // Same shape as the block shield (context line, quest, streak) so
        // every shield reads the same; the buttons carry the "check in or
        // keep going" choice instead of a long sentence.
        let headline: String
        let primaryLabel: String
        if let task = pressingQuest {
            headline = "Still on this quest?\n\(task.title)"
            primaryLabel = "Open Quests"
        } else {
            // No quests at all to remind about -- ask the reflective
            // question instead of just saying nothing to check on. The
            // nudge should still make you pause even with nothing open.
            headline = "Why am I opening \(group.name)?"
            primaryLabel = "Continue"
        }
        return shield(subtitle: "\(headline)\n\(streakLine)",
                      primary: primaryLabel,
                      secondary: .init(text: "Dismiss", color: inkDim))
    }

    /// Shown while a dismiss pause is counting down (see
    /// ShieldActionExtension.startOrCheckPause). Just the one line, no
    /// subtitle -- the number is worked out fresh from the stored end
    /// time every time iOS asks for this shield, which it does after
    /// each Dismiss (`.defer`); the shield can't tick on its own, so it
    /// only updates on tap. The buttons keep their labels because they
    /// still work: "Open Quests" is the better way out, and Dismiss
    /// after the pause lets the user in if the app didn't already open
    /// on its own.
    private func pauseShield(endsAt: Date) -> ShieldConfiguration {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
        let hasQuest = pressingQuest != nil
        return ShieldConfiguration(
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "You will be able to use your app after \(remaining) seconds", color: ink),
            subtitle: nil,
            primaryButtonLabel: .init(text: hasQuest ? "Open Quests" : "Continue", color: bg),
            primaryButtonBackgroundColor: cyan,
            secondaryButtonLabel: .init(text: "Dismiss", color: inkDim)
        )
    }

    /// The daily budget is used up -- neither shield button releases
    /// the app (see ShieldActionExtension), so this deliberately has no
    /// "unlock" framing. Whether ShieldConfiguration's secondary button
    /// can be cleanly omitted/hidden per-shield-instance isn't proven on
    /// this Apple SDK version -- check on device; nil is passed here on
    /// the assumption it renders as a single-button shield, not a
    /// mislabeled one.
    private func lockoutShield(group: AppGroup) -> ShieldConfiguration {
        shield(subtitle: "Daily limit reached for \(group.name).\nIt unlocks with tomorrow's budget or its free window.\n\(streakLine)",
               primary: "Got it",
               secondary: nil)
    }

    private func defaultShield() -> ShieldConfiguration {
        shield(subtitle: "Your quest comes first.\n\(streakLine)",
               primary: "Open Quests",
               secondary: .init(text: "Give up", color: deadRust))
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        brandedShield(for: application.token)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        brandedShield(for: application.token)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        defaultShield()
    }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        defaultShield()
    }
}
