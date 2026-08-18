# Execution log

This is the chronological evidence trail for substantial engineering work. It records what happened, not private reasoning.

## Rules

- Start an entry for every normal or high-risk change and for any multi-step task that changes repository or external state. Documentation-only work may use one compact entry when no future diagnostic value exists.
- Add material actions in execution order and timestamp them in UTC.
- Record commands, targets, outcomes, artifacts, state transitions, approvals and blockers. Summarize noisy output instead of pasting it.
- Never record chain-of-thought, prompts, secrets, credentials, tokens, personal data, raw production payloads or sensitive terminal output.
- Distinguish planned, attempted, completed, failed, skipped and blocked. A command that was not run is not evidence.
- Link the corresponding design, rationale, decision, issue or incident when one exists. Preserve older entries and correct errors with a dated correction.
- When this file becomes hard to scan, move closed entries intact to `docs/execution/YYYY-MM.md` and leave a dated link here.

## Entries

### 2026-08-18T21:05:46Z Apply supplied Vouch brand assets to the production site

- **Status:** completed
- **Scope:** Static landing page brand asset cleanup and Firebase Hosting production target only
- **Reference:** Andrew's 2026-08-18 request to apply the preferred site cleanup
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 21:05:46 | Started the approved brand asset cleanup | Local `site/` artifact | Selected the supplied dark wordmark for the light header, the supplied white wordmark for the dark footer, and the existing 512 pixel Vouch icon for install metadata. Existing favicon and Apple touch icon assets were confirmed as the supplied files. |
| 21:18:00 | Validated the static artifact | Local `site/` artifact | Both supplied SVGs passed XML validation and differ from their source files only by a normalized final newline. The manifest parsed as JSON, all 11 local page references resolved, the project memory check passed, the diff passed whitespace checks, and the retired raster wordmark treatment is no longer referenced. |
| 21:18:30 | Ran the hosting-only release analysis | Firebase Hosting dry run, project `majorcitymusteats` | The dry run completed successfully for Hosting only. No app, Functions or Firestore source or deployment was invoked. |
| 21:19:13 | Published the brand asset cleanup | Firebase Hosting production | Firebase found 30 static files, completed the upload, finalized the version and released it to the live channel. |
| 21:22:53 | Verified the production release record | Firebase Hosting live channel | Firebase reports the live channel release time as 2026-08-18 16:19:13 America/Chicago, matching the completed deployment. Terminal HTTP readback of both the custom domain and Firebase URL timed out before receiving bytes, so independent response-body verification was not available from this environment. |

- **Files/artifacts:** `site/index.html`, `site/site.webmanifest`, `site/img/vouch-wordmark-dark.svg`, `site/img/vouch-wordmark-white.svg`
- **Skipped or blocked:** No app, Functions or Firestore changes were in scope or performed. Browser screenshot inspection was skipped under the active site workflow. Direct HTTP readback was blocked by terminal network timeouts after the Firebase release completed.
- **Final state:** The supplied dark and white wordmarks and the install manifest are released on the Firebase Hosting live channel backing `https://vouchfood.com/`.

### 2026-08-18T15:20:00Z Deploy the approved landing page to vouchfood.com

