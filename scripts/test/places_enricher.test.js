const {
  enrichCandidates,
  tokenOverlap,
  checkCityMatch,
  mapPriceLevel,
  CALL_CAP,
} = require("../lib/places_enricher");
const fixtureResponse = require("./fixtures/places_response.json");

// Fake fetch that returns the fixture response
function makeFakeFetch(response) {
  return async () => ({
    ok: true,
    json: async () => response,
  });
}

function makeFakeFetchError(status) {
  return async () => ({
    ok: false,
    status,
    json: async () => ({}),
  });
}

describe("Places enricher", () => {
  test("maps a successful Places response to restaurant model fields", async () => {
    const candidates = [
      {
        name: "Turkey Leg Hut",
        cuisine: "Soul Food",
        area: "Third Ward / Houston",
        address: "4830 Almeda Rd, Houston, TX 77004",
        isMobileVenue: false,
        placeId: null,
        displayOrder: 1,
      },
    ];

    const { enriched, manualReview, callCount } = await enrichCandidates(
      candidates,
      "fake-key",
      makeFakeFetch(fixtureResponse)
    );

    expect(enriched).toHaveLength(1);
    expect(manualReview).toHaveLength(0);
    expect(callCount).toBe(1);

    const r = enriched[0];
    expect(r.placeId).toBe("ChIJN1t_tDeuEmsRUsoyG83frY4");
    expect(r.priceLevel).toBe(2); // MODERATE -> 2
    expect(r.latitude).toBeCloseTo(29.7306);
    expect(r.longitude).toBeCloseTo(-95.3755);
    expect(r.formattedAddress).toContain("Houston");
    expect(r.openingHours).toHaveLength(7);
  });

  test("puts unresolved row on manual review list", async () => {
    const candidates = [
      {
        name: "Ghost Restaurant",
        cuisine: "Unknown",
        area: "Nowhere",
        address: "999 Fake St",
        isMobileVenue: false,
        placeId: null,
        displayOrder: 1,
      },
    ];

    const { enriched, manualReview } = await enrichCandidates(
      candidates,
      "fake-key",
      makeFakeFetch({ places: [] })
    );

    expect(enriched).toHaveLength(0);
    expect(manualReview).toHaveLength(1);
    expect(manualReview[0].reason).toBe("no Places result");
  });

  test("puts name-mismatch row on manual review", async () => {
    const mismatchResponse = {
      places: [
        {
          id: "ChIJxyz",
          displayName: { text: "Totally Different Place" },
          formattedAddress: "123 Main St, Houston, TX 77001",
          location: { latitude: 29.76, longitude: -95.36 },
        },
      ],
    };

    const candidates = [
      {
        name: "Turkey Leg Hut",
        cuisine: "Soul Food",
        area: "Third Ward",
        address: "4830 Almeda Rd",
        isMobileVenue: false,
        placeId: null,
        displayOrder: 1,
      },
    ];

    const { enriched, manualReview } = await enrichCandidates(
      candidates,
      "fake-key",
      makeFakeFetch(mismatchResponse)
    );

    expect(enriched).toHaveLength(0);
    expect(manualReview).toHaveLength(1);
    expect(manualReview[0].reason).toContain("name mismatch");
  });

  test("puts city-mismatch row on manual review", async () => {
    const wrongCityResponse = {
      places: [
        {
          id: "ChIJabc",
          displayName: { text: "Turkey Leg Hut" },
          formattedAddress: "123 Main St, Dallas, TX 75201",
          location: { latitude: 32.78, longitude: -96.79 },
        },
      ],
    };

    const candidates = [
      {
        name: "Turkey Leg Hut",
        cuisine: "Soul Food",
        area: "Third Ward",
        address: "4830 Almeda Rd",
        isMobileVenue: false,
        placeId: null,
        displayOrder: 1,
      },
    ];

    const { enriched, manualReview } = await enrichCandidates(
      candidates,
      "fake-key",
      makeFakeFetch(wrongCityResponse)
    );

    expect(enriched).toHaveLength(0);
    expect(manualReview).toHaveLength(1);
    expect(manualReview[0].reason).toContain("city mismatch");
  });

  test("respects call cap and aborts", async () => {
    // Create CALL_CAP + 5 candidates, all with addresses
    const candidates = Array.from({ length: CALL_CAP + 5 }, (_, i) => ({
      name: `Restaurant ${i}`,
      cuisine: "Test",
      area: "Houston",
      address: `${i} Main St, Houston, TX`,
      isMobileVenue: false,
      placeId: null,
      displayOrder: i + 1,
    }));

    let actualCalls = 0;
    const fakeFetch = async () => {
      actualCalls++;
      return {
        ok: true,
        json: async () => ({
          places: [
            {
              id: `ChIJ${actualCalls}`,
              displayName: { text: `Restaurant ${actualCalls - 1}` },
              formattedAddress: `${actualCalls} Main St, Houston, TX 77001`,
              location: { latitude: 29.76, longitude: -95.36 },
            },
          ],
        }),
      };
    };

    const { callCount, manualReview } = await enrichCandidates(
      candidates,
      "fake-key",
      fakeFetch
    );

    expect(callCount).toBe(CALL_CAP);
    expect(actualCalls).toBe(CALL_CAP);
    // The 5 over-cap candidates should be in manual review
    expect(manualReview.length).toBeGreaterThanOrEqual(5);
    expect(manualReview.some((r) => r.reason === "call cap reached")).toBe(true);
  });

  test("address-less rows always go to manual review", async () => {
    const candidates = [
      {
        name: "Rosemeyer",
        cuisine: "BBQ",
        area: "Heights / Houston",
        address: "", // no address
        isMobileVenue: true,
        placeId: null,
        displayOrder: 1,
      },
    ];

    const { enriched, manualReview, callCount } = await enrichCandidates(
      candidates,
      "fake-key",
      makeFakeFetch(fixtureResponse) // would match, but no call should be made
    );

    expect(enriched).toHaveLength(0);
    expect(manualReview).toHaveLength(1);
    expect(manualReview[0].reason).toBe("no input address, verify manually");
    expect(callCount).toBe(0); // no API call made
  });
});

