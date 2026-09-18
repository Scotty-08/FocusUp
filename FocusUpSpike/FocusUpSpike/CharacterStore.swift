import Foundation
import Combine
import SwiftUI

/// Cosmetic cloak colors for the Hunter avatar. Unlocked by level, like
/// everything else on this screen -- nothing here is purchasable, only
/// earned.
enum CloakColor: Int, CaseIterable, Codable {
    case cyan, storm, ember, slate

    var color: Color {
        switch self {
        case .cyan: return HunterTheme.cyan
        case .storm: return HunterTheme.steel
        case .ember: return HunterTheme.emberRed
        case .slate: return Color(white: 0.24)
        }
    }

    var label: String {
        switch self {
        case .cyan: return "Cyan"
        case .storm: return "Storm"
        case .ember: return "Ember"
        case .slate: return "Slate"
        }
    }

    var unlockLevel: Int {
        switch self {
        case .cyan: return 1
        case .storm: return 3
        case .ember: return 5
        case .slate: return 8
        }
    }
}

enum HunterStat {
    case focus, discipline
}

/// The "Hunter" character sheet: level, XP, and three stats, all derived
/// from the SAME real numbers Home already shows (StatsStore), plus a
/// small number of points the player can allocate themselves as they
/// level up. Nothing here is fabricated -- Consistency is intentionally
/// not spendable, since it's meant to read directly off your streak.
///
/// This is v2/stretch scope Scott asked to see built for real -- it's
/// additive on top of the existing feasibility-spike data, not a
/// replacement for any of it.
@MainActor
final class CharacterStore: ObservableObject {
    static let shared = CharacterStore()

    private let defaults = UserDefaults.standard
    private let nameKey = "focusUp.hunter.name"
    private let cloakKey = "focusUp.hunter.cloak"
    private let spentFocusKey = "focusUp.hunter.spentFocus"
    private let spentDisciplineKey = "focusUp.hunter.spentDiscipline"

    @Published var name: String
    @Published var cloak: CloakColor
    @Published private(set) var spentFocusPoints: Int
    @Published private(set) var spentDisciplinePoints: Int

    private init() {
        name = defaults.string(forKey: nameKey)
            ?? AuthManager.shared.displayName?.uppercased()
            ?? "HUNTER"
        cloak = CloakColor(rawValue: defaults.integer(forKey: cloakKey)) ?? .cyan
        spentFocusPoints = defaults.integer(forKey: spentFocusKey)
        spentDisciplinePoints = defaults.integer(forKey: spentDisciplineKey)
    }

    // MARK: - Real data (same source Home's Hunter Log reads)

    var completedCount: Int { StatsStore.completedCount }
    var ignoreCount: Int { StatsStore.ignoreCount }
    var currentStreak: Int { StatsStore.currentStreak }

    // MARK: - XP / Level

    static let xpPerLevel = 150

    /// +100 XP per cleared quest, -25 per abandoned one, +15 per point
    /// of current streak. Simple and legible on purpose -- the point is
    /// that clearing quests and holding your streak is what levels you
    /// up, not an opaque formula.
    var xp: Int {
        max(0, completedCount * 100 - ignoreCount * 25 + currentStreak * 15)
    }

    var level: Int { 1 + xp / Self.xpPerLevel }
    var xpIntoLevel: Int { xp % Self.xpPerLevel }
    var xpProgress: Double { Double(xpIntoLevel) / Double(Self.xpPerLevel) }

    // MARK: - Stat points

    /// One point per level above 1, spendable on Focus or Discipline.
    var totalPoints: Int { max(0, level - 1) }
    var unspentPoints: Int { max(0, totalPoints - spentFocusPoints - spentDisciplinePoints) }

    /// Focus = quests actually cleared, plus anything spent into it.
    var focusStat: Int { completedCount + spentFocusPoints }
    /// Discipline = seals you didn't break (cleared minus abandoned,
    /// floored at 0), plus anything spent into it.
    var disciplineStat: Int { max(0, completedCount - ignoreCount) + spentDisciplinePoints }
    /// Consistency = your streak, doubled for a readable bar. Not
    /// spendable -- it only moves if your real streak does.
    var consistencyStat: Int { currentStreak * 2 }

    static let statBarMax = 20.0
    func fraction(for value: Int) -> Double { min(1, Double(value) / Self.statBarMax) }

    func spendPoint(on stat: HunterStat) {
        guard unspentPoints > 0 else { return }
        switch stat {
        case .focus:
            spentFocusPoints += 1
            defaults.set(spentFocusPoints, forKey: spentFocusKey)
        case .discipline:
            spentDisciplinePoints += 1
            defaults.set(spentDisciplinePoints, forKey: spentDisciplineKey)
        }
    }

    // MARK: - Identity / loadout

    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let upper = trimmed.uppercased()
        name = upper
        defaults.set(upper, forKey: nameKey)
    }

    func setCloak(_ c: CloakColor) {
        guard c.unlockLevel <= level else { return }
        cloak = c
        defaults.set(c.rawValue, forKey: cloakKey)
    }

    /// Titles unlock by level; only the next upcoming one is shown on
    /// the loadout card today (matches the design canvas mockup).
    var nextTitle: (name: String, unlockLevel: Int) {
        ("Seeker of the Seal", 6)
    }
}
