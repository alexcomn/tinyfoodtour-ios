import SwiftUI

// Brand fonts — source of truth is tinyfoodtour.com (verified via computed styles):
//   Headings → Josefin Sans, weight 400 (Regular). Every heading on the site is w400.
//   Wordmark → Josefin Sans, weight 500 (Medium). The site uses Josefin Sans for the
//              wordmark, NOT Fraunces (the older brief was out of date).
// TTFs are bundled (TinyFoodTour/Fonts) and registered in Info.plist (UIAppFonts).
// Use these helpers instead of .system() for any heading or the wordmark.
enum TFTFont {

    /// Josefin Sans heading. The website renders ALL headings at weight 400, so the
    /// default is Regular. Heavier weights are available if a specific surface needs one.
    static func heading(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "JosefinSans-Bold"
        case .semibold:             name = "JosefinSans-SemiBold"
        case .medium:               name = "JosefinSans-Medium"
        default:                    name = "JosefinSans-Regular"  // matches the website
        }
        return .custom(name, size: size)
    }

    /// Wordmark "TiNY FOOD TOUR" — Josefin Sans Medium (500), matching the live site.
    static func wordmark(_ size: CGFloat) -> Font {
        .custom("JosefinSans-Medium", size: size)
    }
}
