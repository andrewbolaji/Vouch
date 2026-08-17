# Finding 6: resumable account deletion, revised for approval

Revised 2026-08-18 after Andrew's resolutions. Design only, nothing
built. Supersedes the 2026-08-17 version; what changed is recorded at
the end.

## The defect, stated in the current code

`deleteUserData` (`functions/src/user_cleanup.ts`) performs **seven
distinct operations** in sequence:

| # | Step | Shape |
|---|---|---|
| 1 | `users/{uid}/suggestionCounts/*` | batched delete |
| 2 | `users/{uid}/reportCounts/*` | batched delete |
| 3 | `users/{uid}` | single delete |
| 4 | `suggestions where userId == uid` | batched delete |
| 5 | `reports where reporterUid == uid` | batched delete |
| 6 | votes, `collectionGroup("votes")` filtered to this uid | batched delete |
| 7 | comments, anonymised in place | batched update |

Nothing records which finished. It runs inside `onUserDeleted`, a Gen1
auth trigger, and the auth user is **already gone** when it starts, so
an interruption at step 4 leaves three collections cleaned, four not,
no auth record, and nothing that knows. The user has been told the
account was deleted.

Step 6 is the expensive one: `collectionGroup("votes").get()` reads
every vote document in the database to find the ones whose id matches
the uid. At launch volume that is small. It is the step that will time
out first as the app grows, which makes it the most likely place for
the partial state to occur.

## The definition that carries the whole design

**A deletion job is not complete because the cascade ran. It is
complete because a cascade pass found nothing left to delete.**

Everything below follows from that sentence. It is what absorbs the
race rather than preventing it: anything written after a pass, by a
client whose token has not expired yet, is simply found by the next
pass. There is no window to close, because a window that leaves data
behind is indistinguishable from a pass that had work to do.

**The scheduled resume is therefore part of the correctness argument,
not a retry mechanism.** It cannot be dropped later as an
optimisation, cannot be moved to run "only on failures", and cannot be
made conditional on an error having been recorded. A job with no error
at all still needs the next pass, because the pass is how the system
learns it is finished. Anyone proposing to remove it is proposing to
change what completion means.

**One concrete code consequence.** `deleteUserData` returns `void`
today; it logs counts and discards them. Completion now depends on
those counts, so it must return them, and every one of the seven
operations must contribute. A step that forgets to report its count
makes the job close early, which is the original defect wearing a
different hat. That return value needs a test of its own, asserting a
non-zero count on a first pass and zero on the pass after.

## Entry point, and the protection that has to be rebuilt

Deleting the auth user last means `onUserDeleted` cannot drive the
job, since it only fires after the thing that now happens at the end.
The entry point becomes a callable, `requestAccountDeletion`.

**Freshness has to be re-implemented explicitly, and this is not
optional.** `FirebaseAuth.delete()` is what raises
`requires-recent-login` today. A callable inherits none of it, so
without an explicit check, account deletion becomes available to
anyone holding a stolen unexpired token, which is a worse defect than
the one being fixed.

- Reject unless `request.auth.token.auth_time` is within **five
  minutes**, matching Firebase's own recent-login window.
- Reject with a **distinct error code**, `failed-precondition` carrying
  a `reauth_required` reason, so the client can tell "re-authenticate
  and try again" apart from "something went wrong". Only one of those
  is recoverable, and they produce different user behaviour.
- The client's existing re-auth dialog and its one-attempt retry stay
  exactly as they are (`DECISIONS.md`, 2026-06-09). Only the error it
  keys on changes.

`onUserDeleted` **stays**, for a deletion performed from the Firebase
console or any path that is not the app. It creates a job if one does
not exist and then runs it, so both entry points converge on the same
document and the same idempotent steps.

## Session revocation: accepted, not fought

`revokeRefreshTokens(uid)` invalidates refresh tokens. An ID token
already in the client's hands stays valid until it expires, up to an
hour, and `firestore.rules` cannot see revocation at all.

**The rejected fix, recorded so nobody rediscovers it:** a `deleting`
flag on the user document, checked in rules. That puts a `get()` on
the hot path of every write in the app, permanently, to guard a case
that happens once per account and never for most accounts. The cost is
paid by every user forever; the benefit accrues during a few seconds
of one user's life.

The completion definition above handles it instead, at zero standing
cost.

## The job document

`deletionJobs/{jobId}`, top level, denied to all clients in
`firestore.rules`, with tests proved wired by flipping the rule.

```
{
  jobId,                  // hash of the uid, see the open question
  uid,                    // present while running, removed at close
  requestedAt, updatedAt,
  pending: true,          // false once closed, see the query below
  passes: 0,              // cascade passes run so far
  lastPassDeleted: 0,     // documents the last pass touched
  steps: {
    revoke:     "pending" | "done",
    authDelete: "pending" | "done"
  },
  lastError: string | null,
  expiresAt: Timestamp
}
```

`steps` only tracks the two operations that are not part of the
repeating cascade. The cascade needs no per-step cursor because each
of its seven operations is already idempotent: deleting an absent
document is a no-op, and the comment anonymisation writes fixed values
and then no longer matches its own query. **That is a property of
today's code and must be asserted by a test rather than assumed**,
because the next person adding a step to the cascade will not know it
was load bearing.

## The loop

