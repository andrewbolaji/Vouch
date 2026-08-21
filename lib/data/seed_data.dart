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
      id: 'hou-18',
      cityId: 'houston',
      name: 'ChòpnBlọk',
      cuisine: 'West African',
      imageUrl: 'placeholder://restaurant',
      description: 'West African. Montrose.',
      rank: 1,
      locations: [
        RestaurantLocation(
          name: 'Montrose',
          address: '507 Westheimer Rd, Houston, TX 77006',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-1',
      cityId: 'houston',
      name: 'Mensho',
      cuisine: 'Ramen',
      imageUrl: 'placeholder://restaurant',
      description: 'Ramen. Chinatown.',
      rank: 2,
      locations: [
        RestaurantLocation(
          name: 'Chinatown',
          address:
              '9889 Bellaire Blvd, Ste C308, Houston, TX 77036',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-9',
      cityId: 'houston',
      name: 'CorkScrew BBQ',
      cuisine: 'Barbecue',
      imageUrl: 'placeholder://restaurant',
      description: 'Barbecue. Old Town Spring.',
      rank: 3,
      locations: [
        RestaurantLocation(
          name: 'Old Town Spring',
          address: '26608 Keith St, Spring, TX 77373',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-19',
      cityId: 'houston',
      name: 'Roostar',
      cuisine: 'Vietnamese',
      imageUrl: 'placeholder://restaurant',
      description: 'Vietnamese. Second Ward.',
      rank: 4,
      locations: [
        RestaurantLocation(
          name: 'Second Ward',
          address:
              '2929 Navigation Blvd, Ste 190, Houston, TX 77003',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-16',
      cityId: 'houston',
      name: 'JOEY Uptown',
      cuisine: 'New American',
      imageUrl: 'placeholder://restaurant',
      description: 'New American. Uptown.',
      rank: 5,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Uptown',
          address:
              '5045 Westheimer Rd, Ste X01, Houston, TX 77056',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-13',
      cityId: 'houston',
      name: 'The Peri Peri Factory',
      cuisine: 'Peri Peri Chicken',
      imageUrl: 'placeholder://restaurant',
      description: 'Peri peri chicken. Mid-West.',
      rank: 6,
      locations: [
        RestaurantLocation(
          name: 'Mid-West',
          address: '6375 Westheimer Rd, Houston, TX 77057',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-4',
      cityId: 'houston',
      name: 'Lost & Found',
      cuisine: 'American',
      imageUrl: 'placeholder://restaurant',
      description: 'Cocktails and American food. Midtown.',
      rank: 7,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Midtown',
          address: '160 W Gray St, Houston, TX 77019',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-14',
      cityId: 'houston',
      name: 'Top Sushi',
      cuisine: 'Sushi',
      imageUrl: 'placeholder://restaurant',
      description: 'Japanese sushi. Mid-West.',
      rank: 8,
      locations: [
        RestaurantLocation(
          name: 'Mid-West',
          address:
              '8401 Westheimer Rd, Ste 160, Houston, TX 77063',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-15',
      cityId: 'houston',
      name: 'The Better Box',
      cuisine: 'Comfort Food',
      imageUrl: 'placeholder://restaurant',
      description: 'Comfort food. Northwest Houston.',
      rank: 9,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Northwest Houston',
          address: '8902 Fallbrook Dr, Houston, TX 77064',
        ),
      ],
    ),
    Restaurant(
      id: 'hou-20',
      cityId: 'houston',
      name: 'Caribbean Jerk Palace',
      cuisine: 'Caribbean',
      imageUrl: 'placeholder://restaurant',
      description:
          'Big portions and deeply seasoned food. Pricier, with slower service.',
      rank: 10,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Third Ward',
          address: '3801 Emancipation Ave, Houston, TX 77004',
        ),
      ],
      whatToOrder: 'Oxtails with mac and cheese',
      insiderTip:
          'Smothered turkey necks with distinctive gravy and real tenderism.',
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
      description: '',
      rank: 1,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Williamsburg',
          address:
              '178 Broadway, Brooklyn, NY 11211',
        ),
      ],
    ),
    Restaurant(
      id: 'nyc-2',
      cityId: 'nyc',
      name: 'Di Fara Pizza',
      cuisine: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      description: '',
      rank: 2,
      locations: [
        RestaurantLocation(
          name: 'Midwood',
          address:
              '1424 Avenue J, Brooklyn, NY 11230',
        ),
      ],
    ),
    Restaurant(
      id: 'nyc-3',
      cityId: 'nyc',
      name: 'Los Tacos No. 1',
      cuisine: 'Mexican',
      imageUrl:
          'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800',
      description: '',
      rank: 3,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Chelsea Market',
          address:
              '75 9th Ave, New York, NY 10011',
        ),
      ],
    ),
    Restaurant(
      id: 'nyc-4',
      cityId: 'nyc',
      name: "Katz's Delicatessen",
      cuisine: 'Deli',
      imageUrl:
          'https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800',
      description: '',
      rank: 4,
      locations: [
        RestaurantLocation(
          name: 'Lower East Side',
          address:
              '205 E Houston St, New York, NY 10002',
        ),
      ],
    ),
    Restaurant(
      id: 'nyc-5',
      cityId: 'nyc',
      name: "Xi'an Famous Foods",
      cuisine: 'Chinese',
      imageUrl:
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800',
      description: '',
      rank: 5,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, New York, NY',
        ),
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
      description: '',
      rank: 1,
      locations: [
        RestaurantLocation(
          name: 'Arts District',
          address:
              '2000 E 7th St, Los Angeles, CA 90021',
        ),
      ],
    ),
    Restaurant(
      id: 'la-2',
      cityId: 'la',
      name: "Howlin' Ray's",
      cuisine: 'Hot Chicken',
      imageUrl:
          'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=800',
      description: '',
      rank: 2,
      locations: [
        RestaurantLocation(
          name: 'Chinatown',
          address:
              '727 N Broadway, Los Angeles, CA 90012',
        ),
      ],
    ),
    Restaurant(
      id: 'la-3',
      cityId: 'la',
      name: 'Bestia',
      cuisine: 'Italian',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      description: '',
      rank: 3,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Arts District',
          address:
              '2121 E 7th Pl, Los Angeles, CA 90021',
        ),
      ],
    ),
    Restaurant(
      id: 'la-4',
      cityId: 'la',
      name: 'Jitlada',
      cuisine: 'Thai',
      imageUrl:
          'https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?w=800',
      description: '',
      rank: 4,
      locations: [
        RestaurantLocation(
          name: 'Thai Town',
          address:
              '5233 Sunset Blvd, Los Angeles, CA 90027',
        ),
      ],
    ),
    Restaurant(
      id: 'la-5',
      cityId: 'la',
      name: 'Sugarfish',
      cuisine: 'Japanese',
      imageUrl:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800',
      description: '',
      rank: 5,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Los Angeles, CA',
        ),
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
      description: '',
      rank: 1,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Lincoln Park',
          address:
              '1723 N Halsted St, Chicago, IL 60614',
        ),
      ],
    ),
    Restaurant(
      id: 'chi-2',
      cityId: 'chicago',
      name: "Portillo's",
      cuisine: 'Hot Dogs',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description: '',
      rank: 2,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Chicago, IL',
        ),
      ],
    ),
    Restaurant(
      id: 'chi-3',
      cityId: 'chicago',
      name: "Lou Malnati's",
      cuisine: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      description: '',
      rank: 3,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Chicago, IL',
        ),
      ],
    ),
    Restaurant(
      id: 'chi-4',
      cityId: 'chicago',
      name: 'Girl & The Goat',
      cuisine: 'Modern American',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      description: '',
      rank: 4,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'West Loop',
          address:
              '809 W Randolph St, Chicago, IL 60607',
        ),
      ],
    ),
    Restaurant(
      id: 'chi-5',
      cityId: 'chicago',
      name: 'Smoque BBQ',
      cuisine: 'BBQ',
      imageUrl:
          'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800',
      description: '',
      rank: 5,
      locations: [
        RestaurantLocation(
          name: 'Irving Park',
          address:
              '3800 N Pulaski Rd, Chicago, IL 60641',
        ),
      ],
    ),
  ];
}
