import Combine
import SwiftUI
import RiveRuntime

/// The player's animated companion, rendered with Rive.
///
/// Rive is presentation only: Swift stays the source of truth for what the
/// player owns and has equipped (CharacterStore / AvatarConfig). This view
/// just picks the companion's artboard and translates the equipped items
/// into its state machine inputs.
///
/// All companions live in one file, Companions/companions.riv, built from
/// avatar-companions/ at the repo root (tools/companions.py). Every
/// artboard's state machine takes the same inputs:
///   eyes, cloak, boots, augment -- Numbers, see AvatarItem.rigIndex
///   skin, hair                  -- Numbers, human artboards only
///   calm                        -- Bool; holds still (Reduce Motion)
///   wave                        -- Trigger; tapping the face also fires it
/// If the file can't load, the companion's static portrait is shown instead.
struct CompanionAvatarView: View {
    let config: AvatarConfig

    var body: some View {
        let species = CompanionCatalog.species(config.species)
        // A new artboard needs a new Rive view model, so the view is
        // rebuilt whenever the companion changes.
        CompanionRiveView(species: species, config: config)
            .id(species.artboard)
            .aspectRatio(CompanionRig.aspectRatio, contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel("Your companion, \(species.name.lowercased())")
            .accessibilityHint("Tap its face to wave")
    }
}

private struct CompanionRiveView: View {
    let species: CompanionSpecies
    let config: AvatarConfig

    @StateObject private var rig: CompanionRig
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(species: CompanionSpecies, config: AvatarConfig) {
        self.species = species
        self.config = config
        _rig = StateObject(wrappedValue: CompanionRig(artboard: species.artboard))
    }

    var body: some View {
        if let rive = rig.viewModel {
            rive.view()
                .onAppear {
                    apply(to: rive)
                    rive.play()
                }
                // No reason to keep animating a companion nobody can see.
                .onDisappear { rive.pause() }
                .onChange(of: config) { _, _ in
                    apply(to: rive)
                    // A little celebration whenever the look changes.
                    if !reduceMotion { rive.triggerInput("wave") }
                }
                .onChange(of: reduceMotion) { _, _ in apply(to: rive) }
        } else {
            Image(CompanionCatalog.portraitName(for: config))
                .resizable()
                .scaledToFit()
        }
    }

    private func apply(to rive: RiveViewModel) {
        rive.setInput("eyes", value: rigValue(.eyes))
        rive.setInput("cloak", value: rigValue(.cloak))
        rive.setInput("boots", value: rigValue(.boots))
        rive.setInput("augment", value: rigValue(.augment))
        // Only the human artboards have these inputs.
        if species.isHuman {
            rive.setInput("skin", value: Double(config.skin))
            rive.setInput("hair", value: Double(config.hair))
        }
        rive.setInput("calm", value: reduceMotion)
    }

    private func rigValue(_ slot: AvatarSlot) -> Double {
        let item = AvatarCatalog.item(config.itemID(for: slot))
            ?? AvatarCatalog.item(AvatarConfig.starter.itemID(for: slot))
        return Double(item?.rigIndex ?? 0)
    }
}

/// Owns the Rive view model for one artboard so it survives SwiftUI view
/// updates. Loading can fail (missing or corrupt asset); `viewModel` is nil
/// in that case.
@MainActor
final class CompanionRig: ObservableObject {
    static let fileName = "companions"
    static let stateMachineName = "State Machine 1"
    /// Every companion artboard is 400 x 460.
    static let aspectRatio: CGFloat = 400.0 / 460.0

    let viewModel: RiveViewModel?

    init(artboard: String) {
        if let model = try? RiveModel(fileName: Self.fileName) {
            viewModel = RiveViewModel(
                model,
                stateMachineName: Self.stateMachineName,
                fit: .contain,
                alignment: .bottomCenter,
                artboardName: artboard
            )
        } else {
            viewModel = nil
        }
    }
}
