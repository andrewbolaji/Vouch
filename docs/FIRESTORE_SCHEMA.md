# Vouch -- Firestore Schema Design

**Status:** Design doc. No code. Requires review and
approval before `flutterfire configure`.

---

## Region

**`us-central1`**

Chosen for lowest latency to the initial launch
markets (Houston, NYC, LA, Chicago -- all US).
Firestore region cannot be changed after project
creation without a full data migration to a new
project. Multi-region (`nam5`) was considered but
adds cost with no benefit until international
expansion.

---

## Collections and documents

### `cities`

```
/cities/{cityId}
{
  id: string              // "houston", "nyc", etc.
  name: string            // "Houston"
  state: string           // "TX"
  imageUrl: string        // Unsplash CDN URL
  description: string     // Short editorial blurb
  restaurantCount: number // Denormalized count
  createdAt: timestamp
  updatedAt: timestamp
}
```

**Document IDs:** Slug-based (`houston`, `nyc`, `la`,
`chicago`). Human-readable in URLs for deep links.

### `restaurants`

```
/restaurants/{restaurantId}
{
  id: string              // "hou-1"
  cityId: string          // FK to cities
  name: string
  cuisine: string
  imageUrl: string
  description: string
  rank: number
  voteCount: number       // Denormalized aggregate
  priceLevel: number      // 1-4
  locations: array<{
    name: string,
    address: string,
    latitude: number,
    longitude: number
  }>
  vibeTags: array<string>

  // Insider-gated fields (see Membership-gated reads)
  insiderTip: string | null
  whatToOrder: string | null

  createdAt: timestamp
  updatedAt: timestamp
}
```

**Document IDs:** `{citySlug}-{rank}` (e.g., `hou-1`).
Stable, predictable, deep-linkable.

### `users`

```
/users/{uid}
{
  uid: string             // Firebase Auth UID
  displayName: string
  email: string
  photoUrl: string | null
  membershipTier: string  // "free" | "localsPass" | "cityInsider"
  savedRestaurantIds: array<string>  // See decision below
  createdAt: timestamp
  lastActiveAt: timestamp
}
```

### `comments` (subcollection of restaurants)

```
/restaurants/{restaurantId}/comments/{commentId}
{
  id: string              // Auto-generated
  userId: string          // FK to users
  userName: string        // Denormalized for read perf
  text: string
  parentId: string | null // For threading
  isInsider: boolean      // Denormalized from user tier
  createdAt: timestamp
}
```

### `votes` (subcollection of restaurants)

```
/restaurants/{restaurantId}/votes/{odoc userId}
{
  odoc userId: string        // Document ID = user UID
  createdAt: timestamp
}
```

**Document ID is the user's UID.** This enforces
one-vote-per-user at the document level -- a second
write from the same user overwrites, not duplicates.
The `voteCount` on the restaurant doc is maintained
by a Cloud Function trigger on this subcollection.

### `suggestions`

```
/suggestions/{suggestionId}
{
  id: string
  userId: string
  type: string            // "newRestaurant" | "correction" | "newCity" | "general"
  text: string
  cityId: string | null
  createdAt: timestamp
  status: string          // "pending" | "reviewed" | "accepted" | "rejected"
}
```

### `suggestionCounts` (subcollection of users)

```
/users/{uid}/suggestionCounts/{dateKey}
{
  count: number           // Incremented per submission
  date: string            // "2026-05-01" (UTC)
}
```

Used for server-side rate limiting. See Write patterns
section.

---

## Denormalization choices

| Field | Source of truth | Denormalized to | Read pattern justifying it | Write pattern keeping sync | Staleness acceptable? |
|---|---|---|---|---|---|
| `restaurant.voteCount` | Count of docs in `/restaurants/{id}/votes/` | `restaurant.voteCount` | "Top 10 sorted by votes" -- every city page load reads this. Reading + counting the votes subcollection per restaurant per page load would be 10 subcollection queries. | Cloud Function `onWrite` trigger on votes subcollection updates the count. | Yes -- a few seconds of staleness is fine for a leaderboard. |
| `comment.userName` | `users/{uid}.displayName` | `comment.userName` | Every comment render needs the author name. Joining to users per comment is N reads per page. | Cloud Function on `users/{uid}` update propagates name changes to all comments by that user. Rare operation (name changes). | Yes -- stale name until next batch update is acceptable. |
| `comment.isInsider` | `users/{uid}.membershipTier` | `comment.isInsider` | Insider badge display on every comment. Same join problem as userName. | Cloud Function on membership tier change updates all comments by that user. | Yes -- upgrading/downgrading is rare; a few minutes of stale badge is fine. |
| `cities.restaurantCount` | Count of restaurants with `cityId == X` | `cities.restaurantCount` | Home screen shows count. Counting restaurants per city per load is wasteful. | Cloud Function on restaurant add/remove. | Yes. |

