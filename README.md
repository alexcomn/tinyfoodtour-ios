# Tiny Food Tour iOS

SwiftUI iOS app for [tinyfoodtour.com](https://tinyfoodtour.com).

## Requirements
- Xcode 15+
- iOS 17+ deployment target

## Setup
1. Open `TinyFoodTour.xcodeproj` in Xcode
2. Select your simulator or device
3. Build & run (⌘R)

## Architecture
- **SwiftUI + MVVM** — no third-party dependencies
- **Supabase** — same backend as the web app (REST API + Edge Functions via URLSession)
- **MapKit** — neighborhood and stop maps
- **CoreLocation** — geolocation for neighborhood detection

## Screens
| Screen | Description |
|--------|-------------|
| Home | Landing + past saved tours |
| Quiz | Dynamic multi-step quiz (steps loaded live from `quiz_tree` Supabase table) |
| Generating | Loading screen while `generate-tour` edge function runs |
| Results | Tour overview with stop cards + map |
| Live Tour | Walk through each stop — check off, notes, photos |
| Auth | Sign in / sign up |
