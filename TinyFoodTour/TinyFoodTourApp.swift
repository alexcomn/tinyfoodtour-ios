import SwiftUI

@main
struct TinyFoodTourApp: App {
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(authVM)
        }
    }
}
