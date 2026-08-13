const {
  checkCity,
  publishCity,
  STATUS_LIVE,
} = require("../lib/city_publisher");

/**
 * In-memory Firestore fake, matching the shape used by
 * firestore_writer.test.js. Supports the one query this module makes,
 * restaurants where cityId == x, plus subcollection gets.
 */
function createFakeDb(docs = {}) {
  const store = { ...docs };

  const fakeDoc = (path, id) => {
    const key = `${path}/${id}`;
    return {
      id,
      get: async () => ({
        exists: key in store,
        id,
        data: () => store[key] || null,
      }),
      update: async (data) => {
        if (!(key in store)) throw new Error(`no doc at ${key}`);
        store[key] = { ...store[key], ...data };
      },
      set: async (data) => {
        store[key] = data;
      },
      collection: (sub) => fakeCollection(`${key}/${sub}`),
    };
  };

  const fakeCollection = (path) => ({
    doc: (id) => fakeDoc(path, id),
    where: (field, op, value) => ({
      get: async () => {
        const matches = Object.entries(store)
          .filter(([k]) => k.startsWith(`${path}/`))
          // Direct children only, so a subcollection document never
          // gets mistaken for a restaurant.
          .filter(([k]) => k.slice(path.length + 1).indexOf("/") === -1)
          .filter(([, v]) => op === "==" && v[field] === value)
          .map(([k, v]) => ({
            id: k.split("/").pop(),
            data: () => v,
            exists: true,
          }));
        return { docs: matches, size: matches.length, empty: !matches.length };
      },
    }),
  });

  return { collection: fakeCollection, __store: store };
}

/** A city that passes every blocking check. */
function healthyCity(overrides = {}) {
  const docs = {
    "cities/houston": {
      name: "Houston",
      status: "comingSoon",
      restaurantCount: 5,
      ...(overrides.city || {}),
    },
  };
  for (let rank = 1; rank <= 5; rank++) {
    docs[`restaurants/hou-${rank}`] = {
      cityId: "houston",
      name: `Restaurant ${rank}`,
      rank,
      displayOrder: rank,
      imageUrl: "https://example.com/a.jpg",
      locations: [{ name: "Area", address: "1 St", latitude: 29.7, longitude: -95.3 }],
      ...(overrides.restaurant || {}),
    };
    docs[`restaurants/hou-${rank}/insiderNotes/notes`] = {
      restaurantId: `hou-${rank}`,
      insiderTip: "A real note.",
    };
  }
  return docs;
}

