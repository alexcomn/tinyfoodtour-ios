import SwiftUI

@main
struct TinyFoodTourApp: App {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash = true

    init() {
        // Force all UIScrollViews to always bounce vertically so SwiftUI
        // ScrollViews scroll even if iOS 26 miscalculates content height.
        UIScrollView.appearance().alwaysBounceVertical = true
    }

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
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }
}
