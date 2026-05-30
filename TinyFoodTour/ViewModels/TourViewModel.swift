import Foundation
import SwiftUI

@MainActor
final class TourViewModel: ObservableObject {
    @Published var tour: Tour?
    @Published var isGenerating = false
    @Published var generationError: String?
    @Published var generatingMessage = "Scouting the block..."

    private let messages = [
        "Scouting the block...",
        "Bribing the chefs...",
        "Checking for vibes...",
        "Negotiating with dessert...",
        "Almost plated...",
    ]
    private var messageTask: Task<Void, Never>?

    func generateWithTweaks(answers: QuizAnswers, numStops: Int, maxPrice: Int) async {
        var tweaked = answers
        // numStops and maxPrice passed directly to the edge function
        await generateCore(answers: tweaked, numStops: numStops, maxPrice: maxPrice)
    }

    func generate(answers: QuizAnswers) async {
        await generateCore(answers: answers, numStops: nil, maxPrice: nil)
    }

    private func generateCore(answers: QuizAnswers, numStops: Int?, maxPrice: Int?) async {
        isGenerating = true
        generationError = nil
        startMessageCycle()

        var body: [String: Any] = [
            "neighborhood": answers.neighborhood,
            "vibe": answers.vibe,
            "dietary": [answers.dietary].filter { !$0.isEmpty },
            "walk_distance": answers.walkDistance,
        ]
        if let lat = answers.lat, let lng = answers.lng {
            body["lat"] = lat
            body["lng"] = lng
        }
        if !answers.cuisines.isEmpty { body["cuisines"] = answers.cuisines }
        if !answers.mealType.isEmpty { body["meal_type"] = answers.mealType }
        if let mp = maxPrice {
            body["max_price"] = mp
        } else if !answers.budget.isEmpty {
            let priceMap = ["$": 1, "$$": 2, "$$$": 3]
            if let price = priceMap[answers.budget] { body["max_price"] = price }
        }
        if let ns = numStops { body["num_stops"] = ns }
        if !answers.excludePlaceIds.isEmpty { body["exclude_place_ids"] = answers.excludePlaceIds }
        if !answers.favoritePlaceIds.isEmpty { body["favorite_place_ids"] = answers.favoritePlaceIds }

        do {
            let result: Tour = try await SupabaseService.shared.invokeFunction(name: "generate-tour", body: body)
            tour = result
        } catch {
            if SupabaseService.isNetworkError(error) {
                generationError = "No internet connection. Check your connection and try again."
            } else {
                generationError = error.localizedDescription
            }
        }

        messageTask?.cancel()
        isGenerating = false
    }

    private func startMessageCycle() {
        messageTask?.cancel()
        generatingMessage = messages[0]
        var idx = 0
        messageTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { break }
                idx = (idx + 1) % messages.count
                generatingMessage = messages[idx]
            }
        }
    }
}

@MainActor
final class SavedToursViewModel: ObservableObject {
    @Published var savedTours: [Tour] = []
    @Published var isLoading = false

    private let storageKey = "tft_saved_tour_tokens"
    private let supabase = SupabaseService.shared

    func load() async {
        let tokens = savedTokens()
        guard !tokens.isEmpty else { return }
        isLoading = true
        var tours: [Tour] = []
        for token in tokens {
            struct Row: Codable {
                let id: String; let neighborhood: String; let vibe: [String]
                let dietary: [String]; let walk_distance: String; let stops: AnyCodable
                let created_at: String; let user_id: String?; let share_token: String
            }
            if let rows: [Row] = try? await supabase.query(
                table: "tours", select: "*", filters: ["share_token": "eq.\(token)"]) {
                for row in rows {
                    // Strip _meta before decoding — same pattern as Tour.init(from:)
                    let stops: [TourStop]
                    if let arr = row.stops.value as? [[String: Any]] {
                        stops = arr
                            .filter { $0["_meta"] as? Bool != true }
                            .compactMap { dict in
                                guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                                return try? JSONDecoder().decode(TourStop.self, from: data)
                            }
                    } else { stops = [] }
                    tours.append(Tour(
                        id: row.id, neighborhood: row.neighborhood, vibe: row.vibe,
                        dietary: row.dietary, walk_distance: row.walk_distance,
                        stops: stops, created_at: row.created_at,
                        user_id: row.user_id, share_token: row.share_token))
                }
            }
        }
        savedTours = tours
        isLoading = false
    }

    func saveTour(token: String) {
        var tokens = savedTokens()
        guard !tokens.contains(token) else { return }
        tokens.insert(token, at: 0)
        UserDefaults.standard.set(Array(tokens.prefix(20)), forKey: storageKey)
    }

    private func savedTokens() -> [String] {
        UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }
}
