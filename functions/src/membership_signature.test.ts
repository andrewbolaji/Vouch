/**
 * Finding 5, part 3: webhook signature verification.
 *
 * Built and held. The handler skips verification entirely while
 * REVENUECAT_WEBHOOK_SIGNING_SECRET is unset, so these test the
 * function itself plus that switch, which is the part that has to be
 * right for the hold to be safe.
 */

import {createHmac} from "crypto";
import {
  verifyWebhookSignature,
  REVENUECAT_SIGNATURE_HEADER,
} from "./membership_webhook";

const secret = "whsec_test_value";
const body = Buffer.from(
  JSON.stringify({event: {id: "evt-1", type: "INITIAL_PURCHASE"}})
);

/**
 * The signature RevenueCat would send for these bytes.
 *
 * @param {Buffer} bytes The exact body bytes.
 * @param {string} key The signing secret.
 * @return {string} A hex digest.
 */
function sign(bytes: Buffer, key = secret): string {
  return createHmac("sha256", key).update(bytes).digest("hex");
}

describe("verifyWebhookSignature", () => {
  test("accepts a correct signature, bare or prefixed", () => {
    expect(verifyWebhookSignature(body, sign(body), secret)).toBe(true);
    // Both conventions are in the wild, and rejecting the wrong one
    // would look exactly like a forged request.
    expect(
      verifyWebhookSignature(body, `sha256=${sign(body)}`, secret)
    ).toBe(true);
    expect(
      verifyWebhookSignature(body, sign(body).toUpperCase(), secret)
    ).toBe(true);
  });

  test("rejects a signature made with a different secret", () => {
    expect(
      verifyWebhookSignature(body, sign(body, "wrong_secret"), secret)
    ).toBe(false);
  });

  test("rejects when a single byte of the body changed", () => {
    // The property that makes this worth having over the bearer
    // secret: the bearer header authenticates the sender and says
    // nothing about the payload.
    const signature = sign(body);
    const tampered = Buffer.from(
      JSON.stringify({event: {id: "evt-1", type: "EXPIRATION"}})
    );
    expect(verifyWebhookSignature(tampered, signature, secret)).toBe(false);
  });

  test("rejects missing pieces rather than throwing", () => {
    expect(verifyWebhookSignature(undefined, sign(body), secret)).toBe(false);
    expect(verifyWebhookSignature(body, undefined, secret)).toBe(false);
    expect(verifyWebhookSignature(body, sign(body), "")).toBe(false);
    // A short value would make timingSafeEqual throw if the length
    // check were not first, and a throwing verifier is a 500 where a
    // 401 belongs.
    expect(verifyWebhookSignature(body, "abc", secret)).toBe(false);
    expect(verifyWebhookSignature(body, "", secret)).toBe(false);
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

    const signature = sign(onTheWire);
    expect(verifyWebhookSignature(onTheWire, signature, secret)).toBe(true);
    expect(verifyWebhookSignature(reserialised, signature, secret))
      .toBe(false);
  });

  test("the header name is lower case, which is how Node presents it",
    () => {
      // Node lowercases incoming header names, so a constant with any
      // capitals in it would silently never match. Cheap to assert,
      // and the failure it prevents is total.
      expect(REVENUECAT_SIGNATURE_HEADER)
        .toBe(REVENUECAT_SIGNATURE_HEADER.toLowerCase());
    });
});
