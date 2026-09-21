import Foundation

/// One row of `list_friends()` (supabase/schema.sql): another player plus
/// how they're connected to you. Property names map from the snake_case
/// columns via the client's convertFromSnakeCase decoder (`total_xp` ->
/// `totalXp`, so don't rename these to `totalXP`).
struct FriendRow: Decodable, Identifiable, Equatable {
    let friendshipId: UUID
    let status: String
    let isIncoming: Bool
    /// The OTHER player's account id.
    let id: UUID
    let username: String
    let displayName: String?
    let avatar: AvatarConfig?
    let level: Int
    let totalXp: Int
    let streak: Int
    let completedCount: Int

    var title: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return username
    }
    var avatarConfig: AvatarConfig { avatar ?? .starter }
}

/// One row of `my_cheers()`.
struct CheerRow: Decodable, Identifiable, Equatable {
    let id: UUID
    let senderId: UUID
    let senderUsername: String
    let senderDisplayName: String?
    let message: String
    let createdAt: Date
    let seen: Bool

    var senderTitle: String {
        if let senderDisplayName, !senderDisplayName.isEmpty { return senderDisplayName }
        return senderUsername
    }
}

struct LeaderboardEntry: Identifiable {
    let id: UUID
    let title: String
    let username: String
    let avatar: AvatarConfig
    let level: Int
    let totalXp: Int
    let streak: Int
    let completedCount: Int
    let isMe: Bool
}

enum LeaderboardMetric: String, CaseIterable, Identifiable {
    case level = "Level"
    case streak = "Streak"
    case quests = "Quests"

    var id: String { rawValue }

    func value(for entry: LeaderboardEntry) -> Int {
        switch self {
        case .level: return entry.totalXp
        case .streak: return entry.streak
        case .quests: return entry.completedCount
        }
    }

    func display(for entry: LeaderboardEntry) -> String {
        switch self {
        case .level: return "LV \(entry.level)"
        case .streak: return "\(entry.streak) DAY"
        case .quests: return "\(entry.completedCount) CLEARED"
        }
    }
}

private struct UsernameParams: Encodable { let pUsername: String }
private struct RequestParams: Encodable { let pRequestId: UUID }
private struct FriendshipParams: Encodable { let pFriendshipId: UUID }
private struct CheerParams: Encodable { let pRecipient: UUID; let pMessage: String }

private struct ProfileRow: Encodable {
    let id: UUID
    let username: String
    let displayName: String
    let avatar: AvatarConfig
    let level: Int
    let totalXp: Int
    let streak: Int
    let completedCount: Int
}

private struct UsernameOnly: Decodable { let username: String }