---

## Subcollection vs array decisions

### `user.savedRestaurantIds`: Array on user doc

**Decision:** Array field, not subcollection.

**Reasoning:** The read pattern is "get all saved IDs
for user X" -- a single doc read. A subcollection
would require a query. The array will not exceed
Firestore's 1MB doc limit even at 1000 saved
restaurants (each ID is ~10 bytes). The write pattern
is atomic array add/remove (`arrayUnion`/`arrayRemove`),
which is a single write operation. A subcollection
would require a separate write per save/unsave.

### `restaurant.comments`: Subcollection

**Decision:** Subcollection at
`/restaurants/{id}/comments/`.

**Reasoning:** Comments can grow unbounded. An array
on the restaurant doc would hit the 1MB limit. The
read pattern is paginated (see below), which requires
a query with `orderBy` and `limit` -- only possible
on a subcollection. The write pattern is a single
doc add per comment.

### `restaurant.votes`: Subcollection

**Decision:** Subcollection at
`/restaurants/{id}/votes/` with doc ID = user UID.

**Reasoning:** Using the user UID as the document ID
enforces one-vote-per-user at the storage level --
no security rule needed to prevent duplicates, just
a `set()` call. The aggregate `voteCount` is
denormalized on the restaurant doc (see above).
The subcollection is never read directly by the
client in normal flow -- only the aggregate count
is displayed. The subcollection exists for (a)
server-side vote integrity and (b) the "has user X
voted on restaurant Y" check, which is a single
doc `get()` by path.

---

## Three highest-frequency read paths

### 1. Top 10 restaurants for city X, sorted by votes

```
db.collection('restaurants')
  .where('cityId', '==', cityId)
  .orderBy('rank', 'asc')
  .limit(10)
```

**Index required:**
```
Collection: restaurants
Fields: cityId ASC, rank ASC
```

**Read cost:** 1 query + 10 document reads = 11 reads.
At 4 cities and ~100 DAU, this is ~4,400 reads/day.
Well within free tier (50K/day).

**Note:** Sorting by `rank` (editorially curated)
rather than `voteCount` (dynamic). Rank is updated
periodically by an admin process, not on every vote.
This avoids index churn and hot-path writes.

### 2. User's saved restaurant IDs

```
db.collection('users').doc(uid).get()
// Access savedRestaurantIds array from the doc
```

**Read cost:** 1 document read. No query, no index.

**Why single doc:** The array-on-doc decision (above)
means this is always a single read. The client
fetches the full user doc on login and caches it.
Subsequent reads are from the Provider's in-memory
state, synced by a Firestore snapshot listener on
the user doc.

### 3. Paginated comments for restaurant X

```
db.collection('restaurants')
  .doc(restaurantId)
  .collection('comments')
  .where('parentId', '==', null)  // Top-level only
  .orderBy('createdAt', 'desc')
  .limit(20)
  .startAfter(lastDoc)           // Cursor pagination
```

**Index required:**
```
Collection: restaurants/{id}/comments
Fields: parentId ASC, createdAt DESC
```

**Page size:** 20 comments. Cursor-based pagination
using `startAfter` with the last document snapshot.
No offset-based pagination (Firestore charges for
skipped docs).

**Replies:** Loaded separately per expanded comment:
```
.where('parentId', '==', commentId)
.orderBy('createdAt', 'asc')
```

**Read cost:** 1 query + up to 20 doc reads per page.
Replies are lazy-loaded only when the user expands
a comment thread.

---

## Membership-gated reads

### Approach: Custom claims on Firebase Auth token

**Decision:** Custom claim on the auth token, not a
field on the user doc or a separate entitlements
collection.

**Reasoning:**
- Security rules can read custom claims directly
  from `request.auth.token` without any additional
  Firestore reads. A user-doc-based check would add
  1 read per gated request.
