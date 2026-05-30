import Foundation
import SwiftUI

@MainActor
final class QuizViewModel: ObservableObject {
    // Quiz tree (loaded from Supabase)
    @Published var allSteps: [QuizTreeStep] = []
    @Published var isLoadingTree = true
    @Published var treeError: String?

    // Neighborhood
    @Published var neighborhoodOptions: [NeighborhoodOption] = []
    @Published var isLoadingNeighborhoods = false
    @Published var locationDenied = false
    @Published var neighborhoodMode: String = "neighborhoods"
    @Published var isCuratedCity = false
    @Published var manualQuery = ""
    @Published var manualError: String?
    @Published var isSearching = false

    // Step navigation
    @Published var stepIndex = 0
    @Published var answers = QuizAnswers()

    // User history (for vibe options)
    @Published var completedToursCount = 0
    @Published var visitedPlaceIds: [String] = []
    @Published var favoritePlaceIds: [String] = []

    private let supabase = SupabaseService.shared

    let curatedCities = [
        "Seattle, WA", "Tokyo, Japan", "London, UK", "Paris, France",
        "Mexico City, Mexico", "Barcelona, Spain", "Amsterdam, Netherlands",
        "Sydney, Australia", "Berlin, Germany"
    ]

    var stepMap: [String: QuizTreeStep] {
        Dictionary(uniqueKeysWithValues: allSteps.map { ($0.step_key, $0) })
    }

    var stepSequence: [String] {
        QuizSequenceBuilder(stepMap: stepMap).buildSequence(answers: answers)
    }

    var totalSteps: Int { stepSequence.count }
    var currentStepKey: String { stepSequence[safe: stepIndex] ?? "meal_type" }
    var currentDbStep: QuizTreeStep? { stepMap[currentStepKey] }

    var currentTitle: String {
        if currentStepKey == "neighborhood" {
            return neighborhoodMode == "towns" ? "Explore nearby" : "Where are we exploring?"
        }
        return currentDbStep?.question ?? ""
    }

    var currentHint: String {
        if currentStepKey == "neighborhood" {
            return neighborhoodMode == "towns" ? "Pick a nearby town" : "Pick your neighborhood"
        }
        return currentDbStep?.hint ?? (currentDbStep?.step_type == "multi_select" ? "Select all that apply" : "")
    }

    var currentOptions: [String] {
        if currentStepKey == "neighborhood" {
            return neighborhoodOptions.map { $0.name }
        }
        guard let step = currentDbStep else { return [] }
        var opts = step.options.map { $0.label }
        if currentStepKey == "vibe" {
            if completedToursCount >= 1, !opts.contains("Try somewhere new!") { opts.append("Try somewhere new!") }
            if completedToursCount >= 3, !opts.contains("Visit an old favorite") { opts.append("Visit an old favorite") }
        }
        return opts
    }

    var canAdvance: Bool {
        switch currentStepKey {
        case "neighborhood": return !answers.neighborhood.isEmpty
        case "meal_type": return !answers.mealType.isEmpty
        case "vibe": return !answers.vibe.isEmpty
        case "cuisines", "cuisines_breakfast", "drink_cravings", "dessert_type", "cafe_atmosphere":
            return !answers.cuisines.isEmpty
        case "dietary": return !answers.dietary.isEmpty  // multi_select: need ≥1
        case "budget": return !answers.budget.isEmpty
        case "walk_distance": return !answers.walkDistance.isEmpty
        default: return false
        }
    }

    // MARK: - Load
    func loadTree() async {
        isLoadingTree = true
        treeError = nil
        do {
            struct Row: Codable {
                let step_key: String
                let parent_step_key: String?
                let question: String
                let hint: String?
                let step_type: String
                let options: AnyCodable
                let sort_order: Int
            }
            let rows: [Row] = try await supabase.query(
                table: "quiz_tree",
                select: "step_key,parent_step_key,question,hint,step_type,options,sort_order",
                filters: ["active": "eq.true"],
                order: "sort_order"
            )
            allSteps = rows.map { row in
                let opts: [QuizTreeOption]
                if let arr = row.options.value as? [[String: Any]] {
                    opts = arr.compactMap { dict in
                        guard let label = dict["label"] as? String else { return nil }
                        return QuizTreeOption(
                            label: label,
                            subtitle: dict["subtitle"] as? String,
                            next_step: dict["next_step"] as? String
                        )
                    }
                } else { opts = [] }
                return QuizTreeStep(
                    step_key: row.step_key,
                    parent_step_key: row.parent_step_key,
                    question: row.question,
                    hint: row.hint,
                    step_type: row.step_type,
                    options: opts,
                    sort_order: row.sort_order
                )
            }
        } catch {
            treeError = "Couldn't load the quiz. Please try again."
        }
        isLoadingTree = false
    }

    func loadUserHistory(userId: String) async {
        struct ProfileRow: Codable { let completed_tours_count: Int? }
        struct VisitedRow: Codable { let place_id: String; let is_favorite: Bool }
        async let profile: [ProfileRow] = (try? supabase.query(
            table: "profiles", select: "completed_tours_count",
            filters: ["id": "eq.\(userId)"])) ?? []
        async let visited: [VisitedRow] = (try? supabase.query(
            table: "visited_restaurants", select: "place_id,is_favorite",
            filters: ["user_id": "eq.\(userId)"])) ?? []
        let (p, v) = await (profile, visited)
        completedToursCount = p.first?.completed_tours_count ?? 0
        visitedPlaceIds = Array(Set(v.map { $0.place_id }))
        favoritePlaceIds = Array(Set(v.filter { $0.is_favorite }.map { $0.place_id }))
    }

