//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the system overlay shown when the user opens a shielded app.
/// Looks up the goal text the user set for this specific app (by its
/// opaque token) in the shared App Group store; falls back to a generic
/// message if nothing was saved (e.g. app was shielded before this build).
///
/// Tinted in FocusUp's own cyan-on-dark palette (HunterTheme's bg/cyan/
/// text colors, literal-copied since this target can't import HunterTheme)
/// -- but ShieldConfiguration is a fixed OS template that only accepts flat
/// background/text/button colors plus a static icon, so no glow, gradient,
/// or animation is possible here, unlike the rest of the app.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    // Mirrors HunterTheme's palette (this extension target can't import
    // the main app's HunterTheme.swift, so the values are copied here).
    private static let bg = UIColor(red: 0x05 / 255, green: 0x07 / 255, blue: 0x08 / 255, alpha: 1)
    private static let cyan = UIColor(red: 0x3E / 255, green: 0xE6 / 255, blue: 0xFF / 255, alpha: 1)
    private static let textPrimary = UIColor(red: 0xE8 / 255, green: 0xF6 / 255, blue: 0xFB / 255, alpha: 1)
    private static let textMuted = UIColor(red: 0x7F / 255, green: 0xA7 / 255, blue: 0xB8 / 255, alpha: 1)
    private static let panelDark = UIColor(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255, alpha: 1)

    private static let brandIcon: UIImage? = {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        return UIImage(systemName: "chevron.up.circle.fill", withConfiguration: config)?
            .withTintColor(cyan, renderingMode: .alwaysOriginal)
    }()

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let goalText = application.token.flatMap { GoalStore.goal(for: $0) }
            ?? "Finish your focus task in FocusUp to unlock this app."
        let streak = StatsStore.currentStreak
        let streakLine = streak > 0 ? "Streak: \(streak) day\(streak == 1 ? "" : "s")" : "Start a new streak"
        let subtitleText = "\(goalText)\n\(streakLine)"

        return ShieldConfiguration(
            backgroundColor: Self.bg,
            icon: Self.brandIcon,
            title: ShieldConfiguration.Label(text: "Sealed", color: Self.textPrimary),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: Self.textMuted),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Abandon", color: Self.textPrimary),
            primaryButtonBackgroundColor: Self.panelDark,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Clear Quest — Unlock", color: Self.cyan)
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