- RevenueCat webhook -> Cloud Function sets the
  custom claim when a purchase is verified. The
  claim propagates on the next token refresh (~1hr
  max, or forced on app launch).
- Custom claims are limited to 1000 bytes, but
  membership tier is a single string -- well within
  limits.

**Claim shape:**
```json
{
  "membershipTier": "cityInsider"
}
```

**Security rule for insider-gated fields:**

The insider tips (`insiderTip`, `whatToOrder`) are
stored on the restaurant document. The security
rule restricts which fields are readable based on
the claim:

```javascript
match /restaurants/{restaurantId} {
  allow read: if isEntitled(request.auth);

  function isEntitled(auth) {
    // Free users: all fields except insider fields
    // This is enforced by returning a subset via
    // Cloud Function, NOT by field-level rules
    // (Firestore doesn't support field-level read
    // restrictions).
    return true;
  }
}
```

**Important limitation:** Firestore security rules
cannot restrict individual fields within a document.
A `get()` on a restaurant doc returns ALL fields,
including `insiderTip`. **This means server-side
gating of insider content requires a Cloud Function
API endpoint** that reads the doc and strips insider
fields for non-entitled users, rather than direct
Firestore reads from the client.

**Alternatives considered:**
1. **Separate `insiderNotes` subcollection** --
   would allow subcollection-level rules, but adds
   complexity and an extra read per restaurant view
   for entitled users.
2. **Cloud Function proxy** -- adds latency but
   gives full control over field filtering. This is
   the recommended approach for v1.

**Recommendation:** Use a Cloud Function
(`getRestaurant`) that checks the custom claim and
strips `insiderTip`/`whatToOrder` for free/localsPass
users. Direct Firestore reads for non-gated data
(cities, restaurant list without insider fields).

For Top 6-10 gating: the `rank` field is public.
The security rule limits the query to `rank <= 5`
for free users:

```javascript
match /restaurants/{restaurantId} {
  allow read: if request.auth != null
    && (resource.data.rank <= 5
        || request.auth.token.membershipTier
           in ['localsPass', 'cityInsider']);
}
```

This is enforceable because the client query includes
a `rank` filter, and Firestore validates that the
query results match the rule.

---

## Indexes

| Collection | Fields | Type |
|---|---|---|
| `restaurants` | `cityId` ASC, `rank` ASC | Composite |
| `restaurants/{id}/comments` | `parentId` ASC, `createdAt` DESC | Composite |
| `restaurants/{id}/comments` | `parentId` ASC, `createdAt` ASC | Composite (for replies) |

All single-field indexes are created automatically
by Firestore. Only composite indexes need explicit
declaration in `firestore.indexes.json`.

---

## Write patterns and rate limits

### Suggestion rate limiting: Counter doc + transaction

**Decision:** Counter doc + transaction, not Cloud
Function gate.

**Reasoning:** A Cloud Function gate adds ~200ms
latency per submission and requires an HTTP call
instead of a direct Firestore write. The counter
doc approach uses a Firestore transaction that
atomically reads the count and writes the suggestion
only if under the cap. This is faster and uses
standard Firestore operations.

**Flow:**
1. Client calls a transaction:
   ```
   transaction {
     countDoc = get /users/{uid}/suggestionCounts/{todayUTC}
     if countDoc.count >= 3: abort
     set /suggestions/{newId} { ... }
     set /users/{uid}/suggestionCounts/{todayUTC}
         { count: increment(1) }
   }
   ```
2. Security rule enforces that only the
   authenticated user can write to their own
   `suggestionCounts` subcollection.
3. The transaction ensures atomicity -- no race
   condition between checking and incrementing.

**Security rule:**
```javascript
match /users/{uid}/suggestionCounts/{dateKey} {
  allow read, write: if request.auth.uid == uid;
}

match /suggestions/{suggestionId} {
  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.text.size() <= 500;
}
```

### Vote write pattern

```
db.collection('restaurants')
  .doc(restaurantId)
  .collection('votes')
  .doc(userId)
  .set({ createdAt: serverTimestamp() })
```

One-vote-per-user enforced by document ID = user UID.
Toggle (un-vote) is a `delete()` on the same path.
Cloud Function `onWrite` trigger on the votes
subcollection updates `restaurant.voteCount`.

