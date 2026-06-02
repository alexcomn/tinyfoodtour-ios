import SwiftUI

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
                        .font(.system(size: 24, weight: .bold))

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
                            .font(.system(size: 13))
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
                            .font(.system(size: 14))
                            .foregroundColor(Color("Radish"))
                    }
                }
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
