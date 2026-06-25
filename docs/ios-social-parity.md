# iOS Social Sprint — Parity Map

Maps each web source file to its Swift counterpart so contributors can trace
feature parity. Updated per milestone.

---

## M1 — Foundations (this PR)

| Web file | Swift counterpart | Status | Notes |
|---|---|---|---|
| — | `Foundation/TFTConfig.swift` | ✅ | Centralises Supabase URL + anon key; replaces hardcoded values in SupabaseService |
| — | `Foundation/DeviceIdentity.swift` | ✅ | Keychain-backed `client_id`; mirrors web `localStorage` pattern for guest reactions |
| — | `Foundation/Session.swift` | ✅ | Auth-state singleton for services; wraps `AuthViewModel.$currentUser` |
| — | `Foundation/Toast.swift` + `Views/Shared/ToastView.swift` | ✅ | Sonner-style top-centre toast; `ToastManager.shared.show(…)` |
| — | `Views/Shared/TFTColor.swift` | ✅ | Type-safe `Color.tft*` constants over asset-catalog named colours |
| — | `Views/Shared/TFTTypography.swift` | ✅ | DM Sans body font; falls back to system until TTFs are bundled |
| `apple-app-site-association` (web server) | `apple-app-site-association` (repo root) | ✅ deploy pending | Must be served at `https://tinyfoodtour.com/.well-known/apple-app-site-association` |

### Universal Links — outstanding setup steps

1. **Associated Domains capability** — in Xcode: Target → Signing & Capabilities → + Associated Domains → add `applinks:tinyfoodtour.com`
2. **Deploy AASA** — copy `apple-app-site-association` (repo root) to `tinyfoodtour.com/.well-known/apple-app-site-association` with `Content-Type: application/json`. The Netlify/Lovable hosting layer must serve this path without redirect.
3. **Verify** — after deploy, check `https://app.swchecklist.com` or `curl https://tinyfoodtour.com/.well-known/apple-app-site-association`.
4. **Developer account** — Team ID `9Y98BV3CPZ` is already in `project.pbxproj`. Confirm ordersacom@gmail.com is enrolled in Apple Developer Program; the Associated Domains capability requires a paid account.

### DM Sans — outstanding setup steps

Download from [Google Fonts](https://fonts.google.com/specimen/DM+Sans), add to `TinyFoodTour/Fonts/`:
- `DMSans-Regular.ttf`
- `DMSans-Medium.ttf`
- `DMSans-Bold.ttf`

Register in `Info.plist` UIAppFonts (same pattern as Josefin Sans). Until added, `TFTFont.body()` silently falls back to the system font — no crash.

---

## M2 — Tour Reactions (pending backend confirmation)

| Web file | Swift counterpart | Status |
|---|---|---|
| `src/lib/reactions.ts` | `Services/ReactionsService.swift` | 🔲 pending |
| `src/components/TourReactions.tsx` | `Views/Shared/ReactionBar.swift` | 🔲 pending |

**Blocked on**: `tour_reactions` table + RLS + `client_id` column confirmation.

---

## M3 — Public Profile + Handle Claim (pending backend)

| Web file | Swift counterpart | Status |
|---|---|---|
| `src/pages/PublicProfile.tsx` | `Views/Profile/PublicProfileView.swift` | 🔲 pending |
| `src/lib/badges.ts` | `Services/BadgesService.swift` | 🔲 pending |
| Profile settings | `Views/Auth/ProfileSettingsView.swift` | 🔲 pending |

**Blocked on**: `profiles.handle`, `profiles.bio`, `profiles.is_public`, `is_handle_available` RPC, `tours.is_published`.

---

## M4 — Community Feed (pending backend)

| Web file | Swift counterpart | Status |
|---|---|---|
| `src/lib/communityFeed.ts` | `Services/CommunityFeedService.swift` | 🔲 pending |
| `src/components/CommunityFeed.tsx` | `Views/Home/CommunityFeedView.swift` | 🔲 pending |

---

## M5 — Walk Together (pending backend)

| Web file | Swift counterpart | Status |
|---|---|---|
| `src/lib/walkTogether.ts` | `Services/WalkTogetherService.swift` | 🔲 pending |
| `src/pages/WalkTogether.tsx` | `Views/WalkTogether/WalkTogetherView.swift` | 🔲 pending |

**Blocked on**: `walk_sessions`, `walk_participants` tables + Supabase Realtime channel `walk:<sessionId>`.

**Foreground-only limitation**: Walk Together uses `CLLocationManager` with `whenInUse` authorisation only. Location updates stop when the app is backgrounded. Background location (`always` authorisation) is a future sprint.

---

## M6 — Share + Claim (partially unblocked)

| Web file | Swift counterpart | Status |
|---|---|---|
| `src/lib/tourShare.ts` | already in `Services/SupabaseService.swift` (partial) | 🟡 partial |
| `src/lib/tourClaim.ts` | `Services/TourClaimService.swift` | 🔲 pending |

`ensureShortLink` (calls `create_or_get_short_link` RPC) and `get_tour_by_share_token` RPC are already wired. Short-link resolution via `/t/:slug` is handled in `TinyFoodTourApp.loadTourBySlug()`.

Guest share-token accumulation is implemented in `DeviceIdentity.addGuestShareToken()` / `.guestShareTokens`. The claim sweep (`claimGuestTours()`) is pending M6.

---

## Known divergences / flags

- **`tours.published_by` → `auth.users`**: Web does a two-step fetch (tours, then profiles). iOS must mirror this pattern; direct join is blocked by RLS. Flagged for M4.
- **`share_image_url`**: Web uploads a canvas PNG to `tour-photos` bucket. iOS uses `ImageRenderer` + `TourShareCardView`. The resulting `UIImage` should be uploaded to the same bucket path pattern and stored in `tours.share_image_url` — not yet wired (M6).
- **OG meta endpoint** (`supabase/functions/tour-og/`): Only relevant for web crawlers. iOS share sheet uses the short URL directly; no iOS-side OG handling needed.
