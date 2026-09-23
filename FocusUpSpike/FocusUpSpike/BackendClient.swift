import Combine
import Foundation
import Security
import CryptoKit

/// Where the FocusUp server (a Supabase project -- see /supabase in the
/// repo root for the schema and setup steps) lives. The two values come
/// from BackendSecrets.swift, a gitignored file each developer creates by
/// copying BackendSecrets.swift.example. The anon key is a PUBLIC key by
/// design (Row Level Security in schema.sql is what protects the data --
/// it ships inside the app either way), but never put the project's
/// `service_role` key in the app or the repo.
///
/// While the values still hold the placeholders, `isConfigured` is false
/// and every network feature quietly stays off: the app's core loop
/// (groups, quests, blocking) never depends on the server.
enum BackendConfig {
    // Trimmed: a stray space or newline pasted along with the key makes
    // Supabase answer "Invalid API key".
    static let projectURL = BackendSecrets.projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
    static let anonKey = BackendSecrets.anonKey.trimmingCharacters(in: .whitespacesAndNewlines)

    /// Legacy anon keys are JWTs ("eyJ..."). Newer projects hand out
    /// "sb_publishable_..." keys, which are NOT JWTs and must only go in
    /// the `apikey` header, never `Authorization: Bearer`.
    static var keyIsJWT: Bool { anonKey.hasPrefix("eyJ") }

    static var isConfigured: Bool {
        !projectURL.contains("YOUR-PROJECT-REF")
            && !anonKey.hasPrefix("YOUR-")
            && URL(string: projectURL)?.host != nil
    }
}

enum BackendError: LocalizedError {
    case notConfigured
    case notSignedIn
    case confirmationRequired
    case network(String)
    case server(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The FocusUp server isn't configured in this build."
        case .notSignedIn: return "You're not connected to your FocusUp account."
        case .confirmationRequired: return "Check your email to confirm the account, then sign in."
        case .network: return "Couldn't reach the server. Check your connection and try again."
        case .server(_, let message): return message
        case .invalidResponse: return "The server sent a response the app didn't understand."
        }
    }

    var statusCode: Int? {
        if case .server(let status, _) = self { return status }
        return nil
    }
}

/// Tokens live in the Keychain, not UserDefaults.
private enum Keychain {
    private static let service = "com.scottgray.FocusUpSpike.backend"

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

/// Sign in with Apple hands the backend an identity token; the token
/// embeds a hash of a random nonce we generated, and the backend checks
/// the raw nonce we send alongside it. That stops a stolen token from
/// being replayed.
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, length, &bytes) == errSecSuccess else {
            return UUID().uuidString + UUID().uuidString
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct BackendSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var userID: UUID
    var expiresAt: Date
}

/// Empty JSON body for parameterless RPC calls.
struct NoParams: Encodable {}

/// Minimal Supabase client over plain URLSession -- auth (Apple token or
/// email/password), token refresh, PostgREST reads/writes and RPC calls.
/// No third-party SDK on purpose: nothing to add to the Xcode project.
///
/// UNVERIFIED on a device/simulator: written without a compiler or a live
/// project. Needs a first run against a real Supabase project.
@MainActor
final class BackendClient: ObservableObject {
    static let shared = BackendClient()

    @Published private(set) var session: BackendSession?
    /// Why the most recent sign-in/connect attempt failed, for the UI
    /// (the Apple sign-in exchange runs in the background and would
    /// otherwise fail silently). Cleared on success.
    @Published var lastConnectError: String?
    var isConnected: Bool { session != nil }

