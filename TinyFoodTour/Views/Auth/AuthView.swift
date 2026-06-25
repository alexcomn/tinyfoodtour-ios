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

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
