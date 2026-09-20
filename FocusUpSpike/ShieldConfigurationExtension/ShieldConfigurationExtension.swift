import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let bg = UIColor(red: 14/255, green: 15/255, blue: 16/255, alpha: 1)  // almost-black, kept neutral (a little grey, no color tint)
    private let cyan = UIColor(red: 115/255, green: 191/255, blue: 202/255, alpha: 1)  // same hue, desaturated well off neon
    private let ink = UIColor(red: 226/255, green: 229/255, blue: 231/255, alpha: 1)
    private let inkDim = UIColor(red: 180/255, green: 184/255, blue: 187/255, alpha: 1)
    private let deadRust = UIColor(red: 146/255, green: 94/255, blue: 79/255, alpha: 1)  // pulled further toward grey -- duller, "deader" rust

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

    private func taskTitle(for group: AppGroup) -> String? {
        guard let taskID = group.taskID else { return nil }
        return TaskStore.loadTasks().first { $0.id == taskID }?.title
    }

    /// Every shield this app shows is one of exactly three shapes now:
    /// a Block-rule lockout gated on a task, a Limit-rule reminder nudge
    /// (dismissable), or a Limit-rule budget lockout (not dismissable --
    /// see ShieldActionExtension). `token` resolves back to the owning
    /// AppGroup; web-domain shields and orphaned tokens fall through to
    /// a neutral default since groups only ever select app tokens.
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
            return blockShield(group: group)
        }
    }

    private func blockShield(group: AppGroup) -> ShieldConfiguration {
        let headline = taskTitle(for: group) ?? "Your quest comes first."
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "FocusUp", color: ink),
            subtitle: .init(text: "\(headline)\n\(streakLine)", color: inkDim),
            primaryButtonLabel: .init(text: "Open Quest", color: bg),
            primaryButtonBackgroundColor: cyan,
            secondaryButtonLabel: .init(text: "Give up", color: deadRust)
        )
    }

    /// A dismissable nudge, not a lockout -- copy and button labels make
    /// clear tapping through just continues, it doesn't complete
    /// anything. See ShieldActionExtension.handleLimit: both buttons
    /// behave identically here.
    private func reminderShield(group: AppGroup) -> ShieldConfiguration {
        let task = taskTitle(for: group)
        let headline = task.map { "Still on \u{201C}\($0)\u{201D}?" } ?? "Quick check-in."
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "FocusUp", color: ink),
            subtitle: .init(text: "\(headline)\nTap Continue to keep using \(group.name).", color: inkDim),
            primaryButtonLabel: .init(text: "Continue", color: bg),
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
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "FocusUp", color: ink),
            subtitle: .init(text: "Daily limit reached for \(group.name).\nIt unlocks again with tomorrow's budget (or its free window, if it has one).", color: inkDim),
            primaryButtonLabel: .init(text: "Got it", color: bg),
            primaryButtonBackgroundColor: deadRust,
            secondaryButtonLabel: nil
        )
    }

    private func defaultShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "FocusUp", color: ink),
            subtitle: .init(text: "Your quest comes first.\n\(streakLine)", color: inkDim),
            primaryButtonLabel: .init(text: "Open Quest", color: bg),
            primaryButtonBackgroundColor: cyan,
            secondaryButtonLabel: .init(text: "Give up", color: deadRust)
        )
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
