import Foundation

struct TourStop: Codable, Identifiable {
    var id: String { place_id }
    let stop_number: Int
    let stop_type: String
    let place_id: String
    let name: String
    let address: String?
    let lat: Double?
    let lng: Double?
    let cuisine_type: String?
    let cuisine_label: String?
    let price_level: Int?
    let website_url: String?
    let menu_url: String?
    let google_maps_url: String?
    let description: String?
    let walk_time_from_previous: String?
    let rating: Double?
    let photos: [String]?
    let opening_hours: [String]?

    init(stop_number: Int, stop_type: String, place_id: String, name: String,
         address: String?, lat: Double?, lng: Double?, cuisine_type: String?,
         cuisine_label: String?, price_level: Int?, website_url: String?,
         menu_url: String?, google_maps_url: String?, description: String?,
         walk_time_from_previous: String?, rating: Double?,
         photos: [String]?, opening_hours: [String]?) {
        self.stop_number = stop_number; self.stop_type = stop_type
        self.place_id = place_id; self.name = name; self.address = address
        self.lat = lat; self.lng = lng; self.cuisine_type = cuisine_type
        self.cuisine_label = cuisine_label; self.price_level = price_level
        self.website_url = website_url; self.menu_url = menu_url
        self.google_maps_url = google_maps_url; self.description = description
        self.walk_time_from_previous = walk_time_from_previous; self.rating = rating
        self.photos = photos; self.opening_hours = opening_hours
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Required — if these are missing the stop is malformed
        place_id           = try c.decode(String.self, forKey: .place_id)
        name               = try c.decode(String.self, forKey: .name)
        // Graceful fallbacks for everything else
        stop_number        = (try? c.decode(Int.self,    forKey: .stop_number))        ?? 1
        stop_type          = (try? c.decode(String.self, forKey: .stop_type))          ?? ""
        address            = try? c.decode(String.self, forKey: .address)
        lat                = try? c.decode(Double.self,  forKey: .lat)
        lng                = try? c.decode(Double.self,  forKey: .lng)
        cuisine_type       = try? c.decode(String.self, forKey: .cuisine_type)
        cuisine_label      = try? c.decode(String.self, forKey: .cuisine_label)
        price_level        = try? c.decode(Int.self,    forKey: .price_level)
        website_url        = try? c.decode(String.self, forKey: .website_url)
        menu_url           = try? c.decode(String.self, forKey: .menu_url)
        google_maps_url    = try? c.decode(String.self, forKey: .google_maps_url)
        description        = try? c.decode(String.self, forKey: .description)
        walk_time_from_previous = try? c.decode(String.self, forKey: .walk_time_from_previous)
        rating             = try? c.decode(Double.self, forKey: .rating)
        photos             = try? c.decode([String].self, forKey: .photos)
        opening_hours      = try? c.decode([String].self, forKey: .opening_hours)
    }
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
    // Extracted from the _meta synthetic stop injected by the edge function (§4.12)
    let tourTitle: String?
    let totalDistanceMiles: Double?

    init(id: String, neighborhood: String, vibe: [String], dietary: [String],
         walk_distance: String, stops: [TourStop], created_at: String,
         user_id: String?, share_token: String,
         tourTitle: String? = nil, totalDistanceMiles: Double? = nil) {
        self.id = id; self.neighborhood = neighborhood; self.vibe = vibe
        self.dietary = dietary; self.walk_distance = walk_distance; self.stops = stops
        self.created_at = created_at; self.user_id = user_id; self.share_token = share_token
        self.tourTitle = tourTitle; self.totalDistanceMiles = totalDistanceMiles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        neighborhood  = try c.decode(String.self, forKey: .neighborhood)
        vibe          = (try? c.decode([String].self, forKey: .vibe)) ?? []
        dietary       = (try? c.decode([String].self, forKey: .dietary)) ?? []
        walk_distance = (try? c.decode(String.self, forKey: .walk_distance)) ?? ""
        created_at    = (try? c.decode(String.self, forKey: .created_at)) ?? ""
        user_id       = try? c.decode(String.self, forKey: .user_id)
        share_token   = (try? c.decode(String.self, forKey: .share_token)) ?? ""

        // Decode stops as raw dicts so we can: (a) strip _meta entries,
        // (b) extract tour_title / total_distance_miles from the synthetic _meta stop
        var extractedTitle: String? = nil
        var extractedMiles: Double? = nil
        if let raw = try? c.decode(AnyCodable.self, forKey: .stops),
           let arr = raw.value as? [[String: Any]] {
            // Pull metadata from the _meta stop before filtering
            if let metaStop = arr.first(where: { $0["_meta"] as? Bool == true }),
               let meta = metaStop["_meta"] as? [String: Any] {
                extractedTitle = meta["tour_title"] as? String
                extractedMiles = meta["total_distance_miles"] as? Double
            }
            stops = arr
                .filter { $0["_meta"] as? Bool != true }
                .compactMap { dict in
                    guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                    return try? JSONDecoder().decode(TourStop.self, from: data)
                }
        } else {
            stops = []
        }
        tourTitle = extractedTitle
        totalDistanceMiles = extractedMiles
    }

    /// Display title: AI-generated tour title from _meta, fallback to neighborhood
    var displayTitle: String {
        tourTitle ?? "\(neighborhood) Tour"
    }
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
