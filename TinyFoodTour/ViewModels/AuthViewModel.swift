import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared
    private let tokenKey = "tft_access_token"
    private let userIdKey = "tft_user_id"
    private let userEmailKey = "tft_user_email"

    init() {
        // Restore session from UserDefaults
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let id = UserDefaults.standard.string(forKey: userIdKey) {
            let email = UserDefaults.standard.string(forKey: userEmailKey)
            currentUser = AuthUser(id: id, email: email)
            supabase.setAuthToken(token)
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await supabase.signIn(email: email, password: password)
            persist(response: response)
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        currentUser = nil
        supabase.setAuthToken(nil)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }

    private func persist(response: AuthResponse) {
        guard let token = response.access_token, let user = response.user else { return }
        currentUser = user
        supabase.setAuthToken(token)
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(user.id, forKey: userIdKey)
        UserDefaults.standard.set(user.email, forKey: userEmailKey)
    }
}
