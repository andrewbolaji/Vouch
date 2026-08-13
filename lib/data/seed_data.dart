import 'package:vouch/models/models.dart';

/// Offline fallback content. Free tier only, by construction.
///
/// Everything in here is compiled into the release binary and is
/// readable by anyone willing to unzip the app, so it may hold only
/// what an unauthenticated user is already entitled to see. It
/// carries ranks 1 to `kFreeTierMaxRank` and no insider notes.
///
/// Verified by `strings -a` on the iOS AOT snapshot rather than by
/// reading this file, because the point is what survives compilation:
///
///   flutter build ios --release --no-codesign
///   strings -a build/ios/iphoneos/Runner.app/Frameworks/App.framework/App \
///     | grep -cF "`<canary>`"
///
/// Two other methods produce confident false passes and must not be
/// used: grepping `main.dart.js` from a web build (dart2js does not
/// preserve the strings, so the control disappears too), and `grep -c`
/// straight at the binary without `strings` (returns 0 for
/// everything). Always grep before the change and show the canary is
/// found. See docs/REMEDIATION_STATE.md, "Finding 4".
///
/// The gated content that used to live here is now in
/// `test/helpers/gated_fixtures.dart`. It was moved rather than
/// deleted: a `findsNothing` assertion against a string that exists
/// nowhere passes for the wrong reason, and two tests had already
/// been caught doing exactly that.
///
/// A fallback list is a truncated list, not a short one. Anything
/// rendering it must say so, see `AppState.isOffline`.
class SeedData {
  SeedData._();

  static const List<City> cities = [
    City(
      id: 'houston',
      name: 'Houston',
      state: 'TX',
      imageUrl:
          'https://images.unsplash.com/photo-1530089711124-9ca31fb9e863?w=800',
      description:
          'The most diverse food city in America. No debate.',
      restaurantCount: 10,
      status: CityStatus.live,
    ),
    City(
      id: 'atlanta',
      name: 'Atlanta',
      state: 'GA',
      imageUrl:
          'https://images.unsplash.com/photo-1575917649111-0cee4e0e4b5b?w=800',
      description:
          'Where soul food meets global flavor.'
          ' The South starts here.',
      restaurantCount: 17,
      status: CityStatus.live,
    ),
    City(
      id: 'nyc',
      name: 'New York',
      state: 'NY',
      imageUrl:
          'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800',
      description:
          'Only the best survive here.',
      restaurantCount: 10,
    ),
    City(
      id: 'la',
      name: 'Los Angeles',
      state: 'CA',
      imageUrl:
          'https://images.unsplash.com/photo-1534190760961-74e8c1c5c3da?w=800',
      description:
          'Tacos, sushi, and everything between. Always outside.',
      restaurantCount: 10,
    ),
    City(
      id: 'chicago',
      name: 'Chicago',
      state: 'IL',
      imageUrl:
          'https://images.unsplash.com/photo-1494522855154-9297ac14b55f?w=800',
      description: 'Deep dish is just the beginning.',
      restaurantCount: 10,
    ),
  ];