- **Status:** completed
- **Scope:** Firebase Hosting production target only
- **Reference:** Andrew's 2026-08-18 approval to publish the selected Local Guide site to vouchfood.com
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 15:20:00 | Resolved the production hosting boundary before deployment | Local Firebase configuration and `site/` artifact | Confirmed that `site/firebase.json` publishes only the static `site/` directory. The intended page contains the Build the list contribution section, the real waitlist endpoint, Privacy and Support routes, local fonts and owned imagery. The app, Functions and Firestore rules are outside this hosting-only target. |
| 15:20:00 | Checked Firebase project access | Firebase CLI, project `majorcitymusteats` | The stored Firebase login has expired and requires reauthentication before a hosting release can start. No production state changed. |
| 20:47:00 | Reauthenticated the Firebase CLI and resolved the production site | Firebase project `majorcitymusteats` | Google sign-in completed for the existing project owner. `firebase hosting:sites:list` returned the single Hosting site `majorcitymusteats`, matching the established production configuration. |
| 20:48:00 | Ran the hosting-only release analysis | Firebase Hosting dry run | The dry run completed successfully for Hosting only. No Functions or Firestore source analysis or deployment was invoked. |
| 20:48:00 | Published the approved Local Guide landing page | Firebase Hosting production | Firebase found 27 static files, uploaded the changed assets, finalized the version and released it successfully to `majorcitymusteats.web.app`, which backs the existing custom domain. |
| 20:49:00 | Read back the custom domain rather than relying on the deploy receipt | `https://vouchfood.com/` | The live response contains the new page title, The city knows what we missed contribution section, Contribution earns credit, never rank rule, production waitlist endpoint, and Privacy and Support links. The social image, Privacy route and Support route each returned HTTP 200 with the expected content type. |
| 20:55:00 | Created a narrow source checkpoint and attempted to push it | Local Git and `origin/main` | Commit `4157337` contains only the production site and deployment evidence. The push was blocked before network mutation because production deployment approval did not separately authorize writing to the shared default branch. |

- **Files/artifacts:** `site/index.html`, `site/firebase.json`, `site/fonts/`, `site/img/`, `site/og-image.png`
- **Skipped or blocked:** The waitlist form was not submitted during verification because doing so would create artificial production data. No app, Functions or Firestore deployment was in scope or performed. Commit `4157337` is local; pushing it to `origin/main` requires Andrew's explicit approval.
- **Final state:** The approved Local Guide landing page is deployed and verified on `https://vouchfood.com/`.
- **Follow-up:** Build the operator suggestion inbox and original-photo review pipeline before presenting either workflow as complete.

### 2026-08-18T01:06:00Z Position community restaurant and photo contributions

- **Status:** completed
- **Scope:** Production marketing source, in-app suggestion interface, Instagram-ready messaging and project memory
- **Reference:** Andrew's 2026-08-17 approval of restaurant nominations, original-photo contributions, candidate discovery, contributor status and city activation ideas
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 01:06:00 | Audited the existing suggestion and image paths before changing their positioning | Local Flutter, Functions, Firestore and project memory | Confirmed the one-per-UTC-day suggestion cap is optional participation, not a daily requirement. New Restaurant and New City submissions reach a pending Firestore document, but no operator reader or restaurant-promotion path exists. No user-photo upload pipeline exists. The prior photo objection applies to unverified third-party screenshots, not to contributor-owned originals with an explicit display license. |
| 01:09:00 | Elevated restaurant nomination into a product surface | Local Flutter source and focused tests | Added Add a Place to Profile and each city screen, routed signed-out users through Sign In, focused the existing form on restaurant nominations, and clarified that one submission per UTC day is a maximum rather than a requirement. City-specific suggestion analytics now retain the city ID. |
| 01:12:00 | Positioned community expansion without claiming unfinished systems | Production site source and private Sites candidate | Added a Build the list section for reviewed restaurant nominations, planned original-photo uploads and city activation. The shared rule is explicit: contribution earns credit, never rank. Updated Your Vouches to included free and the weekly recap to planned and optional. |
| 01:14:00 | Prepared Instagram messaging and recorded the product trust contract | Local project memory | Added three pinned-post packages, bio, Stories and language guardrails. Recorded that photo ownership is contributor-attested rather than technically verified, in-app capture is stronger evidence but not proof, review precedes display, and off-app marketing needs separate consent. |
| 01:17:00 | Validated the changed site, backend and project-memory paths | Local source | Host lint passed. A production build completed under Node 24 and both rendered-package tests passed. Functions lint and TypeScript build passed. `git diff --check` and `./scripts/check-project-memory.sh` passed. Flutter tests were not rerun because Flutter still requires a shared SDK-cache write outside the writable workspace. |
| 01:23:00 | Attempted the first Sites publication | Owner-only Sites project, version 2 | The deployment failed before publication because pnpm blocked required dependency build scripts. The previous live version remained intact. |
| 01:29:00 | Added and verified the explicit dependency build policy | Isolated Sites wrapper | `pnpm approve-builds` allowed only esbuild, sharp and workerd. A clean locked install executed exactly those scripts. The site then rebuilt, linted and passed both rendered-package tests. Commits `3459db4` and `e040dbd` were pushed to the existing Sites source repository. |
| 01:31:34 | Published the corrected private site version | Owner-only Sites project, version 3 | Deployment `appgdep_6a83b578c0588191ad425fe63e51b7dd` succeeded at `https://vouch-local-guide-final.andrewbolaji.chatgpt.site`. Access remains owner-only. |

