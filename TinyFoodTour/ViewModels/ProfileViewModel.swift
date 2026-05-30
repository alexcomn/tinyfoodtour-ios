import Foundation

struct ProfileTour: Identifiable {
    let id: String
    let neighborhood: String
    let stopCount: Int
    let shareToken: String
    var customName: String?

    var displayName: String { customName ?? "\(neighborhood) Tour" }
}

struct FavouriteSpot: Identifiable {
    let id: String
    let name: String
    let neighborhood: String?
    let cuisineType: String?
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
    private let storageKey = "tft_saved_tour_tokens"
    private let tourNamesKey = "tft_tour_names"  // [token: name]

    func load(userId: String) async {
        isLoading = true

        // Profile stats + display name
        struct ProfileRow: Codable {
            let completed_tours_count: Int?
            let display_name: String?
        }
        if let rows: [ProfileRow] = try? await supabase.query(
            table: "profiles",
            select: "completed_tours_count,display_name",
            filters: ["id": "eq.\(userId)"]
        ), let row = rows.first {
            completedToursCount = row.completed_tours_count ?? 0
            displayName = row.display_name ?? ""
        }

        // Saved tours from UserDefaults tokens
        let tokens = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        let names = (UserDefaults.standard.dictionary(forKey: tourNamesKey) as? [String: String]) ?? [:]
        var tours: [ProfileTour] = []
        for token in tokens.prefix(20) {
            struct TourRow: Codable { let id: String; let neighborhood: String; let stops: AnyCodable }
            if let rows: [TourRow] = try? await supabase.query(
                table: "tours", select: "id,neighborhood,stops",
                filters: ["share_token": "eq.\(token)"]
            ), let t = rows.first {
                let count = (t.stops.value as? [[String: Any]])?.filter { $0["_meta"] as? Bool != true }.count ?? 0
                tours.append(ProfileTour(id: t.id, neighborhood: t.neighborhood,
                                        stopCount: count, shareToken: token,
                                        customName: names[token]))
            }
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

        isLoading = false
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

    // MARK: - Saved tours management
    func removeTour(token: String) {
        var tokens = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        tokens.removeAll { $0 == token }
        UserDefaults.standard.set(tokens, forKey: storageKey)
        savedTours.removeAll { $0.shareToken == token }
    }

    func renameTour(token: String, newName: String) {
        var names = (UserDefaults.standard.dictionary(forKey: tourNamesKey) as? [String: String]) ?? [:]
        names[token] = newName
        UserDefaults.standard.set(names, forKey: tourNamesKey)
        if let idx = savedTours.firstIndex(where: { $0.shareToken == token }) {
            savedTours[idx].customName = newName
        }
    }
}
