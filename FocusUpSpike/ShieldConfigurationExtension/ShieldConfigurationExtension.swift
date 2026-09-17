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
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let goalText = application.token.flatMap { GoalStore.goal(for: $0) }
            ?? "Finish your focus task in FocusUp to unlock this app."

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor.black,
            title: ShieldConfiguration.Label(text: "Not Yet", color: .white),
            subtitle: ShieldConfiguration.Label(text: goalText, color: UIColor.lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white),
            primaryButtonBackgroundColor: UIColor.systemRed,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Override — I finished it", color: UIColor.systemOrange)
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
