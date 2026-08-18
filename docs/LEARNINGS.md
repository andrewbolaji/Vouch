# Engineering learnings

This is durable, evidence-backed project memory. It prevents the same failure or investigation from being repeated. It is not a diary or a backlog.

## Rules

- Add an entry only after a reproduced failure, measured result, incident or verified correction yields a reusable lesson.
- State the scope. Include the evidence and the concrete behavior future work should follow or avoid.
- Search before adding. Update or supersede an existing lesson instead of creating duplicates.
- Never store secrets, personal data, raw production payloads, private prompts or chain-of-thought.
- Promote mature lessons into code, tests, `AGENTS.md`, decisions or runbooks. Mark stale guidance as superseded instead of silently rewriting it.

## Entries

### 2026-08-17T22:58:11Z A live domain does not prove the local marketing change shipped

- **Status:** promoted
- **Scope:** Static Firebase Hosting and local marketing-site changes
- **Observed:** `https://vouchfood.com/` is reachable, but its public restaurant rows match an earlier three-visible-row build while the checkout contains a different unstaged five-visible-row redesign plus new local assets.
- **Evidence:** Read-only browser inspection of production, `git status`, `git diff -- site/index.html` and the hosting configuration in `site/firebase.json`.
- **Learning:** Report domain availability and content deployment as separate facts. Before saying a site is deployed, compare a distinctive production marker with the intended local artifact and preserve dirty work until ownership is clear.
- **Applied control:** The selected Local Guide source was published with `firebase deploy --only hosting` on 2026-08-18. The deployment was called complete only after a fresh response from `https://vouchfood.com/` contained the distinctive contribution heading, ranking rule, production waitlist endpoint, and Privacy and Support links.
- **Revisit when:** Every future marketing-site deployment. Choose one distinctive intended marker before release and read it back from the custom domain afterward.
- **Related:** `docs/EXECUTION.md`, `docs/INTERFACE.md`, `prototypes/vouch-landing/README.md`

### 2026-08-17T22:07:50Z A reachable write needs an owned read path

- **Status:** promoted
- **Scope:** User submissions, paid-content surfaces and other end-to-end product flows
- **Observed:** `submitSuggestion` accepts a user's restaurant suggestion and confirms success, but no product or operator path reads the `suggestions` collection. Earlier remediation found the same shape in insider notes and the paywall, where downstream mechanisms existed without a reachable reader.
- **Evidence:** `docs/OPEN_LIST_MEASUREMENT.md`, `docs/REMEDIATION_STATE.md`, `functions/src/index.ts` and `lib/widgets/suggestion_box.dart`.
- **Learning:** A write is not a complete feature until its intended consumer can discover, process and communicate the result. Trace reachability from the user's action through storage to an owned reader before calling a flow complete.
- **Applied control:** Open-list work remains explicitly open in `docs/REMEDIATION_STATE.md`; interface inventory now records the suggestion path as incomplete.
- **Revisit when:** A moderation or operator intake surface reads pending suggestions and the user-facing acknowledgement accurately describes what happens next.
- **Related:** `docs/INTERFACE.md`, `docs/OPEN_LIST_MEASUREMENT.md`

### 2026-08-17T22:07:50Z Convenience indexes are not automatically exact state

- **Status:** superseded by transactional reconciliation on 2026-08-18
- **Scope:** Vote state and Firestore trigger-maintained user indexes
- **Observed:** `votedRestaurantIds` uses `arrayUnion` and `arrayRemove` from independently delivered create and delete triggers. The operations are idempotent under redelivery but not order-independent, so a fast vote then unvote can leave the convenience list wrong when events arrive in reverse order.
- **Evidence:** The ordering analysis in `functions/src/vote_aggregation.ts`, per-restaurant repair in `lib/providers/app_state.dart`, and regression tests in `functions/src/index.test.ts` and `test/providers/app_state_test.dart`.
- **Learning:** A denormalized trigger-maintained list can drive cheap hints and reconciliation, but a new feature that promises an exact historical or current list must close ordering and discovery gaps against the authoritative records.
- **Applied control:** Both vote triggers now call one transactional reconciliation that reads the current vote document and applies the matching set operation. Firestore retries if that source changes before commit, so late or repeated events converge to current truth. Restaurant detail keeps its scoped repair as a defense for legacy data and partial failures. Firestore rules deny client writes to `votedRestaurantIds`.
- **Revisit when:** A trigger failure can persist beyond platform retries, or the index approaches the user-document size limit.
- **Related:** `docs/INTERFACE.md`, `functions/src/vote_aggregation.ts`

### 2026-08-17T22:07:50Z Deploy validation must cover source analysis, not only the selected function

- **Status:** promoted
- **Scope:** Firebase Cloud Functions changes and deploy verification
- **Observed:** A secret declared by one function blocked deployment of an unrelated selected function because the Firebase CLI analyzed the whole source before filtering the deploy target. A deploy from an older worktree hid the defect.
- **Evidence:** Commit `1785e21`, `docs/REMEDIATION_STATE.md`, and the phase 19 handoff supplied on 2026-08-17.
- **Learning:** A change under `functions/` is not deploy-ready until whole-codebase Firebase source analysis succeeds. A narrow function selection does not prove unrelated declarations are valid.
- **Applied control:** `AGENTS.md` records the project testing constraints. The standing release check is `firebase deploy --dry-run`, without mutating production.
- **Revisit when:** Firebase documents or demonstrates target filtering before source analysis, and a regression probe proves the behavior changed.
- **Related:** `docs/DECISIONS.md`

### 2026-08-17T22:11:37Z Verify held vendor security contracts before creating their secrets

- **Status:** active
- **Scope:** RevenueCat webhook signature verification
- **Observed:** The held implementation expects `x-revenuecat-signature`, accepts a bare digest or `sha256=` prefix, and computes HMAC-SHA256 over only the raw body. RevenueCat currently documents `X-RevenueCat-Webhook-Signature` with `t=<timestamp>,v1=<digest>`, computed over `<timestamp>.<raw_json_body>`, plus a recommended timestamp-tolerance check.
- **Evidence:** RevenueCat's official Webhooks documentation checked on 2026-08-17, `functions/src/membership_webhook.ts` and `functions/src/membership_signature.test.ts`.
- **Learning:** A test derived from an assumed third-party contract only proves the assumption is internally consistent. Check the current primary vendor documentation and test its exact example shape before creating a secret or enabling a request-rejecting control.
- **Applied control:** `SIGNATURE_ENABLED` remains false and the current verifier must be corrected before the signing secret is enabled or the webhook is redeployed with verification active.
- **Revisit when:** The verifier parses the documented header, signs timestamp plus raw body, enforces a bounded tolerance, passes vendor-shaped tests and accepts a RevenueCat test delivery while rejecting a deliberately invalid one.
- **Related:** `docs/EXECUTION.md`, `functions/src/index.ts`

## Entry template

### [YYYY-MM-DDTHH:MM:SSZ] [LESSON]

- **Status:** [active/promoted/superseded]
- **Scope:** [component, workflow, environment or project-wide]
- **Observed:** [failure or surprising behavior]
- **Evidence:** [test, command, trace, incident, benchmark or source]
- **Learning:** [reusable rule]
- **Applied control:** [code/test/doc/runbook/agent rule, or not yet applied]
- **Revisit when:** [observable trigger]
- **Related:** [execution entry, rationale, decision, PR or incident]
