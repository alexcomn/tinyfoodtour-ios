import Foundation

// MARK: - Configuration (sourced from TFTConfig — see Foundation/TFTConfig.swift)
private let supabaseURL     = TFTConfig.supabaseURL
private let supabaseAnonKey = TFTConfig.supabaseAnonKey

// MARK: - Supabase REST client (no SDK dependency)
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    private var authToken: String? // set after sign-in

    private func baseHeaders(contentType: String = "application/json") -> [String: String] {
        var h: [String: String] = [
            "apikey": supabaseAnonKey,
            "Content-Type": contentType,
        ]
        if let token = authToken {
            h["Authorization"] = "Bearer \(token)"
        } else {
            h["Authorization"] = "Bearer \(supabaseAnonKey)"
        }
        return h
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: - Generic REST query
    func query<T: Decodable>(
        table: String,
        select: String = "*",
        filters: [String: String] = [:],
        order: String? = nil
    ) async throws -> T {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/\(table)")!
        var queryItems = [URLQueryItem(name: "select", value: select)]
        for (key, value) in filters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        if let order { queryItems.append(URLQueryItem(name: "order", value: order)) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Upsert
    func upsert(table: String, body: [String: Any], onConflict: String? = nil) async throws {
        var urlStr = "\(supabaseURL)/rest/v1/\(table)"
        if let conflict = onConflict { urlStr += "?on_conflict=\(conflict)" }
        var request = URLRequest(url: URL(string: urlStr)!)
        request.httpMethod = "POST"
        var headers = baseHeaders()
        headers["Prefer"] = "resolution=merge-duplicates,return=minimal"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Insert
    func insert(table: String, body: [String: Any]) async throws {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/\(table)")!)
        request.httpMethod = "POST"
        var headers = baseHeaders()
        headers["Prefer"] = "return=minimal"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Delete
    func delete(table: String, filters: [String: String]) async throws {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/\(table)")!
        components.queryItems = filters.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Edge Functions
    func invokeFunction<T: Decodable>(name: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/functions/v1/\(name)")!)
        request.httpMethod = "POST"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Log the raw response and detailed decoding error so we can diagnose missing fields
            let raw = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
            print("⚠️ [\(name)] Decode failed: \(error)")
            print("⚠️ [\(name)] Raw response: \(raw)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let ctx):
                    print("⚠️  keyNotFound: \(key.stringValue) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                case .valueNotFound(let type, let ctx):
                    print("⚠️  valueNotFound: \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                case .typeMismatch(let type, let ctx):
                    print("⚠️  typeMismatch: expected \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                default:
                    print("⚠️  \(decodingError)")
                }
            }
            throw error
        }
    }

    // MARK: - Auth
    /// Exchange an Apple/Google identity token for a Supabase session.
    /// `nonce` is the raw (unhashed) nonce — Supabase SHA-256 hashes it and
    /// compares to what Apple embedded in the JWT.
    func signInWithIdToken(provider: String, idToken: String, nonce: String) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!)
        request.httpMethod = "POST"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode([
            "provider": provider,
            "id_token": idToken,
            "nonce": nonce
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    /// Fetch a tour by its public share token — used by deep link handler.
    func fetchTour(byShareToken token: String) async throws -> Tour? {
        struct TourRow: Codable {
            let id: String; let neighborhood: String; let vibe: [String]
            let dietary: [String]; let walk_distance: String; let stops: AnyCodable
            let created_at: String; let user_id: String?; let share_token: String
            let tour_title: String?; let total_distance_miles: Double?
        }
        let rows: [TourRow] = try await query(
            table: "tours", select: "*",
            filters: ["share_token": "eq.\(token)"]
        )
        guard let row = rows.first else { return nil }

        let stops: [TourStop]
        if let arr = row.stops.value as? [[String: Any]] {
            stops = arr.filter { !($0["_meta"] is [String: Any]) }
                .compactMap { dict -> TourStop? in
                    guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                    return try? JSONDecoder().decode(TourStop.self, from: data)
                }
        } else { stops = [] }

        return Tour(
            id: row.id, neighborhood: row.neighborhood,
            vibe: row.vibe, dietary: row.dietary,
            walk_distance: row.walk_distance, stops: stops,
            created_at: row.created_at, user_id: row.user_id,
            share_token: row.share_token,
            tourTitle: row.tour_title,
            totalDistanceMiles: row.total_distance_miles
        )
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        try await authRequest(endpoint: "signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        try await authRequest(endpoint: "token?grant_type=password", email: email, password: password)
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!)
        request.httpMethod = "POST"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    private func authRequest(endpoint: String, email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/auth/v1/\(endpoint)")!)
        request.httpMethod = "POST"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    // MARK: - Storage (photo upload)
    func uploadPhoto(bucket: String, path: String, data: Data, mimeType: String = "image/jpeg") async throws -> String {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/storage/v1/object/\(bucket)/\(path)")!)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authToken ?? supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: Data())
        return "\(supabaseURL)/storage/v1/object/public/\(bucket)/\(path)"
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.unknown }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SupabaseError.httpError(statusCode: http.statusCode, message: msg)
        }
    }
}

// MARK: - Supporting types
struct AuthResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let user: AuthUser?
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

enum SupabaseError: LocalizedError {
    case httpError(statusCode: Int, message: String)
    case noNetwork
    case unknown

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let msg):
            // Surface a friendlier message for common HTTP codes
            switch code {
            case 401: return "You're not signed in. Please sign in and try again."
            case 403: return "You don't have permission to do that."
            case 429: return "Too many requests. Wait a moment and try again."
            case 500...599: return "Our server hit a snag. Try again in a moment."
            default: return msg
            }
        case .noNetwork: return "No internet connection. Check your connection and try again."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

// MARK: - Network availability check
extension SupabaseService {
    static func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
            [NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost].contains(nsError.code)
    }
}
