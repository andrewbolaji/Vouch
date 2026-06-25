# Vouch design direction: Block Party

Status: chosen and approved (Andrew and Christina), June 2026\. This is the source of truth for the beautification block. Logic is not in scope. Visual only.

## The vibe

Vouch is the city's own thing, decided by the people who actually eat there. Block Party dresses that up as a screenprinted neighborhood flyer: bold ink on warm paper, hard edges, big poster numerals, and full color food doing the talking inside it. It reads as local, communal, and a little scrappy, which is exactly the anti-Yelp position. The discipline keeps it from getting loud: generous space, the boldness spent in a few places, and a quieter premium register for the paid tier.

This is a shift from the current dark theme to a light, warm-paper base. That is intentional. A light, print-zine surface with full color food photography feels like a food magazine you want to flip through, and it sets Vouch apart from every dark restaurant app. A dark variant can come later (the light and dark toggle was already deferred to post launch).

## Who it serves

Food-culture-literate 25 to 40 year olds, starting in Houston and expanding nationally, who are Yelp-frustrated and trust personal recommendations over algorithmic ones. They follow local food accounts, read Eater or Bon Appetit, and care about the story behind a place. They open Vouch two or three times a week to answer "where should I eat tonight" and then close it. They want the real shortlist, not a directory and not paid placement, and they trust other locals over star averages. The UI must respect that: fast, opinionated, confident, and unmistakably made by the city for the city, never corporate.

## Refinements baked in (from review)

1. Food photography stays full color. The dish and city photos are the pop of real inside the bold graphic frame. No duotone on real food. This is the single most important rule for keeping the app appetizing.  
2. Disciplined hand. Hard shadows, banners, and stamps are accents used sparingly, not on every element. Generous spacing throughout. Loud is earned, not constant.  
3. A quieter premium register. The City Insider tier and verified-local moments use a deep ochre "gold" treatment that reads as elevated within the bold system, so paying for it still feels special.

## Palette

Tokens, never hardcoded literals. Names map to role.

| Token | Hex | Role |
| :---- | :---- | :---- |
| paper | \#EEE7D8 | Page background, the warm newsprint base |
| paper-raised | \#F7F2E6 | Cards and raised surfaces |
| ink | \#1A1714 | Primary text, 2px borders, hard shadows. The screenprint ink |
| ink-2 | \#5C5142 | Secondary text, meta |
| ink-3 | \#8B8273 | Tertiary text, captions, placeholders |
| flame | \#E8502A | Accent: actions, rank chips, vote counts, key highlights |
| flame-deep | \#C2401C | Pressed and shadowed accent states |
| gold-ink | \#9A6B1F | Premium and verified-local (City Insider, cosign stamp) |
| success | \#2E7D46 | Semantic only |
| warning | \#B07A1C | Semantic only |
| danger | \#C23A2A | Semantic only |
| line-soft | rgba(26,23,20,0.14) | Hairline dividers where 2px ink is too heavy |

Contrast rules (WCAG AA, non negotiable): ink on paper is very high contrast, use it for all body and small text. flame and gold-ink do not pass AA for small body text on paper, so use them only at 18px or larger, bold, or as fills with paper colored text on top. Body and meta text are never flame.

## Typography

Two families. Anton for the poster moments, Archivo for everything else. The display face is swappable if Anton ever reads too common (alternatives: Archivo Expanded Black, or a more characterful condensed), but Anton is the pick.

- Display and rank numerals: Anton. City names, the biggest headers, and rank numbers. This is the poster voice. Used big and short.  
- Headings, restaurant names, UI titles, body, meta: Archivo, weights 400 to 900\. A sturdy grotesque that carries the whole interface so the system stays tight.

Type scale (mobile, px):

- Display XL (Anton): 40 to 48, city names and hero rank  
- Display L (Anton): 28 to 34  
- Rank chip numeral (Anton): 18 to 22  
- Title H1 (Archivo 800): 26 to 30  
- Section H2 (Archivo 700): 16 to 18  
- Restaurant name (Archivo 800): 16 to 18  
- Body (Archivo 400 or 500): 15 to 16, line height 1.45 to 1.5  
- Meta and label (Archivo 600): 12.5 to 13.5  
- Vote and stat (Archivo 800): 13 to 14  
- Caption (Archivo 500): 11 to 12

## Spacing, radii, borders, shadows