### Comment write pattern

```
db.collection('restaurants')
  .doc(restaurantId)
  .collection('comments')
  .add({
    userId: auth.uid,
    userName: user.displayName,  // Read from user doc
    text: text,
    parentId: parentId,
    isInsider: user.membershipTier == 'cityInsider',
    createdAt: serverTimestamp()
  })
```

**Security rule:**
```javascript
match /restaurants/{restaurantId}/comments/{commentId} {
  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.text.size() > 0
    && request.resource.data.text.size() <= 500;
  allow delete: if request.auth.uid
    == resource.data.userId;
}
```

---

## Cost model -- estimated reads/writes per active user per day

**Pricing date stamp:** May 2026. Firestore pricing
(us-central1, pay-as-you-go Blaze plan):
- Document reads: $0.06 per 100K
- Document writes: $0.18 per 100K
- Document deletes: $0.02 per 100K
- Free tier: 50K reads + 20K writes + 20K deletes
  per day, project-wide.
- Cloud Functions: 2M invocations/month free, then
  $0.40 per million. 400K GB-seconds free compute.

### Per-user action costs

**1. Cold app open (first launch of the day)**

| Operation | Reads | Writes |
|---|---|---|
| Fetch user doc | 1 | 0 |
| Fetch cities (4 docs) | 1 query + 4 docs = 5 | 0 |
| Update `lastActiveAt` on user doc | 0 | 1 |
| **Subtotal** | **6** | **1** |

**2. Browse a city + view one restaurant detail**

| Operation | Reads | Writes |
|---|---|---|
| Top 10 query (or Top 5 for free) | 1 query + 5-10 docs = 6-11 | 0 |
| Cloud Function: getRestaurant (insider field stripping) | 1 CF invocation (reads 1 doc internally) | 0 |
| Check if user voted (single doc get by path) | 1 | 0 |
| Load first page of comments (20) | 1 query + 20 docs = 21 | 0 |
| **Subtotal** | **29-34** | **0** |

**3. Cast a vote**

| Operation | Reads | Writes |
|---|---|---|
| Write vote doc (set by user UID) | 0 | 1 |
| Cloud Function trigger: read votes subcollection count, update restaurant.voteCount | ~1 read + 1 write (CF internal) | 0 client-side |
| **Subtotal** | **0 client** | **1 client** |
| **CF cost** | **1 read + 1 write** | |

**4. Save / unsave a restaurant**

| Operation | Reads | Writes |
|---|---|---|
| Update user doc (arrayUnion/arrayRemove) | 0 | 1 |
| **Subtotal** | **0** | **1** |

**5. Submit a comment**

| Operation | Reads | Writes |
|---|---|---|
| Write comment doc | 0 | 1 |
| **Subtotal** | **0** | **1** |

**6. Submit a suggestion**

| Operation | Reads | Writes |
|---|---|---|
| Transaction: read suggestionCount doc | 1 | 0 |
| Transaction: write suggestion + increment count | 0 | 2 |
| **Subtotal** | **1** | **2** |

### Typical session estimate

An average user session: 1 cold open + browses 2
cities + views 3 restaurant details + casts 1 vote +
saves 1 restaurant.

| | Reads | Writes |
|---|---|---|
| Cold open | 6 | 1 |
| Browse 2 cities (Top 10 each) | 22 | 0 |
| View 3 restaurant details | 69 | 0 |
| Cast 1 vote | 0 | 1 |
| Save 1 restaurant | 0 | 1 |
| **Total per session** | **~97** | **~3** |

Assuming 1.5 sessions per active user per day:
**~145 reads, ~5 writes per DAU per day.**

### Scale projections against free tier

| DAU | Daily reads | Daily writes | CF invocations/day | Free tier? |
|---|---|---|---|---|
| 100 | 14,500 | 500 | ~100 | Yes (29% of 50K read limit) |
| 500 | 72,500 | 2,500 | ~500 | **No** -- crosses 50K read limit |
| 1,000 | 145,000 | 5,000 | ~1,000 | No |
| 10,000 | 1,450,000 | 50,000 | ~10,000 | No |

**Free tier inflection: ~345 DAU.** At that point
reads cross 50K/day.

### Cost past free tier

