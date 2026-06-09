// DEMO ONLY. Set false or delete before any public launch build.

/// When true, restaurant images are resolved from [kDemoImageOverrides]
/// before falling through to the Firestore imageUrl. This lets the demo
/// build show hand-picked photos without touching seeded data.
///
/// Removal checklist (before store build):
///   1. Set [kUseDemoImageOverrides] to false, or
///   2. Delete this file, assets/demo/, and the pubspec assets entry.
const bool kUseDemoImageOverrides = true;

/// Image paths for a single restaurant. [primary] is used on the card and
/// as the left/full hero image. [secondary] is optional and triggers the
/// split hero layout on the detail screen.
class DemoImagePaths {
  const DemoImagePaths(this.primary, [this.secondary]);
  final String primary;
  final String? secondary;
}

/// Map of restaurant name (lowercase, trimmed) to demo image paths.
/// Auto-populated from assets/demo/ by filename convention:
///   Primary:   "{Name}.png"
///   Secondary: "{Name} {suffix}.png" (first match only; 3+ is carousel, deferred)
///
/// Use double-quoted keys so names with apostrophes work.
const Map<String, DemoImagePaths> kDemoImageOverrides = {
  // Pairs (primary + secondary)
  "bcn taste & tradition": DemoImagePaths(
    "assets/demo/BCN Taste & Tradition.png",
    "assets/demo/BCN Taste & Tradition 2.png",
  ),
  "blood bros. bbq": DemoImagePaths(
    "assets/demo/Blood Bros. BBQ.png",
    "assets/demo/Blood Bros. BBQ crew.png",
  ),
  "cool runnings": DemoImagePaths(
    "assets/demo/Cool Runnings.png",
    "assets/demo/Cool Runnings entrance.png",
  ),
  "corkscrew bbq": DemoImagePaths(
    "assets/demo/Corkscrew BBQ.png",
    "assets/demo/Corkscrew BBQ entrance.png",
  ),
  "dona leti's": DemoImagePaths(
    "assets/demo/Dona Leti's.png",
    "assets/demo/Dona Leti's funny.png",
  ),
  "killen's barbecue": DemoImagePaths(
    "assets/demo/Killen's Barbecue.png",
    "assets/demo/Killen's Barbecue 2.png",
  ),
  "killen's steakhouse": DemoImagePaths(
    "assets/demo/Killen's Steakhouse.png",
    "assets/demo/Killen's Steakhouse inside.png",
  ),
  "le jardinier": DemoImagePaths(
    "assets/demo/Le Jardinier.png",
    "assets/demo/Le Jardinier entrance.png",
  ),
  "lost and found": DemoImagePaths(
    "assets/demo/Lost and Found.png",
    "assets/demo/Lost and Found 2.png",
  ),
  "mensho": DemoImagePaths(
    "assets/demo/Mensho.png",
    "assets/demo/Mensho 2.png",
  ),
  "mezza grille": DemoImagePaths(
    "assets/demo/Mezza Grille.png",
    "assets/demo/Mezza Grille 2.png",
  ),
  "musaafer": DemoImagePaths(
    "assets/demo/Musaafer.png",
    "assets/demo/Musaafer entrance.png",
  ),
  "pinkerton's barbecue": DemoImagePaths(
    "assets/demo/Pinkerton's Barbecue.png",
    "assets/demo/Pinkerton's Barbecue desert.png",
  ),
  "rosemeyer bar-b-q": DemoImagePaths(
    "assets/demo/Rosemeyer Bar-B-Q.png",
    "assets/demo/Rosemeyer Bar-B-Q 2.png",
  ),
  "taste bar + kitchen": DemoImagePaths(
    "assets/demo/Taste Bar + Kitchen.png",
    "assets/demo/Taste Bar + Kitchen 2.png",
  ),
  "tatemo": DemoImagePaths(
    "assets/demo/Tatemo.png",
    "assets/demo/Tatemo micheline star.png",
  ),
  "tejas chocolate + barbecue": DemoImagePaths(
    "assets/demo/Tejas Chocolate + Barbecue.png",
    "assets/demo/Tejas Chocolate + Barbecue 2.png",
  ),
  "the birria queen": DemoImagePaths(
    "assets/demo/The Birria Queen.png",
    "assets/demo/The Birria Queen entrance.png",
  ),
  "the pit room": DemoImagePaths(
    "assets/demo/The Pit Room.png",
    "assets/demo/The Pit Room entrance.png",
  ),
  "the puddery": DemoImagePaths(
    "assets/demo/The Puddery.png",
    "assets/demo/The Puddery entrance.png",
  ),
  "the waffle bus": DemoImagePaths(
    "assets/demo/The Waffle Bus.png",
    "assets/demo/The Waffle Bus 2.png",
  ),
  "truth bbq": DemoImagePaths(
    "assets/demo/Truth BBQ.png",
    "assets/demo/Truth BBQ entrance.png",
  ),
  // Singles (primary only)
  "butter funk kitchen": DemoImagePaths("assets/demo/Butter Funk Kitchen.png"),
  "chopnblok": DemoImagePaths("assets/demo/ChopnBlok.png"),
  "crave suya": DemoImagePaths("assets/demo/Crave Suya.png"),
  "handies douzo": DemoImagePaths("assets/demo/Handies Douzo.png"),
  "jamaica pon di road": DemoImagePaths(
    "assets/demo/Jamaica Pon Di Road.png",
  ),
  "nancy's hustle": DemoImagePaths("assets/demo/Nancy's Hustle.png"),
  "stick talk": DemoImagePaths("assets/demo/Stick Talk.png"),
  "the breakfast klub": DemoImagePaths("assets/demo/The Breakfast Klub.png"),
  "the better box": DemoImagePaths("assets/demo/The Better Box.png"),
  "top sushi": DemoImagePaths("assets/demo/Top Sushi.png"),
  // No-primary pairs (first secondary used as primary)
  "hidden omakase": DemoImagePaths(
    "assets/demo/Hidden Omakase inside.png",
    "assets/demo/Hidden Omakase uni.png",
  ),
  "march": DemoImagePaths(
    "assets/demo/March 1.png",
    "assets/demo/March 2.png",
  ),
};
