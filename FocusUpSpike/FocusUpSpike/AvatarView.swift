import SwiftUI

/// The player's pixel avatar, drawn as crisp rects on a 16x18 grid -- no
/// image assets. Robe, eye, and hem (cloak) colors and the headwear
/// shape all come from the AvatarConfig, so customization actually shows
/// on the character.
struct PixelAvatarView: View {
    let config: AvatarConfig

    private let gridWidth = 16
    private let gridHeight = 18

    private struct Cell {
        let x: Int, y: Int, w: Int
        let color: Color
    }

    private static let fallbackRobe = Color(red: 0x16 / 255, green: 0x23 / 255, blue: 0x2F / 255)

    private var cells: [Cell] {
        let robe = AvatarCatalog.item(config.robe)?.color ?? Self.fallbackRobe
        let eye = AvatarCatalog.item(config.eyes)?.color ?? PlayerTheme.cyan
        let hem = AvatarCatalog.item(config.cloak)?.color ?? PlayerTheme.cyan

        // Body rows (y is already offset by 3 to leave room for headwear).
        var result: [Cell] = [
            Cell(x: 7, y: 3, w: 2, color: robe),
            Cell(x: 6, y: 4, w: 4, color: robe),
            Cell(x: 6, y: 5, w: 4, color: robe),
            Cell(x: 5, y: 6, w: 6, color: robe),
            Cell(x: 5, y: 7, w: 6, color: robe),
            Cell(x: 5, y: 8, w: 1, color: robe),
            Cell(x: 6, y: 8, w: 1, color: eye),
            Cell(x: 7, y: 8, w: 2, color: robe),
            Cell(x: 9, y: 8, w: 1, color: eye),
            Cell(x: 10, y: 8, w: 1, color: robe),
            Cell(x: 5, y: 9, w: 6, color: robe),
            Cell(x: 4, y: 10, w: 8, color: robe),
            Cell(x: 3, y: 11, w: 10, color: robe),
            Cell(x: 3, y: 12, w: 10, color: robe),
            Cell(x: 2, y: 13, w: 12, color: robe),
            Cell(x: 2, y: 14, w: 12, color: robe),
            Cell(x: 1, y: 15, w: 14, color: robe),
            Cell(x: 1, y: 16, w: 14, color: robe),
            Cell(x: 0, y: 17, w: 16, color: hem),
        ]

        let bone = Color(red: 0xE8 / 255, green: 0xE2 / 255, blue: 0xD0 / 255)
        let gold = PlayerTheme.gold
        switch AvatarCatalog.item(config.headwear)?.headwear ?? Headwear.none {
        case .none:
            break
        case .horns:
            result += [
                Cell(x: 4, y: 2, w: 1, color: bone), Cell(x: 5, y: 3, w: 1, color: bone), Cell(x: 5, y: 4, w: 1, color: bone),
                Cell(x: 11, y: 2, w: 1, color: bone), Cell(x: 10, y: 3, w: 1, color: bone), Cell(x: 10, y: 4, w: 1, color: bone),
            ]
        case .crown:
            result += [
                Cell(x: 6, y: 1, w: 1, color: gold), Cell(x: 8, y: 1, w: 1, color: gold), Cell(x: 10, y: 1, w: 1, color: gold),
                Cell(x: 6, y: 2, w: 5, color: gold),
            ]
        case .halo:
            let glow = gold.opacity(0.9)
            result += [
                Cell(x: 6, y: 0, w: 4, color: glow),
                Cell(x: 5, y: 1, w: 1, color: glow), Cell(x: 10, y: 1, w: 1, color: glow),
                Cell(x: 6, y: 2, w: 4, color: glow),
            ]
        }
        return result
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
        .accessibilityLabel("Pixel player avatar")
    }
}

/// A small framed avatar preview, used as the tappable swatch for each
/// customization option (first-run creator and the upgrade shop) so every
/// option shows exactly what it would look like on the player.
struct AvatarSwatch: View {
    let config: AvatarConfig
    var selected = false
    var dimmed = false

    var body: some View {
        PixelAvatarView(config: config)
            .frame(width: 34, height: 38)
            .padding(8)
            .background(Color(red: 0x0B / 255, green: 0x16 / 255, blue: 0x20 / 255))
            .clipShape(PixelFrameShape(cut: 6))
            .overlay(
                PixelFrameShape(cut: 6)
                    .stroke(selected ? PlayerTheme.cyan : PlayerTheme.cyanDim, lineWidth: selected ? 2 : 1)
            )
            .opacity(dimmed ? 0.45 : 1)
    }
}
