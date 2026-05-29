# Tiny Food Tour — Project Overview

> Read this first. It covers what TFT is, the full tech stack, repo structure, and how everything connects.

---

## What is Tiny Food Tour?

Tiny Food Tour (TFT) builds personalized, walkable food tours for any neighborhood in the world. A user answers a short quiz (location, meal type, vibe, dietary needs, budget, walk distance) and receives a 2–5 stop tour — First Bite → Main Event → Sweet Finish — with walking directions between each stop.

Live at **[tinyfoodtour.com](https://tinyfoodtour.com)**. iOS app in development.

---

## Repositories

| Repo | Location | Purpose |
|---|---|---|
| `tiny-food-tour` | `/Users/alexandracomnenos/Documents/Source/tiny-food-tour` | Web app (React SPA) + Supabase edge functions |
| `tinyfoodtour-ios` | `/Users/alexandracomnenos/Documents/Source/tinyfoodtour-ios` | Native iOS app (SwiftUI) |

Both repos are on GitHub under `alexcomn/`.

---

## Web App (`tiny-food-tour`)

### Stack
- **React 18** SPA, bootstrapped with Vite (`src/main.tsx`)
- **TypeScript** throughout
- **Tailwind CSS** with custom design tokens in `src/index.css`
- **Supabase** — Postgres database + Edge Functions (Deno)
- **shadcn/ui** component library
- **React Router** for client-side routing
- Deployed via **Lovable** / Netlify

### Key web routes
| Route | Purpose |
|---|---|
| `/home` | Landing page |
| `/quiz` | Multi-step quiz |
| `/generating` | Loading screen (calls `generate-tour`) |
| `/results` | Tour results with stop cards + map |
| `/live/:tourId` | Walk-along live tour mode |
| `/auth` | Sign in / sign up |
| `/profile` | User profile, past tours |
| `/cities` | Cities directory |
| `/blog` | Editorial content |

### Key source files
| File | Purpose |
|---|---|
| `src/pages/Quiz.tsx` | Quiz UI — reads `quiz_tree` table, dynamic branching |
| `src/hooks/useQuizTree.ts` | Loads quiz steps from Supabase, builds step sequence |
| `src/pages/Generating.tsx` | Calls `generate-tour` edge function |
| `src/pages/Results.tsx` | Tour display — stop cards, map, shuffle, save |
| `src/pages/LiveTour.tsx` | Walk-along mode — check-off, notes, photos |
| `src/components/TourMap.tsx` | Interactive Google Maps component |
| `src/lib/stopLabels.ts` | Maps stop types to display labels (FIRST BITE, etc.) |
| `src/integrations/supabase/client.ts` | Supabase client (auto-generated, do not edit) |
| `src/integrations/supabase/types.ts` | DB type definitions (auto-generated, do not edit) |

---

## Supabase Backend

### Project
- **URL:** `https://xefehzsclkefebzyqdrh.supabase.co`
- **Anon key:** in `.env` as `VITE_SUPABASE_PUBLISHABLE_KEY`
- **Server key:** `GOOGLE_PLACES_API_KEY` stored in Edge Function secrets (never in client code)

### Key tables
| Table | Purpose |
|---|---|
| `quiz_tree` | Dynamic quiz steps — question, hint, options with `next_step` branching |
| `tours` | Generated tours. `stops` column is JSONB containing `[TourStop, ..., {_meta}]` |
| `profiles` | User profiles, `completed_tours_count` |
| `visited_restaurants` | Per-user place history, favorites |
| `tour_stop_progress` | Live tour check-offs and notes |
| `tour_stop_photos` | Photo URLs from live tour |
| `cities` | Curated cities with `slug`, `name`, coordinates |
| `neighborhoods` | Neighborhoods within curated cities |
| `locations` | Admin-vetted restaurant spots for curated cities |
| `featured_restaurants` | Spots injected as preferred candidates in tour generation |
| `menu_items` | Scanned menu items per tour stop |

### Key Edge Functions
| Function | Purpose |
|---|---|
| `generate-tour` | Main tour generation — Places API, AI curation, TSP reorder, Directions API |
| `fetch-neighborhoods` | Geo → neighborhood list, with 7-day cache |
| `shuffle-stop` | Swap one stop for a new candidate |
| `smart-shuffle` | AI-guided stop swap based on user text instructions |
| `get-place-photo` | Resolve Google Place photo URLs |
| `scan-menu` | OCR/parse menu from a photo |

### Important `generate-tour` contract
- `stops` in the response includes a synthetic `{_meta: {tour_title, total_distance_miles}}` entry as the last element — **always filter it out** before rendering (`stops.filter(s => !s._meta)`).
- Dessert is always pinned last.
- Walk distance → search radius and time cap are locked together (see Maps brief in docs/).

---

## iOS App (`tinyfoodtour-ios`)

### Stack
- **SwiftUI** + **MVVM**
- **No external dependencies** — URLSession for HTTP, MapKit for maps, CoreLocation for geo
- **iOS 17+** deployment target
- **Xcode project** generated via `generate_xcodeproj.py` (run this whenever new Swift files are added)

### Architecture
```
TinyFoodTour/
  Models/           Tour.swift, QuizStep.swift
  Services/         SupabaseService.swift, LocationService.swift
  ViewModels/       QuizViewModel, TourViewModel, LiveTourViewModel, AuthViewModel
  Views/
    Home/           HomeView.swift
    Quiz/           QuizView.swift, NeighborhoodStepView.swift
    Generating/     GeneratingView.swift
    Results/        ResultsView.swift
    LiveTour/       LiveTourView.swift
    Auth/           AuthView.swift
    Shared/         BrandMarkView, SplashView, StopLabel, StatusBarModifier, SafeArea
  Assets.xcassets/  All colors + app icon + launch image
```

### Supabase from iOS
`SupabaseService.swift` is a hand-rolled URLSession client. It calls the same REST endpoints and Edge Functions as the web app. No Supabase Swift SDK is used.

### Adding new Swift files
1. Create the `.swift` file in the right folder under `TinyFoodTour/`
2. Add its path to `swift_files` in `generate_xcodeproj.py`
3. Run `python3 generate_xcodeproj.py` from the repo root
4. Rebuild in Xcode

### Color tokens (all defined as named asset catalog colors)
See `docs/branding.md` for the full palette. Key names: `Primary`, `Radish`, `Yolk`, `PizzaCrust`, `Cream`, `Tomato`, `Foreground`, `TFTSlate`, `SlateMid`, `TFTOrange`, `Burgundy`, `Olive`, `TFTPink`.

---

## Google Maps / API Key Separation

**Never mix these two keys:**

| Key | Where | Used for |
|---|---|---|
| `VITE_GOOGLE_MAPS_API_KEY` | Browser / iOS (via web) | Maps JS API, Static Maps |
| `GOOGLE_PLACES_API_KEY` | Supabase Edge Function secrets only | Places, Geocoding, Directions |

Browser key is referrer-restricted. Server key is unrestricted. Calling Geocoding or Directions from the browser key returns `REQUEST_DENIED`.

---

## Auth Flow

Both web and iOS use **Supabase Auth** (email/password). The iOS app stores the access token in `UserDefaults` and re-injects it into `SupabaseService` on launch.

---

## Getting Started (iOS development)

```bash
# 1. Clone
git clone https://github.com/alexcomn/tinyfoodtour-ios.git
cd tinyfoodtour-ios

# 2. Regenerate Xcode project (required after any new Swift files)
python3 generate_xcodeproj.py

# 3. Open in Xcode
open TinyFoodTour.xcodeproj

# 4. Select iPhone 17 simulator, hit ⌘R
```

No package manager setup required — zero external dependencies.

---

## Getting Started (web development)

```bash
git clone https://github.com/alexcomn/tiny-food-tour.git
cd tiny-food-tour
npm install
cp .env.example .env   # fill in Supabase keys
npm run dev
```
