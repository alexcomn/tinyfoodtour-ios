import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit

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

    // MARK: - Google Sign In
    // Uses ASWebAuthenticationSession to drive Supabase's built-in Google OAuth
    // redirect flow. No Google SDK or client-ID config required on the iOS side —
    // Supabase owns the OAuth dance and redirects back via the tinyfoodtour:// scheme.
    // Tokens arrive in the URL fragment (#access_token=...&refresh_token=...) which
    // ASWebAuthenticationSession captures in full (unlike onOpenURL, which strips fragments).

    private var webAuthSession: ASWebAuthenticationSession?
    private var webAuthContext: WebAuthPresentationContext?

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        let redirectURI = "tinyfoodtour://auth/callback"
        guard let encoded = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string: "\(TFTConfig.supabaseURL)/auth/v1/authorize?provider=google&redirect_to=\(encoded)") else {
            errorMessage = "Invalid auth configuration."
            isLoading = false
            return
        }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
                let ctx = WebAuthPresentationContext()
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "tinyfoodtour"
                ) { url, error in
                    if let error { cont.resume(throwing: error); return }
                    guard let url else { cont.resume(throwing: OAuthError.missingCallback); return }
                    cont.resume(returning: url)
                }
                session.presentationContextProvider = ctx
                session.prefersEphemeralWebBrowserSession = false
                webAuthSession = session
                webAuthContext = ctx
                session.start()
            }

            // Supabase returns tokens in the URL fragment:
            // tinyfoodtour://auth/callback#access_token=...&refresh_token=...
            let params = fragmentParams(from: callbackURL)
            guard let accessToken = params["access_token"] else {
                throw OAuthError.missingToken
            }
            supabase.setAuthToken(accessToken)
            let user = try await supabase.getUser()
            persist(response: AuthResponse(
                access_token: accessToken,
                refresh_token: params["refresh_token"],
                user: user
            ))
        } catch {
            let nsErr = error as NSError
            let cancelled = nsErr.domain == ASWebAuthenticationSessionErrorDomain
                && nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
            if !cancelled { errorMessage = friendlyAuthError(error) }
        }

        isLoading = false
        webAuthSession = nil
        webAuthContext = nil
    }

    private func fragmentParams(from url: URL) -> [String: String] {
        var components = URLComponents()
        components.query = url.fragment ?? ""
        return Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
    }

    // MARK: - Apple Sign In

    private var currentNonce: String?
    private var appleCoordinator: AppleSignInCoordinator?

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        let nonce = randomNonce()
        currentNonce = nonce

        let coordinator = AppleSignInCoordinator()
        appleCoordinator = coordinator

        do {
            let credential = try await withCheckedThrowingContinuation { cont in
                coordinator.continuation = cont
                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                request.requestedScopes = [.email]
                request.nonce = sha256(nonce)

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = coordinator
                controller.presentationContextProvider = coordinator
                controller.performRequests()
            }

            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple Sign In failed. Please try again."
                isLoading = false
                return
            }
            let response = try await supabase.signInWithIdToken(
                provider: "apple", idToken: idToken, nonce: nonce
            )
            persist(response: response)
        } catch {
            if (error as? ASAuthorizationError)?.code == .canceled { /* user cancelled — no message */ }
            else { errorMessage = friendlyAuthError(error) }
        }
        isLoading = false
        appleCoordinator = nil
    }

    // MARK: - Nonce helpers (required by Apple + Supabase for security)

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random = [UInt8](repeating: 0, count: 16)
            SecRandomCopyBytes(kSecRandomDefault, random.count, &random)
            random.forEach { byte in
                if remaining == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Error helpers

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

// MARK: - Google OAuth helpers

enum OAuthError: Error { case missingCallback, missingToken }

private final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Apple Sign In coordinator
// Bridges ASAuthorizationController delegate callbacks to async/await.
private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: ASAuthorizationError(.invalidResponse))
            continuation = nil
            return
        }
        continuation?.resume(returning: cred)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
