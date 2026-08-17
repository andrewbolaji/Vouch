# Finding 6: resumable account deletion, for approval

2026-08-17. Design only. Nothing built, per the standing rule that a
plan is agreed before non-trivial code.

Andrew's shape is taken as given and is right: the job document as the
mechanism, a scheduled resume as the backstop, its own top-level
collection keyed by uid, deleted last, every step idempotent. What
follows is what that shape forces once it meets the code that exists,
plus three questions only he can settle.

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

Nothing records which of the seven finished. It runs inside
`onUserDeleted`, a Gen1 auth trigger, and the auth user is **already
gone** by the time it starts, so an interruption at step 4 leaves
three collections cleaned, four not, no auth record, and nothing
anywhere that knows. The user has been told the account was deleted.

Step 6 is also the expensive one: `collectionGroup("votes").get()`
reads every vote document in the database to find the ones whose id
matches the uid. Today that is thousands of reads at most. It is the
step most likely to time out first as the app grows, which makes it
the most likely place for the partial state to happen.

## What Andrew's ordering forces, and it is the biggest thing here

The specified order is: revoke sessions and mark deleting, cascade,
delete the auth user, clear the job. **Auth deletion moves from first
to last.** That is correct, and it means `onUserDeleted` can no longer
be the driver, because it only fires after the thing that now has to
happen at the end.

So the entry point changes. A callable, `requestAccountDeletion`,
creates the job and runs it. That has one consequence worth naming:

**Re-authentication moves too.** `FirebaseAuth.delete()` is what
raises `requires-recent-login` today, and `auth_service.dart` maps it
to a re-auth dialog with a one-attempt retry (`DECISIONS.md`,
2026-06-09). A callable gets no such error for free, so it must check
`request.auth.token.auth_time` itself and refuse anything older than,
say, five minutes with `failed-precondition`. The client's existing
re-auth flow stays exactly as it is; only the error it keys on
changes. If that check is forgotten, account deletion becomes
available to anyone holding a stolen unexpired token, so it is not
optional and it needs its own test.

**`onUserDeleted` stays**, for a deletion performed from the Firebase
console or by any path that is not the app. It becomes: create a job
if one does not exist, then run it. Both entry points converge on the
same job document and the same idempotent steps, which is what stops
them fighting.

## Session revocation is weaker than it sounds

`revokeRefreshTokens(uid)` invalidates refresh tokens. **An ID token
already in the client's hands stays valid until it expires, up to an
hour**, and `firestore.rules` cannot see revocation at all. So there
is a window in which a client can still write, and a late write can
recreate a document the cascade has just deleted, or fire a trigger
that recreates an aggregate.

Two ways to close it:

1. **Rules read a flag.** Every write path adds a `get()` on a small
   per-uid document. That is a real read cost on every vote and
   comment for every user forever, to protect a window that occurs
   only during deletion. Rejected on cost.
2. **Cascade once more after the auth user is gone.** Once the auth
   record is deleted, no new token can be minted and every existing
   one is refused by Firestore. A second cascade pass at that point is
   almost always a no-op, costs one extra pass at deletion time only,
   and needs no rules change and no per-write cost.

**Recommendation: 2.** The job then has four steps, not three, and the
last one exists specifically to sweep whatever landed during the
window. It is worth writing that reason into the code, or the pass
looks redundant and somebody deletes it.

## The job document

`deletionJobs/{uid}`, top level, denied to all clients in
`firestore.rules` (with tests, proved wired by flipping the rule).
Keyed by uid so a second request for the same account is the same job
rather than a race.

```
{
  uid, requestedAt, updatedAt,
  pending: true,          // false once finished, see the query below
  attempts: 0,
  steps: {
    revoke:      "pending" | "done",
    cascade:     "pending" | "done",
    authDelete:  "pending" | "done",
    sweep:       "pending" | "done"
  },
  lastError: string | null,
  expiresAt: Timestamp    // see question 1
}
```

Each step reads its own status and skips if `done`, which is what
makes replay safe. Every one of the seven cascade operations is
already idempotent (deleting an absent document is a no-op, and the
comment anonymisation writes fixed values), so `cascade` can be
re-entered without a cursor. That is a property of today's code and
should be asserted by a test rather than assumed, because the next
person adding a step to the cascade will not know it was load bearing.

