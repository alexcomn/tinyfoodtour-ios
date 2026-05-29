import Foundation

struct ProfileTour: Identifiable {
    let id: String
    let neighborhood: String
    let stopCount: Int
}

struct FavouriteSpot: Identifiable {
    let id: String
    let name: String
    let neighborhood: String?
    let cuisineType: String?
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var savedTours: [ProfileTour] = []
    @Published var favorites: [FavouriteSpot] = []
    @Published var completedToursCount = 0
    @Published var isLoading = false

    var favoritesCount: Int { favorites.count }

    private let supabase = SupabaseService.shared

    func load(userId: String) async {
        isLoading = true

        // Profile stats
        struct ProfileRow: Codable { let completed_tours_count: Int? }
        if let rows: [ProfileRow] = try? await supabase.query(
            table: "profiles",
            select: "completed_tours_count",
            filters: ["id": "eq.\(userId)"]
        ), let row = rows.first {
            completedToursCount = row.completed_tours_count ?? 0
        }

        // Saved tours (joined with tours table for neighborhood + stop count)
        struct SavedRow: Codable { let tour_id: String }
        if let savedRows: [SavedRow] = try? await supabase.query(
            table: "saved_tours",
            select: "tour_id",
            filters: ["user_id": "eq.\(userId)"],
            order: "created_at.desc"
        ) {
            var tours: [ProfileTour] = []
            for row in savedRows.prefix(20) {
                struct TourRow: Codable {
                    let id: String
                    let neighborhood: String
                    let stops: AnyCodable
                }
                if let tourRows: [TourRow] = try? await supabase.query(
                    table: "tours",
                    select: "id,neighborhood,stops",
                    filters: ["id": "eq.\(row.tour_id)"]
                ), let t = tourRows.first {
                    let count: Int
                    if let arr = t.stops.value as? [[String: Any]] {
                        count = arr.filter { $0["_meta"] as? Bool != true }.count
                    } else { count = 0 }
                    tours.append(ProfileTour(id: t.id, neighborhood: t.neighborhood, stopCount: count))
                }
            }
            savedTours = tours
        }

        // Favourites
        struct FavRow: Codable {
            let place_id: String
            let restaurant_name: String
            let neighborhood: String?
            let cuisine_type: String?
        }
        if let favRows: [FavRow] = try? await supabase.query(
            table: "visited_restaurants",
            select: "place_id,restaurant_name,neighborhood,cuisine_type",
            filters: ["user_id": "eq.\(userId)", "is_favorite": "eq.true"],
            order: "visited_at.desc"
        ) {
            favorites = favRows.map {
                FavouriteSpot(id: $0.place_id, name: $0.restaurant_name,
                              neighborhood: $0.neighborhood, cuisineType: $0.cuisine_type)
            }
        }

        isLoading = false
    }
}
