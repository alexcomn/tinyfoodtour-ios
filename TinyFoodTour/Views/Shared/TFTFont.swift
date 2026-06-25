import SwiftUI

// Brand fonts — source of truth is tinyfoodtour.com (verified via computed styles):
//   Headings → Josefin Sans, weight 400 (Regular). Every heading on the site is w400.
//   Wordmark → Josefin Sans, weight 500 (Medium). The site uses Josefin Sans for the
//              wordmark, NOT Fraunces (the older brief was out of date).
// TTFs are bundled (TinyFoodTour/Fonts) and registered in Info.plist (UIAppFonts).
// Use these helpers instead of .system() for any heading or the wordmark.
//
// Dynamic Type: all helpers use Font.custom(_:size:relativeTo:) so the custom font
// scales proportionally with the user's preferred text size. The `relativeTo:` style
// is the closest standard text style for the given design size — it sets the scaling
// baseline, not the actual rendered size (that's still `size`).
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
        // Map design size to the closest standard text style so Dynamic Type scaling
        // is proportional to the correct tier:
        //   headline  = 17pt default   title3 = 20pt   title2 = 22pt   title = 28pt
        let style: Font.TextStyle
        switch size {
        case ..<18:  style = .headline
        case 18..<22: style = .title3
        case 22..<28: style = .title2
        default:     style = .title
        }
        return .custom(name, size: size, relativeTo: style)
    }

    /// Wordmark "TiNY FOOD TOUR" — Josefin Sans Medium (500), matching the live site.
    static func wordmark(_ size: CGFloat) -> Font {
        let style: Font.TextStyle = size >= 16 ? .title3 : size >= 13 ? .callout : .caption
        return .custom("JosefinSans-Medium", size: size, relativeTo: style)
    }
}

// MARK: - Dynamic Type helper for system fonts

/// Scales a system font with Dynamic Type. Uses @ScaledMetric inside a ViewModifier
/// so the rendered size updates live when the user changes their Accessibility text
/// size setting — unlike .font(.system(size: X)) which is always fixed.
///
/// Usage: replace .font(.system(size: X)) with .scaledFont(size: X)
///        replace .font(.system(size: X, weight: .Y)) with .scaledFont(size: X, weight: .Y)
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric var scaledSize: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight = .regular) {
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight))
    }
}

extension View {
    /// System font at a fixed design size that scales with Dynamic Type.
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight))
    }
}
