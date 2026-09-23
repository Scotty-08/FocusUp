import Foundation

/// The shape both ways FocusUp can learn about a Canvas assignment
/// produce: CanvasClient.swift's REST client (a Personal Access Token,
/// works at any school that allows students to self-generate one) and
/// the FocusUpCanvasExtension Safari extension (rides on whatever Canvas
/// session is already open in Safari, works even where a school has
/// disabled self-service tokens). One shape, so FamilyControlsManager
/// merges either source into the Quest Log the exact same way.
struct CanvasAssignment: Codable {
    let id: Int
    let name: String
    let dueAt: Date?
    let htmlUrl: URL

    enum CodingKeys: String, CodingKey {
        case id, name
        case dueAt = "due_at"
        case htmlUrl = "html_url"
    }
}

/// Hand-off point between the FocusUpCanvasExtension Safari extension and
/// the main app. The extension can't touch the Quest Log directly --
/// FamilyControlsManager only exists in the main app target -- so it
/// drops whatever the popup fetched from Canvas here, in the App Group's
/// shared UserDefaults, and the main app picks it up and clears it the
/// next time it's opened or brought to the foreground (see
/// ContentView.refreshOnActive). This file is duplicated byte-identical
/// into both targets, the same way TaskStore.swift and friends are --
/// targets here don't share files via membership, only via identical
/// copies.
enum CanvasExtensionStore {
    private static let suiteName = "group.com.scottgray.FocusUpSpike"
    private static let pendingKey = "focusUp.canvasExtension.pendingAssignments"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Called by the Safari extension (SafariWebExtensionHandler) after
    /// the popup fetches assignments from whatever Canvas the user is
    /// currently signed into. Overwrites any previous pending batch --
    /// the popup always sends a fresh full "upcoming assignments" list,
    /// not a delta, so there's nothing to merge here, only in the app.
    static func savePending(_ assignments: [CanvasAssignment]) {
        guard let defaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(assignments) else { return }
        defaults.set(data, forKey: pendingKey)
    }

    /// Called by the main app to pick up whatever the extension has
    /// dropped off since the last check, then clears it so the same
    /// batch never gets merged twice.
    static func takePending() -> [CanvasAssignment] {
        guard let defaults, let data = defaults.data(forKey: pendingKey) else { return [] }
        defaults.removeObject(forKey: pendingKey)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CanvasAssignment].self, from: data)) ?? []
    }
}
