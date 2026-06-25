import SwiftUI

// MARK: - TFT Semantic Color Layer
// Type-safe wrappers around the asset-catalog named colors.
// Always use these constants instead of Color("…") string literals so
// any asset rename surfaces as a compile error, not a runtime blank.
//
// Token → asset → hex (light mode)
//   tftBurgundy   Primary     #c40505   CTAs, interactive
//   tftOrange     TFTOrange   #f4a522   eyebrow / accent
//   tftOlive      Olive       #666429   geographic / walk
//   tftPink       TFTPink     #e8c4cd   dessert stops only
//   tftSlate      TFTSlate    #33201b   body copy (dark chocolate)
//   tftSlateMid   SlateMid    #8b7d76   meta / muted
//   tftCream      Cream       #f9f4e8   page backgrounds
//   tftCreamDark  CreamDark   #f2e9d7   card alt backgrounds
//   tftRadish     Radish      #9b193d   alerts / destructive / "Start here"
//   tftPizzaCrust PizzaCrust  #f2e9d7   header sections
//   tftForeground Foreground  #33201b   primary foreground

extension Color {
    static let tftBurgundy   = Color("Primary")
    static let tftOrange     = Color("TFTOrange")
    static let tftOlive      = Color("Olive")
    static let tftPink       = Color("TFTPink")
    static let tftSlate      = Color("TFTSlate")
    static let tftSlateMid   = Color("SlateMid")
    static let tftCream      = Color("Cream")
    static let tftCreamDark  = Color("CreamDark")
    static let tftRadish     = Color("Radish")
    static let tftPizzaCrust = Color("PizzaCrust")
    static let tftForeground = Color("Foreground")
}
