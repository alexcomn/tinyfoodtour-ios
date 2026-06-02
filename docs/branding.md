# Tiny Food Tour — Branding

> Visual identity reference for the iOS app and web app. Use this when building new screens, generating assets, or aligning with the live site at tinyfoodtour.com.

---

## Color Palette

All colors are defined as named assets in `TinyFoodTour/Assets.xcassets/` and as CSS variables in `src/index.css`.

| Name | Hex | HSL | iOS Asset Name | Usage |
|---|---|---|---|---|
| **Primary** | `#540202` | `0 94% 17%` | `Primary` | CTA buttons, serif headings, key accents |
| **Radish** | `#9A183A` | `344 73% 35%` | `Radish` | Progress bar fill, stop labels, secondary accents |
| **Yolk** | `#F4C433` | `45 90% 58%` | `Yolk` | Selected pill border |
| **PizzaCrust** | `#F2E9D8` | `40 51% 90%` | `PizzaCrust` | Header/hero backgrounds, selected pill fill |
| **Cream** | `#FAF6EC` | `43 58% 94%` | `Cream` | Page/screen background |
| **CreamDark** | `#EAE4CF` | `45 36% 86%` | `CreamDark` | Borders, dividers, photo placeholders |
| **Tomato** | `#F90606` | `0 96% 50%` | `Tomato` | Splash screen background only |
| **Burgundy** | `#7D2248` | `334 58% 31%` | `Burgundy` | Available for CTAs/editorial (less used) |
| **TFTOrange** | `#C45C2A` | `18 64% 47%` | `TFTOrange` | Eyebrow labels |
| **Olive** | `#4E6035` | `83 28% 29%` | `Olive` | Walk/geo indicators |
| **TFTPink** | `#C9617A` | `347 49% 59%` | `TFTPink` | Dessert stop only |
| **Foreground** | `#311F1A` | `12 30% 15%` | `Foreground` | BrandMark, body text, pill text |
| **TFTSlate** | `#2E3D47` | `203 20% 23%` | `TFTSlate` | Section headings, card text |
| **SlateMid** | `#5A6A75` | `205 13% 41%` | `SlateMid` | Meta text, hints, secondary labels |
| White | `#FFFFFF` | — | — | Card backgrounds |

### Stop Color Cycle
Used for map markers, circle badges, and stop labels. Always use in this exact order:

```swift
// StopLabel.swift
["#c40505", "#666429", "#540303", "#96b516", "#9b193d"]
// Stop 1 = red, Stop 2 = olive, Stop 3 = dark red, Stop 4 = lime, Stop 5 = deep burgundy
```

---

## Typography

### Web (Tailwind classes)
- **Headings:** `font-heading` → **Josefin Sans** (geometric sans), weights 300–700. Applied site-wide via the Weekly Theme system; Playfair Display is only the Tailwind fallback when no theme is active.
- **Body:** `font-body` → DM Sans (sans), weights 300–700
- **Wordmark:** **Fraunces** (display serif), uppercase, letter-spacing 0.25em, weight 500

### iOS (SwiftUI) — actual brand fonts are now bundled
The real Google Fonts TTFs ship in `TinyFoodTour/Fonts/` and are registered in
Info.plist (`UIAppFonts`). Use the `TFTFont` helper — never `.system()` — for
headings and the wordmark:

- **Headings:** `.font(TFTFont.heading(size, weight:))` → Josefin Sans
  (`JosefinSans-Medium` / `-SemiBold` / `-Bold` by weight)
- **Wordmark:** `.font(TFTFont.wordmark(size))` → `Fraunces-Medium`
- **Body:** `.font(.system(size: X))` — SF Pro (DM Sans not bundled; system sans is fine for body)

Bundled font files and their PostScript names (verified to resolve at runtime):
| File | PostScript name | Used for |
|---|---|---|
| `JosefinSans-Medium.ttf` | `JosefinSans-Medium` | `.medium` headings |
| `JosefinSans-SemiBold.ttf` | `JosefinSans-SemiBold` | `.semibold` headings |
| `JosefinSans-Bold.ttf` | `JosefinSans-Bold` | `.bold` headings |
| `Fraunces-Medium.ttf` | `Fraunces-Medium` | the wordmark |

