import Combine
import Foundation

/// Canvas (Instructure) integration -- reads a signed-in student's
/// upcoming assignments across their active courses and turns each one
/// into a Quest Log entry. Read-only: FocusUp never submits work,
/// touches a grade, or writes anything back to Canvas. It only pulls
/// titles, due dates, and a link to each assignment's own page.
///
/// Auth: proper Canvas OAuth2 ("Login with Canvas") needs the school's
/// own Canvas admin to register a Developer Key for this app first --
/// not something a student can get for a personal project. A Personal
/// Access Token, which any Canvas user can generate themselves under
/// Account -> Settings -> "New Access Token", works today with no
/// institutional approval, so that's what this uses. A PAT carries the
/// same access as the account itself (it isn't scoped to just "read
/// assignments"), so it lives in the Keychain, never UserDefaults --
/// same treatment BackendClient gives the Supabase session token.
///
/// Works for any school's Canvas, not just one: the domain is whatever
/// the user types in when connecting (e.g. "iowastate.instructure.com"),
/// and every request -- including the `html_url` handed back on each
/// quest for "Open in Canvas" (see FocusTask.canvasURL) -- is built from
/// that domain, so nothing about a specific school is hardcoded.
@MainActor
final class CanvasClient: ObservableObject {
    static let shared = CanvasClient()

    @Published private(set) var domain: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published var lastSyncError: String?

    var isConnected: Bool { domain != nil }

    private static let domainKey = "focusUp.canvas.domain"
    private static let tokenKeychainKey = "token"

    private init() {
        domain = UserDefaults.standard.string(forKey: Self.domainKey)
    }

    // MARK: - Connect / disconnect

    /// Normalizes what the user typed (a bare domain or a full URL they
    /// may have pasted both work) and confirms the token actually works
    /// against THAT domain via one lightweight call before saving
    /// anything -- a typo'd domain or a bad token fails loudly here,
    /// right when the user is looking at the form, instead of silently
    /// during the next background sync.
    func connect(domain rawDomain: String, token rawToken: String) async throws {
        let domain = Self.normalize(domain: rawDomain)
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domain.isEmpty, !token.isEmpty else {
            throw CanvasError.invalidInput
        }
        _ = try await Self.request(domain: domain, token: token, path: "/api/v1/users/self", as: CanvasUser.self)
        CanvasKeychain.set(token, for: Self.tokenKeychainKey)
        UserDefaults.standard.set(domain, forKey: Self.domainKey)
        self.domain = domain
        lastSyncError = nil
    }

    /// Only forgets the connection -- quests already imported stay in
    /// the Quest Log exactly as they are (still completable, still
    /// linking to Canvas), they just stop getting refreshed.
    func disconnect() {
        CanvasKeychain.remove(Self.tokenKeychainKey)
        UserDefaults.standard.removeObject(forKey: Self.domainKey)
        domain = nil
        lastSyncedAt = nil
        lastSyncError = nil
    }

    // MARK: - Sync

    /// Pulls every active course's upcoming assignments and merges each
    /// into the Quest Log via `manager.mergeCanvasAssignments`. A no-op
    /// when Canvas isn't connected, so this is safe to call opportunistically
    /// (ContentView calls it the same way it refreshes friends/stats on
    /// launch and foreground) without every call site checking
    /// `isConnected` first.
    func sync(into manager: FamilyControlsManager) async {
        guard let domain, let token = CanvasKeychain.get(Self.tokenKeychainKey) else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let courses = try await Self.request(
                domain: domain, token: token,
                path: "/api/v1/courses",
                query: [URLQueryItem(name: "enrollment_state", value: "active")],
                as: [CanvasCourse].self
            )
            var assignments: [CanvasAssignment] = []
            for course in courses {
                // bucket=upcoming is Canvas's own filter for "due in the
                // future, not yet closed" -- the same set of assignments
                // that drives a student's own Canvas To-Do list, so this
                // mirrors what they'd see there.
                let courseAssignments = try await Self.request(
                    domain: domain, token: token,
                    path: "/api/v1/courses/\(course.id)/assignments",
                    query: [
                        URLQueryItem(name: "bucket", value: "upcoming"),
                        URLQueryItem(name: "order_by", value: "due_at")
                    ],
                    as: [CanvasAssignment].self
                )
                assignments.append(contentsOf: courseAssignments)
            }
            manager.mergeCanvasAssignments(assignments)
            lastSyncedAt = Date()
            lastSyncError = nil
        } catch {
            lastSyncError = (error as? CanvasError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Networking

    /// Accepts "iowastate.instructure.com", "https://iowastate.instructure.com",
    /// or that URL with a trailing path pasted along with it -- keeps
    /// just the host either way.
    private static func normalize(domain raw: String) -> String {
        var d = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where d.hasPrefix(prefix) {
            d.removeFirst(prefix.count)
        }
        if let slashIndex = d.firstIndex(of: "/") {
            d = String(d[d.startIndex..<slashIndex])
        }
        return d
    }

    private static func request<T: Decodable>(
        domain: String, token: String, path: String, query: [URLQueryItem] = [], as type: T.Type
    ) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw CanvasError.invalidInput }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CanvasError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw CanvasError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw CanvasError.unauthorized }
            throw CanvasError.server(status: http.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CanvasError.invalidResponse
        }
    }
}

enum CanvasError: LocalizedError {
    case invalidInput
    case unauthorized
    case network(String)
    case server(status: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Enter your school's Canvas domain and an access token."
        case .unauthorized:
            return "Canvas rejected that token. Generate a new one under Account -> Settings -> New Access Token, then try again."
        case .network(let message):
            return "Couldn't reach Canvas: \(message)"
        case .server(let status):
            return "Canvas returned an error (\(status))."
        case .invalidResponse:
            return "Canvas sent a response the app didn't understand."
        }
    }
}

private struct CanvasUser: Decodable {
    let id: Int
}

private struct CanvasCourse: Decodable {
    let id: Int
    let name: String?
}

// CanvasAssignment now lives in CanvasExtensionStore.swift -- shared,
// byte-identical, with the FocusUpCanvasExtension Safari extension target
// so both the PAT sync path here and the browser-session sync path there
// produce the exact same type for FamilyControlsManager to merge.

/// Separate Keychain service from BackendClient's -- a different
/// credential (a Canvas PAT, not a Supabase session) with its own
/// lifecycle; connecting/disconnecting Canvas should never touch the
/// FocusUp account session and vice versa.
private enum CanvasKeychain {
    private static let service = "com.scottgray.FocusUpSpike.canvas"

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for key: String) {
        remove(key)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