- **Files/artifacts:** `lib/screens/add_place_screen.dart`, `lib/screens/city_detail_screen.dart`, `lib/screens/profile_screen.dart`, `lib/widgets/suggestion_box.dart`, focused Flutter tests, `site/index.html`, `prototypes/vouch-landing/final-direction/`, `docs/INSTAGRAM_CONTRIBUTOR_POSITIONING.md`, `docs/USER_GUIDE.md`, `docs/WISHLIST.md`, `docs/INTERFACE.md`, `docs/DECISIONS.md`
- **Skipped or blocked:** The Instagram package is ready to post but was not posted. Photo upload, operator review, candidate promotion and automatic city activation remain planned, not live. The app and `vouchfood.com` were not deployed in this task. Flutter tests remain blocked by the shared SDK-cache boundary; previous focused coverage was extended in source but not rerun.
- **Final state:** Community contribution is implemented as an honest in-app and site entry point, documented across product memory, validated on the available paths, and published to the owner-only Sites URL as version 3.
- **Follow-up:** Build the structured operator inbox and candidate pool before relaxing the one-submission-per-day spam brake. Then add the private original-photo upload, license, moderation, attribution, reporting and takedown pipeline.

### 2026-08-18T00:17:00Z Implement Local Guide and the free Your Vouches list

- **Status:** blocked
- **Scope:** Flutter profile and vote-history UI, production marketing site, tests, project memory and approved deployment
- **Reference:** Andrew's 2026-08-17 approval of the Local Guide candidate and Your Vouches retention loop
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 00:17:00 | Converted Andrew's approval into an implementation contract | Local source and project memory | The free surface will list every currently active vouch that is present in the readable catalogue, ordered by city and current rank. Saved Restaurants remains separate. Weekly recap remains a second layer until authoritative rank history and notification controls exist. The Local Guide candidate becomes the production-site base while preserving the real waitlist endpoint. |
| 00:22:00 | Implemented the signed-in Your Vouches surface and profile entry | Local Flutter source | Added a separate taste-record screen with city grouping, current-rank ordering, count, empty state, unavailable-detail state and restaurant-detail navigation. Signed-out taps route to Sign In. Saved Restaurants remains unchanged and separate. |
| 00:27:00 | Extended the personal record beyond the free public catalogue | Local Flutter data layer and Firestore rules | An authenticated free user can directly read a restaurant they already vouched for after it moves below rank five. That private document is kept out of the normal city-list collection, so it does not unlock or leak the rest of ranks six through ten. Free users cannot create a vote for a hidden restaurant by guessing its ID; paid members retain the existing ability. |
| 00:31:00 | Made the per-user vote index converge to authoritative truth | Local Cloud Functions source | Both vote-created and vote-deleted triggers now transactionally read the current vote document and reconcile the user's `votedRestaurantIds`. This removes the prior event-ordering failure where a rapid vote and unvote could leave the convenience index wrong. |
| 00:34:00 | Promoted the approved Local Guide prototype into the production site source | Local `site/` | Ported the responsive Local Guide design without the concept switcher, copied its owned font and social-card assets, retained Privacy, Support and Instagram links, and connected the form to the existing production `waitlistSignup` endpoint with validation and duplicate, rate-limit and network states. |
| 00:36:00 | Exercised the production-site source at desktop and mobile sizes | Local in-app browser against a temporary HTTP server | Desktop and 390 by 844 layouts rendered without horizontal overflow. Hero, board, Your Vouches, signup and footer were inspected. The page title and form handler were present and all eleven referenced local assets resolved. The temporary server was stopped after validation. |
| 00:38:00 | Ran focused Flutter screen and profile tests before the final private-detail refinement | Local Flutter test runner | Nineteen focused tests passed, covering the new screen, profile navigation and the adjusted suggestion-box interaction. A later test was added for a below-Top-5 own-vouch detail, but the final Flutter rerun could not start because Flutter needs to update its shared SDK cache outside the writable workspace and the approval service reported its usage limit. |
| 00:40:00 | Attempted backend and rule validation | Local Functions and emulator test environments | Functions lint and TypeScript build passed. The combined Jest run reached tests but had no emulator project environment and was stopped rather than treated as evidence. Firestore rule tests could not start because Java is not installed. |
| 00:44:07 | Ran final local static and project-memory checks | Local source | `npm run lint`, `npm run build`, `./scripts/check-project-memory.sh`, `sh -n scripts/check-project-memory.sh` and `git diff --check` passed. Changed feature files contain no em dash or en dash characters. |
| 00:44:07 | Corrected the existing notification and marketing copy to match delivery reality | Local Flutter, site and user guide | Your Vouches is labeled as included free. The recap is labeled planned and optional. The existing notification switches now state that they save device-local preferences and that delivery is not live yet. |
| 00:44:07 | Attempted to continue release validation and deployment | Local tool approval and network boundary | Blocked by the Codex execution usage limit until 2026-08-24. No production deploy, commit or push was performed. The public domain remains unchanged and the previously published owner-only prototype remains separate. |