> When adding a Swift file OR font, run `python3 generate_xcodeproj.py` — the
> generator wires fonts into the Resources build phase and `UIAppFonts`.

---

## Wordmark

**"TINY FOOD TOUR"** — always all-caps, wide letter-spacing, Fraunces / system serif approximation, medium weight, `Foreground` color.

- The brand quirk is a lowercase `i` in the logo PNG ("TiNY") but text rendering shows all-caps.
- The BrandMark renders in a serif display face (Fraunces / system serif) — **not** the plain sans that body copy uses.
- Used at 11pt in navs/headers; scale up for hero contexts (13–15pt max).

```swift
// BrandMarkView.swift
Text("TINY FOOD TOUR")
    .font(.system(size: 11, weight: .medium))
    .tracking(fontSize * 0.25)
    .foregroundColor(Color("Foreground"))
```

---

## UI Components

### Pill Buttons (quiz options)
- Unselected: `Cream` background, `Foreground/0.15` border, `Foreground` text
- Selected: `PizzaCrust` background, `Yolk` border, `Foreground` text
- Corner radius: 20pt (very rounded, near-capsule)
- Padding: 16px horizontal, 10px vertical
- Font: 14pt regular

### CTA Buttons
- Background: `Primary` (#540202)
- Text: white, 15pt semibold
- Corner radius: 10–12pt
- Disabled: `TFTSlate/0.25` background

### Stop Cards (Results screen)
- Background: white
- Border: `Foreground/0.08`, 1px
- Corner radius: 12pt
- Internal padding: 16pt
- Circle badge: 30pt, filled with stop color, white `01`/`02`/... text, 11pt semibold
- Stop label: 10pt, 1.5pt kerning, uppercase, stop color
- Stop name: 17pt semibold, `.serif`, `TFTSlate`
- Description: 12pt, `SlateMid`
- Link buttons: bordered, 11pt, `Foreground` text, 6pt radius

### Progress Bar (quiz)
- Filled: `Radish`
- Unfilled: `Foreground/0.12`
- Height: 3pt, 2pt radius
- Gap between segments: 4pt

---

## Screen Background Rules

| Screen | Background |
|---|---|
| Home hero | `PizzaCrust` |
| Home content (past tours) | `Cream` |
| Quiz | `Cream` |
| Generating | `Cream` |
| Results header | `PizzaCrust` |
| Results card list | `Cream` |
| Stop cards | White |
| Live Tour | System background (white) |
| Auth | System background |
| Splash | `Tomato` |

---

## Launch Screen

- **OS-level splash** (before app code): solid `Tomato` (`#F90606`) via `UILaunchScreen` plist, no image
- **In-app splash** (`SplashView.swift`): Tomato background + `SplashLogo` image at 60% screen width
- **Duration:** 2.0 seconds, then 0.6s opacity fade to home
- **Logo asset:** `SplashLogo.imageset` — sourced from `src/assets/splash-logo.png` (@3x)

---

## App Icon

- **Background:** Tomato `#F90606`
- **Foreground:** Centered TFT logo, ~65% of tile width
- **Generated by:** `generate_assets.py` — run from repo root to regenerate all sizes
- **Sizes:** 20/29/40/58/60/76/80/87/120/152/167/180/1024px

To regenerate after changing logo or color:
```bash
python3 generate_assets.py
```

---

## Status Bar

- **Light screens (Tomato bg):** White icons — `.lightStatusBar()` modifier
- **All other screens:** Dark icons — `.darkStatusBar()` modifier
- Implemented via `.preferredColorScheme(.dark/.light)` — see `StatusBarModifier.swift`

---

## Assets Locations

| Asset | Location |
|---|---|
| Source splash logo | `tiny-food-tour/src/assets/splash-logo.png` |
| iOS color assets | `tinyfoodtour-ios/TinyFoodTour/Assets.xcassets/*.colorset/` |
| iOS app icon | `tinyfoodtour-ios/TinyFoodTour/Assets.xcassets/AppIcon.appiconset/` |
| iOS splash image | `tinyfoodtour-ios/TinyFoodTour/Assets.xcassets/LaunchImage.imageset/` |
| iOS splash logo | `tinyfoodtour-ios/TinyFoodTour/Assets.xcassets/SplashLogo.imageset/` |
| Asset generators | `tinyfoodtour-ios/generate_assets.py`, `generate_colors.py` |
