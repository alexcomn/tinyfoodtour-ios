# Tiny Food Tour — Tone & Voice

> The single reference for how TFT sounds. Read this before writing any copy — button labels, error messages, empty states, notifications, onboarding.

---

## The One-Line Brief

**A knowledgeable, opinionated food magazine editor who happens to be your friend — handing you a route, not a lecture.**

---

## Voice in 5 Words

**Specific. Confident. Warm. Editorial. Walkable.**

---

## Personality Axes

| Axis | Our lean | Not |
|---|---|---|
| Warm ↔ Crisp | 70% warm | Cold or clinical |
| Confident ↔ Humble | 75% confident | Arrogant |
| Playful ↔ Serious | 60% playful | Silly |

---

## Tone by Context

| Context | Tone | Example |
|---|---|---|
| Home / marketing | Editorial, evocative | *"Every neighborhood is a menu."* |
| Quiz | Friendly, low-friction | *"Where are we exploring?"* |
| Generating | Cheeky, kitchen-themed | *"Bribing the chefs..."* |
| Results | Confident, curatorial | *"Your Capitol Hill Tour"* |
| Live tour | Encouraging, present | *"Stop checked off! 🎉"* |
| Errors | Honest, blameless, with next step | *"Tour generation hit a snag"* |
| Empty states | Inviting, not apologetic | *"Start a tour from the quiz first"* |
| Notifications | Urgent + warm | *"Your Saturday route is ready →"* |

---

## The 4 Principles

### 1. Be specific, never generic
The whole product is curation. Generic words betray the brand.

| ❌ | ✅ |
|---|---|
| "Delicious food nearby" | "A pork bao that justifies the line" |
| "Great restaurants" | "The bakery locals queue for at 7am" |
| "Amazing vibes" | "Wine bar with one shared table and good lighting" |

### 2. Sequence is the product
Tours build. Appetizer → main → dessert isn't a list, it's a meal with an arc. Copy should honor that arc.

Good: *"FIRST BITE → MAIN EVENT → SWEET FINISH"*
Good: *"A walk. A story. The feeling of having actually been somewhere."*

### 3. Friend voice, not app voice

| ❌ App | ✅ Friend |
|---|---|
| "Please select your preferences" | "Where are we exploring?" |
| "Tour generation in progress" | "Scouting the block..." |
| "Stop marked as complete" | "Stop checked off! 🎉" |
| "Submit" | "I'm in →" |

### 4. Food-first, tech-last
Never sell the AI. Sell the meal.

| ❌ Tech-first | ✅ Food-first |
|---|---|
| "AI-powered recommendations" | "A personalized food tour of any neighborhood" |
| "Our algorithm finds the best spots" | "We'll source stops just for you" |
| "Smart shuffle uses ML to swap stops" | "Don't love a stop? Tell us what you'd rather have." |

---

## Do / Don't Word List

| ❌ Never use | ✅ Use instead |
|---|---|
| "AI," "algorithm," "machine learning" | "we," "our curation," or nothing |
| "Restaurants" (in body copy) | "stops," "spots," "places" |
| "Foodie" | (describe the food instead) |
| "Delicious," "amazing," "yummy" | specific food details |
| "Discover" | "find," "eat your way through," "explore" |
| "Best of [neighborhood]" | "Your [neighborhood] tour" |
| "Itinerary" | "tour," "route" |
| "Submit" | the actual verb ("Save →", "Search →") |
| "Log in" | "Sign in" |
| "Click" | "tap" (mobile) or omit |
| "An error occurred. Please try again." | name what happened + give next step |

---

## Copy Patterns

### Headlines
- Short, declarative, ownable: *"Every neighborhood is a menu."*
- ≤ 8 words. Sentence case (not Title Case).

### CTAs
- Verb + arrow: *"Get Started →"*, *"Walk the tour →"*, *"Build my tour →"*
- Never: "Click here", "Submit", "Learn more"

### Generating / loading messages (cheeky, kitchen-themed)
```
"Scouting the block..."
"Bribing the chefs..."
"Checking for vibes..."
"Negotiating with dessert..."
"Almost plated..."
```

### Errors — template
*"[What happened]. [What to do next]."*
- ✅ *"We couldn't find that location. Try a city name or zip code."*
- ✅ *"Tour generation hit a snag — try again."*
- ❌ *"An error occurred."*
- ❌ *"Invalid input."* (never blame the user)

### Success / toasts
- Past tense for confirmations: *"Notes saved."*, *"Stop checked off! 🎉"*
- Specific: *"Swapped in Altura!"*, *"Added to favorites ❤️"*
- Never: *"Operation completed successfully."*

### Empty states
- Inviting, not apologetic: *"Start a tour from the quiz first"*
- Never: *"No data available."*

---

## Terminology Glossary

| Term | Definition | Notes |
|---|---|---|
| **Tour** | The full curated route (2–5 stops) | Capitalize in titles (*Your Capitol Hill Tour*), lowercase mid-sentence |
| **Stop** | A single restaurant/bar/café within a tour | Always "stop," never "venue" or "destination" |
| **Spot** | Synonym for stop, used in casual/marketing copy | "Don't love a spot?" |
| **Route** | The walking path; interchangeable with "tour" in editorial copy | |
| **Neighborhood** | The geographic anchor of a tour | Never "area," "district," "zone" |
| **Vibe** | The mood/occasion of the tour | "Date night," "Flying solo," etc. |
| **Meal type** | The kind of meal the tour delivers | "Just drinks!", "Late night bites," etc. |
| **Live tour** | The walk-along mode (two words, lowercase) | |
| **Shuffle** | Swap one stop randomly | Verb + noun |
| **Smart shuffle** | AI-guided stop swap via user instructions | Two words |
| **Sign in / Sign up** | Auth actions | Never "Log in" |
| **Saved tours** | Tours the user bookmarked | |
| **Completed tours** | Tours finished in Live Tour mode | |
| **Favorites** | Spots the user hearted | Never "visited restaurants" (that's the internal table name) |

### Stop labels (from `src/lib/stopLabels.ts`)
Always uppercase, letter-spaced. Do not invent new ones without updating the source file.

| Tour shape | Labels |
|---|---|
| Default 2-stop | FIRST BITE · MAIN EVENT |
| Default 3-stop | FIRST BITE · MAIN EVENT · SWEET FINISH |
| Default 4-stop | FIRST BITE · MAIN EVENT · SIDE QUEST · SWEET FINISH |
| Default 5-stop | FIRST BITE · DRINKS · MAIN EVENT · SIDE QUEST · SWEET FINISH |
| Café hopping | CAFÉ ONE · CAFÉ TWO · CAFÉ THREE |
| Just drinks! | FIRST ROUND · SECOND ROUND · NIGHTCAP |
| Late night bites | LATE BITE 1 · LATE BITE 2 · LATE BITE 3 |
| Happy hour | HH SPOT · HH SPOT · HH FINALE |

---

## The Wordmark

**TiNY FOOD TOUR** — lowercase `i` is intentional (logo quirk in the PNG).
In body copy, "Tiny Food Tour" (title case) is acceptable.
Never "TFT" in user-facing copy — that's internal shorthand only.