    func geolocate() async {
        isLoadingNeighborhoods = true
        locationDenied = false
        do {
            let loc = try await LocationService.shared.requestLocation()
            await fetchNeighborhoods(body: ["lat": loc.coordinate.latitude, "lng": loc.coordinate.longitude])
        } catch {
            locationDenied = true
            isLoadingNeighborhoods = false
        }
    }

    func searchManual() async {
        guard !manualQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        manualError = nil
        await fetchNeighborhoods(body: ["query": manualQuery.trimmingCharacters(in: .whitespaces)])
        isSearching = false
    }

    func searchCity(_ query: String) async {
        isSearching = true
        manualError = nil
        manualQuery = query
        await fetchNeighborhoods(body: ["query": query])
        isSearching = false
    }

    private func fetchNeighborhoods(body: [String: Any]) async {
        struct Response: Codable {
            let neighborhoods: [NeighborhoodOption]?
            let mode: String?
            let curated: Bool?
            let error: String?
        }
        do {
            let response: Response = try await supabase.invokeFunction(name: "fetch-neighborhoods", body: body)
            if response.error == "location_not_found" {
                manualError = "We couldn't find that location. Try a city name or zip code."
                locationDenied = true
            } else if let nbhds = response.neighborhoods, !nbhds.isEmpty {
                neighborhoodOptions = nbhds
                neighborhoodMode = response.mode ?? "neighborhoods"
                isCuratedCity = response.curated ?? false
                locationDenied = false
            } else {
                locationDenied = true
            }
        } catch {
            manualError = "Something went wrong. Please try again."
            locationDenied = true
        }
        isLoadingNeighborhoods = false
    }

    // MARK: - Answer handling
    func selectNeighborhood(_ name: String) {
        let option = neighborhoodOptions.first(where: { $0.name == name })
        answers.neighborhood = name
        answers.lat = option?.lat
        answers.lng = option?.lng
    }

    func toggleOption(_ option: String) {
        switch currentStepKey {
        case "neighborhood":
            selectNeighborhood(option)
        case "meal_type":
            answers.mealType = option
        case "vibe":
            if let step = currentDbStep, step.step_type == "multi_select" {
                if answers.vibe.contains(option) {
                    answers.vibe.removeAll { $0 == option }
                } else {
                    answers.vibe.append(option)
                }
            } else {
                answers.vibe = [option]
            }
        case "cuisines", "cuisines_breakfast", "drink_cravings", "dessert_type", "cafe_atmosphere":
            if let step = currentDbStep, step.step_type == "multi_select" {
                if answers.cuisines.contains(option) {
                    answers.cuisines.removeAll { $0 == option }
                } else {
                    answers.cuisines.append(option)
                }
            } else {
                answers.cuisines = [option]
            }
        case "dietary":
            // Dietary is multi_select in quiz_tree — toggle membership
            if answers.dietary.contains(option) {
                answers.dietary.removeAll { $0 == option }
            } else {
                answers.dietary.append(option)
            }
        case "budget":
            answers.budget = option
        case "walk_distance":
            answers.walkDistance = option
        default:
            break
        }
    }

    func isSelected(_ option: String) -> Bool {
        switch currentStepKey {
        case "neighborhood": return answers.neighborhood == option
        case "meal_type": return answers.mealType == option
        case "vibe": return answers.vibe.contains(option)
        case "cuisines", "cuisines_breakfast", "drink_cravings", "dessert_type", "cafe_atmosphere":
            return answers.cuisines.contains(option)
        case "dietary": return answers.dietary.contains(option)
        case "budget": return answers.budget == option
        case "walk_distance": return answers.walkDistance == option
        default: return false
        }
    }

    func goNext() -> Bool {
        if answers.vibe.contains("Try somewhere new!") {
            answers.excludePlaceIds = visitedPlaceIds
        }
        if answers.vibe.contains("Visit an old favorite") {
            answers.favoritePlaceIds = favoritePlaceIds
        }
        if stepIndex < totalSteps - 1 {
            stepIndex += 1
            return false
        }
        return true // done — caller navigates to Generating
    }

    func goBack() -> Bool {
        if stepIndex > 0 {
            stepIndex -= 1
            return false
        }
        return true // back to Home
    }
}

// MARK: - AnyCodable helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([AnyDecodable].self) {
            value = arr.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            value = dict.mapValues { $0.value }
        } else if let str = try? container.decode(String.self) {
            // try JSON-parsing the string
            if let data = str.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                value = parsed
            } else {
                value = str
            }
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(describing: value))
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let arr = try? c.decode([AnyDecodable].self) { value = arr.map { $0.value } }
        else if let dict = try? c.decode([String: AnyDecodable].self) { value = dict.mapValues { $0.value } }
        else { value = "" }
    }
}

// MARK: - Safe subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
