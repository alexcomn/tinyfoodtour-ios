import Foundation
import SwiftUI
import PhotosUI

struct StopProgress {
    var completed: Bool = false
    var notes: String = ""
    var photos: [String] = []
}

@MainActor
final class LiveTourViewModel: ObservableObject {
    @Published var tour: Tour?
    @Published var isLoading = true
    @Published var currentStopIndex = 0
    @Published var progress: [StopProgress] = []
    @Published var noteText = ""
    @Published var isSaving = false
    @Published var isUploading = false
    @Published var favorites: Set<String> = []
    @Published var errorMessage: String?
    @Published var showCompletionCard = false

    private let supabase = SupabaseService.shared
    var tourId: String = ""

    var currentStop: TourStop? { tour?.stops[safe: currentStopIndex] }
    var currentProgress: StopProgress { progress[safe: currentStopIndex] ?? StopProgress() }
    var allCompleted: Bool { progress.allSatisfy { $0.completed } }

    func load(tourId: String, userId: String?) async {
        self.tourId = tourId
        struct TourRow: Codable {
            let id: String; let neighborhood: String; let vibe: [String]
            let dietary: [String]; let walk_distance: String; let stops: AnyCodable
            let created_at: String; let user_id: String?; let share_token: String
        }
        guard let rows: [TourRow] = try? await supabase.query(
            table: "tours", select: "*", filters: ["id": "eq.\(tourId)"]),
              let row = rows.first else {
            errorMessage = "Couldn't load this tour. Go back and try again."
            isLoading = false
            return
        }
        // Decode stops the same way as Tour.init(from:) — strip _meta entries first,
        // then decode each dict individually so one bad stop doesn't kill the array.
        let stops: [TourStop]
        if let arr = row.stops.value as? [[String: Any]] {
            stops = arr
                .filter { $0["_meta"] as? Bool != true }
                .compactMap { dict in
                    guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                    return try? JSONDecoder().decode(TourStop.self, from: data)
                }
        } else {
            stops = []
        }
        tour = Tour(id: row.id, neighborhood: row.neighborhood, vibe: row.vibe,
                    dietary: row.dietary, walk_distance: row.walk_distance,
                    stops: stops, created_at: row.created_at,
                    user_id: row.user_id, share_token: row.share_token)

        progress = Array(repeating: StopProgress(), count: stops.count)

        // Load saved progress
        struct ProgressRow: Codable { let stop_index: Int; let completed: Bool; let notes: String? }
        struct PhotoRow: Codable { let stop_index: Int; let photo_url: String }
        async let progressRows: [ProgressRow] = (try? supabase.query(
            table: "tour_stop_progress", select: "*", filters: ["tour_id": "eq.\(tourId)"])) ?? []
        async let photoRows: [PhotoRow] = (try? supabase.query(
            table: "tour_stop_photos", select: "*", filters: ["tour_id": "eq.\(tourId)"])) ?? []

        let (pRows, phRows) = await (progressRows, photoRows)
        for p in pRows where p.stop_index < stops.count {
            progress[p.stop_index].completed = p.completed
            progress[p.stop_index].notes = p.notes ?? ""
        }
        for ph in phRows where ph.stop_index < stops.count {
            progress[ph.stop_index].photos.append(ph.photo_url)
        }

        // Load favorites
        if let uid = userId {
            struct FavRow: Codable { let place_id: String }
            let favRows: [FavRow] = (try? await supabase.query(
                table: "visited_restaurants", select: "place_id",
                filters: ["user_id": "eq.\(uid)", "is_favorite": "eq.true"])) ?? []
            favorites = Set(favRows.map { $0.place_id })
        }

        let firstIncomplete = progress.firstIndex(where: { !$0.completed }) ?? 0
        currentStopIndex = firstIncomplete
        noteText = progress[safe: firstIncomplete]?.notes ?? ""
        isLoading = false
    }

    func checkOff(userId: String?) async {
        guard currentStopIndex < progress.count else { return }
        let newCompleted = !currentProgress.completed
        progress[currentStopIndex].completed = newCompleted
        await saveProgress(stopIndex: currentStopIndex, userId: userId)
        if newCompleted && allCompleted {
            showCompletionCard = true
            if let uid = userId { await recordTourCompletion(userId: uid) }
        }
    }

    func saveNotes(userId: String?) async {
        guard currentStopIndex < progress.count else { return }
        progress[currentStopIndex].notes = noteText
        await saveProgress(stopIndex: currentStopIndex, userId: userId)
    }

    private func saveProgress(stopIndex: Int, userId: String?) async {
        guard stopIndex < progress.count else { return }
        isSaving = true
        defer { isSaving = false }
        try? await supabase.upsert(
            table: "tour_stop_progress",
            body: [
                "tour_id": tourId,
                "stop_index": stopIndex,
                "completed": progress[stopIndex].completed,
                "notes": progress[stopIndex].notes,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ],
            onConflict: "tour_id,stop_index"
        )
        // Record visit
        if let uid = userId, let stop = tour?.stops[safe: stopIndex] {
            try? await supabase.upsert(
                table: "visited_restaurants",
                body: [
                    "user_id": uid,
                    "place_id": stop.place_id,
                    "restaurant_name": stop.name,
                    "neighborhood": tour?.neighborhood ?? "",
                    "cuisine_type": stop.cuisine_type ?? "",
                    "is_favorite": favorites.contains(stop.place_id),
                    "tour_id": tourId
                ],
                onConflict: "user_id,place_id,tour_id"
            )
        }
    }

    func toggleFavorite(stop: TourStop, userId: String?) async {
        let isFav = favorites.contains(stop.place_id)
        if isFav { favorites.remove(stop.place_id) } else { favorites.insert(stop.place_id) }
        guard let uid = userId else { return }
        try? await supabase.upsert(
            table: "visited_restaurants",
            body: [
                "user_id": uid,
                "place_id": stop.place_id,
                "restaurant_name": stop.name,
                "neighborhood": tour?.neighborhood ?? "",
                "cuisine_type": stop.cuisine_type,
                "is_favorite": !isFav,
                "tour_id": tourId
            ],
            onConflict: "user_id,place_id,tour_id"
        )
    }

    private func recordTourCompletion(userId: String) async {
        // Increment completed_tours_count in the user's profile
        // Uses Supabase RPC-style: read then write (no RPC function available)
        struct ProfileRow: Codable { let completed_tours_count: Int? }
        guard let rows: [ProfileRow] = try? await supabase.query(
            table: "profiles", select: "completed_tours_count",
            filters: ["id": "eq.\(userId)"]
        ), let current = rows.first?.completed_tours_count else { return }
        try? await supabase.upsert(
            table: "profiles",
            body: ["id": userId, "completed_tours_count": current + 1],
            onConflict: "id"
        )
    }

    func uploadPhoto(data: Data, userId: String?) async {
        isUploading = true
        defer { isUploading = false }
        let ext = "jpg"
        let path = "\(tourId)/\(currentStopIndex)/\(UUID().uuidString).\(ext)"
        do {
            let url = try await supabase.uploadPhoto(bucket: "tour-photos", path: path, data: data)
            guard currentStopIndex < progress.count else { return }
            progress[currentStopIndex].photos.append(url)
            try? await supabase.insert(
                table: "tour_stop_photos",
                body: ["tour_id": tourId, "stop_index": currentStopIndex, "photo_url": url]
            )
        } catch {
            errorMessage = "Couldn't save that photo. Try again."
        }
    }
}
