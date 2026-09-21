import SwiftUI

/// The Player screen: the pixel avatar, level + EXP progress, the coin
/// balance, and an upgrade shop where coins buy avatar cosmetics. EXP
/// only drives the level (never spent); coins are the spendable side --
/// both are earned by clearing quests (see CharacterStore.rewardQuest).
/// Codedex-inspired (pixel avatar customization + an XP/level loop),
/// kept in FocusUp's own dark cyan/steel/ember system rather than
/// Codedex's bright palette.
struct CharacterView: View {
    @ObservedObject private var character = CharacterStore.shared
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var shopSlot: AvatarSlot = .robe
    @State private var pendingPurchase: AvatarItem?
    @State private var shopMessage: String?

    var body: some View {
        ZStack {
            PlayerBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    avatarSection
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
        } message: { item in
            Text("You have \(character.coins) coins. It equips right away.")
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
                    .fill(RadialGradient(colors: [PlayerTheme.cyan.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 210, height: 210)
                FireAura(diameter: 190)
                PixelAvatarView(config: character.avatar)
                    .frame(width: 118, height: 131)
                    .padding(24)
                    .background(Color(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255))
                    .clipShape(PixelFrameShape(cut: 14))
                    .overlay(PixelFrameShape(cut: 14).stroke(PlayerTheme.cyan, lineWidth: 3))
                    .shadow(color: PlayerTheme.cyan.opacity(0.25), radius: 14)
            }
            .frame(width: 190, height: 190)

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

    // MARK: - Upgrade shop

    private var upgradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLabel(text: "Upgrades")

            HStack(spacing: 6) {
                ForEach(AvatarSlot.allCases, id: \.self) { slot in
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

            Text("Clear quests to earn coins and EXP -- a medium quest pays 100 EXP and 20 coins, low pays half and high pays 1.5x. EXP raises your level; coins buy upgrades.")
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
                AvatarSwatch(
                    config: character.avatar.setting(item.id, for: item.slot),
                    selected: equipped,
                    dimmed: !owned && !affordable
                )
                Text(item.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PlayerTheme.textPrimary)
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

#Preview {
    NavigationStack { CharacterView() }
}
