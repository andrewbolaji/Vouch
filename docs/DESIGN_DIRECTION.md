# Vouch design direction

## The audience

25-40 year olds in Houston (expanding nationally) who are food-culture-literate, Yelp-frustrated, and trust personal recommendations over algorithmic ones. They follow local food accounts, read Eater or Bon Appetit, care about the story behind a restaurant. They open Vouch 2-3 times a week to answer "where should I eat tonight" and close it. The UI must respect that: fast, opinionated, confident. Not a social media feed. Not a review platform. A curated editorial list.

## Visual vibe

**Editorial food magazine, in your pocket, at night.**

Think: the intersection of a Bon Appetit feature, a Linear product surface, and a Stripe dark-mode dashboard. Calm, spacious, type-driven. The photography carries the emotion; the chrome stays quiet. Every screen should feel like opening a well-designed menu at a restaurant you trust.

Reference points:
- **Linear**: Dark surfaces, restrained accent, generous whitespace, strong type hierarchy
- **Stripe dark docs**: Clean information density, subtle borders, professional confidence
- **Notion**: Spacing rhythm, content-first, nothing decorative that doesn't earn its place
- **Bon Appetit / Eater**: Editorial serif headlines, food photography as hero, opinionated voice in type

The current `instagramDark` theme (pure black, pink accent) reads as generic dark-mode social media. The direction below refines the palette with warm near-black surfaces, vermilion (#FF5436) accent, and DM Serif Display headlines.

## Palette

Warm dark, not cold dark. The background should feel like a candlelit restaurant, not a phone screen.

| Token | Value | Role |
|-------|-------|------|
| `background` | `#0F0D0B` | Near-black with warm undertone. Not pure black. |
| `surface` | `#1A1714` | Cards, sheets, elevated surfaces. |
| `surfaceVariant` | `#252118` | Input fills, inactive toggles, shimmer base. |
| `accent` | `#FF5436` | Vermilion. Actions, rank badges, links. Used surgically. Appetite-forward, editorial. |
| `accentMuted` | `#CC432B` | Accent at reduced intensity. Borders, inactive accent elements. |
| `textPrimary` | `#F5F0EB` | Warm white. Headlines, primary body text. |
| `textSecondary` | `#B8AFA6` | Warm gray. Metadata, supporting text. |
| `textTertiary` | `#7A7269` | Warm dark gray. Timestamps, tertiary info. |
| `divider` | `#2E2A27` | Hairline separators. |
| `error` | `#CF6679` | Error states. Material standard for dark themes. |
| `cardBackground` | `#1A1714` | Same as surface. |
| `primaryMuted` | `#3D3530` | Muted accent background for insider notes, badges. |
| `onAccent` | `#0F0D0B` | Dark text on accent-colored surfaces. |

Rationale: The warm undertones create a food-appropriate atmosphere (think restaurant lighting, warm tones) rather than the clinical feel of pure black. Vermilion (#FF5436) reads warm-on-warm (integrated, appetite-forward, editorial) and scored highest contrast of accent candidates (6.07:1 on background).

## Typography

Two typefaces, clear hierarchy, editorial personality.

| Token | Typeface | Size | Weight | Role |
|-------|----------|------|--------|------|
| `displayLarge` | DM Serif Display | 32 | Regular | App title, hero moments |
| `displayMedium` | DM Serif Display | 24 | Regular | Screen titles, restaurant names on detail |
| `headlineLarge` | DM Serif Display | 20 | Regular | Section headers, city names |
| `headlineMedium` | DM Serif Display | 18 | Regular | Subsection headers |
| `accentItalic` | DM Serif Display | 18 | Italic | Tagline, editorial callouts |
| `bodyLarge` | Inter | 16 | Regular (400) | Primary body text, descriptions |
| `bodyMedium` | Inter | 14 | Regular (400) | Secondary body, metadata |
| `bodySmall` | Inter | 12 | Regular (400) | Timestamps, tertiary info |
| `labelLarge` | Inter | 14 | Semibold (600) | Buttons, card titles, labels |
| `labelMedium` | Inter | 12 | Medium (500) | Chips, badge text, small labels |
| `buttonText` | Inter | 14 | Semibold (600) | Button labels |
| `rankDisplay` | DM Serif Display | 20 | Regular | Rank badge number (new token) |

The serif/sans pairing (DM Serif Display + Inter) creates immediate editorial personality. Headlines feel like a magazine masthead; body text stays clean and legible. This is already built into the `editorialDark` variant but unused.

## Spacing scale

Already defined and mostly followed. Codify one addition:

| Token | Value |
|-------|-------|
| `spacingXxs` | 2 |
| `spacingXs` | 4 |
| `spacingSm` | 8 |
| `spacingMd` | 16 |
| `spacingLg` | 24 |
| `spacingXl` | 32 |
| `spacingXxl` | 48 |

Add `spacingXxs: 2` to formalize the half-step used in city card padding and label gaps. Replace all hardcoded `2` values.

## Radius scale

No changes. Current scale is clean:

| Token | Value |
|-------|-------|
| `radiusSm` | 8 |
| `radiusMd` | 12 |
| `radiusLg` | 16 |
| `radiusXl` | 24 |

## Component principles

### Rank badges (signature brand element)

The rank badge is Vouch's most distinctive UI element -- the #1-#10 pill that appears on every restaurant card and detail screen. It deserves dedicated treatment:

- **Top 3**: Accent background, dark text, serif `rankDisplay` font. These are the "podium" ranks and should feel premium.
- **4-5 (free tier visible)**: Surface variant background, primary text, serif font. Visible but visually quieter than top 3.
- **6-10 (paid tier)**: Same as 4-5 styling, but with a subtle accent border to signal "this content is special."
- **Size**: Two variants -- standard (in list cards, `spacingSm` padding) and large (on detail screen, `spacingMd` padding). Both use the serif `rankDisplay` token.
- **Shape**: Rounded rectangle with `radiusSm`. Not a circle (too generic), not a square (too rigid).

### City cards

The strongest existing screen element. Enhancements:
- Warm surface instead of pure black card background
- Slightly more padding in the text area
- City name in serif headline for editorial feel
- Description in `bodySmall` stays as-is (already good)

### Restaurant cards

Clean as-is. Enhancements:
- Add serif font to restaurant name for consistency with detail screen
- Vote count text stays accent-colored (good existing choice)
- Rank badge gets the serif treatment described above

### Insider notes

The gradient container is the right instinct. Refine:
- Use `primaryMuted` to `surfaceVariant` gradient (warm tones)
- Accent border stays
- "Insider Notes" header in accent serif italic for editorial personality

### Buttons

- Primary (accent): Accent background, dark text. Rounded rectangle (`radiusSm`).
- Secondary (outline): Surface variant border, primary text. Same shape.
- Text buttons: Accent text, no container.

### Empty states

- Large icon (tertiary color), warm serif headline, body-medium description
- Match the editorial voice: "We're not there yet" (already good), "No saved restaurants yet" (fine)

### Loading states (shimmer)

- Base color: `surfaceVariant`. Highlight: `surface`. Same as current, but warmer with the new palette.

## Prioritized opportunities (highest-impact first)

1. **Switch to editorialDark** (or refined version above): Single change that transforms the entire app from generic to deliberate. Every screen benefits.
2. **Rank badges**: Small component, high visibility. The serif treatment + warm accent makes them a signature element.
3. **Restaurant detail screen**: The longest screen, most time spent. Serif restaurant name, refined spacing, warmer insider notes.
4. **Home screen header**: App title in serif + warm tagline accent sets tone on first screen.
5. **Upgrade screen**: Trust surface -- this is where the user decides to pay. Clean, confident, warm.
6. **Onboarding**: First impression. Serif headlines, warm accent, generous spacing.
7. **Profile/settings**: Lower traffic, inherits from component improvements.

## Implementation notes

- **No logic changes.** This is a visual pass only.
- **Tokens, not magic numbers.** Every color, size, and spacing traces to AppTheme.
- **One file for the switch**: Change `kActiveTheme` in `theme_variants.dart` and refine the `editorialDark` palette to match the values above. The theme system already supports this.
- **Add `spacingXxs` and `rankDisplay`** as new tokens in `app_theme.dart`.
- Tests as deliverables only where testable logic is touched.
