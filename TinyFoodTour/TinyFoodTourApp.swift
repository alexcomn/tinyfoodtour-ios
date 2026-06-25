import SwiftUI

// Thin Identifiable wrappers so optional-binding sheet works with String values.
struct HandleRoute: Identifiable { let id: String }   // id = handle

@main
struct TinyFoodTourApp: App {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash = true
    @State private var deepLinkedTour: Tour?

    // Universal Link destinations (set by handleUniversalLink)
    @State private var handleRoute: HandleRoute?       // /u/:handle  → M3
    @State private var universalLinkWalkCode: String?  // /walk/:code → M5

    init() {
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
            .toastOverlay()
            .task {
                // Bind Session singleton to auth state once at startup
                Session.shared.bind(to: authVM)

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
            // ── URL routing ──────────────────────────────────────────────────
            // Custom scheme:  tinyfoodtour://tour/{token}
            // Universal Link: https://tinyfoodtour.com/t/{slug}
            //                 https://tinyfoodtour.com/tour/{token}
            //                 https://tinyfoodtour.com/u/{handle}
            //                 https://tinyfoodtour.com/walk/{code}
            .onOpenURL { url in
                if url.scheme == "tinyfoodtour" {
                    handleCustomScheme(url)
                } else {
                    Task { await handleUniversalLink(url) }
                }
            }
            // Deep-linked tour (custom scheme + /tour/* universal)
            .sheet(item: $deepLinkedTour) { tour in
                NavigationStack {
                    ResultsView(tour: tour, isShared: true, generationParams: nil)
                        .environmentObject(authVM)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { deepLinkedTour = nil }
                                    .foregroundColor(Color.tftSlateMid)
                            }
                        }
                }
            }
            .sheet(item: $handleRoute) { route in
                PublicProfileView(handle: route.id)
                    .environmentObject(authVM)
            }
            // TODO M5: .sheet(item: $universalLinkWalkCode) { WalkTogetherView(code: $0) }
        }
    }

    // MARK: - Custom scheme handler (tinyfoodtour://)

    private func handleCustomScheme(_ url: URL) {
        guard url.scheme == "tinyfoodtour",
              url.host == "tour",
              let token = url.pathComponents.dropFirst().first
        else { return }
        Task {
            deepLinkedTour = try? await SupabaseService.shared.fetchTour(byShareToken: token)
        }
    }

    // MARK: - Universal Link handler (https://tinyfoodtour.com/*)

    @MainActor
    private func handleUniversalLink(_ url: URL) async {
        guard url.host == TFTConfig.webHost else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let prefix = parts.first else { return }

        switch prefix {
        case "t":
            // Short link: /t/{slug} — resolve slug → share_token, then load tour
            if let slug = parts[safe: 1] {
                await loadTourBySlug(slug)
            }

        case "tour":
            // Long link: /tour/{share_token}
            if let token = parts[safe: 1] {
                deepLinkedTour = try? await SupabaseService.shared.fetchTour(byShareToken: token)
            }

        case "u":
            if let handle = parts[safe: 1] {
                handleRoute = HandleRoute(id: handle)
            }

        case "walk":
            // Walk Together: /walk/{code} — wired up in M5
            if let code = parts[safe: 1] {
                universalLinkWalkCode = code
            }

        default:
            break
        }
    }

    private func loadTourBySlug(_ slug: String) async {
        struct SlugRow: Decodable { let share_token: String }
        guard let rows: [SlugRow] = try? await SupabaseService.shared.query(
            table: "tour_short_links",
            select: "share_token",
            filters: ["slug": "eq.\(slug)"]
        ), let token = rows.first?.share_token
        else { return }
        deepLinkedTour = try? await SupabaseService.shared.fetchTour(byShareToken: token)
    }
}

