import Foundation

// MARK: - Model

struct TourReaction: Codable, Equatable {
    let share_token: String
    let stop_index: Int?
    let user_id: String
    let emoji: String
    let created_at: String
}

// MARK: - ViewModel
// One instance per tour (created in ResultsView). All ReactionBar views within
// the same tour share this instance — a single fetch covers tour + all stops.

@MainActor
final class ReactionsViewModel: ObservableObject {
    @Published private(set) var reactions: [TourReaction] = []
    @Published private(set) var isLoading = false

    let shareToken: String

    init(shareToken: String) {
        self.shareToken = shareToken
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            reactions = try await ReactionsService.fetch(shareToken: shareToken)
        } catch {
            // Non-critical — silently fail; user can still see the empty bar
        }
        isLoading = false
    }

    /// Grouped reaction counts for a given scope (nil = tour-level, int = stop-level).
    func grouped(forStop stopIndex: Int?) -> [(emoji: String, count: Int, userReacted: Bool)] {
        let userId = Session.shared.userId
        let filtered = reactions.filter { $0.stop_index == stopIndex }
        var groups: [String: (count: Int, reacted: Bool)] = [:]
        for r in filtered {
            var g = groups[r.emoji] ?? (0, false)
            g.count += 1
            if let uid = userId, r.user_id == uid { g.reacted = true }
            groups[r.emoji] = g
        }
        return groups
            .sorted { $0.value.count > $1.value.count }
            .map { (emoji: $0.key, count: $0.value.count, userReacted: $0.value.reacted) }
    }

    func toggle(emoji: String, stopIndex: Int?) async {
        guard let userId = Session.shared.userId else { return }
        let alreadyReacted = reactions.contains {
            $0.emoji == emoji && $0.stop_index == stopIndex && $0.user_id == userId
        }
        if alreadyReacted {
            reactions.removeAll { $0.emoji == emoji && $0.stop_index == stopIndex && $0.user_id == userId }
            do {
                try await ReactionsService.remove(shareToken: shareToken, stopIndex: stopIndex, emoji: emoji, userId: userId)
            } catch {
                await load()  // revert optimistic removal
            }
        } else {
            let new = TourReaction(
                share_token: shareToken, stop_index: stopIndex,
                user_id: userId, emoji: emoji,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            reactions.append(new)
            do {
                try await ReactionsService.add(shareToken: shareToken, stopIndex: stopIndex, emoji: emoji, userId: userId)
            } catch {
                await load()  // revert optimistic add
            }
        }
    }
}

// MARK: - Service (static helpers)

enum ReactionsService {
    static func fetch(shareToken: String) async throws -> [TourReaction] {
        try await SupabaseService.shared.query(
            table: "tour_reactions",
            select: "*",
            filters: ["share_token": "eq.\(shareToken)"]
        )
    }

    static func add(shareToken: String, stopIndex: Int?, emoji: String, userId: String) async throws {
        var body: [String: Any] = ["share_token": shareToken, "emoji": emoji, "user_id": userId]
        if let idx = stopIndex { body["stop_index"] = idx }
        try await SupabaseService.shared.insert(table: "tour_reactions", body: body)
    }

    static func remove(shareToken: String, stopIndex: Int?, emoji: String, userId: String) async throws {
        var filters: [String: String] = [
            "share_token": "eq.\(shareToken)",
            "emoji": "eq.\(emoji)",
            "user_id": "eq.\(userId)",
        ]
        // Supabase REST filter for NULL: "is.null"
        filters["stop_index"] = stopIndex.map { "eq.\($0)" } ?? "is.null"
        try await SupabaseService.shared.delete(table: "tour_reactions", filters: filters)
    }
}
