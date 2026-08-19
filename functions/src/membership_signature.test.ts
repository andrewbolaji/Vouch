/**
 * RevenueCat timestamped webhook signature verification.
 */

import {createHmac} from "crypto";
import {
  verifyWebhookSignature,
  REVENUECAT_SIGNATURE_HEADER,
  REVENUECAT_SIGNATURE_TOLERANCE_SECONDS,
} from "./membership_webhook";

const secret = "whsec_test_value";
const body = Buffer.from(
  JSON.stringify({event: {id: "evt-1", type: "INITIAL_PURCHASE"}})
);
const now = new Date("2026-08-18T22:00:00.000Z");
const timestamp = Math.floor(now.getTime() / 1000).toString();

/**
 * The signature RevenueCat would send for these bytes.
 *
 * @param {Buffer} bytes The exact body bytes.
 * @param {string} signedAt The exact timestamp string in the header.
 * @param {string} key The signing secret.
 * @return {string} A hex digest.
 */
function sign(
  bytes: Buffer,
  signedAt: string = timestamp,
  key = secret,
): string {
  return createHmac("sha256", key)
    .update(Buffer.from(`${signedAt}.`))
    .update(bytes)
    .digest("hex");
}

/**
 * Builds the exact header shape RevenueCat documents.
 *
 * @param {Buffer} bytes The exact body bytes.
 * @param {string} signedAt The unix timestamp text.
 * @param {string} key The signing secret.
 * @return {string} The signature header value.
 */
function headerFor(
  bytes: Buffer,
  signedAt: string = timestamp,
  key = secret,
): string {
  return `t=${signedAt},v1=${sign(bytes, signedAt, key)}`;
}

describe("verifyWebhookSignature", () => {
  test("accepts RevenueCat's documented timestamped header", () => {
    expect(
      verifyWebhookSignature(body, headerFor(body), secret, now)
    ).toBe(true);
    expect(
      verifyWebhookSignature(
        body,
        `t=${timestamp},v1=${sign(body).toUpperCase()}`,
        secret,
        now,
      )
    ).toBe(true);
  });

  test("rejects a signature made with a different secret", () => {
    expect(
      verifyWebhookSignature(
        body,
        headerFor(body, timestamp, "wrong_secret"),
        secret,
        now,
      )
    ).toBe(false);
  });

  test("rejects when a single byte of the body changed", () => {
    // The property that makes this worth having over the bearer
    // secret: the bearer header authenticates the sender and says
    // nothing about the payload.
    const signature = headerFor(body);
    const tampered = Buffer.from(
      JSON.stringify({event: {id: "evt-1", type: "EXPIRATION"}})
    );
    expect(
      verifyWebhookSignature(tampered, signature, secret, now)
    ).toBe(false);
  });

  test("rejects missing pieces rather than throwing", () => {
    expect(
      verifyWebhookSignature(undefined, headerFor(body), secret, now)
    ).toBe(false);
    expect(verifyWebhookSignature(body, undefined, secret)).toBe(false);
    expect(verifyWebhookSignature(body, headerFor(body), "", now))
      .toBe(false);
    expect(verifyWebhookSignature(body, "abc", secret, now)).toBe(false);
    expect(verifyWebhookSignature(body, "", secret)).toBe(false);
  });

  test.each([
    ["legacy bare digest", sign(body)],
    ["legacy sha256 prefix", `sha256=${sign(body)}`],
    ["missing timestamp", `v1=${sign(body)}`],
    ["missing signature", `t=${timestamp}`],
    ["non-numeric timestamp", `t=now,v1=${sign(body, "now")}`],
    ["short signature", `t=${timestamp},v1=abc`],
    ["non-hex signature", `t=${timestamp},v1=${"z".repeat(64)}`],
    ["duplicate timestamp", headerFor(body) + `,t=${timestamp}`],
    ["duplicate signature", headerFor(body) + `,v1=${sign(body)}`],
  ])("rejects malformed header: %s", (_label, header) => {
    expect(verifyWebhookSignature(body, header, secret, now)).toBe(false);
  });

  test("rejects signatures outside the five-minute replay window", () => {
    const tolerance = REVENUECAT_SIGNATURE_TOLERANCE_SECONDS;
    const atPastBoundary = (Number(timestamp) - tolerance).toString();
    const beforePastBoundary = (Number(timestamp) - tolerance - 1).toString();
    const atFutureBoundary = (Number(timestamp) + tolerance).toString();
    const afterFutureBoundary = (Number(timestamp) + tolerance + 1).toString();

    expect(
      verifyWebhookSignature(
        body,
        headerFor(body, atPastBoundary),
        secret,
        now,
      )
    ).toBe(true);
    expect(
      verifyWebhookSignature(
        body,
        headerFor(body, beforePastBoundary),
        secret,
        now,
      )
    ).toBe(false);
    expect(
      verifyWebhookSignature(
        body,
        headerFor(body, atFutureBoundary),
        secret,
        now,
      )
    ).toBe(true);
    expect(
      verifyWebhookSignature(
        body,
        headerFor(body, afterFutureBoundary),
        secret,
        now,
      )
    ).toBe(false);
  });

  test("rejects an invalid replay tolerance", () => {
    expect(
      verifyWebhookSignature(body, headerFor(body), secret, now, -1)
    ).toBe(false);
    expect(
      verifyWebhookSignature(body, headerFor(body), secret, now, Infinity)
    ).toBe(false);
  });

  test("verifies the bytes received, not a re-serialised copy", () => {
    // Why the handler passes req.rawBody. These two parse to the same
    // object and hash differently, so a check computed over
    // JSON.stringify(req.body) would verify the reconstruction rather
    // than the request, and would fail on every real webhook whose
    // spacing or unicode escaping differs from Node's.
    //
    // Whitespace rather than key order, deliberately: V8 preserves
    // insertion order for string keys, so a reordering example would
    // pass for the wrong reason and prove nothing. Measured rather
    // than assumed, after the first version of this test did exactly
    // that.
    const onTheWire = Buffer.from("{\"a\": 1, \"b\": \"\\u00e9\"}");
    const reserialised = Buffer.from(
      JSON.stringify(JSON.parse(onTheWire.toString()))
    );
    expect(reserialised.toString()).not.toBe(onTheWire.toString());

    const signature = headerFor(onTheWire);
    expect(verifyWebhookSignature(onTheWire, signature, secret, now))
      .toBe(true);
    expect(verifyWebhookSignature(reserialised, signature, secret, now))
      .toBe(false);
  });

  test("the header name is lower case, which is how Node presents it",
    () => {
      // Node lowercases incoming header names, so a constant with any
      // capitals in it would silently never match. Cheap to assert,
      // and the failure it prevents is total.
      expect(REVENUECAT_SIGNATURE_HEADER)
        .toBe(REVENUECAT_SIGNATURE_HEADER.toLowerCase());
      expect(REVENUECAT_SIGNATURE_HEADER)
        .toBe("x-revenuecat-webhook-signature");
    });
});
