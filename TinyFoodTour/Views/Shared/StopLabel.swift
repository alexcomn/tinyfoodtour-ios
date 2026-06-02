import SwiftUI

// Mirrors stopLabels.ts (tone-and-voice-brief.md §4 + quiz-and-tour-logic-brief.md §4.3)
// Labels are keyed by meal_type FIRST (read from _meta.meal_type), with legacy
// vibe-keyed fallbacks for tours generated before meal_type was persisted.
struct StopLabel {

    // MARK: - Default food progression
    private static let defaultLabels: [Int: [String]] = [
        2: ["FIRST BITE", "MAIN EVENT"],
        3: ["FIRST BITE", "MAIN EVENT", "SWEET FINISH"],
        4: ["FIRST BITE", "MAIN EVENT", "SIDE QUEST", "SWEET FINISH"],
        5: ["FIRST BITE", "DRINKS", "MAIN EVENT", "SIDE QUEST", "SWEET FINISH"],
    ]

    // MARK: - Meal-type keyed progressions (canonical — §4.3 brief)
    private static let mealTypeLabels: [String: [Int: [String]]] = [
        "Cafe hopping": [
            2: ["ESPRESSO BAR", "PASTRY CAFÉ"],
            3: ["ESPRESSO BAR", "POUR-OVER", "PASTRY CAFÉ"],
            4: ["ESPRESSO BAR", "POUR-OVER", "TEA HOUSE", "PASTRY CAFÉ"],
            5: ["ESPRESSO BAR", "POUR-OVER", "TEA HOUSE", "MATCHA CAFÉ", "PASTRY CAFÉ"],
        ],
        "Just drinks!": [
            2: ["OPENER", "NIGHTCAP"],
            3: ["OPENER", "MAIN BAR", "NIGHTCAP"],
            4: ["OPENER", "SIDE BAR", "MAIN BAR", "NIGHTCAP"],
            5: ["OPENER", "SIDE BAR", "DANCE FLOOR", "MAIN BAR", "NIGHTCAP"],
        ],
        "Desserts": [
            2: ["SWEET START", "SWEET FINALE"],
            3: ["SWEET START", "MAIN INDULGENCE", "SWEET FINALE"],
            4: ["SWEET START", "SIDE TREAT", "MAIN INDULGENCE", "SWEET FINALE"],
            5: ["SWEET START", "PALATE CLEANSER", "SIDE TREAT", "MAIN INDULGENCE", "SWEET FINALE"],
        ],
        "Happy Hour": [
            2: ["FIRST POUR", "DEAL FINALE"],
            3: ["FIRST POUR", "SHAREABLE BITES", "DEAL FINALE"],
            4: ["FIRST POUR", "DEAL HUNT", "SHAREABLE BITES", "DEAL FINALE"],
            5: ["FIRST POUR", "DEAL HUNT", "MAIN POUR", "SHAREABLE BITES", "DEAL FINALE"],
        ],
        "Late night bites": [
            2: ["LATE BITE", "NIGHTCAP BITE"],
            3: ["LATE BITE", "MAIN LATE EATS", "NIGHTCAP BITE"],
            4: ["LATE BITE", "SIDE QUEST", "MAIN LATE EATS", "NIGHTCAP BITE"],
            5: ["LATE BITE", "SIDE QUEST", "EXTRA EATS", "MAIN LATE EATS", "NIGHTCAP BITE"],
        ],
    ]

    // MARK: - Lookup

    /// Primary entry point. Pass mealType from _meta (preferred) and vibes as fallback.
    static func labels(mealType: String? = nil, vibes: [String] = [], count: Int) -> [String] {
        // 1. meal_type key (authoritative for tours with _meta.meal_type)
        if let mt = mealType, let byCount = mealTypeLabels[mt] {
            return byCount[count] ?? byCount[3] ?? defaultLabels[count] ?? defaultLabels[3]!
        }
        // 2. Legacy vibe fallback (tours generated before meal_type was persisted)
        for vibe in vibes {
            if let byCount = mealTypeLabels[vibe] {
                return byCount[count] ?? byCount[3] ?? defaultLabels[count] ?? defaultLabels[3]!
            }
        }
        // 3. Default food progression
        return defaultLabels[count] ?? defaultLabels[3]!
    }

    static func label(index: Int, total: Int, mealType: String? = nil, vibes: [String] = []) -> String {
        let all = labels(mealType: mealType, vibes: vibes, count: total)
        return all[safe: index] ?? "STOP \(index + 1)"
    }

    // MARK: - TSP: stop types that must be pinned last
    // Extended per §4.2 brief to include all "final" stop types across progressions.
    static let finalStopTypes: Set<String> = [
        "dessert", "sweet_finish", "sweet finish",
        "sweet finale", "sweet_finale",
        "nightcap", "nightcap bite", "nightcap_bite",
        "deal finale", "deal_finale",
        "pastry cafe", "pastry_cafe",
    ]

    // MARK: - Marker colors (fixed cycle — maps-and-walking-brief.md §2)
    static let colors: [Color] = [
        Color(hex: "#c40505"),
        Color(hex: "#666429"),
        Color(hex: "#540303"),
        Color(hex: "#96b516"),
        Color(hex: "#9b193d"),
    ]

    static func color(index: Int) -> Color {
        colors[safe: index % colors.count] ?? colors[0]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
