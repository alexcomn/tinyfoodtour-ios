import SwiftUI

// Brand fonts (ios-branding-brief.md §1):
//   Headings → Josefin Sans (geometric sans), weights 500/600/700
//   Wordmark → Fraunces (display serif), weight 500
// The actual TTFs are bundled (TinyFoodTour/Fonts) and registered in Info.plist
// (UIAppFonts). Use these helpers instead of .system() for any heading/wordmark.
enum TFTFont {

    /// Josefin Sans heading. Maps a SwiftUI weight to the closest bundled static face.
    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .medium:                 name = "JosefinSans-Medium"
        case .semibold:               name = "JosefinSans-SemiBold"
        default:                      name = "JosefinSans-Bold"   // .bold and heavier
        }
        return .custom(name, size: size)
    }

    /// Fraunces wordmark (display serif), weight 500.
    static func wordmark(_ size: CGFloat) -> Font {
        .custom("Fraunces-Medium", size: size)
    }
}