## The backstop

A scheduled function every 15 minutes:

```
deletionJobs.where("pending", "==", true)
            .where("updatedAt", "<", now - 15 minutes)
            .limit(20)
```

Two details that decide whether this works.

**`pending` is a boolean, not a status string.** Firestore allows
range filters on only one field per query, so `status != "done"`
alongside `updatedAt <` is not expressible. A boolean equality plus
one inequality is.

**It needs a composite index** on `(pending, updatedAt)` added to
`firestore.indexes.json` and deployed. Without it the query fails at
run time, in the backstop, which is the one place nobody is watching.
That index is part of the change, not a follow-up.

It scans jobs, never user data, so it stays cheap forever: at launch
volume the query returns nothing and costs one read.

## Order of operations

| # | Step | Idempotent because |
|---|---|---|
| 1 | `revokeRefreshTokens`, write job with `steps.revoke = done` | Revoking twice is the same as once |
| 2 | Run the seven-operation cascade | Deletes of absent documents are no-ops |
| 3 | `deleteUser(uid)` | `auth/user-not-found` is success, not failure |
| 4 | Cascade once more, the window sweep | Same as 2 |
| 5 | `pending = false`, `steps.* = done` | Terminal |

Step 3 treating `user-not-found` as success is what lets the
`onUserDeleted` path share this code: arriving from the console, the
auth record is already gone before step 1.

## What I would not build

- **No sweep over user data.** The backstop scans jobs only. A sweeper
  that walks users looking for orphans is the version of this that
  gets expensive precisely when the app succeeds.
- **No client-side retry as the guarantee.** The client may retry, but
  the guarantee has to survive the client being uninstalled, which is
  a normal thing to do immediately after deleting an account.

## One thing that already works, and is not reopened

A user who deletes their account while subscribed leaves a live
RevenueCat subscriber, so a later webhook will try to set a claim for
a uid that no longer exists. `handleWebhookEvent` already treats
`auth/user-not-found` as a skip and acknowledges, so RevenueCat does
not retry forever. Nothing to do; recorded so the next reader does not
have to work it out.

## Tests, before any of it is called done

- Interrupted at **each** of the four steps: the job resumes at the
  step that did not finish, and does not repeat one that did.
- Running the whole job twice end to end leaves the same state.
- The backstop picks up a job stale by 15 minutes and finishes it.
- The backstop ignores a job that is not stale, and one that is done.
- `auth_time` older than the window is refused.
- `deletionJobs` denied to clients, proved wired by flipping the rule.
- The composite index exists, which in practice means running the
  backstop query against the emulator so a missing index fails a test
  rather than production.

## Three questions for Andrew

**1. Keep the job document or delete it?** The brief says clear it.
The counter-argument is that a deletion with no record is exactly the
state finding 6 is about: if something goes wrong afterwards there is
nothing to look at. The middle option is `expiresAt` with a 30 day
TTL, which now works in this project and was verified ACTIVE today.
The tension is real though: the document is keyed by the uid of a user
who asked to be erased, so retaining it for 30 days retains an
identifier. Options are delete immediately, keep 30 days, or keep 30
days keyed by a hash of the uid instead. **My recommendation: keep 30
days, keyed by the hash.** It is auditable and holds nothing that
points back at a person.

**2. Five minutes for the `auth_time` freshness window?** Apple's
guideline cares that deletion is reachable, not about the window.
Shorter is safer and more re-auth prompts; five is the usual choice.

**3. Does the user wait?** The callable can run the whole job inline
and return when it is done, which is honest but can take seconds, or
it can create the job, kick off step 1, and return immediately with
the client showing "deletion in progress". The second is what makes
the backstop meaningful. It also means the app must handle being
signed in to an account that is mid-deletion, which is a UI state that
does not exist today. **My recommendation: run inline, with the
backstop as the safety net rather than the normal path.** At current
data volumes the whole cascade is well under a second, and inventing a
new UI state to solve a latency problem nobody has yet is the more
expensive mistake.
