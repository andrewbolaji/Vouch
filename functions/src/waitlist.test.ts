/**
 * Tests for waitlistSignup, finding 15.
 *
 * These call the deployed handler. That matters more here than
 * usual, because the tests that were already in index.test.ts under
 * "Waitlist signup logic" do not: they build their own document ids,
 * write their own documents and then assert that Firestore stored
 * what they wrote. Every one of them passes with the handler deleted.
 * They were checking that Firestore is Firestore.
 *
 * So the caps and the rate limit are asserted through
 * `waitlistSignup(req, res)` itself, with a fake request and a
 * recording response, which is the same shape submit_comment.test.ts
 * uses and for the same reason.
 *
 * In its own file, like submit_comment.test.ts, because importing
 * index.ts runs its module-scope initializeApp() and index.test.ts
 * already initializes its own app.
 */

import {getApps, deleteApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

// eslint-disable-next-line import/first
import {waitlistSignup} from "./index";
// eslint-disable-next-line import/first
import {
  checkSignupInput,
  clientIpFrom,
  dateKeyFor,
  ipCounterDocId,
  recordSignupAttempt,
  IP_COUNTS_COLLECTION,
  MAX_EMAIL_CHARS,
  MAX_SIGNUPS_PER_IP_PER_DAY,
  MAX_WAITLIST_FIELD_CHARS,
} from "./waitlist";

const db = getFirestore();

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

/**
 * Deletes every top-level document and everything under it.
 */
async function clearFirestore() {
  const collections = await db.listCollections();
  for (const col of collections) {
    const docs = await col.listDocuments();
    for (const d of docs) {
      await db.recursiveDelete(d);
    }
  }
}

type Body = {
  email?: string;
  city?: string;
  source?: string;
  website?: string;
};

/**
 * A request shaped like the one Cloud Run hands the handler.
 *
 * The address arrives in x-forwarded-for because that is where it
 * arrives in production. Sending it any other way would test a path
 * the deployment does not have.
 *
 * @param {Body} body The JSON body.
 * @param {object} opts Overrides for method and client address.
 * @return {object} The fake request.
 */
function reqFor(
  body: Body,
  opts: {ip?: string | null; method?: string} = {}
) {
  const headers: Record<string, string> = {
    "content-type": "application/json",
    "origin": "https://vouchfood.com",
  };
  if (opts.ip !== null) {
    headers["x-forwarded-for"] = `${opts.ip ?? "203.0.113.7"}, 10.0.0.1`;
  }
  return {
    method: opts.method ?? "POST",
    headers,
    body,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

/**
 * A response that records the status and payload it was given.
 *
 * @return {object} The response double and the recording it fills.
 */
function resSpy() {
  const out: {status: number | null; body: unknown} =
    {status: null, body: null};
  const headers: Record<string, unknown> = {};
  const res = {
    statusCode: 200,
    status(code: number) {
      out.status = code;
      res.statusCode = code;
      return res;
    },
    json(payload: unknown) {
      out.body = payload;
      return res;
    },
    send(payload: unknown) {
      out.body = payload;
      return res;
    },
    setHeader(name: string, value: unknown) {
      headers[name] = value;
      return res;
    },
    getHeader(name: string) {
      return headers[name];
    },
    removeHeader(name: string) {
      delete headers[name];
      return res;
    },
    end() {
      return res;
    },
    vary() {
      return res;
    },
    // onRequest wraps a cors handler that resolves on either the
    // "finish" event or the middleware calling next(). Registering
    // the listener without firing it leaves the next() path, which is
    // the one a POST takes.
    on() {
      return res;
    },
  };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return {res: res as any, out};
}

/**
 * Calls the deployed handler and returns what it answered.
 *
 * @param {Body} body The JSON body.
 * @param {object} opts Overrides for method and client address.
 * @return {Promise<object>} The recorded status and payload.
 */
async function post(
  body: Body,
  opts: {ip?: string | null; method?: string} = {}
) {
  const {res, out} = resSpy();
  await waitlistSignup(reqFor(body, opts), res);
  return out;
}

describe("waitlistSignup: what it accepts", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  test("a valid signup writes exactly one row", async () => {
    const out = await post({email: "Test@Example.COM", city: "Houston"});

    expect(out.status).toBe(200);
    const snap = await db.collection("waitlist").get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].id).toBe("test@example.com");
    expect(snap.docs[0].data().city).toBe("Houston");
    expect(snap.docs[0].data().source).toBe("landing");
  });

  test("an omitted city is stored as null, not as the string", async () => {
    await post({email: "nocity@example.com"});

    const doc = await db.collection("waitlist").doc("nocity@example.com").get();
    expect(doc.data()?.city).toBeNull();
    expect(doc.data()?.source).toBe("landing");
  });

  test("a repeated address is still one row", async () => {
    await post({email: "dupe@example.com"});
    const out = await post({email: "DUPE@example.com"});

    expect(out.body).toMatchObject({ok: true, duplicate: true});
    expect((await db.collection("waitlist").get()).size).toBe(1);
  });

  test("the honeypot still writes nothing and still says ok", async () => {
    const out = await post({email: "bot@example.com", website: "spam"});

    expect(out.status).toBe(200);
    expect(out.body).toMatchObject({ok: true});
    expect((await db.collection("waitlist").get()).size).toBe(0);
    // And it does not spend the IP allowance, because it did not
    // touch Firestore. A bot filling the honeypot should not be able
    // to exhaust an address's quota for the humans behind it.
    expect((await db.collection(IP_COUNTS_COLLECTION).get()).size).toBe(0);
  });
});