- **Files/artifacts:** `lib/screens/your_vouches_screen.dart`, `lib/providers/app_state.dart`, `lib/screens/profile_screen.dart`, focused Flutter tests, `functions/src/vote_aggregation.ts`, `functions/src/index.ts`, `firestore.rules`, rule and Function tests, `site/index.html`, `site/fonts/`, `site/og-image.png`, project memory
- **Skipped or blocked:** Weekly movement notifications remain intentionally unimplemented because no authoritative rank-history ledger or notification-delivery pipeline exists. The final Flutter rerun, Firestore emulator suite, Functions emulator suite, deployment, commit and push are blocked as recorded above.
- **Final state:** The approved app and site behavior is implemented and locally reviewed. Static checks and responsive browser checks pass, but the change is not release-complete or deployed.
- **Follow-up:** After execution access returns, install or expose Java, run the focused and full Flutter suites plus both emulator suites and deploy dry-run, capture the app screenshot, then commit, push and deploy the app rules, Functions and production site deliberately.

### 2026-08-17T23:20:23Z Refine the chosen marketing direction

- **Status:** completed
- **Scope:** Local final-candidate prototype, project memory and wishlist; existing `site/` changes remain untouched
- **Reference:** Andrew's 2026-08-17 selection feedback and four supplied screenshots
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 23:20:23 | Reconciled Andrew's feedback with the chosen app direction and existing product contract | Local design docs and source | Kept Block Party's warm paper, ink rules, hard accents and full-color food. Removed the ticker, yellow circle, oversized sans headline and “No filler” framing. Selected City Scorecard's spacious serif hierarchy, dark ranking board and Your Vouches product panels as the elements to translate into the app palette. |
| 23:26:00 | Built the Local Guide final candidate and updated the comparison gallery | Local `prototypes/vouch-landing/` | Added a complete responsive page with restaurant-led hero, dark five-row board, Your Vouches product preview, weekly movement recap, integrity rules, inert early-access form and a recommended-direction entry in the gallery. Existing `site/` files remained untouched. |
| 23:29:30 | Rechecked the shipped app's vote-history reachability | Local Flutter source | Confirmed the user document and `AppState` retain voted restaurant IDs for button state, but Profile exposes only Saved Restaurants and no screen lists the user's active vouches. Recorded the separate product contract and retention idea rather than claiming the preview already ships. |
| 23:31:00 | Rendered and exercised the candidate at default desktop and 390 by 844 mobile sizes | Local browser | Hero, board, Your Vouches and recap panels rendered without horizontal overflow. All images loaded, internal anchors resolved, the inert form confirmed nothing was sent and the browser reported no warnings or errors. |
| 23:34:00 | Generated and inspected one site-specific social preview card | Project asset | The card preserves the owned food photograph, exact Vouch copy, warm paper, ink and flame palette, with no invented restaurant claims. Saved as `prototypes/vouch-landing/final-direction/og.png`. |
| 23:43:00 | Built and tested an isolated Sites hosting wrapper | Local `prototypes/vouch-landing/final-direction/host/` | Vinext build completed and two focused rendered-output tests passed. The wrapper serves the validated static candidate and project-specific social metadata without connecting the waitlist or modifying production. |
| 23:49:46 | Published version 1 with owner-only access | Sites private deployment | Deployment succeeded at `https://vouch-local-guide-final.andrewbolaji.chatgpt.site`. It requires sign-in and is separate from `vouchfood.com`. |
| 23:50:26 | Ran final project-memory and punctuation checks | Local source | `./scripts/check-project-memory.sh` passed. Changed prototype and memory files contain no em dash or en dash characters. |