  static const List<Restaurant> restaurants = [
    // Houston
    Restaurant(
      id: 'hou-1',
      cityId: 'houston',
      name: 'Mensho',
      cuisine: 'Ramen',
      imageUrl: 'placeholder://restaurant',
      description:
          "Tokyo ramen master Tomoharu Shono's Houston"
          ' shop. Michelin-recognized, known for a'
          ' wagyu-meets-Texas-BBQ bowl.',
      rank: 1,
      locations: [
        RestaurantLocation(
          name: 'Chinatown',
          address:
              '9889 Bellaire Blvd, Ste C308, Houston, TX 77036',
        ),
      ],
      vibeTags: ['Quick Bite', 'Cozy', 'Neighborhood Favorite'],
    ),
    Restaurant(
      id: 'hou-11',
      cityId: 'houston',
      name: 'Tacos Los Brothers',
      cuisine: 'Mexican (Tacos)',
      imageUrl: 'placeholder://restaurant',
      description:
          'Dollar tacos from a gas-station truck that'
          ' somehow became the best late-night move in'
          ' Houston. Carne asada, al pastor, fresh'
          ' tortillas.',
      rank: 2,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'South Main',
          address: '9365 S Main St, Houston, TX 77025',
        ),
      ],
      vibeTags: ['Late Night', 'Cash Friendly', 'No Frills'],
      isMobileVenue: true,
    ),
    Restaurant(
      id: 'hou-12',
      cityId: 'houston',
      name: 'Crave Suya',
      cuisine: 'West African',
      imageUrl: 'placeholder://restaurant',
      description:
          'Nigerian suya done right, from a food truck'
          ' that draws lines across Houston. Spicy'
          ' grilled beef skewers with yaji seasoning.',
      rank: 3,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Richmond Ave',
          address:
              '8633 Richmond Ave, Houston, TX 77063',
        ),
      ],
      vibeTags: ['Flavor Bomb', 'Hidden Gem', 'Cash Friendly'],
      isMobileVenue: true,
    ),
    Restaurant(
      id: 'hou-13',
      cityId: 'houston',
      name: 'The Peri Peri Factory',
      cuisine: 'Portuguese-African (Peri Peri Chicken)',
      imageUrl: 'placeholder://restaurant',
      description:
          'Flame-grilled peri peri chicken with sauces'
          ' from mild to extra hot. Houston first.'
          ' Halal-certified.',
      rank: 4,
      locations: [
        RestaurantLocation(
          name: 'Westheimer',
          address:
              '6375 Westheimer Rd, Houston, TX 77057',
        ),
      ],
      vibeTags: ['Spicy', 'Halal', 'Casual'],
    ),
    Restaurant(
      id: 'hou-9',
      cityId: 'houston',
      name: 'Corkscrew BBQ',
      cuisine: 'BBQ',
      imageUrl: 'placeholder://restaurant',
      description:
          'Pitmaster Will Buckman cooks over all-wood'
          ' fires. Michelin-starred in 2024. Get there'
          ' early or eat somewhere else.',
      rank: 5,
      locations: [
        RestaurantLocation(
          name: 'Spring',
          address: '26608 Keith St, Spring, TX 77373',
        ),
      ],
      vibeTags: ['Worth the Drive', 'No Frills', 'Cash Friendly'],
    ),

    // Atlanta
    Restaurant(
      id: 'atl-1',
      cityId: 'atlanta',
      name: 'Pasta da Pulcinella',
      cuisine: 'Italian',
      imageUrl: 'placeholder://restaurant',
      description: '',
      rank: 1,
      locations: [
        RestaurantLocation(
          name: 'Midtown',
          address:
              '1100 W Peachtree St NW, Atlanta, GA 30309',
        ),
      ],
    ),
    Restaurant(
      id: 'atl-2',
      cityId: 'atlanta',
      name: 'Pollo Primo',
      cuisine: 'Sinaloan grilled chicken',
      imageUrl: 'placeholder://restaurant',
      description: '',
      rank: 2,
      locations: [
        RestaurantLocation(
          name: 'East Atlanta Village',
          address:
              '792 Moreland Ave SE, Atlanta, GA 30316',
        ),
      ],
    ),
    Restaurant(
      id: 'atl-3',
      cityId: 'atlanta',
      name: 'Best Wings',
      cuisine: 'Wings',
      imageUrl: 'placeholder://restaurant',
      description: '',
      rank: 3,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Old Fourth Ward',
          address:
              '463 Ponce De Leon Ave NE, Atlanta,'
              ' GA 30308',
        ),
      ],
    ),
    Restaurant(
      id: 'atl-4',
      cityId: 'atlanta',
      name: 'Red Rice',
      cuisine: 'Soul food',
      imageUrl: 'placeholder://restaurant',
      description: '',
      rank: 4,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'East Atlanta (Moreland Ave)',
          address:
              '1401 Moreland Ave SE, Atlanta, GA 30316',
        ),
      ],
    ),
    Restaurant(
      id: 'atl-5',
      cityId: 'atlanta',
      name: "Poor Calvin's",
      cuisine: 'Southern-Asian fusion',
      imageUrl: 'placeholder://restaurant',
      description: '',
      rank: 5,
      locations: [
        RestaurantLocation(
          name: 'Midtown',
          address:
              '510 Piedmont Ave NE, Atlanta, GA 30308',
        ),
      ],
    ),

    // NYC
    Restaurant(
      id: 'nyc-1',
      cityId: 'nyc',
      name: 'Peter Luger',
      cuisine: 'Steakhouse',
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
      description:
          'Cash only, no menu needed.'
          ' Porterhouse for two since 1887.',
      rank: 1,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Williamsburg',
          address:
              '178 Broadway, Brooklyn, NY 11211',
        ),
      ],
      vibeTags: [
        'Iconic',
        'Special Occasion',
        'Old School',
      ],
    ),
    Restaurant(
      id: 'nyc-2',
      cityId: 'nyc',
      name: 'Di Fara Pizza',
      cuisine: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      description:
          'Dom DeMarco has been hand-cutting basil on'
          ' every slice since 1965.',
      rank: 2,
      locations: [
        RestaurantLocation(
          name: 'Midwood',
          address:
              '1424 Avenue J, Brooklyn, NY 11230',
        ),
      ],
      vibeTags: [
        'Iconic',
        'Cash Only',
        'Worth the Wait',
      ],
    ),
    Restaurant(
      id: 'nyc-3',
      cityId: 'nyc',
      name: 'Los Tacos No. 1',
      cuisine: 'Mexican',
      imageUrl:
          'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800',
      description:
          'Proof that a taco stand in a food hall can'
          ' be world-class.',
      rank: 3,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Chelsea Market',
          address:
              '75 9th Ave, New York, NY 10011',
        ),
      ],
      vibeTags: [
        'Quick Bite',
        'Cash Friendly',
        'No Frills',
      ],
    ),
    Restaurant(
      id: 'nyc-4',
      cityId: 'nyc',
      name: "Katz's Delicatessen",
      cuisine: 'Deli',
      imageUrl:
          'https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800',
      description:
          'Do not lose your ticket. The pastrami has'
          ' been perfect since 1888.',
      rank: 4,
      locations: [
        RestaurantLocation(
          name: 'Lower East Side',
          address:
              '205 E Houston St, New York, NY 10002',
        ),
      ],
      vibeTags: [
        'Iconic',
        'Tourist Worthy',
        'Old School',
      ],
    ),
    Restaurant(
      id: 'nyc-5',
      cityId: 'nyc',
      name: "Xi'an Famous Foods",
      cuisine: 'Chinese',
      imageUrl:
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800',
      description:
          'Hand-pulled noodles and cumin lamb that built'
          ' an empire from a basement.',
      rank: 5,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, New York, NY',
        ),
      ],
      vibeTags: [
        'Cash Friendly',
        'Quick Bite',
        'Flavor Bomb',
      ],
    ),

    // LA
    Restaurant(
      id: 'la-1',
      cityId: 'la',
      name: 'Guerrilla Tacos',
      cuisine: 'Mexican',
      imageUrl:
          'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800',
      description:
          'Chef Wes Avila turned a taco cart into an'
          ' LA institution.',
      rank: 1,
      locations: [
        RestaurantLocation(
          name: 'Arts District',
          address:
              '2000 E 7th St, Los Angeles, CA 90021',
        ),
      ],
      vibeTags: [
        'Chef-Driven',
        'Casual',
        'Adventurous',
      ],
    ),
    Restaurant(
      id: 'la-2',
      cityId: 'la',
      name: "Howlin' Ray's",
      cuisine: 'Hot Chicken',
      imageUrl:
          'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=800',
      description:
          'Nashville hot chicken that makes Angelenos'
          ' wait 3 hours happily.',
      rank: 2,
      locations: [
        RestaurantLocation(
          name: 'Chinatown',
          address:
              '727 N Broadway, Los Angeles, CA 90012',
        ),
      ],
      vibeTags: [
        'Worth the Wait',
        'Spicy',
        'Loud and Fun',
      ],
    ),
    Restaurant(
      id: 'la-3',
      cityId: 'la',
      name: 'Bestia',
      cuisine: 'Italian',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      description:
          'Industrial-chic Italian that still requires'
          ' booking weeks out.',
      rank: 3,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Arts District',
          address:
              '2121 E 7th Pl, Los Angeles, CA 90021',
        ),
      ],
      vibeTags: [
        'Date Night',
        'Group Friendly',
        'Trendy',
      ],
    ),
    Restaurant(
      id: 'la-4',
      cityId: 'la',
      name: 'Jitlada',
      cuisine: 'Thai',
      imageUrl:
          'https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?w=800',
      description:
          'Southern Thai food that does not compromise'
          ' on spice. Jonathan Gold approved.',
      rank: 4,
      locations: [
        RestaurantLocation(
          name: 'Thai Town',
          address:
              '5233 Sunset Blvd, Los Angeles, CA 90027',
        ),
      ],
      vibeTags: [
        'Hidden Gem',
        'Spicy',
        'Flavor Bomb',
      ],
    ),
    Restaurant(
      id: 'la-5',
      cityId: 'la',
      name: 'Sugarfish',
      cuisine: 'Japanese',
      imageUrl:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800',
      description:
          "Kazunori Nozawa's approachable omakase."
          ' "Trust Me" is the only order.',
      rank: 5,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Los Angeles, CA',
        ),
      ],
      vibeTags: [
        'Omakase',
        'Date Night',
        'Clean Vibes',
      ],
    ),

    // Chicago
    Restaurant(
      id: 'chi-1',
      cityId: 'chicago',
      name: 'Alinea',
      cuisine: 'Molecular Gastronomy',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      description:
          "Grant Achatz's three-Michelin-star temple of"
          ' creativity. Dining as performance art.',
      rank: 1,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Lincoln Park',
          address:
              '1723 N Halsted St, Chicago, IL 60614',
        ),
      ],
      vibeTags: [
        'Special Occasion',
        'Adventurous',
        'Chef-Driven',
      ],
    ),
    Restaurant(
      id: 'chi-2',
      cityId: 'chicago',
      name: "Portillo's",
      cuisine: 'Hot Dogs',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description:
          'Chicago institution. Italian beef and hot'
          ' dogs that define the city.',
      rank: 2,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Chicago, IL',
        ),
      ],
      vibeTags: [
        'Iconic',
        'Cash Friendly',
        'Big Portions',
      ],
    ),
    Restaurant(
      id: 'chi-3',
      cityId: 'chicago',
      name: "Lou Malnati's",
      cuisine: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      description:
          'Deep dish done right. Butter crust, sausage'
          ' patty, chunky tomato.',
      rank: 3,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Chicago, IL',
        ),
      ],
      vibeTags: [
        'Iconic',
        'Group Friendly',
        'Tourist Worthy',
      ],
    ),
    Restaurant(
      id: 'chi-4',
      cityId: 'chicago',
      name: 'Girl & The Goat',
      cuisine: 'Modern American',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      description:
          "Stephanie Izard's flagship. Bold flavors,"
          ' every dish fights for your attention.',
      rank: 4,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'West Loop',
          address:
              '809 W Randolph St, Chicago, IL 60607',
        ),
      ],
      vibeTags: [
        'Chef-Driven',
        'Date Night',
        'Trendy',
      ],
    ),
    Restaurant(
      id: 'chi-5',
      cityId: 'chicago',
      name: 'Smoque BBQ',
      cuisine: 'BBQ',
      imageUrl:
          'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800',
      description:
          'Texas-style BBQ in Chicago that Texans'
          ' actually respect.',
      rank: 5,
      locations: [
        RestaurantLocation(
          name: 'Irving Park',
          address:
              '3800 N Pulaski Rd, Chicago, IL 60641',
        ),
      ],
      vibeTags: [
        'No Frills',
        'Worth the Wait',
        'Casual',
      ],
    ),
  ];
}
