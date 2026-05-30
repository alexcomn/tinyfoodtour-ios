import SwiftUI

struct StopLabel {
    // Mirrors stopLabels.ts exactly
    private static let defaultLabels: [Int: [String]] = [
        2: ["FIRST BITE", "MAIN EVENT"],
        3: ["FIRST BITE", "MAIN EVENT", "SWEET FINISH"],
        4: ["FIRST BITE", "MAIN EVENT", "SIDE QUEST", "SWEET FINISH"],
        5: ["FIRST BITE", "DRINKS", "MAIN EVENT", "SIDE QUEST", "SWEET FINISH"],
    ]

    private static let specialPathLabels: [String: [String]] = [
        "Cafe hopping":    ["CAFÉ ONE", "CAFÉ TWO", "CAFÉ THREE"],
        "Just drinks!":    ["FIRST ROUND", "SECOND ROUND", "NIGHTCAP"],
        "Late night bites":["LATE BITE 1", "LATE BITE 2", "LATE BITE 3"],
        "Happy hour":      ["HH SPOT", "HH SPOT", "HH FINALE"],
    ]

    static func labels(vibes: [String], count: Int) -> [String] {
        for vibe in vibes {
            if let special = specialPathLabels[vibe] { return special }
        }
        return defaultLabels[count] ?? defaultLabels[3]!
    }

    static func label(index: Int, total: Int, vibes: [String] = []) -> String {
        let all = labels(vibes: vibes, count: total)
        return all[safe: index] ?? "STOP \(index + 1)"
    }

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
