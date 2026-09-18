import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let bg = UIColor(red: 5/255, green: 7/255, blue: 8/255, alpha: 1)
    private let cyan = UIColor(red: 62/255, green: 230/255, blue: 1, alpha: 1)

    private func brandedShield() -> ShieldConfiguration {
        let title = TaskStore.activeTask?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = title.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Your quest comes first.\nReturn when you’re ready."
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: bg,
            icon: FocusUpEmblem.image,
            title: .init(text: "FocusUp", color: UIColor(red: 232/255, green: 246/255, blue: 251/255, alpha: 1)),
            subtitle: .init(text: subtitle, color: UIColor(red: 171/255, green: 193/255, blue: 202/255, alpha: 1)),
            primaryButtonLabel: .init(text: "Open Quest", color: bg),
            primaryButtonBackgroundColor: cyan,
            secondaryButtonLabel: .init(text: "Keep it blocked", color: .white)
        )
    }
    override func configuration(shielding application: Application) -> ShieldConfiguration { brandedShield() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { brandedShield() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { brandedShield() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { brandedShield() }
}
