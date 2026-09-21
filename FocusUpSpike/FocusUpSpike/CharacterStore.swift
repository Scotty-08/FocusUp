import Foundation
import Combine
import SwiftUI

/// What one quest completion paid out. `newLevel` is non-nil only when
/// this reward pushed the player into a new level.
struct QuestReward: Equatable {
    let xp: Int
    let coins: Int
    let newLevel: Int?
}

/// The player's progression and look.
///
/// Two separate currencies, on purpose:
/// - EXP only ever goes up and only drives the level -- it is never spent.
/// - Coins are the spendable balance, earned alongside EXP and spent on
///   avatar upgrades (see AvatarCatalog).
///
/// Everything is earned by clearing quests; nothing is fabricated from
/// other stats. There are no skill points or stat sheets anymore.
@MainActor
final class CharacterStore: ObservableObject {
    static let shared = CharacterStore()

    private let defaults = UserDefaults.standard
    private let nameKey = "focusUp.player.name"
    private let avatarKey = "focusUp.player.avatar"
    private let xpKey = "focusUp.player.xp"
    private let coinsKey = "focusUp.player.coins"
    private let ownedKey = "focusUp.player.ownedItems"
    private let rewardedKey = "focusUp.player.rewardedQuests"

    @Published var name: String
    @Published private(set) var avatar: AvatarConfig
    @Published private(set) var totalXP: Int
    @Published private(set) var coins: Int
    @Published private(set) var ownedItems: Set<String>
    private var rewardedQuestIDs: Set<String>

    private init() {
        name = defaults.string(forKey: nameKey)
            ?? AuthManager.shared.displayName?.uppercased()
            ?? "PLAYER"
        if let data = defaults.data(forKey: avatarKey),
           let saved = try? JSONDecoder().decode(AvatarConfig.self, from: data) {
            avatar = saved
        } else {
            avatar = .starter
        }
        totalXP = defaults.integer(forKey: xpKey)
        coins = defaults.integer(forKey: coinsKey)
        ownedItems = Set(defaults.stringArray(forKey: ownedKey) ?? [])
        rewardedQuestIDs = Set(defaults.stringArray(forKey: rewardedKey) ?? [])
    }

    // MARK: - Level

    static let xpPerLevel = 200

    var level: Int { 1 + totalXP / Self.xpPerLevel }
    var xpIntoLevel: Int { totalXP % Self.xpPerLevel }
    var xpProgress: Double { Double(xpIntoLevel) / Double(Self.xpPerLevel) }

    // MARK: - Rewards

    /// Scaled by priority -- harder quests pay more. A medium quest is
    /// 100 EXP + 20 coins.
    static func reward(for priority: TaskPriority) -> (xp: Int, coins: Int) {
        switch priority {
        case .low: return (50, 10)
        case .medium: return (100, 20)
        case .high: return (150, 30)
        }
    }

    /// Pays out EXP and coins for completing `task`, once per quest.
    /// Returns nil if this quest already paid out, so un-checking and
    /// re-checking the same quest can't farm rewards. (Deleting a quest
    /// and re-adding it creates a new quest with a new id, which this
    /// can't distinguish from genuinely new work -- an accepted limit,
    /// not a bug.)
    @discardableResult
    func rewardQuest(_ task: FocusTask) -> QuestReward? {
        let key = task.id.uuidString
        guard !rewardedQuestIDs.contains(key) else { return nil }
        rewardedQuestIDs.insert(key)
        defaults.set(Array(rewardedQuestIDs), forKey: rewardedKey)

        let payout = Self.reward(for: task.priority)
        let levelBefore = level
        totalXP += payout.xp
        coins += payout.coins
        defaults.set(totalXP, forKey: xpKey)
        defaults.set(coins, forKey: coinsKey)
        return QuestReward(xp: payout.xp, coins: payout.coins, newLevel: level > levelBefore ? level : nil)
    }

    // MARK: - Identity

    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let upper = trimmed.uppercased()
        name = upper
        defaults.set(upper, forKey: nameKey)
    }

    // MARK: - Avatar

    func isOwned(_ item: AvatarItem) -> Bool {
        item.cost == 0 || ownedItems.contains(item.id)
    }

    func isEquipped(_ item: AvatarItem) -> Bool {
        avatar.itemID(for: item.slot) == item.id
    }

    /// First-run creation: applies a whole config at once, falling back
    /// to the starter option for any slot whose item isn't actually
    /// owned (creation only offers free items, but this never trusts
    /// its caller to have checked).
    func setAvatar(_ config: AvatarConfig) {
        var checked = config
        for slot in AvatarSlot.allCases {
            let id = config.itemID(for: slot)
            if let item = AvatarCatalog.item(id), isOwned(item), item.slot == slot {
                continue
            }
            checked = checked.setting(AvatarConfig.starter.itemID(for: slot), for: slot)
        }
        saveAvatar(checked)
    }

    func equip(_ item: AvatarItem) {
        guard isOwned(item) else { return }
        saveAvatar(avatar.setting(item.id, for: item.slot))
    }

    enum PurchaseResult {
        case purchased
        case alreadyOwned
        case insufficientCoins
    }

    /// Buys `item` with coins and equips it.
    @discardableResult
    func buy(_ item: AvatarItem) -> PurchaseResult {
        guard !isOwned(item) else { return .alreadyOwned }
        guard coins >= item.cost else { return .insufficientCoins }
        coins -= item.cost
        ownedItems.insert(item.id)
        defaults.set(coins, forKey: coinsKey)
        defaults.set(Array(ownedItems), forKey: ownedKey)
        saveAvatar(avatar.setting(item.id, for: item.slot))
        return .purchased
    }

    private func saveAvatar(_ config: AvatarConfig) {
        avatar = config
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: avatarKey)
        }
    }
}