- **Files/artifacts:** `prototypes/vouch-landing/final-direction/`, `prototypes/vouch-landing/index.html`, `prototypes/vouch-landing/README.md`, `docs/INTERFACE.md`, `docs/WISHLIST.md`
- **Skipped or blocked:** Production `site/`, the real waitlist endpoint, the Flutter Your Vouches feature, commit/push of the main Vouch checkout and `vouchfood.com` deployment remain deliberately skipped while Andrew reviews the candidate. The private preview requires the owner to sign in.
- **Final state:** The Local Guide candidate is implemented, responsive, documented, tested and published privately. Existing live and unstaged marketing-site work remains unchanged.
- **Follow-up:** Andrew reviews the private candidate. On approval, port it into `site/index.html`, reconnect and test the real waitlist path, then deploy `vouchfood.com` deliberately. Decide the exact Your Vouches list contract before app implementation.

### 2026-08-17T22:29:19Z Explore Vouch marketing-site directions

- **Status:** completed
- **Scope:** Local static prototypes and read-only production-site inspection; existing `site/` redesign remains untouched
- **Reference:** Andrew's 2026-08-17 request, `vouch-design-reference.html`, `docs/INTERFACE.md`
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 22:29:19 | Audited the working tree, current site, supplied reference, imagery and Firebase Hosting configuration | Local `main` checkout | Confirmed `site/index.html` and its new visual assets are pre-existing unstaged work. Prototype work is isolated under `prototypes/` so it cannot overwrite the current direction or enter a normal `site/` deploy. |
| 22:29:19 | Inspected `https://vouchfood.com/` | Production, read-only | The domain is live, but it serves the earlier three-public-row version rather than the five-row unstaged redesign in this checkout. No deployment was performed. |
| 22:58:11 | Built a comparison gallery and three complete responsive landing concepts | Local `prototypes/vouch-landing/` | Added After Hours, Block Party and City Scorecard. Each has distinct layout and positioning, real local imagery, cross-concept navigation, integrity proof, an early-access action and an inert form. City Scorecard includes a concrete Your Vouches retention concept. |
| 22:58:11 | Rendered each concept at desktop and 390 by 844 mobile sizes | Local browser against a temporary HTTP server | All images loaded, all internal anchors resolved, all headings fit, mobile comparison collapsed to one column and horizontal page overflow was removed. Browser console returned no warnings or errors. |
| 22:58:11 | Exercised the prototype form and ran repository memory checks | Local browser and shell | The form cleared locally, displayed “Prototype only. Nothing was sent.” and did not navigate. HTML files and project memory contain no em dashes; the project-memory checker passed. |

- **Files/artifacts:** `prototypes/vouch-landing/`, `docs/INTERFACE.md`, `docs/LEARNINGS.md`
- **Skipped or blocked:** Production deploy, commit and push remain deliberately skipped while Andrew compares concepts. The prototype forms do not call the production waitlist endpoint.
- **Final state:** Three isolated concepts are implemented and visually verified locally. Production remains on its earlier deployed version, and the existing unstaged redesign remains untouched.
- **Follow-up:** Andrew chooses one direction or names a hybrid. Codex then ports only that choice into `site/`, reconnects and tests the waitlist flow, and deploys it deliberately.

