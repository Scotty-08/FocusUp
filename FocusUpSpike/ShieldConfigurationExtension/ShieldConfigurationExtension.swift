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

    /// token is the specific app being shielded, when known -- lets the
    /// headline show the goal text the user typed for THIS app
    /// (GoalStore) instead of always falling back to the active task
    /// title. Web-domain shields have no per-app goal, so they pass nil
    /// and fall straight through to the task/default text.
    private func brandedShield(for token: ApplicationToken?) -> ShieldConfiguration {
        let goal = token.flatMap { GoalStore.goal(for: $0) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let taskTitle = TaskStore.activeTask?.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = [goal, taskTitle].compactMap { $0 }.first { !$0.isEmpty }
            ?? "Your quest comes first."

        let streak = StatsStore.currentStreak
        let streakLine = streak > 0
            ? "\(streakDots(streak))  \(streak)-quest streak"
            : "Stay locked in."

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

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        brandedShield(for: application.token)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        brandedShield(for: application.token)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        brandedShield(for: nil)
    }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        brandedShield(for: nil)
    }
}
