/**
 * Waitlist signup limits. Finding 15.
 *
 * `waitlistSignup` is a public, unauthenticated write path, and App
 * Check can never be enforced on it: its caller is the marketing
 * site's plain browser fetch, which has no attestation token to
 * present. So these limits are the only thing standing between a
 * script and the Firestore bill on a pre-launch project nobody is
 * watching the bill on.
 *
 * What was already strong, and is not re-litigated here:
 * deduplication is structural. The document id IS the normalised
 * email, so a repeated address is one row permanently and the obvious
 * flood attack does nothing. What was missing was a bound on unique
 * addresses and a bound on how large one row could be made.
 *
 * The write cost is one time. The storage cost is recurring, and the
 * recurring one is the actual damage.
 */

import {Timestamp} from "firebase-admin/firestore";

/**
 * Longest `city` or `source` string accepted.
 *
 * These two were written essentially unvalidated (`city?.trim() ||
 * null`, `source || "landing"`), and Firestore's document limit is
 * about 1 MiB, so one row could be inflated toward a megabyte and
 * then sit there costing storage every month.
 *
 * 100 rather than something tighter because the longest real answer
 * is nowhere near it: "Winston-Salem, North Carolina" is 29
 * characters. Anything past 100 is not a city, it is a payload.
 *
 * If you are here to widen this, the question to answer first is what
 * legitimate value did not fit, because that is the only reason it
 * should move.
 */
export const MAX_WAITLIST_FIELD_CHARS = 100;

/**
 * Longest email accepted, and the reason it needs its own limit.
 *
 * `EMAIL_RE` is `^[^\s@]+@[^\s@]+\.[^\s@]+$`, and "not a space and
 * not an at sign" happily matches a megabyte. The address also
 * becomes the document id, and Firestore caps ids at 1500 bytes, so
 * without this the failure mode was not a rejection but an exception
 * caught by the handler's catch and returned as a 500.
 *
 * 254 is the RFC 5321 limit on a forward path, so nothing legitimate
 * is being turned away.
 */
export const MAX_EMAIL_CHARS = 254;

/**
 * Signups accepted from one IP in one UTC day.
 *
 * Set on the shape of the damage rather than on a feel for traffic.
 * The residual exposure after the field caps is unique addresses, and
 * each costs a read, a write and a permanent row, so what matters is
 * how many rows one source can create per day, not how fast.
 *
 * 20 rather than something tighter because the cost of being wrong is
 * asymmetric and points the other way. Carrier-grade NAT puts many
 * real people behind one address, and a pre-launch waitlist that
 * silently refuses a genuine signup has lost the only thing it
 * exists to collect. 20 rows a day from one address is a rounding
 * error on the bill; a blocked signup is not recoverable.
 *
 * Every rejection is logged, so if real people are hitting this the
 * evidence exists rather than having to be inferred from silence.
 */
export const MAX_SIGNUPS_PER_IP_PER_DAY = 20;

/**
 * How long an IP counter document lives.
 *
 * The counters are themselves storage that grows with unique IPs, so
 * a fix for unbounded storage that leaves unbounded storage behind it
 * would not be a fix. Two days rather than one so that a counter is
 * never deleted while the UTC day it belongs to is still being
 * written to.
 *
 * This field does nothing on its own. A Firestore TTL policy has to
 * be configured once against this collection, and until it is, the
 * documents accumulate. The command is in docs/DECISIONS.md.
 */
export const IP_COUNTER_TTL_DAYS = 2;

/** Collection holding the per IP, per day signup counters. */
export const IP_COUNTS_COLLECTION = "waitlistIpCounts";

/** Why a signup was refused, or "ok". Returned to the caller. */
export type SignupCheck =
  | {ok: true; email: string; city: string | null; source: string}
  | {ok: false; error: "invalid_email" | "email_too_long" | "field_too_long"};

/**
 * Validates and normalises the request body.
 *
 * Rejects rather than truncates. A truncated city is a wrong answer
 * stored as though it were a right one, and this is a field a human
 * typed: telling them it was refused is honest, silently keeping the
 * first 100 characters is not.
 *
 * @param {object} body The parsed request body.
 * @param {RegExp} emailRe The email pattern the handler already uses.
 * @return {SignupCheck} The normalised values, or the refusal reason.
 */
