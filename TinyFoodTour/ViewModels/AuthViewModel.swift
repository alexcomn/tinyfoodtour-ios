import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared
    private let tokenKey        = "tft_access_token"
    private let refreshTokenKey = "tft_refresh_token"
    private let userIdKey       = "tft_user_id"
    private let userEmailKey    = "tft_user_email"

    init() {
        // Restore session from UserDefaults. Access tokens expire after ~1 hour,
        // so we set up the token for immediate use and kick off a refresh in the background.
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let id = UserDefaults.standard.string(forKey: userIdKey) {
            let email = UserDefaults.standard.string(forKey: userEmailKey)
            currentUser = AuthUser(id: id, email: email)
            supabase.setAuthToken(token)
            // Refresh silently so the token is fresh for subsequent requests
            Task { await refreshIfNeeded() }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await supabase.signIn(email: email, password: password)
            persist(response: response)
        } catch {
            errorMessage = friendlyAuthError(error)
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await supabase.signUp(email: email, password: password)
            persist(response: response)
        } catch {
            errorMessage = friendlyAuthError(error)
        }
        isLoading = false
    }

    func signOut() {
        currentUser = nil
        supabase.setAuthToken(nil)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }

    // MARK: - Token refresh
    private func refreshIfNeeded() async {
        guard let refresh = UserDefaults.standard.string(forKey: refreshTokenKey) else { return }
        do {
            let response = try await supabase.refreshToken(refresh)
            persist(response: response)
        } catch {
            // Refresh failed (token revoked or expired) — sign out silently
            signOut()
        }
    }

    // MARK: - Helpers
    private func persist(response: AuthResponse) {
        guard let token = response.access_token, let user = response.user else { return }
        currentUser = user
        supabase.setAuthToken(token)
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(user.id, forKey: userIdKey)
        UserDefaults.standard.set(user.email, forKey: userEmailKey)
        if let refresh = response.refresh_token {
            UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
        }
    }

    private func friendlyAuthError(_ error: Error) -> String {
        if SupabaseService.isNetworkError(error) {
            return "No internet connection. Check your connection and try again."
        }
        let desc = error.localizedDescription.lowercased()
        if desc.contains("invalid") || desc.contains("credentials") || desc.contains("password") {
            return "Incorrect email or password."
        }
        if desc.contains("already registered") || desc.contains("already exists") {
            return "An account with that email already exists. Try signing in."
        }
        return error.localizedDescription
    }
}
