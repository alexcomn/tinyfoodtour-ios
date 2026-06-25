import Foundation

struct Badge: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let description: String
    let requiredCount: Int
}

enum BadgesService {
    static let catalog: [Badge] = [
        Badge(id: "first_bite",  emoji: "🥢", title: "First Bite",          description: "Completed your first food tour",        requiredCount: 1),
        Badge(id: "explorer",    emoji: "🗺️", title: "Food Explorer",        description: "Completed 5 food tours",                requiredCount: 5),
        Badge(id: "regular",     emoji: "🏘️", title: "Neighborhood Regular", description: "Completed 10 food tours",               requiredCount: 10),
        Badge(id: "seasoned",    emoji: "🍜", title: "Seasoned Eater",        description: "Completed 25 food tours",               requiredCount: 25),
        Badge(id: "legend",      emoji: "🌟", title: "Tour Legend",           description: "Completed 50 food tours",               requiredCount: 50),
    ]

    static func earned(completedCount: Int) -> [Badge] {
        catalog.filter { completedCount >= $0.requiredCount }
    }

    static func nextUnearned(completedCount: Int) -> Badge? {
        catalog.first { completedCount < $0.requiredCount }
    }
}