    private static let sessionKey = "session"
    private let urlSession = URLSession(configuration: .ephemeral)
    private var refreshTask: Task<Void, Error>?

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)"))
        }
        return decoder
    }()

    private init() {
        if let json = Keychain.get(Self.sessionKey),
           let stored = try? JSONDecoder().decode(BackendSession.self, from: Data(json.utf8)) {
            session = stored
        }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, rawNonce: String) async throws {
        try await authenticate(
            path: "/auth/v1/token",
            grantType: "id_token",
            body: ["provider": "apple", "id_token": idToken, "nonce": rawNonce]
        )
    }

    func signIn(email: String, password: String) async throws {
        try await authenticate(path: "/auth/v1/token", grantType: "password", body: ["email": email, "password": password])
    }

    /// Throws `.confirmationRequired` if the project has "Confirm email"
    /// turned on (no session is issued until the link is clicked).
    func signUp(email: String, password: String) async throws {
        try await authenticate(path: "/auth/v1/signup", grantType: nil, body: ["email": email, "password": password])
    }

    func signOut() {
        session = nil
        Keychain.remove(Self.sessionKey)
    }

    private struct AuthResponse: Decodable {
        struct AuthUser: Decodable { let id: UUID }
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Double?
        let user: AuthUser?
    }

    private func authenticate(path: String, grantType: String?, body: [String: String]) async throws {
        let query = grantType.map { [URLQueryItem(name: "grant_type", value: $0)] } ?? []
        do {
            let data = try await send(
                method: "POST", path: path, query: query,
                body: try JSONSerialization.data(withJSONObject: body),
                authorized: false
            )
            try adoptSession(from: data)
            lastConnectError = nil
        } catch {
            lastConnectError = error.localizedDescription
            throw error
        }
    }

    private func adoptSession(from data: Data) throws {
        guard let response = try? Self.decoder.decode(AuthResponse.self, from: data) else {
            throw BackendError.invalidResponse
        }
        guard let access = response.accessToken, let refresh = response.refreshToken else {
            throw BackendError.confirmationRequired
        }
        guard let userID = response.user?.id else { throw BackendError.invalidResponse }
        let newSession = BackendSession(
            accessToken: access,
            refreshToken: refresh,
            userID: userID,
            expiresAt: Date().addingTimeInterval(response.expiresIn ?? 3600)
        )
        session = newSession
        if let json = try? JSONEncoder().encode(newSession), let string = String(data: json, encoding: .utf8) {
            Keychain.set(string, for: Self.sessionKey)
        }
    }

    /// Only a definitive rejection from the server (bad/expired refresh
    /// token) signs the user out -- a network blip must not.
    ///
    /// Concurrent callers share one in-flight refresh: refresh tokens
    /// rotate, so two simultaneous refreshes with the same token would
    /// race and one could invalidate the session.
    private func refreshSession() async throws {
        if let inFlight = refreshTask {
            try await inFlight.value
            return
        }
        let task = Task { @MainActor in try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    private func performRefresh() async throws {
        guard let refresh = session?.refreshToken else { throw BackendError.notSignedIn }
        do {
            let data = try await send(
                method: "POST", path: "/auth/v1/token",
                query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                body: try JSONSerialization.data(withJSONObject: ["refresh_token": refresh]),
                authorized: false
            )
            try adoptSession(from: data)
        } catch let error as BackendError {
            if let status = error.statusCode, [400, 401, 403].contains(status) { signOut() }
            throw error
        }
    }

    // MARK: - Data

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try decode(try await send(method: "GET", path: path, query: query, authorized: true))
    }

    /// Calls a Postgres function (see supabase/schema.sql).
    func call<T: Decodable, P: Encodable>(_ function: String, _ params: P) async throws -> T {
        try decode(try await send(
            method: "POST", path: "/rest/v1/rpc/\(function)",
            body: try Self.encoder.encode(params), authorized: true
        ))
    }

    func callVoid<P: Encodable>(_ function: String, _ params: P) async throws {
        _ = try await send(
            method: "POST", path: "/rest/v1/rpc/\(function)",
            body: try Self.encoder.encode(params), authorized: true
        )
    }

    /// Insert-or-update by primary key.
    func upsert<P: Encodable>(table: String, _ row: P) async throws {
        _ = try await send(
            method: "POST", path: "/rest/v1/\(table)",
            query: [URLQueryItem(name: "on_conflict", value: "id")],
            body: try Self.encoder.encode(row),
            headers: ["Prefer": "resolution=merge-duplicates,return=minimal"],
            authorized: true
        )
    }

    /// Assignments a desktop/browser extension (FocusUpCanvasWeb) has
    /// already pushed to the server -- the network equivalent of what
    /// CanvasExtensionStore.takePending() reads locally for the Safari
    /// extension on iOS, just reachable from any device instead of only
    /// this one. RLS scopes every row to the signed-in user, so nothing
    /// to filter here.
    ///
    /// Decoded with a plain decoder (not `Self.decoder`, which converts
    /// snake_case JSON keys and would collide with CanvasAssignment's
    /// own explicit CodingKeys) -- same decoder shape CanvasClient uses
    /// against Canvas's own API.
    func fetchPendingCanvasAssignments() async throws -> [CanvasAssignment] {
        let data = try await send(method: "GET", path: "/rest/v1/canvas_pending_assignments", authorized: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([CanvasAssignment].self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
    }

    /// Deletes rows once their assignments have been merged into the
    /// Quest Log, so the next fetch only returns what's actually new.
    func clearPendingCanvasAssignments(ids: [Int]) async throws {
        guard !ids.isEmpty else { return }
        let idList = ids.map(String.init).joined(separator: ",")
        _ = try await send(
            method: "DELETE", path: "/rest/v1/canvas_pending_assignments",
            query: [URLQueryItem(name: "id", value: "in.(\(idList))")],
            authorized: true
        )
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
    }

    // MARK: - Transport

    private func send(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        authorized: Bool,
        allowRefresh: Bool = true
    ) async throws -> Data {
        guard BackendConfig.isConfigured else { throw BackendError.notConfigured }
        let base = BackendConfig.projectURL.hasSuffix("/") ? String(BackendConfig.projectURL.dropLast()) : BackendConfig.projectURL
        guard var components = URLComponents(string: base + path) else { throw BackendError.invalidResponse }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw BackendError.invalidResponse }

        if authorized {
            guard let current = session else { throw BackendError.notSignedIn }
            if allowRefresh, current.expiresAt < Date().addingTimeInterval(30) {
                try await refreshSession()
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.httpBody = body
        request.setValue(BackendConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // An authorized call must carry the user's token. If the refresh
        // above signed the user out, fail here instead of quietly
        // sending the public anon key as if it were a login.
        if authorized, session == nil { throw BackendError.notSignedIn }
        if authorized, let token = session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if BackendConfig.keyIsJWT {
            request.setValue("Bearer \(BackendConfig.anonKey)", forHTTPHeaderField: "Authorization")
        }
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw BackendError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }

        if http.statusCode == 401, authorized, allowRefresh {
            try await refreshSession()
            return try await send(method: method, path: path, query: query, body: body, headers: headers, authorized: true, allowRefresh: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            var message = Self.errorMessage(from: data)
            if message.lowercased().contains("api key") {
                message = "The server rejected this app's API key. Check the URL and anon/publishable key in BackendSecrets.swift (Supabase -> Project Settings -> API), then rebuild."
            }
            throw BackendError.server(status: http.statusCode, message: message)
        }
        return data
    }

    private static func errorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "msg", "error_description", "error"] {
                if let text = object[key] as? String, !text.isEmpty { return text }
            }
        }
        return "The server returned an error."
    }
}