describe("checkCity", () => {
  test("a healthy city passes with no blockers or warnings", async () => {
    const db = createFakeDb(healthyCity());
    const r = await checkCity(db, "houston");
    expect(r.blockers).toEqual([]);
    expect(r.warnings).toEqual([]);
    expect(r.ok).toBe(true);
    expect(r.stats.restaurants).toBe(5);
  });

  test("a city that does not exist is blocked, not crashed", async () => {
    const db = createFakeDb(healthyCity());
    const r = await checkCity(db, "atlantis");
    expect(r.ok).toBe(false);
    expect(r.blockers[0]).toMatch(/does not exist/);
  });

  // The check that exists because Chicago, LA and NYC each carried
  // displayOrder on 0 of 10 documents. A recompute on a city in that
  // state discards the curated order it was published with.
  test("blocks when any restaurant has no displayOrder", async () => {
    const docs = healthyCity();
    delete docs["restaurants/hou-3"].displayOrder;
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(false);
    expect(r.blockers.join(" ")).toMatch(/no displayOrder/);
    expect(r.blockers.join(" ")).toMatch(/hou-3/);
  });

  test("blocks on a duplicate rank", async () => {
    const docs = healthyCity();
    docs["restaurants/hou-4"].rank = 3;
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(false);
    expect(r.blockers.join(" ")).toMatch(/Duplicate ranks: 3/);
  });

  test("blocks on a gap in the ranks", async () => {
    const docs = healthyCity();
    docs["restaurants/hou-5"].rank = 9;
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(false);
    expect(r.blockers.join(" ")).toMatch(/not contiguous.*Missing: 5/);
  });

  test("blocks a city too small for the free tier", async () => {
    const docs = healthyCity({ city: { restaurantCount: 3 } });
    delete docs["restaurants/hou-4"];
    delete docs["restaurants/hou-4/insiderNotes/notes"];
    delete docs["restaurants/hou-5"];
    delete docs["restaurants/hou-5/insiderNotes/notes"];
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(false);
    expect(r.blockers.join(" ")).toMatch(/at least 5 for the free tier/);
  });

  test("blocks when restaurantCount disagrees with reality", async () => {
    const docs = healthyCity({ city: { restaurantCount: 10 } });
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(false);
    expect(r.blockers.join(" ")).toMatch(/restaurantCount is 10 but 5/);
  });

  // Warnings are product judgements. They must never block, or a
  // city could not launch while its photographs are still being
  // taken, which is the state Houston is actually in.
  test("missing images warn but do not block", async () => {
    const docs = healthyCity();
    docs["restaurants/hou-2"].imageUrl = "placeholder://restaurant";
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(true);
    expect(r.blockers).toEqual([]);
    expect(r.warnings.join(" ")).toMatch(/1 of 5 restaurants have no usable/);
  });

  test("missing insider notes warn but do not block", async () => {
    const docs = healthyCity();
    delete docs["restaurants/hou-2/insiderNotes/notes"];
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(true);
    expect(r.warnings.join(" ")).toMatch(/1 of 5 .* no insider notes/);
  });

  test("0,0 coordinates warn but do not block", async () => {
    const docs = healthyCity();
    docs["restaurants/hou-2"].locations = [
      { name: "Area", address: "1 St", latitude: 0, longitude: 0 },
    ];
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(true);
    expect(r.warnings.join(" ")).toMatch(/Gulf of Guinea/);
  });

  test("only the named city is examined", async () => {
    const docs = healthyCity();
    // A broken restaurant in a different city must not block Houston.
    docs["restaurants/atl-1"] = { cityId: "atlanta", name: "X", rank: 1 };
    const r = await checkCity(createFakeDb(docs), "houston");
    expect(r.ok).toBe(true);
    expect(r.stats.restaurants).toBe(5);
  });
});

describe("publishCity", () => {
  test("dry run reports pass and writes nothing", async () => {
    const db = createFakeDb(healthyCity());
    const r = await publishCity(db, "houston");
    expect(r.published).toBe(false);
    expect(r.reason).toBe("dry-run");
    expect(r.check.ok).toBe(true);
    expect(db.__store["cities/houston"].status).toBe("comingSoon");
  });

  test("confirm publishes and the write is verified by read-back", async () => {
    const db = createFakeDb(healthyCity());
    const r = await publishCity(db, "houston", { confirm: true });
    expect(r.published).toBe(true);
    expect(db.__store["cities/houston"].status).toBe(STATUS_LIVE);
  });

  test("publishing writes status and nothing else", async () => {
    const db = createFakeDb(healthyCity());
    const before = { ...db.__store["cities/houston"] };
    await publishCity(db, "houston", { confirm: true });
    const after = db.__store["cities/houston"];
    expect(after.name).toBe(before.name);
    expect(after.restaurantCount).toBe(before.restaurantCount);
    expect(Object.keys(after).sort()).toEqual(Object.keys(before).sort());
  });

  test("re-running on a live city is a no-op", async () => {
    const db = createFakeDb(healthyCity({ city: { status: STATUS_LIVE } }));
    const r = await publishCity(db, "houston", { confirm: true });
    expect(r.published).toBe(false);
    expect(r.reason).toBe("already-live");
    expect(db.__store["cities/houston"].status).toBe(STATUS_LIVE);
  });

  test("a blocked city is never published, even with confirm", async () => {
    const docs = healthyCity();
    delete docs["restaurants/hou-3"].displayOrder;
    const db = createFakeDb(docs);
    const r = await publishCity(db, "houston", { confirm: true });
    expect(r.published).toBe(false);
    expect(r.reason).toBe("blocked");
    expect(db.__store["cities/houston"].status).toBe("comingSoon");
  });

  test("a city with only warnings publishes", async () => {
    const docs = healthyCity();
    docs["restaurants/hou-2"].imageUrl = "placeholder://restaurant";
    delete docs["restaurants/hou-4/insiderNotes/notes"];
    const db = createFakeDb(docs);
    const r = await publishCity(db, "houston", { confirm: true });
    expect(r.published).toBe(true);
    expect(r.check.warnings.length).toBe(2);
  });
});