- Spacing scale (4 based): 2, 4, 8, 12, 16, 20, 24, 32, 40, 48\.  
- Radii are minimal, the hard edge is a signature: radius-sm 4\. Segmented toggles (Top 5 / Top 10) use radius-sm like everything else. Pill (999) remains only for small circular indicators (page dots) where the rounded shape is inherent to the element.  
- Borders: border-ink is 2px solid ink on cards, image frames, and buttons. Hairline is 1px line-soft for dividers inside a card.  
- Shadows: shadow-hard is a 4px 4px 0 offset in ink, no blur. Used sparingly on primary cards, primary buttons, and rank stickers. No soft or blurred shadows anywhere, they fight the screenprint look. Pressed state shifts the element 2px down and right and collapses the shadow to 2px, so it feels like a sticker pressing down.

## Signature elements

- Big condensed rank numerals (Anton). Honest, because it is a real ranked list. The numbers are the hero device.  
- The cosign. A deep ochre stamp or "voted by locals" banner marks the number one spot, most-vouched items, and verified-local voices. It ties straight to the name Vouch, to put your reputation on something. It also gives gold-ink a clear job.  
- Subtle halftone dot texture on the page background, low opacity. The print signature. Background only, never piled onto elements.  
- Hard 2px ink outlines plus offset shadows. The screenprint and sticker tactility.  
- Full color food inside the ink frames. The pop of real.

## Component principles

- Primary button: flame fill, 2px ink border, hard shadow, ink text, Archivo 700 to 800\. Pressed collapses the shadow.  
- Secondary button: paper-raised fill, 2px ink border, ink text.  
- Card: paper-raised fill, 2px ink border, radius-sm. Hard shadow on primary cards only, not every card.  
- Tag and pill: small, flame or ink outline, Archivo 600\.  
- Input: paper-raised fill, 2px ink border, ink text, ink-3 placeholder. Focus thickens or darkens the border, no glow.  
- Rank chip: solid flame square, 2px ink border, Anton numeral, ink text. The number one chip may use gold-ink or carry the cosign stamp.  
- Image frame: full color photo, 2px ink border, radius-sm.  
- Hero (restaurant detail): full bleed full color photo with a bottom ink scrim gradient (rgba(26,23,20,0) up to about 0.6) so the rank and name stay legible over it.  
- City Insider and premium: gold-ink treatment, lock, gold-ink call to action with paper text. Elevated and distinct from the flame action color.  
- Banners and stamps: bold ink or flame, slight rotation, used only for special states (number one, most vouched, verified local), never routinely.  
- Shell and nav: paper base, ink text and icons, a 2px ink rule or border to separate bars rather than a soft shadow.

## Every state designed

- Empty: an invitation in the bold voice, for example "No spots here yet. Be the first to vouch." Never a blank screen.  
- Loading: paper and ink skeleton blocks. Subtle, no flashy animation.  
- Error: direct, in the interface voice, with a concrete next step, for example "Couldn't load Houston. Check your connection and try again." No apology, never vague.  
- Success: a short confirmation in voice.

## Motion

Minimal and deliberate. The button and card press shift (sticker pressing down) is the main interaction. Respect reduced motion. Extra animation reads as generated, so do not add it.

## Imagery

Dish and city photos are full color, inside a 2px ink frame, radius-sm. The restaurant detail hero is a full color photo with the bottom ink scrim. Let the food be the brightest, most saturated thing on the screen against the warm paper and ink graphics.

## What this is not

- Not duotone or tinted real food. Food is full color, always.  
- Not busy. Discipline and space first, loudness in a few earned places.  
- Not corporate, sterile, or generic dark app.  
- No mascot, no gamification, no bouncy animation. The personality is print and voice, not cartoon.  
- No neon and no soft blurred shadows. Those belong to a different direction.

## Prioritized opportunities audit

Fix the system once, then hand tune the few screens that earn it. Build order:

0. Design system and shared primitives. Tokens (color, type, spacing, radii, borders, shadows), and the restyled Button, Card, Tag, Input, rank chip, image frame, plus the app shell and nav and the empty, loading, and error states. Highest leverage, everything inherits from this.  
1. City list (the Top 10 screen). The core browse screen and the most used. Hand tune.  
2. Restaurant detail. The destination: hero, rank and name, tags, votes, the City Insider block, comments. Hand tune.  
3. Home and city grid. First impression after splash, the city cards. Hand tune.  
4. Onboarding (three screens). High first impression for new users, currently plain. Reset the icons, type, and voice to the system.  
5. Splash. Quick win, the wordmark and tagline in the new identity.  
6. Paywall and plans, plus profile, settings, and the suggestion box. Mostly inherit from primitives, with a light hand tune for the gold-ink premium moments and the suggestion box personality.  
7. Sign in. Inherits from the primitives, minimal custom work.

## Guardrails

Visual only, no logic changes. Tests are deliverables only where testable logic is genuinely touched, since most of this is styling. Hold the quality floor: AA contrast, tap targets at least 44px, text that respects system scaling, reduced motion respected. No em dashes anywhere.  
