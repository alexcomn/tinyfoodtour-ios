import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    BrandMarkView(fontSize: 20)
                        .padding(.top, 32)

                    Text(isSignUp ? "Create an account" : "Welcome back")
                        .font(TFTFont.heading(24))

                    // ── Social sign-in ────────────────────────────────────
                    VStack(spacing: 12) {
                        SignInWithAppleButton(
                            isSignUp ? .signUp : .signIn,
                            onRequest: { _ in },
                            onCompletion: { _ in }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            Task {
                                await authVM.signInWithApple()
                                if authVM.currentUser != nil { dismiss() }
                            }
                        }

                        GoogleSignInButton {
                            Task {
                                await authVM.signInWithGoogle()
                                if authVM.currentUser != nil { dismiss() }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // ── Divider ───────────────────────────────────────────
                    HStack(spacing: 10) {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                        Text("or")
                            .scaledFont(size: 12)
                            .foregroundColor(Color("SlateMid"))
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // ── Email / password ──────────────────────────────────
                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 24)

                    if let error = authVM.errorMessage {
                        Text(error)
                            .scaledFont(size: 13)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    CTAButton(
                        title: isSignUp ? "Sign up" : "Sign in",
                        isEnabled: !email.isEmpty && password.count >= 6 && !authVM.isLoading
                    ) {
                        Task {
                            if isSignUp {
                                await authVM.signUp(email: email, password: password)
                            } else {
                                await authVM.signIn(email: email, password: password)
                            }
                            if authVM.currentUser != nil { dismiss() }
                        }
                    }

                    if authVM.isLoading {
                        ProgressView().tint(Color("Radish"))
                    }

                    Button {
                        isSignUp.toggle()
                        authVM.errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                            .scaledFont(size: 14)
                            .foregroundColor(Color("Radish"))
                    }
                }
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Google Sign-In button
// Follows Google's brand guidelines: white background, border, Google G logo.
// Replace the "G" Text with an Image("google-logo") asset if you add the SVG to Assets.xcassets.

struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Google G — four-color approximation using a rounded square + text
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                    Text("G")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.27, blue: 0.23),  // Google red
                                    Color(red: 0.06, green: 0.56, blue: 0.94),  // Google blue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Continue with Google")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
