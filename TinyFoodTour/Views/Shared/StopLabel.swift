import SwiftUI

struct StopLabel {
    static func label(index: Int, total: Int) -> String {
        switch total {
        case 2:
            return index == 0 ? "FIRST BITE" : "MAIN EVENT"
        case 3:
            switch index {
            case 0: return "FIRST BITE"
            case 1: return "MAIN EVENT"
            default: return "SWEET FINISH"
            }
        case 4:
            switch index {
            case 0: return "FIRST BITE"
            case 1: return "MAIN EVENT"
            case 2: return "SIDE QUEST"
            default: return "SWEET FINISH"
            }
        default: // 5+
            switch index {
            case 0: return "FIRST BITE"
            case 1: return "DRINKS"
            case 2: return "MAIN EVENT"
            case 3: return "SIDE QUEST"
            default: return "SWEET FINISH"
            }
        }
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
