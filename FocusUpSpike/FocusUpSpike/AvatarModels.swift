import SwiftUI

/// The four things about the player's avatar that can be customized.
enum AvatarSlot: String, CaseIterable, Codable {
    case robe, eyes, cloak, headwear

    var label: String {
        switch self {
        case .robe: return "Robe"
        case .eyes: return "Eyes"
        case .cloak: return "Cloak"
        case .headwear: return "Headwear"
        }
    }
}

/// Which headwear shape PixelAvatarView draws for a headwear item.
enum Headwear: String {
    case none, horns, crown, halo
}

/// One customization option. `cost == 0` means it's a free starter
/// option available during first-run avatar creation; anything above 0
/// is an upgrade bought with coins (see CharacterStore.buy).
struct AvatarItem: Identifiable, Hashable {
    let id: String
    let slot: AvatarSlot
    let name: String
    let cost: Int
    /// RGB hex for color slots (robe/eyes/cloak); nil for headwear.
    let hex: UInt32?
    let headwear: Headwear?

    var color: Color? {
        guard let hex else { return nil }
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum AvatarCatalog {
    private static func color(_ slot: AvatarSlot, _ key: String, _ name: String, _ cost: Int, _ hex: UInt32) -> AvatarItem {
        AvatarItem(id: "\(slot.rawValue).\(key)", slot: slot, name: name, cost: cost, hex: hex, headwear: nil)
    }

    private static func headwear(_ key: String, _ name: String, _ cost: Int, _ shape: Headwear) -> AvatarItem {
        AvatarItem(id: "headwear.\(key)", slot: .headwear, name: name, cost: cost, hex: nil, headwear: shape)
    }

    /// Free options first in each slot, then priced upgrades cheapest to
    /// most expensive. A medium-priority quest pays 20 coins (see
    /// CharacterStore.reward), so the cheapest upgrade is ~2 quests and
    /// the priciest is ~15.
    static let items: [AvatarItem] = [
        color(.robe, "midnight", "Midnight", 0, 0x16232F),
        color(.robe, "moss", "Moss", 0, 0x1F3A2B),
        color(.robe, "plum", "Plum", 0, 0x3A2247),
        color(.robe, "ocean", "Ocean", 0, 0x1B3554),
        color(.robe, "ivory", "Ivory", 60, 0xD9D4C7),
        color(.robe, "crimson", "Crimson", 100, 0x5A1E28),
        color(.robe, "royal", "Royal", 160, 0x2A2E6B),

        color(.eyes, "cyan", "Cyan", 0, 0x3EE6FF),
        color(.eyes, "green", "Green", 0, 0x5CFF9D),
        color(.eyes, "amber", "Amber", 0, 0xFFC94D),
        color(.eyes, "violet", "Violet", 0, 0xB07CFF),
        color(.eyes, "crimson", "Crimson", 40, 0xFF4D5E),
        color(.eyes, "white", "White", 60, 0xFFFFFF),

        color(.cloak, "cyan", "Cyan", 0, 0x3EE6FF),
        color(.cloak, "slate", "Slate", 0, 0x3D3D3D),
        color(.cloak, "storm", "Storm", 40, 0x6E8CA8),
        color(.cloak, "ember", "Ember", 80, 0xFF6A2B),
        color(.cloak, "gold", "Gold", 150, 0xFFC94D),

        headwear("none", "None", 0, .none),
        headwear("horns", "Horns", 100, .horns),
        headwear("crown", "Crown", 200, .crown),
        headwear("halo", "Halo", 300, .halo),
    ]

    static func items(in slot: AvatarSlot) -> [AvatarItem] {
        items.filter { $0.slot == slot }
    }

    /// The free options for a slot -- all first-run avatar creation offers.
    static func starterItems(in slot: AvatarSlot) -> [AvatarItem] {
        items(in: slot).filter { $0.cost == 0 }
    }

    static func item(_ id: String) -> AvatarItem? {
        items.first { $0.id == id }
    }
}

/// A player's chosen item per slot, stored as catalog item ids.
struct AvatarConfig: Codable, Equatable {
    var robe: String
    var eyes: String
    var cloak: String
    var headwear: String

    static let starter = AvatarConfig(
        robe: "robe.midnight",
        eyes: "eyes.cyan",
        cloak: "cloak.cyan",
        headwear: "headwear.none"
    )

    func itemID(for slot: AvatarSlot) -> String {
        switch slot {
        case .robe: return robe
        case .eyes: return eyes
        case .cloak: return cloak
        case .headwear: return headwear
        }
    }

    func setting(_ itemID: String, for slot: AvatarSlot) -> AvatarConfig {
        var copy = self
        switch slot {
        case .robe: copy.robe = itemID
        case .eyes: copy.eyes = itemID
        case .cloak: copy.cloak = itemID
        case .headwear: copy.headwear = itemID
        }
        return copy
    }
}
