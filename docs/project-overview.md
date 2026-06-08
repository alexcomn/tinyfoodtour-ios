# Tiny Food Tour — Project Overview

> Read this first. Covers what TFT is, the full tech stack, repo structure, and everything a new developer or contractor needs to get productive.
> **Last updated: June 7, 2026**

---

## What is Tiny Food Tour?

Tiny Food Tour (TFT) builds personalised, walkable food tours for any neighbourhood in the world. A user answers a short quiz (location, meal type, vibe, dietary needs, budget, walk distance) and receives a 2–5 stop tour — First Bite → Main Event → Sweet Finish — with real walking times between each stop.

Live at **[tinyfoodtour.com](https://tinyfoodtour.com)**. Native iOS app feature-complete, pre-TestFlight.

---

## Repositories

| Repo | Local path | GitHub |
|---|---|---|
| `tiny-food-tour` | `/Users/alexandracomnenos/Documents/Source/tiny-food-tour` | `alexcomn/tiny-food-tour` |
| `tinyfoodtour-ios` | `/Users/alexandracomnenos/Documents/Source/tinyfoodtour-ios` | `alexcomn/tinyfoodtour-ios` |

---

## Web App (`tiny-food-tour`)

### Stack
- **React 18** SPA, bootstrapped with Vite (`src/main.tsx`)
- **TypeScript** throughout
- **Tailwind CSS** with custom design tokens in `src/index.css`
- **Supabase** — Postgres database + Deno Edge Functions
- **shadcn/ui** component library
- **React Router** for client-side routing
- Deployed via **Lovable** / Netlify

### Key routes
| Route | Purpose |
|---|---|
| `/home` | Landing page |
| `/quiz` | Multi-step quiz (DB-driven from `quiz_tree`) |
| `/generating` | Loading screen — calls `generate-tour` |
| `/results` | Tour results — stop cards, map, shuffle, save |
| `/live/:tourId` | Walk-along live tour mode |
| `/auth` | Sign in / sign up |
| `/profile` | User profile, past tours |
| `/cities` | Cities directory |
| `/blog` | Editorial content |

### Key source files
| File | Purpose |
|---|---|
| `src/pages/Quiz.tsx` | Quiz UI — reads `quiz_tree`, dynamic branching |
| `src/hooks/useQuizTree.ts` | Loads quiz steps, builds step sequence, sortOptions() |
| `src/pages/Generating.tsx` | Translates quiz answers → edge function request |
| `src/pages/Results.tsx` | Tour display — stop cards, map, shuffle, save |
| `src/pages/LiveTour.tsx` | Walk-along mode — check-off, notes, photos |
| `src/components/TourMap.tsx` | Interactive Google Maps (custom Marker SVGs, polyline) |
| `src/lib/stopLabels.ts` | Maps stop types → display labels (FIRST BITE etc.) |
| `src/integrations/supabase/client.ts` | Supabase client (auto-generated — do not edit) |
| `src/integrations/supabase/types.ts` | DB type definitions (auto-generated — do not edit) |

---

## Supabase Backend

### Project
- **URL:** `https://xefehzsclkefebzyqdrh.supabase.co`
- **Anon key:** in `.env` as `VITE_SUPABASE_PUBLISHABLE_KEY`
- **Server key:** `GOOGLE_PLACES_API_KEY` in Edge Function secrets (never in client code)

### Key tables
| Table | Purpose |
|---|---|
| `quiz_tree` | Dynamic quiz steps — question, hint, options with `next_step` branching |
| `tours` | Generated tours. `stops` JSONB column ends with a synthetic `{_meta: …}` object |
| `profiles` | User display name, `completed_tours_count` |
| `visited_restaurants` | Per-user place history and favourites |
| `tour_stop_progress` | Live tour check-offs and notes (per stop) |
| `tour_stop_photos` | Photo URLs uploaded during live tour |
| `cities` | Curated cities with `slug`, name, coordinates |
| `neighborhoods` | Neighbourhoods within curated cities |
| `locations` | Admin-vetted restaurant spots for curated cities |
| `featured_restaurants` | Spots boosted in tour generation |
| `menu_items` | Scanned menu items cached per tour stop (used by iOS in-app menu viewer) |
| `menu_cache` | Per-URL scraped menu cache used by `fetch-menu` edge function |

### Key Edge Functions
| Function | Purpose |
|---|---|
| `generate-tour` | Main tour generation (~1380 lines) — Places API, Gemini AI curation, TSP reorder, Directions API |
| `fetch-neighborhoods` | Geo → neighbourhood list, 7-day cache |
| `fetch-menu` | Scrapes restaurant website for menu data; called by iOS in-app menu viewer |
| `shuffle-stop` | Swap one stop for a fresh candidate; preserves stop_type |
| `smart-shuffle` | Natural-language AI-guided stop swap (web only; iOS UI not yet built) |
| `get-place-photo` | Resolves Google Place photo URLs |
| `scan-menu` | OCR/parses a menu photo |

### `generate-tour` stops contract — critical
The `stops` JSONB array written to `tours` always ends with a synthetic metadata entry:
```json
{ "_meta": { "tour_title": "...", "total_distance_miles": 1.2, "relaxations": ["allowed_visited"] } }
```
- **Always filter it** before rendering: `stops.filter(s => !s._meta)`
- `relaxations` lists any search constraints that were relaxed (e.g. `"allowed_visited"` means a previously-visited place was included). The iOS app and web both show a notice when this is present.
- Dessert stop is always pinned last by the AI prompt + a server-side safety re-sort.
- Walk distance → radius + max-walk-minutes are **locked string constants** — renaming the quiz option labels breaks generation silently.

---

## iOS App (`tinyfoodtour-ios`)

### Stack
- **SwiftUI + MVVM** — no external dependencies
- **URLSession** for all HTTP (Supabase REST + edge functions)
- **MapKit** for route snapshot maps (MKMapSnapshotter)
- **CoreLocation** for geo
- **iOS 17+ deployment target**
- **Xcode project generated by `generate_xcodeproj.py`** — run this script whenever Swift files are added or removed

### Architecture

```
TinyFoodTour/
  Models/
    Tour.swift              — Tour, TourStop, QuizAnswers, NeighborhoodOption
    QuizStep.swift          — QuizTreeStep, QuizTreeOption, QuizSequenceBuilder
  Services/
    SupabaseService.swift   — hand-rolled URLSession REST + edge function client
    LocationService.swift   — CoreLocation async wrapper
  ViewModels/
    AuthViewModel.swift     — sign in/up, token refresh, UserDefaults persistence
    QuizViewModel.swift     — quiz tree loading, step sequencing, answer state
    TourViewModel.swift     — tour generation, tweak-with-filters, SavedToursViewModel
    LiveTourViewModel.swift — stop check-off, notes, photo upload, progress persistence
    ProfileViewModel.swift  — display name, saved tours (Supabase + UserDefaults sync), favourites
  Views/
    Home/         HomeView.swift
    Quiz/         QuizView.swift, NeighborhoodStepView.swift
    Generating/   GeneratingView.swift
    Results/      ResultsView.swift
    LiveTour/     LiveTourView.swift
    Auth/         AuthView.swift, ProfileView.swift
    Shared/
      BrandMarkView.swift       — wordmark component
      SplashView.swift          — in-app splash (shown on first launch, fades to home)
      StopLabel.swift           — stop color cycle + vibe-aware label strings
      MapViews.swift            — RouteSnapshotView (MKMapSnapshotter), MiniMapView
      MenuViewerSheet.swift     — in-app menu viewer (calls fetch-menu edge function)
      StatusBarModifier.swift   — .lightStatusBar() / .darkStatusBar() helpers
      SafeArea.swift            — UIApplication.safeAreaBottom helper
      Notifications.swift       — Notification.Name extensions
      FullScreenPresenter.swift — ⚠️ LEGACY / UNUSED — superseded by inline swaps (see below)
  Assets.xcassets/
    AppIcon.appiconset/   — all 14 required sizes (iphone + ipad + ios-marketing)
    LaunchImage.imageset/ — 3 scale variants (375pt display canvas)
    SplashLogo.imageset/  — source illustration @3x for in-app splash
    *.colorset/           — named brand colors (Primary, Radish, Yolk, PizzaCrust, Cream, Tomato, …)
```

### Navigation: inline view swaps for the deep flow

**This is the most important thing a new iOS developer needs to know about navigation.**

The deepest screen transitions are done with **inline `if/else` view swaps**, not `.navigationDestination` or `.fullScreenCover`:
- `GeneratingView` → `ResultsView` — `GeneratingView` swaps its own body to `ResultsView` once `vm.tour` is set (`if showResults`).
- `ResultsView` → `LiveTourView` — `ResultsView` swaps to `LiveTourView` (`if showLiveTour`); the `.buildAnotherTour` notification cascade unwinds everything back to `HomeView`.

Unwinding "back" is therefore a matter of flipping the bool (`showResults`/`showLiveTour`) — there is no navigation stack to pop. The "Review your stops" path passes completed stop indices back via the `onReviewStops` closure when `LiveTourView` swaps back to `ResultsView`.

**Why inline swaps instead of NavigationStack:** iOS 26 introduced a zoom presentation animation that left presented views with a residual coordinate transform (content offset ~8-10pt left, scroll unreliable). Inline swaps avoid the presentation machinery entirely, so there is no transform to leak. `QuizView` and `GeneratingView` are still reached via `navigationDestination` from `HomeView` (1–2 levels deep is fine); auth/profile/tweaks use `.sheet`.

> **Note on `FullScreenPresenter.swift`:** this was an earlier UIKit-based workaround (`view.uiFullScreen(...)`, `animated: false`) for the same iOS 26 issue. It is **no longer used** — the inline-swap approach replaced it. The file remains in the repo but is dead code; safe to delete once you're confident nothing else references it.

### The Results scroll / layout saga (resolved)

For a long stretch the Results screen appeared to not scroll and its content extended past the physical viewport. After many dead ends (blamed on presentation transforms), the **actual root cause** was found: the photo strip was a fixed `HStack` of 4×100pt tiles = 456pt wide inside a 402pt viewport. That horizontal overflow broke vertical scrolling *and* shifted content left.

**Fix (do not regress):**
- The photo strip is a `ScrollView(.horizontal)` — **never** a fixed-width `HStack` that can exceed screen width.
- The outer Results `ScrollView` is bounded by a `GeometryReader` (`.frame(width: geo.size.width, height: geo.size.height)`), with the nav row as a top `.overlay` and a `Color.clear.frame(height: 56)` spacer so content clears it.
- `TinyFoodTourApp.init()` sets `UIScrollView.appearance().alwaysBounceVertical = true` as a belt-and-suspenders guard.

Verified empirically in the simulator (content height > container height; programmatic `scrollTo(.bottom)` works) and confirmed visually ("content edges are presenting perfectly").

### Supabase from iOS

`SupabaseService.swift` is a hand-rolled URLSession client with:
- Generic `query<T>()` for REST GET
- `upsert()`, `insert()` for writes
- `invokeFunction<T>()` for edge functions
- `signIn()`, `signUp()`, `refreshToken()` for auth
- `uploadPhoto()` for Storage

**Auth persistence:** Access token + refresh token stored in UserDefaults. On every app launch, `AuthViewModel.init()` restores the session and kicks off a background token refresh (Supabase tokens expire after ~1 hour). If refresh fails, the user is signed out silently.

**Saved tours (cross-device sync):** Saving a tour while signed in writes to **both** stores:
- **Supabase `saved_tours`** (`user_id`, `tour_id`, `name`, `created_at`) — the primary store, shared with the web app, enables cross-device access. `name` holds the AI-generated tour title (`tour.displayTitle`).
- **`UserDefaults`** — `tft_saved_tour_tokens` (array of `share_token`) keeps the home-screen list working offline and supports anonymous (signed-out) saves.

On profile load (`ProfileViewModel.load`), Supabase `saved_tours` is the source of truth for signed-in users; any UserDefaults-only tokens (anonymous or pre-sync saves) are **migrated up** to Supabase automatically, with the AI title pulled from the tour's `_meta`. Removing a tour deletes from both stores. Custom renames stay local in `UserDefaults` (`tft_tour_names: [token: name]`) and take display priority over the AI title.

Saved tour cards in the profile show the AI title, stop count, and the **date saved** (from `saved_tours.created_at`). See `SavedToursViewModel.saveTour(tour:userId:)` and `ProfileViewModel`.

### Adding new Swift files

1. Create the `.swift` file in the correct folder under `TinyFoodTour/`
2. Add its repo-relative path to `swift_files` in `generate_xcodeproj.py`
3. Run `python3 generate_xcodeproj.py` from the repo root
4. Rebuild in Xcode (or `xcodebuild`)

### Color tokens
All defined as named `.colorset` assets. Key names:

| Asset name | Hex | Usage |
|---|---|---|
| `Primary` | `#540202` | CTA buttons, serif headings |
| `Radish` | `#9A183A` | Progress bar, stop labels |
| `Yolk` | `#F4C433` | Selected pill border |
| `PizzaCrust` | `#F2E9D8` | Hero/header backgrounds |
| `Cream` | `#FAF6EC` | Page/screen backgrounds |
| `Tomato` | `#F90606` | Splash screen only |
| `Foreground` | `#311F1A` | Body text, BrandMark |
| `TFTOrange` | `#C45C2A` | Eyebrow labels |
| `SlateMid` | `#5A6A75` | Meta text, hints |

See `docs/branding.md` for the complete palette.

---

## Google Maps / API Key Separation

| Key | Where | Used for |
|---|---|---|
| `VITE_GOOGLE_MAPS_API_KEY` | Browser / web only | Maps JS API, Static Maps |
| `GOOGLE_PLACES_API_KEY` | Supabase Edge Function secrets only | Places, Geocoding, Directions |

The iOS app does **not** use Google Maps directly — it uses `MKMapSnapshotter` (Apple Maps) for all map rendering. All Google API calls go through Supabase edge functions.

---

## Getting Started (iOS)

```bash
git clone https://github.com/alexcomn/tinyfoodtour-ios.git
cd tinyfoodtour-ios

# Regenerate the Xcode project (always do this after pulling)
python3 generate_xcodeproj.py

open TinyFoodTour.xcodeproj
# Select a simulator or device, hit ⌘R
```

**Before building to a real device:** You must configure signing in Xcode:
- Target → Signing & Capabilities → set Team to your Apple Developer account
- Bundle Identifier: `com.tinyfoodtour.app` (or change if needed)

Zero external package dependencies — no `npm install`, no CocoaPods, no SPM packages.

---

## Getting Started (Web)

```bash
git clone https://github.com/alexcomn/tiny-food-tour.git
cd tiny-food-tour
npm install
cp .env.example .env   # fill in Supabase keys
npm run dev
```

---

## Companion docs (in `docs/`)

| File | What it covers |
|---|---|
| `branding.md` | Full color palette, typography, UI component specs, asset locations |
| `tone-and-voice.md` | Voice principles, copy patterns, terminology glossary |
| `product-roadmap.md` | Feature status, priorities, tech debt |
