import SwiftUI

/// Pixel-art "Hunter" character sheet -- level, XP, three stats derived
/// from real quest/streak data, and a small loadout (aura, title,
/// cloak color). Codedex-inspired (pixel avatar customization + an
/// XP/level/rank/badge loop), kept in FocusUp's own dark cyan/steel/
/// ember system rather than Codedex's bright palette.
struct CharacterView: View {
    @ObservedObject private var character = CharacterStore.shared
    @State private var isRenaming = false
    @State private var renameText = ""

    var body: some View {
        ZStack {
            HunterBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    avatarSection
                    statsSection
                    loadoutSection
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Hunter")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Hunter", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Save") { character.rename(renameText) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            HUDLabel(text: "Hunter Profile")
            Spacer()
            Text("LV.\(character.level)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(HunterTheme.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PixelFrameShape(cut: 6).fill(HunterTheme.panelFill))
                .overlay(PixelFrameShape(cut: 6).stroke(HunterTheme.cyanDim, lineWidth: 1))
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [HunterTheme.cyan.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 210, height: 210)
                FireAura(diameter: 190)
                PixelAvatarView(cloak: character.cloak)
                    .frame(width: 118, height: 111)
                    .padding(24)
                    .background(Color(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255))
                    .clipShape(PixelFrameShape(cut: 14))
                    .overlay(PixelFrameShape(cut: 14).stroke(HunterTheme.cyan, lineWidth: 3))
                    .shadow(color: HunterTheme.cyan.opacity(0.25), radius: 14)
            }
            .frame(width: 168, height: 168)

            HStack(spacing: 8) {
                Text(character.name)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(HunterTheme.textPrimary)
                Button {
                    renameText = character.name
                    isRenaming = true
                } label: {
                    Text("RENAME")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(HunterTheme.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .hudPanel()
            }

            VStack(spacing: 4) {
                SegmentedBar(fraction: character.xpProgress, color: HunterTheme.cyan, height: 12)
                    .frame(maxWidth: 260)
                Text("\(character.xpIntoLevel) / \(CharacterStore.xpPerLevel) XP TO LEVEL \(character.level + 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(HunterTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HUDLabel(text: "Stats")
                Spacer()
                if character.unspentPoints > 0 {
                    Text("\(character.unspentPoints) POINT\(character.unspentPoints == 1 ? "" : "S") TO SPEND")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HunterTheme.gold)
                }
            }

            statRow(label: "Focus", value: character.focusStat, color: HunterTheme.cyan, stat: .focus)
            statRow(label: "Discipline", value: character.disciplineStat, color: HunterTheme.steel, stat: .discipline)
            statRow(label: "Consistency", value: character.consistencyStat, color: HunterTheme.emberOrange, stat: nil)

            Text("Stats track how you actually play: Focus from cleared quests, Discipline from seals you didn't break, Consistency from your streak.")
                .font(.system(size: 10))
                .foregroundStyle(HunterTheme.textMuted)
        }
    }

    private func statRow(label: String, value: Int, color: Color, stat: HunterStat?) -> some View {
        HStack(spacing: 10) {
            HUDLabel(text: label, size: 9, color: color)
                .frame(width: 78, alignment: .leading)
            SegmentedBar(fraction: character.fraction(for: value), color: color, height: 10)
            Text("\(value)")
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 22, alignment: .trailing)
            if let stat {
                Button {
                    character.spendPoint(on: stat)
                } label: {
                    Text("+")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(color)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .hudPanel(borderColor: color.opacity(0.4), cornerAccent: color)
                .disabled(character.unspentPoints == 0)
                .opacity(character.unspentPoints == 0 ? 0.35 : 1)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }
        }
    }

    private var loadoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HUDLabel(text: "Loadout")

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(HunterTheme.emberOrange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ember Wisp").font(.system(size: 10, weight: .bold)).foregroundStyle(HunterTheme.textPrimary)
                        Text("AURA \u{00B7} EQUIPPED").font(.system(size: 9)).foregroundStyle(HunterTheme.textMuted)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hudPanel()

                VStack(alignment: .leading, spacing: 1) {
                    Text(character.nextTitle.name).font(.system(size: 10, weight: .bold)).foregroundStyle(HunterTheme.textPrimary)
                    Text("TITLE \u{00B7} UNLOCKS LV.\(character.nextTitle.unlockLevel)").font(.system(size: 9)).foregroundStyle(HunterTheme.textMuted)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hudPanel()
                .opacity(0.55)
            }

            HStack(spacing: 8) {
                HUDLabel(text: "Cloak", size: 9, color: HunterTheme.textMuted)
                ForEach(CloakColor.allCases, id: \.self) { c in
                    let unlocked = c.unlockLevel <= character.level
                    Button {
                        character.setCloak(c)
                    } label: {
                        Circle()
                            .fill(c.color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(character.cloak == c ? Color.white : Color.white.opacity(0.15), lineWidth: 2)
                            )
                            .overlay {
                                if !unlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .opacity(unlocked ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityLabel("\(c.label) cloak\(unlocked ? "" : ", locked until level \(c.unlockLevel)")")
                }
            }
        }
    }
}

/// A small vector-pixel hunter, drawn as crisp rects on a 16x15 grid --
/// no image assets. The bottom hem row picks up the equipped cloak
/// color so customization actually shows on the character.
private struct PixelCell {
    let x: Int, y: Int, w: Int
    let color: Color
}

struct PixelAvatarView: View {
    let cloak: CloakColor
    private let gridWidth = 16
    private let gridHeight = 15

    private var cells: [PixelCell] {
        let body = Color(red: 0x16 / 255, green: 0x23 / 255, blue: 0x2F / 255)
        let eye = HunterTheme.cyan
        return [
            PixelCell(x: 7, y: 0, w: 2, color: body),
            PixelCell(x: 6, y: 1, w: 4, color: body),
            PixelCell(x: 6, y: 2, w: 4, color: body),
            PixelCell(x: 5, y: 3, w: 6, color: body),
            PixelCell(x: 5, y: 4, w: 6, color: body),
            PixelCell(x: 5, y: 5, w: 1, color: body),
            PixelCell(x: 6, y: 5, w: 1, color: eye),
            PixelCell(x: 7, y: 5, w: 2, color: body),
            PixelCell(x: 9, y: 5, w: 1, color: eye),
            PixelCell(x: 10, y: 5, w: 1, color: body),
            PixelCell(x: 5, y: 6, w: 6, color: body),
            PixelCell(x: 4, y: 7, w: 8, color: body),
            PixelCell(x: 3, y: 8, w: 10, color: body),
            PixelCell(x: 3, y: 9, w: 10, color: body),
            PixelCell(x: 2, y: 10, w: 12, color: body),
            PixelCell(x: 2, y: 11, w: 12, color: body),
            PixelCell(x: 1, y: 12, w: 14, color: body),
            PixelCell(x: 1, y: 13, w: 14, color: body),
            PixelCell(x: 0, y: 14, w: 16, color: cloak.color),
        ]
    }

    var body: some View {
        Canvas { context, size in
            let unit = size.width / CGFloat(gridWidth)
            for cell in cells {
                let rect = CGRect(x: CGFloat(cell.x) * unit, y: CGFloat(cell.y) * unit, width: CGFloat(cell.w) * unit, height: unit)
                context.fill(Path(rect), with: .color(cell.color))
            }
        }
        .aspectRatio(CGFloat(gridWidth) / CGFloat(gridHeight), contentMode: .fit)
        .accessibilityLabel("Pixel hunter avatar")
    }
}

#Preview {
    NavigationStack { CharacterView() }
}
