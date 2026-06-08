const { parseCsv, parseCsvLine, FOOD_TRUCK_PATTERN } = require("../lib/csv_parser");
const fs = require("fs");
const path = require("path");
const os = require("os");

function writeTempCsv(content) {
  const tmpPath = path.join(os.tmpdir(), `test_csv_${Date.now()}.csv`);
  fs.writeFileSync(tmpPath, content, "utf-8");
  return tmpPath;
}

describe("CSV parser", () => {
  test("parses a valid row into expected object", () => {
    const csv = [
      "Restaurant,Cuisine,Area / City,Address,Source,Place ID",
      'Turkey Leg Hut,Soul Food,Third Ward / Houston,"4830 Almeda Rd, Houston, TX 77004",Keith Lee + Yelp,',
    ].join("\n");

    const tmpPath = writeTempCsv(csv);
    const candidates = parseCsv(tmpPath);
    fs.unlinkSync(tmpPath);

    expect(candidates).toHaveLength(1);
    expect(candidates[0].name).toBe("Turkey Leg Hut");
    expect(candidates[0].cuisine).toBe("Soul Food");
    expect(candidates[0].area).toBe("Third Ward / Houston");
    expect(candidates[0].address).toBe("4830 Almeda Rd, Houston, TX 77004");
    expect(candidates[0].isMobileVenue).toBe(false);
    expect(candidates[0].placeId).toBeNull();
    expect(candidates[0].displayOrder).toBe(1);
  });

  test("drops the Source column", () => {
    const csv = [
      "Restaurant,Cuisine,Area / City,Address,Source,Place ID",
      "Test Place,Tacos,Montrose / Houston,123 Main St,Michelin + Eater,",
    ].join("\n");

    const tmpPath = writeTempCsv(csv);
    const candidates = parseCsv(tmpPath);
    fs.unlinkSync(tmpPath);

    // Source should not appear on the candidate object
    expect(candidates[0]).not.toHaveProperty("source");
    expect(Object.keys(candidates[0])).not.toContain("source");
  });

  test("detects (FOOD TRUCK) and sets mobile flag, strips tag from cuisine", () => {
    const csv = [
      "Restaurant,Cuisine,Area / City,Address,Source,Place ID",
      "Rosemeyer,BBQ (FOOD TRUCK),Heights / Houston,,Eater Houston,",
      "The Better Box,Tacos (food truck),EaDo / Houston,,Reddit,",
    ].join("\n");

    const tmpPath = writeTempCsv(csv);
    const candidates = parseCsv(tmpPath);
    fs.unlinkSync(tmpPath);

    expect(candidates[0].isMobileVenue).toBe(true);
    expect(candidates[0].cuisine).toBe("BBQ");
    expect(candidates[1].isMobileVenue).toBe(true);
    expect(candidates[1].cuisine).toBe("Tacos");
  });

  test("handles missing Address gracefully", () => {
    const csv = [
      "Restaurant,Cuisine,Area / City,Address,Source,Place ID",
      "Rosemeyer,BBQ (FOOD TRUCK),Heights / Houston,,Eater Houston,",
    ].join("\n");

    const tmpPath = writeTempCsv(csv);
    const candidates = parseCsv(tmpPath);
    fs.unlinkSync(tmpPath);

    expect(candidates[0].address).toBe("");
    expect(candidates[0].area).toBe("Heights / Houston");
  });
});

describe("parseCsvLine", () => {
  test("handles quoted fields with commas", () => {
    const fields = parseCsvLine('"Hello, World",Foo,Bar');
    expect(fields).toEqual(["Hello, World", "Foo", "Bar"]);
  });
});

describe("FOOD_TRUCK_PATTERN", () => {
  test("matches case insensitive", () => {
    expect(FOOD_TRUCK_PATTERN.test("BBQ (FOOD TRUCK)")).toBe(true);
    expect(FOOD_TRUCK_PATTERN.test("Tacos (food truck)")).toBe(true);
    expect(FOOD_TRUCK_PATTERN.test("Tacos (Food Truck)")).toBe(true);
    expect(FOOD_TRUCK_PATTERN.test("Regular BBQ")).toBe(false);
  });
});
