import Foundation

struct ProfileTour: Identifiable {
    let id: String                  // tours.id
    let savedTourId: String?        // saved_tours.id — nil for just-migrated rows
    let neighborhood: String
    let tourTitle: String?          // name stored in saved_tours (AI title or custom)
    let stopCount: Int
    let shareToken: String
    let savedAt: Date?              // saved_tours.created_at
    var customName: String?         // user rename, in UserDefaults

    /// Display hierarchy: user rename → saved title → "Neighbourhood Tour"
    var displayName: String { customName ?? tourTitle ?? "\(neighborhood) Tour" }

    var formattedDate: String? {
        guard let date = savedAt else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

struct FavouriteSpot: Identifiable {
    let id: String; let name: String
    let neighborhood: String?; let cuisineType: String?
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var editingDisplayName = false
    @Published var displayNameDraft = ""
    @Published var savedTours: [ProfileTour] = []
    @Published var favorites: [FavouriteSpot] = []
    @Published var completedToursCount = 0
    @Published var isLoading = false
    @Published var isSavingName = false

    var favoritesCount: Int { favorites.count }

    private let supabase = SupabaseService.shared
    private let localTokensKey = "tft_saved_tour_tokens"
    private let localNamesKey  = "tft_tour_names"

    // MARK: - Load
    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        // Profile stats
        struct ProfileRow: Codable { let completed_tours_count: Int?; let display_name: String? }
        if let rows: [ProfileRow] = try? await supabase.query(
            table: "profiles", select: "completed_tours_count,display_name",
            filters: ["id": "eq.\(userId)"]
        ), let row = rows.first {
            completedToursCount = row.completed_tours_count ?? 0
            displayName = row.display_name ?? ""
        }

        // Supabase saved_tours is the primary store for signed-in users
        struct SavedRow: Codable {
            let id: String; let tour_id: String; let name: String; let created_at: String
        }
        let supabaseRows: [SavedRow] = (try? await supabase.query(
            table: "saved_tours", select: "id,tour_id,name,created_at",
            filters: ["user_id": "eq.\(userId)"], order: "created_at.desc"
        )) ?? []

        // Build ProfileTours from Supabase
        struct TourRow: Codable {
            let id: String; let neighborhood: String; let stops: AnyCodable; let share_token: String
        }
        let localNames = (UserDefaults.standard.dictionary(forKey: localNamesKey) as? [String: String]) ?? [:]
        var tours: [ProfileTour] = []
        var syncedTourIds = Set<String>()

        for row in supabaseRows {
            syncedTourIds.insert(row.tour_id)
            guard let tRows: [TourRow] = try? await supabase.query(
                table: "tours", select: "id,neighborhood,stops,share_token",
                filters: ["id": "eq.\(row.tour_id)"]
            ), let t = tRows.first else { continue }

            let count = (t.stops.value as? [[String: Any]])?.filter { $0["_meta"] as? Bool != true }.count ?? 0
            let savedAt = ISO8601DateFormatter().date(from: row.created_at)
            tours.append(ProfileTour(
                id: t.id, savedTourId: row.id,
                neighborhood: t.neighborhood, tourTitle: row.name,
                stopCount: count, shareToken: t.share_token,
                savedAt: savedAt, customName: localNames[t.share_token]
            ))
            // Keep local tokens in sync so HomeView saved list stays consistent
            addLocalToken(t.share_token)
        }

        // Migrate UserDefaults-only tokens to Supabase (fire-and-forget)
        let localTokens = UserDefaults.standard.stringArray(forKey: localTokensKey) ?? []
        let syncedTokens = Set(tours.map { $0.shareToken })
        for token in localTokens where !syncedTokens.contains(token) {
            guard let tRows: [TourRow] = try? await supabase.query(
                table: "tours", select: "id,neighborhood,stops,share_token",
                filters: ["share_token": "eq.\(token)"]
            ), let t = tRows.first else { continue }
            if syncedTourIds.contains(t.id) { continue }

            // Extract AI title from _meta for a better default name
            var aiTitle: String? = nil
            if let arr = t.stops.value as? [[String: Any]],
               let meta = arr.first(where: { $0["_meta"] as? Bool == true })?["_meta"] as? [String: Any] {
                aiTitle = meta["tour_title"] as? String
            }
            let name = aiTitle ?? "\(t.neighborhood) Tour"
            let count = (t.stops.value as? [[String: Any]])?.filter { $0["_meta"] as? Bool != true }.count ?? 0

            // Insert to Supabase (savedTourId comes back on next load)
            try? await supabase.insert(
                table: "saved_tours",
                body: ["user_id": userId, "tour_id": t.id, "name": name]
            )
            tours.append(ProfileTour(
                id: t.id, savedTourId: nil,           // populated next time
                neighborhood: t.neighborhood, tourTitle: name,
                stopCount: count, shareToken: token,
                savedAt: Date(), customName: localNames[token]
            ))
        }

        savedTours = tours

        // Favourites
        struct FavRow: Codable {
            let place_id: String; let restaurant_name: String
            let neighborhood: String?; let cuisine_type: String?
        }
        if let rows: [FavRow] = try? await supabase.query(
            table: "visited_restaurants",
            select: "place_id,restaurant_name,neighborhood,cuisine_type",
            filters: ["user_id": "eq.\(userId)", "is_favorite": "eq.true"],
            order: "visited_at.desc"
        ) {
            favorites = rows.map {
                FavouriteSpot(id: $0.place_id, name: $0.restaurant_name,
                              neighborhood: $0.neighborhood, cuisineType: $0.cuisine_type)
            }
        }
    }

    // MARK: - Display name
    func saveDisplayName(userId: String) async {
        guard !displayNameDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSavingName = true
        try? await supabase.upsert(
            table: "profiles",
            body: ["id": userId, "display_name": displayNameDraft.trimmingCharacters(in: .whitespaces)],
            onConflict: "id"
        )
        displayName = displayNameDraft.trimmingCharacters(in: .whitespaces)
        editingDisplayName = false
        isSavingName = false
    }

    // MARK: - Saved tours
    func removeTour(token: String, savedTourId: String?) async {
        removeLocalToken(token)
        savedTours.removeAll { $0.shareToken == token }
        if let sid = savedTourId {
            try? await supabase.delete(table: "saved_tours", filters: ["id": "eq.\(sid)"])
        }
    }

    func renameTour(token: String, newName: String) {
        var names = (UserDefaults.standard.dictionary(forKey: localNamesKey) as? [String: String]) ?? [:]
        names[token] = newName
        UserDefaults.standard.set(names, forKey: localNamesKey)
        if let idx = savedTours.firstIndex(where: { $0.shareToken == token }) {
            savedTours[idx].customName = newName
        }
    }

    // MARK: - Helpers
    private func addLocalToken(_ token: String) {
        var tokens = UserDefaults.standard.stringArray(forKey: localTokensKey) ?? []
        guard !tokens.contains(token) else { return }
        tokens.insert(token, at: 0)
        UserDefaults.standard.set(Array(tokens.prefix(20)), forKey: localTokensKey)
    }

    private func removeLocalToken(_ token: String) {
        var tokens = UserDefaults.standard.stringArray(forKey: localTokensKey) ?? []
        tokens.removeAll { $0 == token }
        UserDefaults.standard.set(tokens, forKey: localTokensKey)
    }
}
