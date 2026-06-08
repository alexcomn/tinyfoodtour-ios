# Tiny Food Tour — Product Roadmap

> Current state, near-term priorities, and future bets.
> **Last updated: June 7, 2026**

---

## Current State

### Web App — Production ✅
Live at [tinyfoodtour.com](https://tinyfoodtour.com). Core flow fully operational.

### iOS App — Feature Complete, Pre-TestFlight 🔨
Native SwiftUI app. All core screens built and tested on iPhone 17 simulator / iOS 26.5.

**Results scroll / layout — resolved.** The long-running "content extends past viewport, scroll doesn't work" issue was root-caused to the photo strip being a fixed-width `HStack` (456pt) inside a 402pt viewport, not the iOS 26 presentation transform that was originally suspected. Fixed by making the photo strip a horizontal `ScrollView` and bounding the outer Results `ScrollView` with a `GeometryReader`. The deep flow now uses inline `if/else` view swaps instead of `.fullScreenCover`/`navigationDestination`. See `docs/project-overview.md` → "The Results scroll / layout saga".

| Feature | Status | Notes |
|---|---|---|
| Dynamic quiz (7 steps, DB-driven branching) | ✅ | |
| Neighborhood detection + manual search | ✅ | |
| Curated city quick-picks | ✅ | |
| Tour generation | ✅ | |
| Results screen (cards, map, photos, hours) | ✅ | |
| Stop shuffle (single stop replacement) | ✅ | Calls `shuffle-stop` edge function |
| Smart shuffle (natural language) | ❌ Not built | Web has a chat-bubble popover; iOS has no UI for this yet |
| Tweak your tour (stops + pricing sliders) | ✅ | |
| In-app menu viewer | ✅ | Checks `menu_items` DB first, falls back to `fetch-menu` |
| Live tour (check-off, notes, photos, map) | ✅ | |
| Completed stop checkmarks on route map | ✅ | |
| Completion card + Build Another flow | ✅ | |
| Auth (sign in / sign up, token refresh) | ✅ | |
| Profile (display name, saved tours, favourites) | ✅ | |
| Share tour (native iOS share sheet) | ✅ | |
| Saved tours on home screen | ✅ | UserDefaults tokens (works offline + signed-out) |
| Saved tours cross-device sync | ✅ | Writes to Supabase `saved_tours` when signed in; profile load merges + migrates UserDefaults-only saves up. Cards show AI title + date saved |
| App icon (custom illustration) | ✅ | |
| Launch / splash screen | ✅ | |
| Branding aligned to web | ✅ | |
| Quiz & tour logic aligned to brief | ✅ | Dietary mutual-exclusion, "Surprise me!" sort, relaxations notice |
| Client-side TSP route optimisation | ✅ | Compensates for server-side zigzag bugs |
| Results scroll + container sizing (iOS 26) | ✅ | Root cause = photo-strip width; fixed with horizontal ScrollView + GeometryReader bounding |
| Route preview map zoom tuning | 🔄 | Map preview currently too zoomed out; tightening the region to fit the route with a small padding (see Near-Term P1) |
| Dynamic Type | ❌ | Font sizes don't scale with user's accessibility setting |
| Push notifications | ❌ | APNs not configured |
| Offline support | ❌ | |
| App Store submission | ❌ | |

---

## Blocker Before TestFlight

**Bundle ID + signing** — requires Apple Developer account in Xcode:
1. Open `TinyFoodTour.xcodeproj`
2. Target → **Signing & Capabilities** → set your Team
3. Update Bundle Identifier (`com.tinyfoodtour.app`) if needed
4. Xcode auto-provisions → build to device → submit to TestFlight

---

## Near-Term Priorities (pre-release)

### P0 — Must confirm before TestFlight

1. **End-to-end test on a real device** — quiz → generate → results (scroll, menu, shuffle) → live tour (check-off, notes, photos) → completion → home. The scroll/layout issue is fixed in the simulator; a real-device pass is the remaining confidence check before TestFlight.

### P1 — Valuable before wider release

2. **Route preview map zoom** *(in progress)* — the route preview (`RouteSnapshotView` in `MapViews.swift`, via `MKMapSnapshotter`) is currently too zoomed out, so the route sits small in the frame. Goal: compute the bounding `MKCoordinateRegion` of all stop coordinates and inset it with a modest padding factor (≈1.2–1.4×) so the whole route fills the preview without being cropped or over-zoomed. Watch the single-stop / tightly-clustered case (enforce a sensible minimum span).

3. **Smart shuffle UI** — web has a chat-bubble popover per stop card where users type e.g. "something cheaper" or "has outdoor seating". The `smart-shuffle` edge function already exists; iOS just needs the input UI. Mirrors `Results.tsx` lines 853–900.

4. **Dynamic Type** — system font-size scaling. All `Text` views use hard-coded sizes; wrap in `.font(.system(size: X))` using scaled values.

5. **App Store submission** — description, screenshots (6.7" and 6.1" required), privacy manifest (`PrivacyInfo.xcprivacy`).

---

## Post-Release (P2)

| Feature | Notes |
|---|---|
| Push notifications | APNs + Supabase pg_cron or Edge Function triggers needed |
| Offline map caching | For live tour underground; would need pre-downloaded tiles |
| Android app | Natural follow-on once iOS is stable |

---

## Tech Debt

| Item | Risk / Action |
|---|---|
| **Inline view swaps for the deep flow** | `GeneratingView`→`ResultsView`→`LiveTourView` swap inline via `if/else` bools instead of NavigationStack, to dodge the iOS 26 zoom-presentation transform. If Apple patches that animation, this could move back to native `.fullScreenCover` + NavigationStack for cleaner back-nav semantics |
| **`FullScreenPresenter.swift` is dead code** | Earlier UIKit presentation workaround, no longer referenced anywhere. Safe to delete |
| **Xcode project generated by Python** | `generate_xcodeproj.py` must be run after adding any Swift file. Consider migrating to Xcodegen for robustness |
| **`SupabaseService.swift` is hand-rolled** | Zero dependencies is a feature, but if auth requirements grow, the official Supabase Swift SDK is worth evaluating |
| **`generate-tour` edge function ~1380 lines** | Monolithic; worth splitting into location-resolution, discovery, AI-curation, and enrichment modules when next touching it |
| **Directions API deprecated** | Works today; migrate to Routes API (`routes/directions/v2:computeRoutes`) if Google enforces the sunset |
| **TSP reorder runs client-side AND server-side** | `Tour.reorderLinear()` in iOS compensates for server-side zigzag bugs. Remove the client-side pass if `reorderStopsLinear` in the edge function is fixed |
| **Saved tours dual-write** | iOS writes saved tours to both Supabase `saved_tours` and UserDefaults (the latter for offline + anonymous saves). Custom renames are still local-only — they don't sync cross-device. Acceptable for now; revisit if rename-sync is requested |

---

## Known Gaps (Documented, Not Blocking)

- **Zigzag routes** — `reorderStopsLinear` in `generate-tour` occasionally returns suboptimal walking paths. The iOS app applies `Tour.reorderLinear()` client-side as a fallback, but the root fix belongs in the edge function.
- **Adjacent walk times after shuffle** — only the swapped stop's inbound walk time is recomputed. Neighbouring stops may drift 1–3 min. Tracked in brief §10 as acceptable.
- **Anonymous user visit history** — no server-side record for anon users; their `exclude_place_ids` (for "Try somewhere new!") comes entirely from the client. Consider a `localStorage`-persisted exclusion list for multi-session anon users.
- **Smart shuffle** — not built in iOS. Users can only do random single-stop shuffles. Web users can type natural language requests ("something vegan", "has a patio").