/// Friends, requests, cheers and the player-card sync. Everything here is
/// best-effort and additive: if the server is unconfigured, offline, or
/// signed out, the store just stays empty and the rest of the app is
/// unaffected.
@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    @Published private(set) var friends: [FriendRow] = []
    @Published private(set) var incoming: [FriendRow] = []
    @Published private(set) var outgoing: [FriendRow] = []
    @Published private(set) var cheers: [CheerRow] = []
    @Published private(set) var myUsername: String?
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?

    static let cheerPresets = [
        "You've got this \u{1F4AA}",
        "Go clear a quest!",
        "Stay locked in \u{1F512}"
    ]

    private let backend = BackendClient.shared
    private let usernameKey = "focusUp.backend.username"
    private var isSyncingProfile = false

    private init() {
        myUsername = UserDefaults.standard.string(forKey: usernameKey)
    }

    var unseenCheerCount: Int { cheers.filter { !$0.seen }.count }
    var badgeCount: Int { incoming.count + unseenCheerCount }

    func reset() {
        friends = []
        incoming = []
        outgoing = []
        cheers = []
        myUsername = nil
        statusMessage = nil
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }

    // MARK: - Profile sync

    /// Lowercase letters, digits and underscores only, 3-16 characters
    /// (leaving room for a numeric suffix under the server's 20 limit).
    static func sanitizedHandle(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
        var handle = String(raw.lowercased().filter { allowed.contains($0) })
        if handle.count < 3 { handle += "player" }
        return String(handle.prefix(16))
    }

    /// Publishes this player's card (handle, avatar, level, streak...).
    /// Claims a unique handle on first run, derived from the player name.
    func syncProfile() async {
        guard backend.isConnected, let userID = backend.session?.userID else { return }
        // Called from several places at once (app foreground, the
        // Friends tab, a quest reward). Overlapping calls could each
        // try to claim a handle, so let one run at a time.
        guard !isSyncingProfile else { return }
        isSyncingProfile = true
        defer { isSyncingProfile = false }
        let character = CharacterStore.shared

        if myUsername == nil {
            if let existing: [UsernameOnly] = try? await backend.get(
                "/rest/v1/profiles",
                query: [URLQueryItem(name: "id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "select", value: "username")]
            ), let saved = existing.first?.username {
                setUsername(saved)
            }
        }

        var candidates: [String] = []
        if let saved = myUsername {
            candidates = [saved]
        } else {
            let base = Self.sanitizedHandle(character.name)
            candidates = [base] + (0..<5).map { _ in base + String(Int.random(in: 100...9999)) }
        }

        for candidate in candidates {
            let row = ProfileRow(
                id: userID,
                username: candidate,
                displayName: character.name,
                avatar: character.avatar,
                level: character.level,
                totalXp: character.totalXP,
                streak: StatsStore.currentStreak,
                completedCount: StatsStore.completedCount
            )
            do {
                try await backend.upsert(table: "profiles", row)
                setUsername(candidate)
                return
            } catch let error as BackendError where error.statusCode == 409 && myUsername == nil {
                continue // handle already taken -- try the next candidate
            } catch {
                statusMessage = error.localizedDescription
                return
            }
        }
        statusMessage = "Couldn't reserve a unique username. Try renaming your player."
    }

    private func setUsername(_ value: String) {
        myUsername = value
        UserDefaults.standard.set(value, forKey: usernameKey)
    }

    // MARK: - Reading

    func refresh() async {
        guard backend.isConnected else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [FriendRow] = try await backend.call("list_friends", NoParams())
            friends = rows.filter { $0.status == "accepted" }
            incoming = rows.filter { $0.status == "pending" && $0.isIncoming }
            outgoing = rows.filter { $0.status == "pending" && !$0.isIncoming }
            cheers = try await backend.call("my_cheers", NoParams())
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// Friends plus you, ranked by the chosen metric (ties broken by
    /// total EXP). Your own row uses live local numbers so it's never
    /// stale.
    func leaderboard(by metric: LeaderboardMetric) -> [LeaderboardEntry] {
        let character = CharacterStore.shared
        var entries = friends.map {
            LeaderboardEntry(
                id: $0.id, title: $0.title, username: $0.username, avatar: $0.avatarConfig,
                level: $0.level, totalXp: $0.totalXp, streak: $0.streak,
                completedCount: $0.completedCount, isMe: false
            )
        }
        if let userID = backend.session?.userID {
            entries.append(LeaderboardEntry(
                id: userID, title: character.name, username: myUsername ?? "you", avatar: character.avatar,
                level: character.level, totalXp: character.totalXP, streak: StatsStore.currentStreak,
                completedCount: StatsStore.completedCount, isMe: true
            ))
        }
        return entries.sorted {
            let (a, b) = (metric.value(for: $0), metric.value(for: $1))
            return a != b ? a > b : $0.totalXp > $1.totalXp
        }
    }

    // MARK: - Actions

    func sendRequest(toUsername raw: String) async {
        let handle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        guard !handle.isEmpty else {
            statusMessage = "Enter a username to add."
            return
        }
        do {
            let result: String = try await backend.call("send_friend_request", UsernameParams(pUsername: handle))
            switch result {
            case "sent": statusMessage = "Request sent to @\(handle)."
            case "accepted": statusMessage = "You and @\(handle) are now friends!"
            case "already_friends": statusMessage = "You're already friends with @\(handle)."
            case "already_sent": statusMessage = "You already sent @\(handle) a request."
            case "not_found": statusMessage = "No player with the username @\(handle)."
            case "self": statusMessage = "That's you!"
            case "no_profile": statusMessage = "Your player card isn't published yet. Try again in a moment."
            default: statusMessage = "Something went wrong."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
        await refresh()
    }

    func accept(_ row: FriendRow) async {
        do {
            try await backend.callVoid("accept_friend_request", RequestParams(pRequestId: row.friendshipId))
            statusMessage = "You and @\(row.username) are now friends!"
        } catch {
            statusMessage = error.localizedDescription
        }
        await refresh()
    }

    /// Decline an incoming request, cancel an outgoing one, or unfriend.
    func remove(_ row: FriendRow) async {
        do {
            try await backend.callVoid("remove_friendship", FriendshipParams(pFriendshipId: row.friendshipId))
        } catch {
            statusMessage = error.localizedDescription
        }
        await refresh()
    }

    func cheer(_ row: FriendRow, message: String) async {
        do {
            let result: String = try await backend.call("send_cheer", CheerParams(pRecipient: row.id, pMessage: message))
            switch result {
            case "sent": statusMessage = "Cheer sent to @\(row.username)!"
            case "too_soon": statusMessage = "Give @\(row.username) a minute before cheering again."
            case "not_friends": statusMessage = "You're not friends with @\(row.username) anymore."
            default: statusMessage = "Couldn't send that cheer."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func markCheersSeen() async {
        do {
            try await backend.callVoid("mark_cheers_seen", NoParams())
        } catch {
            statusMessage = error.localizedDescription
        }
        await refresh()
    }
}
