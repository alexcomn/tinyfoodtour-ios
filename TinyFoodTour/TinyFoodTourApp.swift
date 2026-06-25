import SwiftUI

@main
struct TinyFoodTourApp: App {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash = true
    @State private var deepLinkedTour: Tour?
    @State private var isLoadingDeepLink = false

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
            // tinyfoodtour://tour/{share_token}
            .onOpenURL { url in
                guard url.scheme == "tinyfoodtour",
                      url.host == "tour",
                      let token = url.pathComponents.dropFirst().first
                else { return }
                Task {
                    isLoadingDeepLink = true
                    deepLinkedTour = try? await SupabaseService.shared.fetchTour(byShareToken: token)
                    isLoadingDeepLink = false
                }
            }
            .sheet(item: $deepLinkedTour) { tour in
                NavigationStack {
                    ResultsView(tour: tour, isShared: true, generationParams: nil)
                        .environmentObject(authVM)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { deepLinkedTour = nil }
                                    .foregroundColor(Color("SlateMid"))
                            }
                        }
                }
            }
        }
    }
}
