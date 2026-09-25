import SwiftUI

/// The Player screen: the animated companion, level + EXP progress, the
/// coin balance, the companion picker, and the upgrade shop.
///
/// EXP only drives the level (never spent); coins are the spendable side --
/// both are earned by clearing quests (see CharacterStore.rewardQuest).
/// Companions unlock by level or cost coins (CompanionCatalog); cosmetics
/// (eyes, cloak, boots, extras) cost coins and fit every companion.
/// Tapping something you'd buy previews it on the companion first.
struct CharacterView: View {
    @ObservedObject private var character = CharacterStore.shared
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var shopSlot: AvatarSlot = .eyes
    @State private var pendingPurchase: AvatarItem?
    @State private var pendingCompanion: CompanionSpecies?
    @State private var shopMessage: String?
    @State private var companionMessage: String?

    private var currentSpecies: CompanionSpecies { CompanionCatalog.species(character.avatar.species) }

    /// What the big companion shows: a try-on while a purchase is being
    /// confirmed, otherwise what's equipped.
    private var shownConfig: AvatarConfig {
        if let item = pendingPurchase { return character.avatar.setting(item.id, for: item.slot) }
        if let species = pendingCompanion { return character.avatar.withSpecies(species.id) }
        return character.avatar
    }

    var body: some View {
        ZStack {
            PlayerBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    avatarSection
                    companionsSection
                    if currentSpecies.isHuman {
                        lookSection
                    }
                    upgradesSection
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Player", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Save") { character.rename(renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            pendingPurchase.map { "Buy \($0.name) \($0.slot.label.lowercased())?" } ?? "",
            isPresented: Binding(
                get: { pendingPurchase != nil },
                set: { if !$0 { pendingPurchase = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingPurchase
        ) { item in
            Button("Buy for \(item.cost) coins") {
                character.buy(item)
                shopMessage = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You have \(character.coins) coins. It equips right away.")
        }
        .confirmationDialog(
            pendingCompanion.map { "Unlock the \($0.name)?" } ?? "",
            isPresented: Binding(
                get: { pendingCompanion != nil },
                set: { if !$0 { pendingCompanion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingCompanion
        ) { species in
            if case .coins(let price) = species.unlock {
                Button("Unlock for \(price) coins") {
                    character.buy(species)
                    companionMessage = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You have \(character.coins) coins. Your eyes, cloak, boots and extras come with you.")
        }
    }

    private var header: some View {
        HStack {
            HUDLabel(text: "Player Profile")
            Spacer()
            Text("LV.\(character.level)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(PlayerTheme.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PixelFrameShape(cut: 6).fill(PlayerTheme.panelFill))
                .overlay(PixelFrameShape(cut: 6).stroke(PlayerTheme.cyanDim, lineWidth: 1))
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [PlayerTheme.cyan.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 130))
                    .frame(width: 250, height: 250)
                CompanionAvatarView(config: shownConfig)
                    .frame(width: 214, height: 246)
            }
            .frame(width: 250, height: 250)

            HStack(spacing: 8) {
                Text(character.name)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(PlayerTheme.textPrimary)
                Button {
                    renameText = character.name
                    isRenaming = true
                } label: {
                    Text("RENAME")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(PlayerTheme.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .hudPanel()
            }

            VStack(spacing: 4) {
                SegmentedBar(fraction: character.xpProgress, color: PlayerTheme.cyan, height: 12)
                    .frame(maxWidth: 260)
                Text("\(character.xpIntoLevel) / \(CharacterStore.xpPerLevel) EXP TO LEVEL \(character.level + 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(PlayerTheme.textMuted)
            }

            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(PlayerTheme.gold)
                Text("\(character.coins) COINS")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(PlayerTheme.gold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .hudPanel(borderColor: PlayerTheme.gold.opacity(0.5), cornerAccent: PlayerTheme.gold)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Companions

    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HUDLabel(text: "Companions")
                Spacer()
                let unlocked = CompanionCatalog.all.filter { character.isUnlocked($0) }.count
                Text("\(unlocked) / \(CompanionCatalog.all.count) UNLOCKED")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(PlayerTheme.textMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(CompanionCatalog.all) { species in
                        companionCard(species)
                    }
                }
                .padding(.vertical, 2)
            }

            if let companionMessage {
                Text(companionMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.emberOrange)
            }
        }
    }

    private func companionCard(_ species: CompanionSpecies) -> some View {
        let unlocked = character.isUnlocked(species)
        let equipped = character.avatar.species == species.id
        let label = species.isHuman ? (species.id == "human.female" ? "Human F" : "Human M") : species.name
        return Button {
            tapCompanion(species)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Image(CompanionCatalog.portraitName(species: species, skin: character.avatar.skin,
                                                        cloakItemID: character.avatar.cloak))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 1 : 0.4)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PlayerTheme.textPrimary.opacity(0.85))
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .lineLimit(1)
                Group {
                    if equipped {
                        Text("EQUIPPED").foregroundStyle(PlayerTheme.cyan)
                    } else if unlocked {
                        Text("EQUIP").foregroundStyle(PlayerTheme.textMuted)
                    } else {
                        switch species.unlock {
                        case .level(let needed):
                            Text("LV \(needed)").foregroundStyle(PlayerTheme.cyan.opacity(0.8))
                        case .coins(let price):
                            Text("\(price)").foregroundStyle(character.coins >= price ? PlayerTheme.gold : PlayerTheme.textMuted)
                        case .starter:
                            Text("")
                        }
                    }
                }
                .font(.system(size: 9, weight: .heavy))
            }
            .frame(width: 84)
            .padding(.vertical, 8)
            .hudPanel(
                borderColor: equipped ? PlayerTheme.cyanDim : Color.white.opacity(0.06),
                cornerAccent: equipped ? PlayerTheme.cyan : .clear
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(equipped ? ", equipped" : unlocked ? ", unlocked" : ", locked")")
    }

    private func tapCompanion(_ species: CompanionSpecies) {
        companionMessage = nil
        if character.isUnlocked(species) {
            character.selectSpecies(species)
            return
        }
        switch species.unlock {
        case .level(let needed):
            companionMessage = "The \(species.name) unlocks at level \(needed) -- you're level \(character.level). Clear quests to level up."
        case .coins(let price):
            if character.coins >= price {
                pendingCompanion = species
            } else {
                companionMessage = "The \(species.name) costs \(price) coins -- you need \(price - character.coins) more. Clear quests to earn them."
            }
        case .starter:
            break
        }
    }

    // MARK: - Human look

    private var lookSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLabel(text: "Look")
            swatchRow(title: "Skin", colors: CompanionCatalog.skinTones.map { $0.color },
                      names: CompanionCatalog.skinTones.map { $0.name }, selected: character.avatar.skin) {
                character.setSkin($0)
            }
            swatchRow(title: "Hair", colors: CompanionCatalog.hairColors.map { $0.color },
                      names: CompanionCatalog.hairColors.map { $0.name }, selected: character.avatar.hair) {
                character.setHair($0)
            }
        }
    }

    private func swatchRow(title: String, colors: [Color], names: [String], selected: Int,
                           pick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(PlayerTheme.textMuted)
                .frame(width: 38, alignment: .leading)
            ForEach(colors.indices, id: \.self) { i in
                Button { pick(i) } label: {
                    Circle()
                        .fill(colors[i])
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(i == selected ? PlayerTheme.cyan : Color.white.opacity(0.15),
                                                 lineWidth: i == selected ? 3 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(names[i]) \(title.lowercased())\(i == selected ? ", selected" : "")")
            }
        }
    }

    // MARK: - Upgrade shop

    private var upgradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLabel(text: "Upgrades")

            HStack(spacing: 6) {
                ForEach(AvatarSlot.companionSlots, id: \.self) { slot in
                    slotTab(slot)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(AvatarCatalog.items(in: shopSlot)) { item in
                    itemCard(item)
                }
            }

            if let shopMessage {
                Text(shopMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(PlayerTheme.emberOrange)
            }

            Text("Clear quests to earn coins and EXP -- a medium quest pays 100 EXP and 20 coins, low pays half and high pays 1.5x. EXP raises your level and unlocks companions; coins buy upgrades and the rarer companions. Everything you buy fits every companion.")
                .font(.system(size: 10))
                .foregroundStyle(PlayerTheme.textMuted)
        }
    }

    private func slotTab(_ slot: AvatarSlot) -> some View {
        let selected = shopSlot == slot
        return Button {
            shopSlot = slot
            shopMessage = nil
        } label: {
            Text(slot.label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(selected ? PlayerTheme.bg : PlayerTheme.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(selected ? PlayerTheme.cyan : PlayerTheme.cyan.opacity(0.08))
                .overlay(Rectangle().strokeBorder(PlayerTheme.cyanDim, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func itemCard(_ item: AvatarItem) -> some View {
        let owned = character.isOwned(item)
        let equipped = character.isEquipped(item)
        let affordable = character.coins >= item.cost
        return Button {
            tap(item)
        } label: {
            VStack(spacing: 6) {
                ItemIcon(item: item, selected: equipped, dimmed: !owned && !affordable)
                Text(item.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PlayerTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if equipped {
                    Text("EQUIPPED")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(PlayerTheme.cyan)
                } else if owned {
                    Text("EQUIP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PlayerTheme.textMuted)
                } else {
                    Text("\(item.cost) COINS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(affordable ? PlayerTheme.gold : PlayerTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .hudPanel(
                borderColor: equipped ? PlayerTheme.cyanDim : Color.white.opacity(0.06),
                cornerAccent: equipped ? PlayerTheme.cyan : .clear
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name) \(item.slot.label)\(equipped ? ", equipped" : owned ? ", owned" : ", \(item.cost) coins")")
    }

    private func tap(_ item: AvatarItem) {
        shopMessage = nil
        if character.isOwned(item) {
            character.equip(item)
        } else if character.coins >= item.cost {
            pendingPurchase = item
        } else {
            shopMessage = "Not enough coins for \(item.name) -- you need \(item.cost - character.coins) more. Clear quests to earn them."
        }
    }
}

/// A shop item's icon on a dark framed tile.
struct ItemIcon: View {
    let item: AvatarItem
    var selected = false
    var dimmed = false

    var body: some View {
        Group {
            if let icon = item.iconName {
                Image(icon).resizable().scaledToFit()
            } else {
                Circle().fill(item.color ?? PlayerTheme.cyan).padding(12)
            }
        }
        .frame(width: 50, height: 50)
        .padding(6)
        .background(Color(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255))
        .clipShape(PixelFrameShape(cut: 6))
        .overlay(
            PixelFrameShape(cut: 6)
                .stroke(selected ? PlayerTheme.cyan : PlayerTheme.cyanDim, lineWidth: selected ? 2 : 1)
        )
        .opacity(dimmed ? 0.45 : 1)
    }
}

#Preview {
    NavigationStack { CharacterView() }
}
