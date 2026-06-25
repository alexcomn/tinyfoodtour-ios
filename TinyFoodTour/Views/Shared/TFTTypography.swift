import SwiftUI

// MARK: - DM Sans body font
// Brand body typeface (verified from tinyfoodtour.com computed styles).
//
// SETUP: Download from https://fonts.google.com/specimen/DM+Sans
//   Place these files in TinyFoodTour/Fonts/:
//     DMSans-Regular.ttf
//     DMSans-Medium.ttf
//     DMSans-Bold.ttf
//   Register in Info.plist UIAppFonts array (same as Josefin Sans entries).
//   Until the files are added, Font.custom falls back to the system font automatically.

extension TFTFont {

    /// DM Sans body font at a given design size. Falls back to system sans-serif
    /// until DMSans TTFs are registered in Info.plist.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:    name = "DMSans-Bold"
        case .medium, .semibold:       name = "DMSans-Medium"
        default:                       name = "DMSans-Regular"
        }
        let style: Font.TextStyle
        switch size {
        case ..<12:    style = .caption
        case 12..<14:  style = .footnote
        case 14..<17:  style = .subheadline
        default:       style = .body
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

// MARK: - scaledBodyFont convenience modifier
// Mirrors scaledFont() but uses DM Sans instead of the system font.

private struct ScaledBodyFontModifier: ViewModifier {
    @ScaledMetric var scaledSize: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight = .regular) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(TFTFont.body(scaledSize, weight: weight))
    }
}

extension View {
    /// DM Sans at a design size that scales with Dynamic Type.
    func scaledBodyFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledBodyFontModifier(size: size, weight: weight))
    }
}
