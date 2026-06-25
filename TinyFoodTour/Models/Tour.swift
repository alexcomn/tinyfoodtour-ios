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

struct Tour: Codable, Identifiable, Equatable {
    static func == (lhs: Tour, rhs: Tour) -> Bool { lhs.id == rhs.id }
    let id: String
    let neighborhood: String
    let vibe: [String]
    let dietary: [String]
    let walk_distance: String
    let stops: [TourStop]
    let created_at: String
    let user_id: String?
    let share_token: String
    // Extracted from the _meta synthetic stop (§4.8 quiz-and-tour-logic-brief.md)
    let tourTitle: String?
    let totalDistanceMiles: Double?
    /// Relaxations fired during generation. "allowed_visited" → show stretched-tour notice.
    let relaxations: [String]
    /// The meal_type that drove this tour's progression (§4.8 brief).
    /// Used to key the correct stop labels in StopLabel.labels(mealType:vibes:count:).
    let mealType: String?

    init(id: String, neighborhood: String, vibe: [String], dietary: [String],
         walk_distance: String, stops: [TourStop], created_at: String,
         user_id: String?, share_token: String,
         tourTitle: String? = nil, totalDistanceMiles: Double? = nil,
         relaxations: [String] = [], mealType: String? = nil) {
        self.id = id; self.neighborhood = neighborhood; self.vibe = vibe
        self.dietary = dietary; self.walk_distance = walk_distance; self.stops = stops
        self.created_at = created_at; self.user_id = user_id; self.share_token = share_token
        self.tourTitle = tourTitle; self.totalDistanceMiles = totalDistanceMiles
        self.relaxations = relaxations; self.mealType = mealType
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
        var extractedRelaxations: [String] = []
        var extractedMealType: String? = nil
        if let raw = try? c.decode(AnyCodable.self, forKey: .stops),
           let arr = raw.value as? [[String: Any]] {
            // Pull metadata from the _meta stop (§4.8 brief)
            if let metaStop = arr.first(where: { $0["_meta"] is [String: Any] }),
               let meta = metaStop["_meta"] as? [String: Any] {
                extractedTitle = meta["tour_title"] as? String
                extractedMiles = meta["total_distance_miles"] as? Double
                extractedRelaxations = (meta["relaxations"] as? [String]) ?? []
                extractedMealType = meta["meal_type"] as? String  // §4.8: persisted for label keying
            }
            let decoded = arr
                .filter { !($0["_meta"] is [String: Any]) }
                .compactMap { dict -> TourStop? in
                    guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                    return try? JSONDecoder().decode(TourStop.self, from: data)
                }
            stops = Tour.reorderLinear(decoded)
        } else {
            stops = []
        }
        tourTitle = extractedTitle
        totalDistanceMiles = extractedMiles
        relaxations = extractedRelaxations
        mealType = extractedMealType
    }

    /// Display title: AI-generated tour title from _meta, fallback to neighborhood
    var displayTitle: String {
        tourTitle ?? "\(neighborhood) Tour"
    }

    // MARK: - Client-side TSP reorder
    // Mirrors reorderStopsLinear in generate-tour edge function.
    // Pins dessert last, runs nearest-neighbour TSP on remaining stops,
    // picks the start that yields the shortest total haversine distance.
    static func reorderLinear(_ stops: [TourStop]) -> [TourStop] {
        guard stops.count > 1 else { return stops }

        // Pin any "final" stop type last — extended per §4.2 brief to cover all progressions
        let dessertIdx = stops.indices.last(where: {
            StopLabel.finalStopTypes.contains(stops[$0].stop_type.lowercased())
        })

        var mobile = stops
        var pinned: TourStop? = nil
        if let di = dessertIdx {
            pinned = mobile.remove(at: di)
        }
        guard mobile.count > 1 else {
            var result = mobile
            if let p = pinned { result.append(p) }
            return result
        }

        func dist(_ a: TourStop, _ b: TourStop) -> Double {
            guard let la = a.lat, let lna = a.lng,
                  let lb = b.lat, let lnb = b.lng else { return 0 }
            let dLat = (lb - la) * .pi / 180
            let dLng = (lnb - lna) * .pi / 180
            let sinLat = sin(dLat / 2)
            let sinLng = sin(dLng / 2)
            let a2 = sinLat*sinLat + cos(la * .pi/180)*cos(lb * .pi/180)*sinLng*sinLng
            return 6371000 * 2 * atan2(sqrt(a2), sqrt(1 - a2))
        }

        var bestRoute = mobile
        var bestDist = Double.infinity

        for startIdx in mobile.indices {
            var remaining = mobile
            var route: [TourStop] = [remaining.remove(at: startIdx)]
            while !remaining.isEmpty {
                let last = route.last!
                let nextIdx = remaining.indices.min(by: { dist(last, remaining[$0]) < dist(last, remaining[$1]) })!
                route.append(remaining.remove(at: nextIdx))
            }
            var total = zip(route, route.dropFirst()).map { dist($0, $1) }.reduce(0, +)
            // Critically, include the leg from the last mobile stop to the pinned
            // final stop (dessert). Without this, the chosen ordering can end far
            // from the dessert, forcing the walker to double back to reach it.
            if let p = pinned, let last = route.last { total += dist(last, p) }
            if total < bestDist { bestDist = total; bestRoute = route }
        }

        // Final ordered list (mobile route + pinned final stop)
        var ordered = bestRoute
        if let p = pinned { ordered.append(p) }

        // Re-number and recompute walk_time_from_previous for the NEW order.
        // The server's Directions times were for its original ordering; after we
        // reorder they would be attached to the wrong legs. A haversine estimate
        // (~80 m/min walking) keeps the displayed times consistent with the drawn path.
        return ordered.enumerated().map { i, s in
            let walkText: String
            if i == 0 {
                walkText = "Starting point"
            } else {
                let meters = dist(ordered[i - 1], s)
                let mins = max(1, Int((meters / 80).rounded()))
                walkText = "\(mins) min walk"
            }
            return TourStop(stop_number: i + 1, stop_type: s.stop_type, place_id: s.place_id,
                            name: s.name, address: s.address, lat: s.lat, lng: s.lng,
                            cuisine_type: s.cuisine_type, cuisine_label: s.cuisine_label,
                            price_level: s.price_level, website_url: s.website_url,
                            menu_url: s.menu_url, google_maps_url: s.google_maps_url,
                            description: s.description, walk_time_from_previous: walkText,
                            rating: s.rating, photos: s.photos, opening_hours: s.opening_hours)
        }
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
    var dietary: [String] = []
    var budget: String = ""
    var walkDistance: String = ""
    var excludePlaceIds: [String] = []
    var favoritePlaceIds: [String] = []
}