### 2026-08-17T22:07:50Z Adopt Codex project memory

- **Status:** completed
- **Scope:** Local `main` checkout, documentation and project tooling only
- **Reference:** Codex Engineering Framework project-memory contract
- **Operator:** Codex

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| 22:07:50 | Inventoried Vouch checkouts and current Git state | Local workstation | `vouch-repo` is the active Git checkout at `0292334`; the Desktop and Downloads `Vouch-main` directories are non-Git copies. Existing site and documentation changes were left untouched. |
| 22:07:50 | Traced vote persistence and user-facing navigation | Local source | `votedRestaurantIds` is maintained server-side and reconciled into `AppState`, but Profile exposes only Saved Restaurants. There is no screen listing a user's votes. |
| 22:07:50 | Added separate execution, interface and learning memory | Local source | Added `docs/EXECUTION.md`, `docs/INTERFACE.md`, `docs/LEARNINGS.md`, the project-memory checker and references in `AGENTS.md`. |
| 22:10:11 | Ran structural validation and shell syntax check, then reviewed every added file | Local source | `./scripts/check-project-memory.sh` passed, `sh -n scripts/check-project-memory.sh` passed, and the new files contain no em dashes. |
| 22:11:37 | Verified the held RevenueCat manual steps against current official documentation | Read-only vendor documentation review | The dashboard steps and need for a secret API key are current, but the held verifier is not compatible with RevenueCat's documented signature contract. It uses the wrong header, parses the wrong format and hashes the wrong payload. `SIGNATURE_ENABLED` remains false, so live webhook traffic is unaffected. |
| 22:13:16 | Reconciled the Codex-facing command reference with the latest committed engineering review | Local source | Updated `AGENTS.md` from stale 349/135/91 counts to the review's 402 Flutter, 222 Functions and 112 rules tests. Official OpenAI documentation and the installed app bundle did not establish support for the imported `.codex/hooks.json` Claude-style Stop schema, so the memory checker was not attached to it. |
| 22:15:39 | Recorded Andrew's photograph ownership attestation | Local documentation | Added a dated owner-attestation section and filled Source and Permission for all 59 manifest rows. The measured Screenshot metadata was preserved unchanged. This closes the documented provenance hold without representing attestation as measurement. |

- **Files/artifacts:** `AGENTS.md`, `docs/EXECUTION.md`, `docs/INTERFACE.md`, `docs/LEARNINGS.md`, `docs/PHOTO_MANIFEST.md`, `scripts/check-project-memory.sh`
- **Skipped or blocked:** No product code, production data, Firebase configuration, deployment, commit or push was changed. The upvoted-places interface remains a product decision for Andrew before implementation.
- **Final state:** Project-memory adoption is implemented and verified locally. It is not committed or pushed.
- **Follow-up:** Fix and test the RevenueCat signature contract before Andrew creates or enables the signing secret. Andrew and Codex will choose the Your Vouches product contract before implementation. Commit the memory files without sweeping in unrelated site work when Andrew wants this transition checkpoint pushed.

## Entry template

### [YYYY-MM-DDTHH:MM:SSZ] [TASK OR CHANGE]

- **Status:** [in progress/completed/blocked]
- **Scope:** [repository boundary, branch/range, affected systems]
- **Reference:** [design/rationale/issue/decision or none]
- **Operator:** [person/agent if known]

| UTC time | Action | Target/environment | Result and evidence |
|---|---|---|---|
| [HH:MM:SS] | [command or material action] | [local/test/staging/production] | [completed/failed/skipped plus artifact or meaningful result] |

- **Files/artifacts:** [paths, reports, screenshots, build artifacts]
- **Skipped or blocked:** [check/action and why]
- **Final state:** [implemented/verified/reviewed/merged/deployed/observed, kept separate]
- **Follow-up:** [owner and trigger, or none]