describe("waitlistSignup: the size caps", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  test("an oversized city is refused, not truncated", async () => {
    const out = await post({
      email: "big@example.com",
      city: "H".repeat(MAX_WAITLIST_FIELD_CHARS + 1),
    });

    expect(out.status).toBe(400);
    expect(out.body).toMatchObject({error: "field_too_long"});
    // The point of the finding: nothing was stored at all. A
    // truncating fix would leave a row saying the user is from
    // "HHHHH..." and call that a success.
    expect((await db.collection("waitlist").get()).size).toBe(0);
  });

  test("an oversized source is refused", async () => {
    const out = await post({
      email: "src@example.com",
      source: "s".repeat(MAX_WAITLIST_FIELD_CHARS + 1),
    });

    expect(out.status).toBe(400);
    expect(out.body).toMatchObject({error: "field_too_long"});
  });

  test("a city at exactly the cap is accepted", async () => {
    // The boundary in the direction that matters. A cap that is one
    // character tight refuses a legitimate signup, and a refused
    // signup is the one thing this endpoint exists to not do.
    const out = await post({
      email: "edge@example.com",
      city: "H".repeat(MAX_WAITLIST_FIELD_CHARS),
    });

    expect(out.status).toBe(200);
    expect((await db.collection("waitlist").get()).size).toBe(1);
  });

  test("a megabyte email is refused rather than throwing a 500", async () => {
    // EMAIL_RE is [^\s@]+@[^\s@]+\.[^\s@]+, and "not a space and not
    // an at sign" matches a megabyte. Before the cap this reached
    // Firestore, which rejects document ids over 1500 bytes, so the
    // handler's catch turned it into a 500: a server error for what
    // is plainly a bad request.
    const out = await post({
      email: `a@${"b".repeat(2000)}.com`,
    });

    expect(out.status).toBe(400);
    expect(out.body).toMatchObject({error: "email_too_long"});
    expect((await db.collection("waitlist").get()).size).toBe(0);
  });
});

describe("waitlistSignup: the per IP daily limit", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  test("stops one address after its allowance and keeps the rows", async () => {
    for (let i = 0; i < MAX_SIGNUPS_PER_IP_PER_DAY; i++) {
      const out = await post({email: `flood-${i}@example.com`});
      expect(out.status).toBe(200);
    }

    const blocked = await post({email: "one-too-many@example.com"});
    expect(blocked.status).toBe(429);
    expect(blocked.body).toMatchObject({error: "rate_limited"});

    // The allowance is what bounds unique addresses, so the count of
    // rows is the assertion that matters, not the status code.
    expect((await db.collection("waitlist").get()).size)
      .toBe(MAX_SIGNUPS_PER_IP_PER_DAY);
  });

  test("a different address has its own allowance", async () => {
    for (let i = 0; i < MAX_SIGNUPS_PER_IP_PER_DAY; i++) {
      await post({email: `first-${i}@example.com`}, {ip: "198.51.100.1"});
    }
    const blocked = await post(
      {email: "blocked@example.com"},
      {ip: "198.51.100.1"}
    );
    const other = await post(
      {email: "other@example.com"},
      {ip: "198.51.100.2"}
    );

    expect(blocked.status).toBe(429);
    expect(other.status).toBe(200);
  });

  test("an invalid email does not spend the allowance", async () => {
    // Ordering, asserted rather than assumed. A request that never
    // reaches Firestore costs nothing to serve, so counting it would
    // let a stream of garbage lock out the humans behind the same
    // carrier NAT.
    for (let i = 0; i < MAX_SIGNUPS_PER_IP_PER_DAY + 5; i++) {
      await post({email: "not-an-email"});
    }

    const out = await post({email: "still@example.com"});
    expect(out.status).toBe(200);
  });
});

