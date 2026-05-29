import Foundation

// MARK: - Configuration
// Set these in TinyFoodTour/Config.xcconfig (not committed) or via Info.plist
// For initial development they are hardcoded here and should be moved to env config before shipping
private let supabaseURL = "https://xefehzsclkefebzyqdrh.supabase.co"
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlZmVoenNjbGtlZmVienlxZHJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzU5NTMsImV4cCI6MjA5MDUxMTk1M30.lPR244Zm5Dgrx5zy_tO8v3sQWyQRZF0ZFRjmfnGGl6c"

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

    // MARK: - Edge Functions
    func invokeFunction<T: Decodable>(name: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: URL(string: "\(supabaseURL)/functions/v1/\(name)")!)
        request.httpMethod = "POST"
        baseHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Auth
    func signUp(email: String, password: String) async throws -> AuthResponse {
        try await authRequest(endpoint: "signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        try await authRequest(endpoint: "token?grant_type=password", email: email, password: password)
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
    let user: AuthUser?
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

enum SupabaseError: LocalizedError {
    case httpError(statusCode: Int, message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .httpError(_, let msg): return msg
        case .unknown: return "An unknown error occurred"
        }
    }
}
