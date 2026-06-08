// DEMO ONLY. Set false or delete before any public launch build.

/// When true, restaurant images are resolved from [kDemoImageOverrides]
/// before falling through to the Firestore imageUrl. This lets the demo
/// build show hand-picked photos without touching seeded data.
///
/// Removal checklist (before store build):
///   1. Set [kUseDemoImageOverrides] to false, or
///   2. Delete this file, assets/demo/, and the pubspec assets entry.
const bool kUseDemoImageOverrides = true;

/// Map of restaurant name (lowercase, trimmed) to bundled asset path.
/// Use double-quoted keys so names with apostrophes work.
const Map<String, String> kDemoImageOverrides = {
  "turkey leg hut": "assets/demo/turkey_leg_hut.jpg",
  "killen's bbq": "assets/demo/killens_bbq.jpg",
};