export function checkSignupInput(
  body: {email?: string; city?: string; source?: string},
  emailRe: RegExp
): SignupCheck {
  const email = body.email;
  if (!email || !emailRe.test(email.trim())) {
    return {ok: false, error: "invalid_email"};
  }

  const normalized = email.trim().toLowerCase();
  // Checked after the format test so that a long value that is not
  // an address at all still reads as invalid_email, which is the
  // truer answer and the one the site already knows how to show.
  if (normalized.length > MAX_EMAIL_CHARS) {
    return {ok: false, error: "email_too_long"};
  }

  const city = body.city?.trim() || null;
  const source = body.source || "landing";

  if (
    (city !== null && city.length > MAX_WAITLIST_FIELD_CHARS) ||
    source.length > MAX_WAITLIST_FIELD_CHARS
  ) {
    return {ok: false, error: "field_too_long"};
  }

  return {ok: true, email: normalized, city, source};
}

/**
 * The client IP for rate limiting, or null if there is not one.
 *
 * `x-forwarded-for` is set by Google's front end and its first entry
 * is the client. It is read before `req.ip` because behind Cloud Run
 * `req.ip` can be the proxy, and rate limiting every request under
 * one proxy address would be a global limit wearing a per IP costume.
 *
 * @param {object} req The request, or anything shaped like one.
 * @return {string|null} The client address, or null.
 */
export function clientIpFrom(req: {
  headers?: Record<string, string | string[] | undefined>;
  ip?: string;
}): string | null {
  const forwarded = req.headers?.["x-forwarded-for"];
  const raw = Array.isArray(forwarded) ? forwarded[0] : forwarded;
  const first = raw?.split(",")[0]?.trim();
  if (first) return first;
  return req.ip?.trim() || null;
}

/**
 * The UTC day a request belongs to, as `YYYY-MM-DD`.
 *
 * UTC and not local time, because the function has no local time: it
 * runs in us-central1 today and the counter must not shift if that
 * ever changes.
 *
 * @param {Date} now The reference time.
 * @return {string} The date key.
 */
export function dateKeyFor(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/**
 * The counter document id for one IP on one day.
 *
 * @param {string} dateKey From dateKeyFor.
 * @param {string} ip The client address.
 * @return {string} A Firestore-safe document id.
 */
export function ipCounterDocId(dateKey: string, ip: string): string {
  // Firestore document ids cannot contain "/". IPv6 addresses do not,
  // but a proxy putting something unexpected in the header would.
  return `${dateKey}_${ip}`.replace(/\//g, "__");
}

/**
 * Counts this attempt against the IP's daily allowance.
 *
 * In a transaction, because two concurrent requests that both read 19
 * would both write 20 and the limit would be advisory. Cheap here:
 * `maxInstances` is 10, so contention is bounded by construction.
 *
 * A null IP is counted under a single shared bucket rather than
 * waved through. That is deliberate and it is the trade-off worth
 * knowing about: if the platform ever stops providing a client
 * address, every caller shares one allowance and the endpoint
 * effectively closes. It fails toward protecting the bill rather than
 * toward an unbounded public write path, and it logs, so the failure
 * announces itself instead of arriving as an invoice.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string|null} ip The client address, or null if unknown.
 * @param {Date} now The reference time.
 * @return {Promise<object>} Whether it was allowed, and the new count.
 */
export async function recordSignupAttempt(
  db: FirebaseFirestore.Firestore,
  ip: string | null,
  now: Date
): Promise<{allowed: boolean; count: number}> {
  const dateKey = dateKeyFor(now);
  const key = ip ?? "unknown";
  const ref = db
    .collection(IP_COUNTS_COLLECTION)
    .doc(ipCounterDocId(dateKey, key));

  const expiresAt = Timestamp.fromDate(
    new Date(now.getTime() + IP_COUNTER_TTL_DAYS * 24 * 60 * 60 * 1000)
  );

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number) ?? 0;

    if (count >= MAX_SIGNUPS_PER_IP_PER_DAY) {
      return {allowed: false, count};
    }

    tx.set(ref, {
      ip: key,
      dateKey,
      count: count + 1,
      expiresAt,
    });
    return {allowed: true, count: count + 1};
  });
}
