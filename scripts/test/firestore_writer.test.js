const {
  scanDemoData,
  cleanDemoData,
  writeHoustonData,
  UNRANKED_RANK,
  DEMO_CITY_IDS,
} = require("../lib/firestore_writer");

// In-memory Firestore fake
function createFakeDb(initialDocs = {}) {
  const store = { ...initialDocs };

  const fakeDoc = (collectionPath, docId) => {
    const key = `${collectionPath}/${docId}`;
    return {
      get: async () => ({
        exists: key in store,
        data: () => store[key] || null,
      }),
      set: async (data) => {
        store[key] = data;
      },
      update: async (data) => {
        store[key] = { ...store[key], ...data };
      },
      delete: async () => {
        delete store[key];
      },
      collection: (sub) => ({
        doc: (subId) => fakeDoc(`${key}/${sub}`, subId),
      }),
    };
  };

  return {
    collection: (name) => ({
      doc: (id) => fakeDoc(name, id),
    }),
    _store: store,
  };
}

const fakeFieldValue = {
  serverTimestamp: () => "SERVER_TIMESTAMP",
};

describe("Firestore writer", () => {
  test("scanDemoData finds demo docs", async () => {
    const db = createFakeDb({
      "cities/houston": { id: "houston" },
      "cities/nyc": { id: "nyc" },
      "restaurants/hou-1": { id: "hou-1" },
      "restaurants/hou-2": { id: "hou-2" },
      "restaurants/hou-1/insiderNotes/notes": { whatToOrder: "test" },
    });

    const result = await scanDemoData(db);

    expect(result.demoCities).toContain("houston");
    expect(result.demoCities).toContain("nyc");
    expect(result.demoRestaurants).toContain("hou-1");
    expect(result.demoRestaurants).toContain("hou-2");
    expect(result.demoNotes).toContain("hou-1");
  });

  test("dry-run counts without writing", async () => {
    const db = createFakeDb({});

    const enriched = [
      {
        name: "Turkey Leg Hut",
        cuisine: "Soul Food",
        placeId: "ChIJ123",
        priceLevel: 2,
        latitude: 29.73,
        longitude: -95.37,
        formattedAddress: "4830 Almeda Rd, Houston, TX",
        openingHours: ["Mon: 11-9"],
        isMobileVenue: false,
        area: "Third Ward",
        displayOrder: 1,
      },
    ];

    // dry-run: confirm = false
    const result = await writeHoustonData(db, fakeFieldValue, enriched, false);

    expect(result.created).toBe(2); // city + restaurant
    expect(result.updated).toBe(0);
    // Nothing actually written
    expect(db._store).toEqual({});
  });

  test("confirm mode creates city and restaurant docs", async () => {
    const db = createFakeDb({});

    const enriched = [
      {
        name: "Turkey Leg Hut",
        cuisine: "Soul Food",
        placeId: "ChIJ123",
        priceLevel: 2,
        latitude: 29.73,
        longitude: -95.37,
        formattedAddress: "4830 Almeda Rd, Houston, TX",
        openingHours: ["Mon: 11-9"],
        isMobileVenue: false,
        area: "Third Ward",
        displayOrder: 1,
      },
    ];

    const result = await writeHoustonData(db, fakeFieldValue, enriched, true);

    expect(result.created).toBe(2);
    // City doc exists
    expect(db._store["cities/houston"]).toBeDefined();
    expect(db._store["cities/houston"].name).toBe("Houston");
    // Restaurant doc exists with placeId-based ID
    expect(db._store["restaurants/hou-ChIJ123"]).toBeDefined();
    expect(db._store["restaurants/hou-ChIJ123"].rank).toBe(UNRANKED_RANK);
    expect(db._store["restaurants/hou-ChIJ123"].voteCount).toBe(0);
    expect(db._store["restaurants/hou-ChIJ123"].imageUrl).toBe(
      "placeholder://restaurant"
    );
  });

  test("update mode preserves voteCount and rank", async () => {
    const db = createFakeDb({
      "cities/houston": { id: "houston", restaurantCount: 1 },
      "restaurants/hou-ChIJ123": {
        id: "hou-ChIJ123",
        name: "Turkey Leg Hut",
        rank: 3, // user-voted rank
        voteCount: 500, // real votes
        priceLevel: 1,
      },
    });

    const enriched = [
      {
        name: "Turkey Leg Hut",
        cuisine: "Soul Food",
        placeId: "ChIJ123",
        priceLevel: 2, // updated price
        latitude: 29.73,
        longitude: -95.37,
        formattedAddress: "4830 Almeda Rd, Houston, TX",
        openingHours: ["Mon: 11-9"],
        isMobileVenue: false,
        area: "Third Ward",
        displayOrder: 1,
      },
    ];

    await writeHoustonData(db, fakeFieldValue, enriched, true);

    const doc = db._store["restaurants/hou-ChIJ123"];
    // Enrichment fields updated
    expect(doc.priceLevel).toBe(2);
    // User data preserved (not overwritten)
    expect(doc.rank).toBe(3);
    expect(doc.voteCount).toBe(500);
  });
});