| # | Step | Repeats | Idempotent because |
|---|---|---|---|
| 1 | `revokeRefreshTokens`, mark `revoke: done` | no | revoking twice equals revoking once |
| 2 | One cascade pass, record `lastPassDeleted` | **yes** | absent documents delete as no-ops |
| 3 | When a pass reports 0: `deleteUser(uid)` | no | `auth/user-not-found` is success |
| 4 | One more cascade pass after the auth record is gone | **yes** | as step 2 |
| 5 | When that pass also reports 0: `pending = false`, drop `uid` | no | terminal |

Closure requires a clean pass **after** the auth record is gone. That
is Andrew's definition applied twice, and it is deliberate: it removes
any dependence on a claim about how long a token outlives the account
it names. If tokens die instantly, step 4 is a cheap no-op. If they do
not, step 4 keeps sweeping until they do. The design does not need to
know which, and neither does the reader.

Step 3 treating `auth/user-not-found` as success is what lets the
`onUserDeleted` path share this code: arriving from the console, the
auth record is already gone before step 1.

**A bound, so a pathological client cannot keep a job open forever.**
If `passes` exceeds 12, roughly three hours at the cadence below, log
`[deletion] ANOMALY: job still finding data after N passes` and keep
going. It does not stop, because stopping would leave data; it becomes
visible, because a job that never closes is a fact somebody should
learn from a log rather than from a bill.

## The backstop

Every 15 minutes:

```
deletionJobs.where("pending", "==", true)
            .where("updatedAt", "<", now - 15 minutes)
            .limit(20)
```

Two details decide whether this works.

**`pending` is a boolean, not a status string.** Firestore allows a
range filter on only one field per query, so `status != "done"`
alongside `updatedAt <` is not expressible. A boolean equality plus
one inequality is.

**It needs a composite index** on `(pending, updatedAt)` in
`firestore.indexes.json`, deployed. Without it the query fails at run
time, inside the backstop, which is the one place nobody is watching.
The index is part of this change, not a follow-up.

It scans jobs, never user data, so it stays cheap as the app grows: at
launch volume the query returns nothing and costs one read.

## What the user sees, which the definition settles

The 2026-08-17 draft recommended running the whole job inline and
returning when it was done. **That is no longer possible**, and the
completion definition is what makes it impossible: a job closes only
after a pass that finds nothing, and the earliest that can happen is
one resume cycle later.

So: the callable runs step 1 and one cascade pass inline, clears local
data, signs the user out, and returns. From the user's side the
account is gone at that moment, which is true in every sense they can
observe: they are signed out, their data is deleted, and their auth
record follows within the hour. No new "deletion in progress" UI state
is needed, because the user is not signed in to see it.

## What I would not build

- **No sweep over user data.** The backstop scans jobs only. A sweeper
  that walks users looking for orphans gets expensive exactly when the
  app succeeds.
- **No client-side retry as the guarantee.** The client may retry, but
  the guarantee has to survive the app being deleted from the phone,
  which is a normal thing to do straight after deleting an account.

## One thing that already works, and is not reopened

A user who deletes their account while subscribed leaves a live
RevenueCat subscriber, so a later webhook will try to set a claim for
a uid that no longer exists. `handleWebhookEvent` already treats
`auth/user-not-found` as a skip and acknowledges, so RevenueCat does
not retry forever. Nothing to do; recorded so the next reader does not
have to work it out.

## Tests, before any of it is called done

- A pass that deletes something reports a non-zero count; the pass
  after it reports zero. This is the test the whole design rests on.
- Interrupted after revoke, after a cascade pass, and after
  `deleteUser`: the job resumes and reaches closure.
- Data written **between** a clean pass and the auth deletion is found
  by the pass in step 4, and the job does not close until it is gone.
- Running the whole job twice end to end leaves the same state.
- The backstop picks up a job stale by 15 minutes, ignores a fresh one
  and ignores a closed one.
- `auth_time` older than five minutes is refused, with the
  distinguishable code.
- `deletionJobs` denied to clients, proved wired by flipping the rule.
- The backstop query runs against the emulator, so a missing composite
  index fails a test rather than production.

## The one open question

**Retain the job document, and under what identifier?**

The brief said clear it. The counter-argument is that a deletion with
no record is the state finding 6 is about: if something goes wrong
afterwards there is nothing to look at. But the document is keyed by
the uid of a user who asked to be erased, so retaining it retains an
identifier.

**Recommendation: key it by a hash of the uid, keep the plain uid as a
field only while the job is running, and drop that field at closure,
leaving a 30 day TTL record that holds timestamps, pass counts and no
identifier.** The TTL mechanism is proven in this project as of
2026-08-17. A second deletion request for the same account hashes to
the same job, so idempotency survives.

## What changed from the 2026-08-17 draft

- Completion is now "a pass found nothing", not "the cascade ran".
  This replaces the earlier single extra sweep pass, and it is
  stronger: the sweep was one attempt at absorbing the token window,
  the loop absorbs it however long it takes.
- The scheduled resume is stated as part of correctness rather than as
  a safety net.
- `deleteUserData` must return counts. This is new, and it is the
  concrete code change the definition forces.
- The freshness window is settled at five minutes with a
  distinguishable error code.
- The rules-flag approach to revocation is recorded as rejected, with
  the reason, so it is not rediscovered.
- "Does the user wait" is no longer an open question. The definition
  answers it.
- Two of the three open questions are closed. The remaining one is the
  job document's identifier and retention.