| DAU | Monthly reads | Monthly writes | Read cost | Write cost | CF cost | **Total/month** |
|---|---|---|---|---|---|---|
| 500 | 2.2M | 75K | $1.32 | $0.14 | ~$0 (free tier) | **~$1.46** |
| 1,000 | 4.4M | 150K | $2.64 | $0.27 | ~$0 | **~$2.91** |
| 5,000 | 21.8M | 750K | $13.05 | $1.35 | ~$0 | **~$14.40** |
| 10,000 | 43.5M | 1.5M | $26.10 | $2.70 | $0.12 | **~$28.92** |

### Cost drivers ranked

1. **Document reads dominate.** Comments pagination
   (21 reads per restaurant view) is the largest
   single cost driver. If users view 3 restaurants
   per session, that's 63 reads just on comments.

2. **Cloud Function invocations are negligible.**
   Vote aggregation triggers fire once per vote, not
   per read. At 10K DAU with ~10K votes/day, that's
   300K invocations/month -- well within the 2M free
   tier.

3. **Writes are cheap.** Even at 10K DAU, write cost
   is under $3/month. The schema's denormalization
   strategy (read-heavy, write-light) is working as
   designed.

### Cost optimization levers (if needed)

- **Cache cities locally.** Cities change rarely.
  A 24-hour local cache eliminates 5 reads per cold
  open. At 10K DAU, saves ~1.5M reads/month ($0.90).
- **Reduce comment page size.** 20 -> 10 per page
  cuts comment reads nearly in half per restaurant
  view.
- **Snapshot listeners instead of cold reads.** A
  real-time listener on the cities collection is 1
  read on connect + incremental updates, not 5 reads
  per cold open.

---

## Open questions

These require product decisions before the schema
is final:

1. **All-time vs windowed vote counts.** Current
   design uses all-time `voteCount`. Should we also
   track weekly/monthly windows for trending? This
   would require a `votesThisWeek` field and a
   scheduled Cloud Function to reset it.

2. **Comment editing.** Current schema supports
   create and delete only. Should users be able to
   edit comments? If yes, add `updatedAt` field and
   an `allow update` rule restricted to the author
   within a time window (e.g., 15 minutes).

3. **Restaurant images.** Currently Unsplash URLs.
   Should we support user-uploaded photos? If yes,
   add a `photos` subcollection with Firebase Storage
   references and moderation status.

4. **City expansion workflow.** When a new city
   launches, who seeds the initial 10 restaurants?
   Admin-only writes via a Cloud Function, or a
   Firestore admin SDK script?

5. **Vote weight.** City Insider tier has "3x vote
   weight" in the membership copy. Is this actually
   desired? If yes, the Cloud Function that
   aggregates `voteCount` needs to read the voter's
   tier and weight accordingly. This adds complexity
   and makes the count non-obvious to users.

---

## Security adversarial review

*"You are a security auditor reviewing this schema
before launch. What's exploitable through reads or
writes?"*

| Finding | Severity | Mitigation |
|---|---|---|
| `insiderTip`/`whatToOrder` on restaurant doc readable by any authenticated user (Firestore has no field-level read rules) | High | Cloud Function proxy strips insider fields for non-entitled users. Direct client reads blocked by security rule requiring `rank <= 5` for free users (prevents reading Top 6-10 docs). Insider fields on Top 1-5 docs still leak -- Cloud Function is the only complete fix. |
| Predictable document IDs (`hou-1`, `houston`) enable enumeration of all restaurants/cities | Low | Acceptable. Restaurant/city data is not secret. The IDs are designed for deep links. |
| `userName` on comment is client-supplied, could be spoofed | Medium | Security rule should validate `request.resource.data.userName == get(/users/$(request.auth.uid)).data.displayName`. Adds 1 read per comment write but prevents impersonation. |
| User could write arbitrary `isInsider: true` on comments | High | Security rule must validate `request.resource.data.isInsider == (request.auth.token.membershipTier == 'cityInsider')`. Custom claim is server-set and not spoofable. |
| `suggestionCounts` date key is client-supplied, could be backdated to bypass cap | Medium | Security rule should validate that `dateKey` matches the current UTC date: `dateKey == string(request.time.toMillis() / 86400000)` or similar server-timestamp validation. |
| No rate limit on comment writes | Low | Add a Cloud Function rate limiter or per-user daily comment cap if spam becomes an issue. Not needed at launch scale. |
