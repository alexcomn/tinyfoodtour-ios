import SwiftUI

// Brief §D equivalent for SwiftUI:
//   .lightStatusBar  → white icons (use on Tomato-background screens: Splash, Generating)
//   .darkStatusBar   → dark icons (use on Cream-background screens: everything else)
//
// SwiftUI controls status bar icon colour through the colour scheme of the
// topmost view — dark scheme = white icons, light scheme = dark icons.

extension View {
    /// White status bar icons — for screens with a dark/tomato background.
    func lightStatusBar() -> some View {
        self.preferredColorScheme(.dark)
    }

    /// Dark status bar icons — for screens with a light/cream background.
    func darkStatusBar() -> some View {
        self.preferredColorScheme(.light)
    }
}