describe("tokenOverlap", () => {
  test("identical names score 1.0", () => {
    expect(tokenOverlap("Turkey Leg Hut", "Turkey Leg Hut")).toBe(1);
  });

  test("similar names with variant score above threshold", () => {
    expect(tokenOverlap("Killen's BBQ", "Killen's Barbecue")).toBeGreaterThanOrEqual(0.5);
  });

  test("completely different names score 0", () => {
    expect(tokenOverlap("Turkey Leg Hut", "Auto Parts Store")).toBe(0);
  });
});

describe("mapPriceLevel", () => {
  test.each([
    ["PRICE_LEVEL_FREE", 1],
    ["PRICE_LEVEL_INEXPENSIVE", 1],
    ["PRICE_LEVEL_MODERATE", 2],
    ["PRICE_LEVEL_EXPENSIVE", 3],
    ["PRICE_LEVEL_VERY_EXPENSIVE", 4],
    [undefined, 2],
    [null, 2],
  ])("maps %s to %d", (input, expected) => {
    expect(mapPriceLevel(input)).toBe(expected);
  });
});

describe("checkCityMatch", () => {
  test("matches Houston address", () => {
    expect(
      checkCityMatch({
        formattedAddress: "4830 Almeda Rd, Houston, TX 77004",
        location: { latitude: 29.73, longitude: -95.37 },
      })
    ).toBe(true);
  });

  test("matches Katy (metro suburb)", () => {
    expect(
      checkCityMatch({
        formattedAddress: "123 Main St, Katy, TX 77494",
        location: { latitude: 29.78, longitude: -95.82 },
      })
    ).toBe(true);
  });

  test("matches Pearland (metro suburb)", () => {
    expect(
      checkCityMatch({
        formattedAddress: "3613 E Broadway St, Pearland, TX 77581",
        location: { latitude: 29.55, longitude: -95.28 },
      })
    ).toBe(true);
  });

  test("rejects Dallas address", () => {
    expect(
      checkCityMatch({
        formattedAddress: "123 Main St, Dallas, TX 75201",
        location: { latitude: 32.78, longitude: -96.79 },
      })
    ).toBe(false);
  });
});
