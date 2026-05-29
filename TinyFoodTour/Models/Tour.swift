import Foundation

struct TourStop: Codable, Identifiable {
    var id: String { place_id }
    let stop_number: Int
    let stop_type: String
    let place_id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let cuisine_type: String
    let cuisine_label: String?
    let price_level: Int
    let website_url: String
    let menu_url: String?
    let google_maps_url: String?
    let description: String
    let walk_time_from_previous: String
    let rating: Double?
    let photos: [String]?
    let opening_hours: [String]?
}

struct Tour: Codable, Identifiable {
    let id: String
    let neighborhood: String
    let vibe: [String]
    let dietary: [String]
    let walk_distance: String
    let stops: [TourStop]
    let created_at: String
    let user_id: String?
    let share_token: String
}

struct NeighborhoodOption: Codable {
    let name: String
    let lat: Double
    let lng: Double
}

struct QuizAnswers {
    var mealType: String = ""
    var neighborhood: String = ""
    var lat: Double?
    var lng: Double?
    var vibe: [String] = []
    var cuisines: [String] = []
    var dietary: String = ""
    var budget: String = ""
    var walkDistance: String = ""
    var excludePlaceIds: [String] = []
    var favoritePlaceIds: [String] = []
}
