# Manual QA checklist

Items that require on-device verification before release. Each entry lists what to check, which screen, and the expected result.

---

## Authentication
- [ ] Google sign-in end-to-end: Sign In screen > "Continue with Google" > completes auth flow, returns to app signed in, display name shows in Profile.
- [ ] Apple sign-in end-to-end: Sign In screen > "Continue with Apple" > completes auth flow, returns to app signed in.
- [ ] Email sign-up + sign-in round trip: create account, sign out, sign back in with same credentials.
- [ ] Delete account: Profile > Delete Account > confirm > account deleted, returned to signed-out state.

## Animations and visual polish
- [ ] Shimmer animation: Home screen on cold launch or pull-to-refresh > shimmer placeholders animate smoothly before cities load.
- [ ] Vote button bounce: Restaurant Detail > tap vote > elastic scale animation plays.
- [ ] Save button bounce: Restaurant Detail > tap save (Locals Pass+) > elastic scale animation plays.
- [ ] Splash screen fade/scale: App cold launch > logo fades in and scales up smoothly > transitions to Home or Onboarding.

## Onboarding
- [ ] "Next" label: Onboarding screen > button reads "Next" on pages 1-2, "Get Started" on page 3.
- [ ] Page indicators: Onboarding > swipe between pages > active indicator animates width change.
- [ ] Skip button: Onboarding > tap "Skip" > navigates to Home, onboarding not shown again.

## Accessibility (on-device)
- [ ] Screen-reader walkthrough (VoiceOver on iOS): Navigate every screen with VoiceOver. Confirm all interactive elements announce meaningful labels, no "button button" duplicates, reading order is logical.
- [ ] Dynamic type testing: Set system text size to largest > relaunch app > confirm all text scales, no truncation or overflow on Home, City Detail, Restaurant Detail, Profile, Upgrade screens.
- [ ] Reduced motion: Enable "Reduce Motion" in system settings > confirm shimmer, vote bounce, save bounce, and splash animations degrade gracefully (no jarring motion).

## Contrast (visual verification)
- [ ] Accent text (#FF5436 vermilion) on warm background (#0F0D0B): confirm "actually" tagline, "Free" badge text, accent links are readable in normal lighting and sunlight.
- [ ] Gray secondary text (#B8AFA6) on warm background: confirm body text in city descriptions, restaurant metadata is comfortable to read. Math passes (7.04:1) but warm-on-warm can feel low-contrast; verify readability in practice.
- [ ] Warm-on-warm secondary gray on city cards: text area uses surface (#1A1714) background with textTertiary (#7A7269) descriptions. Verify comfortable readability on device.

## Performance
- [ ] Performance profile: Run the app in profile mode on a physical device. Navigate Home > City Detail > Restaurant Detail > back. Confirm no jank (>16ms frames) during scrolling or transitions.
- [ ] Pull-to-refresh: Home screen > pull down > loading completes, data refreshes, no duplicate data.

## Paywall and membership
- [ ] Free user sees Top 5 only: City Detail > "Top 10" toggle > ranks 6-10 show blurred paywall, not real data.
- [ ] Locals Pass user sees Top 10: After upgrading to Locals Pass, City Detail > "Top 10" toggle > ranks 6-10 render with real data.
- [ ] City Insider sees insider notes: Restaurant Detail > insider notes section visible with real content, not "Unlock to see" placeholders.
- [ ] Paywall "See plans" opens upgrade sheet: Tap "See plans" on any paywall > Upgrade bottom sheet appears.

## Notifications
- [ ] Notification toggles persist: Notification Settings > toggle each switch > leave screen > return > toggles retain state.

## Share
- [ ] Share restaurant: Restaurant Detail > share icon > system share sheet opens with correct restaurant name and rank.
- [ ] Share app: Profile > "Share App" > system share sheet opens with Vouch branding.

## Design direction (pending on-device approval)
- [ ] DM Serif Display renders on headlines: Home screen city name "Vouch", city card names, Restaurant Detail restaurant name, section headers ("Comments", "Locations") all render in unmistakable editorial serif, not bold Inter or a default fallback font. If Google Fonts fails to load, headlines will silently fall back to the system default.
- [ ] Warm-on-warm secondary gray readability: City card descriptions, restaurant metadata, comment text are all comfortable to read on the warm surfaces. Math passes but warm-on-warm needs eyes-on verification.
- [ ] Rank badges read as seal/award: Serif font on vermilion background at badge size (#1, #2, #3) reads as a deliberate award mark, not cramped or muddy. Both standard (list card) and large (detail screen) sizes.
- [ ] Vermilion consistency check: Walk every screen and verify #FF5436 looks appetizing and consistent everywhere it appears: CTA buttons (onboarding "Get Started", upgrade "Start 7-day free trial", sign-in submit), vote pill (both active/voted and default states), vibe tags, Free/PRO/Insider badges, tagline "actually", accent text links ("Reply", "See plans", "Restore purchases"), send icon, location pin icon. No instance should look garish on large fills or washed out on small text.
- [ ] Theme inheritance completeness: Verify every screen feels like one deliberate product. Specifically check the "inherited, no edits needed" screens (City Detail, Sign In, Splash, Saved Restaurants) for any hardcoded colors that didn't pick up the warm theme. No screen should feel stranded on the old cold black/pink theme.

## Firestore data layer (Block 4)
- [ ] Auth still works against the real Firebase project: sign in with Google/Apple/email, profile shows display name, sign out works. (kUseFirebase flipped to true.)
- [ ] Cities load from Firestore after seed script runs: Home screen shows 4 cities with correct names, images, descriptions.
- [ ] Restaurant rank gating: Free user sees only Top 5 in City Detail. Locals Pass user sees all 10.
- [ ] Insider notes gating: City Insider sees "What to order" and "Pro tip" on Restaurant Detail. Free/Locals Pass user sees paywall overlay with no insider data in the widget tree.
- [ ] Voting writes to Firestore: vote a restaurant, force-close app, reopen. Vote persists.
- [ ] Vote count updates: after voting, the restaurant's vote count increments (may take a few seconds for the Cloud Function trigger).
- [ ] Comments write to Firestore: add a comment, force-close app, reopen. Comment persists.
- [ ] Suggestion submission via Cloud Function: submit a suggestion, confirm it completes. Submit a second suggestion on the same day, confirm "You've hit the limit for today" error appears.
- [ ] Offline behavior: enable airplane mode, open app. Cached data (if available) shows with "Showing saved data" indicator. Disable airplane mode, pull to refresh, live data loads.
- [ ] Account deletion cleanup: delete account, confirm user data is removed from Firestore (votes, comments, suggestions, user doc). Requires checking Firestore console or running a query.

## Deferred
- [ ] Golden tests for the 3-4 highest-traffic screens to lock the approved design against future regressions. Trigger: after design signed off on device.
- [x] Firebase rules-unit-testing: 55 tests (22 positive, 33 negative) covering every rule path. Runs via `firebase emulators:exec --only firestore 'cd test-rules && npx jest'`. Requires OpenJDK 21.

## Investigate or resolve
- [ ] 2 mockup golden tests fail in batch mode but pass standalone. Carried since Block B. Root cause: Flutter golden test rendering differs between isolated and batched execution (font loading timing). Disposition needed: either pin the goldens with a tolerance threshold, exclude from CI batch runs, or delete the mockup tests now that the design direction is approved. These are reference artifacts, not regression tests.