describe("waitlist limits: the pieces, directly", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  test("a long non-address reads as invalid, not as too long", () => {
    // Order of checks. "That is not an email" is the truer answer and
    // the one the marketing site already knows how to display.
    const result = checkSignupInput({email: "x".repeat(500)}, emailRe);
    expect(result).toMatchObject({ok: false, error: "invalid_email"});
  });

  test("an address at exactly the RFC limit is accepted", () => {
    const local = "a".repeat(MAX_EMAIL_CHARS - "@example.com".length);
    const email = `${local}@example.com`;
    expect(email.length).toBe(MAX_EMAIL_CHARS);
    expect(checkSignupInput({email}, emailRe)).toMatchObject({ok: true});
  });

  test("the client address comes from x-forwarded-for, not req.ip", () => {
    // Behind Cloud Run req.ip can be the proxy, and rate limiting
    // every request under one proxy address would be a global limit
    // wearing a per IP costume.
    expect(
      clientIpFrom({
        headers: {"x-forwarded-for": "203.0.113.9, 10.0.0.1"},
        ip: "10.0.0.1",
      })
    ).toBe("203.0.113.9");
    expect(clientIpFrom({headers: {}, ip: "10.0.0.1"})).toBe("10.0.0.1");
    expect(clientIpFrom({headers: {}})).toBeNull();
  });

  test("an unknown address shares one bucket rather than being waved through",
    async () => {
      // The trade-off is deliberate and this pins it: if the platform
      // ever stops providing a client address, the endpoint closes
      // rather than becoming an unbounded public write path.
      const now = new Date("2026-08-16T12:00:00Z");
      for (let i = 0; i < MAX_SIGNUPS_PER_IP_PER_DAY; i++) {
        const attempt = await recordSignupAttempt(db, null, now);
        expect(attempt.allowed).toBe(true);
      }
      const blocked = await recordSignupAttempt(db, null, now);
      expect(blocked.allowed).toBe(false);
    });

  test("the counter rolls over at the UTC day boundary", async () => {
    const lateOnDay1 = new Date("2026-08-16T23:59:59Z");
    const earlyOnDay2 = new Date("2026-08-17T00:00:01Z");

    for (let i = 0; i < MAX_SIGNUPS_PER_IP_PER_DAY; i++) {
      await recordSignupAttempt(db, "203.0.113.7", lateOnDay1);
    }
    expect((await recordSignupAttempt(db, "203.0.113.7", lateOnDay1)).allowed)
      .toBe(false);
    expect((await recordSignupAttempt(db, "203.0.113.7", earlyOnDay2)).allowed)
      .toBe(true);
  });

  test("every counter carries the expiry the TTL policy reads", async () => {
    // The counters are themselves storage that grows with unique IPs.
    // A fix for unbounded storage that leaves unbounded storage
    // behind it is not a fix, and the TTL policy cannot delete a
    // document that does not carry the field.
    const now = new Date("2026-08-16T12:00:00Z");
    await recordSignupAttempt(db, "203.0.113.7", now);

    const id = ipCounterDocId(dateKeyFor(now), "203.0.113.7");
    const doc = await db.collection(IP_COUNTS_COLLECTION).doc(id).get();
    const expiresAt = doc.data()?.expiresAt as
      {toDate: () => Date} | undefined;

    expect(expiresAt).toBeDefined();
    expect(expiresAt?.toDate().getTime()).toBeGreaterThan(now.getTime());
  });
});
