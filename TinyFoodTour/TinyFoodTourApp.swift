import SwiftUI

@main
struct TinyFoodTourApp: App {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .environmentObject(authVM)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Hold splash briefly, then fade out
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}
