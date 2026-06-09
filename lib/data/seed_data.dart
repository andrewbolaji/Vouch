import 'package:vouch/models/models.dart';

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
    ),
    City(
      id: 'nyc',
      name: 'New York',
      state: 'NY',
      imageUrl:
          'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800',
      description:
          'If you can eat here, you can eat anywhere.',
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
          'Tokyo ramen master Tomoharu Shono\'s Houston'
          ' shop. Michelin-recognized, known for a'
          ' wagyu-meets-Texas-BBQ bowl.',
      rank: 1,
      voteCount: 2847,
      locations: [
        RestaurantLocation(
          name: 'Chinatown',
          address:
              '9889 Bellaire Blvd, Ste C308, Houston, TX 77036',
        ),
      ],
      insiderTip:
          'No reservations and lines form.'
          ' Go off-peak, around 4 PM.',
      whatToOrder:
          'The Wagyu Texas BBQ Tantanmen (smoked A5'
          ' beef). Matcha Duck Ramen for something'
          ' different.',
      vibeTags: ['Quick Bite', 'Cozy', 'Neighborhood Favorite'],
    ),
    Restaurant(
      id: 'hou-2',
      cityId: 'houston',
      name: 'Cool Runnings',
      cuisine: 'Jamaican',
      imageUrl: 'placeholder://restaurant',
      description:
          'Authentic Jamaican and Caribbean cooking from'
          ' a Jamaica-native chef. The brown stew chicken'
          ' and oxtail are the move.',
      rank: 2,
      voteCount: 2534,
      locations: [
        RestaurantLocation(
          name: 'Southwest Houston',
          address:
              '8270 W Bellfort Ave, Houston, TX 77071',
        ),
      ],
      insiderTip:
          'They do not take phone orders. Order ahead'
          ' on DoorDash or come in.',
      whatToOrder:
          'Brown stew chicken, oxtail, and ackee and'
          ' saltfish.',
      vibeTags: ['Flavor Bomb', 'Casual', 'Hidden Gem'],
    ),
    Restaurant(
      id: 'hou-3',
      cityId: 'houston',
      name: 'The Puddery',
      cuisine: 'Dessert',
      imageUrl: 'placeholder://restaurant',
      description:
          'Banana pudding in 30-plus flavors, served in a'
          ' cup, plus the famous Oreo Croffle. The spot'
          ' Keith Lee called the best dessert of his life.',
      rank: 3,
      voteCount: 2298,
      locations: [
        RestaurantLocation(
          name: 'Pearland',
          address:
              '5517 Broadway St, Ste M, Pearland, TX 77581',
        ),
      ],
      insiderTip:
          'Weekend lines wrap the building. Go early or'
          ' on a weeknight.',
      whatToOrder:
          'Banana pudding (any flavor) and the Oreo'
          ' Croffle.',
      vibeTags: ['Sweet Tooth', 'Worth the Wait', 'Date Night'],
    ),
    Restaurant(
      id: 'hou-4',
      cityId: 'houston',
      name: 'Lost and Found',
      cuisine: 'Cocktail Bar + Kitchen',
      imageUrl: 'placeholder://restaurant',
      description:
          'A lively Midtown bar with colorful craft'
          ' cocktails, a downtown-view patio, and a famous'
          ' Travis Scott mural.',
      rank: 4,
      voteCount: 2087,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Midtown',
          address: '160 W Gray St, Houston, TX 77019',
        ),
      ],
      insiderTip:
          'The patio with the downtown skyline view is'
          ' the spot.',
      whatToOrder:
          'Craft cocktails and shareable plates on the'
          ' patio.',
      vibeTags: ['Good Drinks', 'Lively', 'Patio Views'],
    ),
    Restaurant(
      id: 'hou-5',
      cityId: 'houston',
      name: 'Le Jardinier',
      cuisine: 'French',
      imageUrl: 'placeholder://restaurant',
      description:
          'Vegetable-forward modern French inside the'
          ' MFAH. Michelin-starred, from chef Alain'
          ' Verzeroli.',
      rank: 5,
      voteCount: 1876,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Museum District',
          address:
              'Museum of Fine Arts (Kinder Building),'
              ' 5500 Main St, Ste 122, Houston, TX 77004',
        ),
      ],
      insiderTip:
          'Pair lunch with the museum. Patio seats'
          ' overlook the sculpture garden.',
      whatToOrder:
          'The seasonal tasting menu; the burrata and'
          ' Ora King salmon are standouts.',
      vibeTags: ['Date Night', 'Chef-Driven', 'Clean Vibes'],
    ),
    Restaurant(
      id: 'hou-6',
      cityId: 'houston',
      name: "Dona Leti's",
      cuisine: 'Mexican',
      imageUrl: 'placeholder://restaurant',
      description:
          'H-Mex done big. Family-owned, named for the'
          " owners' late mother, famous for quesabirria"
          ' tacos and massive portions.',
      rank: 6,
      voteCount: 1654,
      locations: [
        RestaurantLocation(
          name: 'Southwest Houston',
          address:
              '10425 S Post Oak Rd, Houston, TX 77053',
        ),
      ],
      insiderTip:
          'Portions are huge. Come hungry or plan to'
          ' share.',
      whatToOrder:
          'Quesabirria tacos with consome, and a'
          ' strawberry horchata.',
      vibeTags: ['Big Portions', 'Family-Owned', 'Flavor Bomb'],
    ),
    Restaurant(
      id: 'hou-7',
      cityId: 'houston',
      name: 'Hidden Omakase',
      cuisine: 'Japanese',
      imageUrl: 'placeholder://restaurant',
      description:
          'A hidden, dark 18-seat sushi counter sealed off'
          ' from the strip mall outside. Chef-led omakase,'
          ' BYOB.',
      rank: 7,
      voteCount: 1432,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Galleria / Uptown',
          address:
              '5353 W Alabama St, Ste 102,'
              ' Houston, TX 77056',
        ),
      ],
      insiderTip:
          'Reservations are Resy-only and go fast.'
          ' BYOB with a \$20 corkage.',
      whatToOrder:
          'The omakase. The uni and the wagyu larb hand'
          ' roll are standouts.',
      vibeTags: ['Special Occasion', 'Omakase', 'Hidden Gem'],
    ),
    Restaurant(
      id: 'hou-8',
      cityId: 'houston',
      name: 'Tatemo',
      cuisine: 'Modern Mexican (Masa Tasting Menu)',
      imageUrl: 'placeholder://restaurant',
      description:
          "Houston's Michelin-starred Mexican tasting-menu"
          ' spot, built entirely around heirloom corn and'
          ' house-nixtamalized masa. Chef Emmanuel Chavez.',
      rank: 8,
      voteCount: 1298,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Spring Branch',
          address: '4740 Dacoma St, Houston, TX 77092',
        ),
      ],
      insiderTip:
          'Tasting-menu only, around 13 seats, Thursday'
          ' to Saturday. Reservations release a few weeks'
          ' out and vanish fast.',
      whatToOrder:
          'The multi-course masa tasting menu'
          ' (tasting-menu only). BYOB.',
      vibeTags: ['Hidden Gem', 'Date Night', 'Chef-Driven'],
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
      rank: 9,
      voteCount: 1156,
      locations: [
        RestaurantLocation(
          name: 'Spring',
          address: '26608 Keith St, Spring, TX 77373',
        ),
      ],
      insiderTip:
          'Arrive by 10 AM on weekends or the brisket'
          ' is gone.',
      whatToOrder:
          'Brisket, beef ribs, and the garlic sausage'
          ' links.',
      vibeTags: ['Worth the Drive', 'No Frills', 'Cash Friendly'],
    ),
    Restaurant(
      id: 'hou-10',
      cityId: 'houston',
      name: 'Taste Bar + Kitchen',
      cuisine: 'Southern Comfort + Cocktails',
      imageUrl: 'placeholder://restaurant',
      description:
          'Globally-spun Southern comfort from chef Don'
          ' Bowie. An over-the-top chicken-and-waffles'
          ' menu, craft cocktails, and live entertainment.',
      rank: 10,
      voteCount: 1087,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Midtown',
          address: '3015 Bagby St, Houston, TX 77006',
        ),
      ],
      insiderTip:
          'Live music, comedy, and karaoke through the'
          ' week. Reserve, it gets busy.',
      whatToOrder:
          'Chicken and waffles (try the chicken-fried'
          ' lobster version) and a craft cocktail.',
      vibeTags: ['Lively', 'Group Friendly', 'Comfort Food'],
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
      voteCount: 3241,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Williamsburg',
          address:
              '178 Broadway, Brooklyn, NY 11211',
        ),
      ],
      insiderTip:
          'Reservations book 30 days out.'
          ' Call at exactly noon.',
      whatToOrder:
          'Porterhouse for two. German fried potatoes.'
          ' Creamed spinach.',
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
      voteCount: 2876,
      locations: [
        RestaurantLocation(
          name: 'Midwood',
          address:
              '1424 Avenue J, Brooklyn, NY 11230',
        ),
      ],
      insiderTip:
          'Cash only. The square slice is the move.',
      whatToOrder: 'Square slice. Period.',
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
      voteCount: 2654,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Chelsea Market',
          address:
              '75 9th Ave, New York, NY 10011',
        ),
      ],
      insiderTip:
          'Get the adobada. Skip the line at lunch,'
          ' go at 3 PM.',
      whatToOrder:
          'Adobada taco with everything.'
          ' Horchata to drink.',
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
      voteCount: 2432,
      locations: [
        RestaurantLocation(
          name: 'Lower East Side',
          address:
              '205 E Houston St, New York, NY 10002',
        ),
      ],
      insiderTip:
          'Tip the cutter and they will hook you up'
          ' with extra meat.',
      whatToOrder:
          'Pastrami on rye with mustard. Nothing else.',
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
      voteCount: 2198,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, New York, NY',
        ),
      ],
      insiderTip:
          'Spicy level 1 is already intense.'
          ' You have been warned.',
      whatToOrder:
          'Spicy cumin lamb hand-pulled noodles.',
      vibeTags: [
        'Cash Friendly',
        'Quick Bite',
        'Flavor Bomb',
      ],
    ),
    Restaurant(
      id: 'nyc-6',
      cityId: 'nyc',
      name: "Joe's Pizza",
      cuisine: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      description:
          'The quintessential New York slice.',
      rank: 6,
      voteCount: 1987,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Greenwich Village',
          address:
              '7 Carmine St, New York, NY 10014',
        ),
      ],
      insiderTip:
          'Late night after bars is the real'
          ' experience.',
      whatToOrder: 'Plain cheese slice, folded.',
      vibeTags: ['Late Night', 'Quick Bite', 'Iconic'],
    ),
    Restaurant(
      id: 'nyc-7',
      cityId: 'nyc',
      name: 'Russ & Daughters',
      cuisine: 'Jewish Deli',
      imageUrl:
          'https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800',
      description:
          'Smoked fish and bagels, family-run'
          ' since 1914.',
      rank: 7,
      voteCount: 1765,
      locations: [
        RestaurantLocation(
          name: 'Lower East Side',
          address:
              '179 E Houston St, New York, NY 10002',
        ),
      ],
      insiderTip:
          'The cafe on Orchard St has seating,'
          ' the original is counter only.',
      whatToOrder:
          'Classic bagel with lox, cream cheese,'
          ' capers, onions.',
      vibeTags: [
        'Breakfast Spot',
        'Old School',
        'Iconic',
      ],
    ),
    Restaurant(
      id: 'nyc-8',
      cityId: 'nyc',
      name: 'Sushi Nakazawa',
      cuisine: 'Japanese',
      imageUrl:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800',
      description:
          'Jiro Dreams of Sushi graduate.'
          ' Omakase perfection.',
      rank: 8,
      voteCount: 1543,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'West Village',
          address:
              '23 Commerce St, New York, NY 10014',
        ),
      ],
      insiderTip:
          'Book exactly 30 days ahead via Resy.',
      whatToOrder:
          'Omakase. There is no other option.',
      vibeTags: [
        'Special Occasion',
        'Omakase',
        'Date Night',
      ],
    ),
    Restaurant(
      id: 'nyc-9',
      cityId: 'nyc',
      name: 'Lucali',
      cuisine: 'Pizza',
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      description:
          'BYOB, cash only, no slices.'
          ' The pizza speaks for itself.',
      rank: 9,
      voteCount: 1321,
      locations: [
        RestaurantLocation(
          name: 'Carroll Gardens',
          address:
              '575 Henry St, Brooklyn, NY 11231',
        ),
      ],
      insiderTip:
          'Line up by 4:30 PM. Bring your own wine.',
      whatToOrder:
          'Plain pie with calzone on the side.',
      vibeTags: [
        'BYOB',
        'Worth the Wait',
        'Neighborhood Favorite',
      ],
    ),
    Restaurant(
      id: 'nyc-10',
      cityId: 'nyc',
      name: 'Levain Bakery',
      cuisine: 'Bakery',
      imageUrl:
          'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800',
      description:
          'Cookies the size of your fist.'
          ' Gooey center, crispy outside.',
      rank: 10,
      voteCount: 1198,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Upper West Side',
          address:
              '167 W 74th St, New York, NY 10023',
        ),
      ],
      insiderTip:
          'Go early. They sell out of dark chocolate'
          ' peanut butter by noon.',
      whatToOrder:
          'Dark chocolate peanut butter cookie.',
      vibeTags: [
        'Quick Bite',
        'Sweet Tooth',
        'Tourist Worthy',
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
      voteCount: 2567,
      locations: [
        RestaurantLocation(
          name: 'Arts District',
          address:
              '2000 E 7th St, Los Angeles, CA 90021',
        ),
      ],
      insiderTip:
          'The sweet potato taco is unexpectedly'
          ' the star.',
      whatToOrder:
          'Sweet potato taco and the tuna tostada.',
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
      voteCount: 2345,
      locations: [
        RestaurantLocation(
          name: 'Chinatown',
          address:
              '727 N Broadway, Los Angeles, CA 90012',
        ),
      ],
      insiderTip:
          'Howlin is not a joke. Start at Medium'
          ' your first time.',
      whatToOrder:
          'Sando at Medium with slaw and pickles.',
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
      voteCount: 2123,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Arts District',
          address:
              '2121 E 7th Pl, Los Angeles, CA 90021',
        ),
      ],
      insiderTip:
          'Reservations drop at midnight on Resy,'
          ' 30 days ahead.',
      whatToOrder:
          'Spaghetti rustichella, bone marrow,'
          ' any pizza.',
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
      voteCount: 1876,
      locations: [
        RestaurantLocation(
          name: 'Thai Town',
          address:
              '5233 Sunset Blvd, Los Angeles, CA 90027',
        ),
      ],
      insiderTip:
          'Order from the Southern Thai menu,'
          ' not the regular one.',
      whatToOrder:
          'Crying Tiger beef, morning glory,'
          ' jazz fried rice.',
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
      voteCount: 1654,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Los Angeles, CA',
        ),
      ],
      insiderTip:
          'No modifications, no soy sauce.'
          ' Trust the chef.',
      whatToOrder: 'Trust Me menu. Always.',
      vibeTags: [
        'Omakase',
        'Date Night',
        'Clean Vibes',
      ],
    ),
    Restaurant(
      id: 'la-6',
      cityId: 'la',
      name: "Langer's Deli",
      cuisine: 'Deli',
      imageUrl:
          'https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800',
      description:
          'The #19 pastrami sandwich might be better'
          " than Katz's. We said it.",
      rank: 6,
      voteCount: 1432,
      locations: [
        RestaurantLocation(
          name: 'Westlake',
          address:
              '704 S Alvarado St, Los Angeles, CA 90057',
        ),
      ],
      insiderTip: 'Lunch only. They close at 4 PM.',
      whatToOrder:
          '#19 pastrami with coleslaw and swiss'
          ' on rye.',
      vibeTags: [
        'Old School',
        'Lunch Only',
        'Iconic',
      ],
    ),
    Restaurant(
      id: 'la-7',
      cityId: 'la',
      name: 'Mariscos Jalisco',
      cuisine: 'Mexican Seafood',
      imageUrl:
          'https://images.unsplash.com/photo-1559847844-5315695dadae?w=800',
      description:
          'A taco truck that won a James Beard Award.'
          ' Crispy shrimp tacos.',
      rank: 7,
      voteCount: 1298,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Boyle Heights',
          address:
              '3040 E Olympic Blvd, Los Angeles,'
              ' CA 90023',
        ),
      ],
      insiderTip:
          'Cash only. Get there before the line'
          ' wraps.',
      whatToOrder:
          'Tacos dorados de camaron. Multiple.',
      vibeTags: [
        'Cash Only',
        'Street Food',
        'No Frills',
      ],
    ),
    Restaurant(
      id: 'la-8',
      cityId: 'la',
      name: 'Petit Trois',
      cuisine: 'French',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      description:
          "Ludo Lefebvre's no-reservations French"
          ' bistro. 25 seats.',
      rank: 8,
      voteCount: 1156,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Mid-Wilshire',
          address:
              '718 N Highland Ave, Los Angeles,'
              ' CA 90038',
        ),
      ],
      insiderTip:
          'Go solo and sit at the bar.'
          ' It is the best seat.',
      whatToOrder:
          'Omelette, double cheeseburger,'
          ' and the Big Mec.',
      vibeTags: [
        'Solo Dining',
        'Chef-Driven',
        'Cozy',
      ],
    ),
    Restaurant(
      id: 'la-9',
      cityId: 'la',
      name: 'Pine & Crane',
      cuisine: 'Taiwanese',
      imageUrl:
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800',
      description:
          'Silver Lake Taiwanese that makes dan dan'
          ' noodles worth crossing town for.',
      rank: 9,
      voteCount: 1034,
      locations: [
        RestaurantLocation(
          name: 'Silver Lake',
          address:
              '1521 Griffith Park Blvd,'
              ' Los Angeles, CA 90026',
        ),
      ],
      insiderTip:
          'Their three cup chicken is underrated.',
      whatToOrder:
          'Dan dan noodles, beef roll,'
          ' three cup chicken.',
      vibeTags: [
        'Neighborhood Favorite',
        'Casual',
        'Cash Friendly',
      ],
    ),
    Restaurant(
      id: 'la-10',
      cityId: 'la',
      name: "Porto's Bakery",
      cuisine: 'Cuban Bakery',
      imageUrl:
          'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800',
      description:
          'Cuban bakery chain where the cheese rolls'
          ' cause actual stampedes.',
      rank: 10,
      voteCount: 987,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Los Angeles, CA',
        ),
      ],
      insiderTip:
          'Order online for pickup. The in-store line'
          ' is brutal.',
      whatToOrder:
          'Cheese rolls (a dozen), guava and cheese'
          ' pastry, potato ball.',
      vibeTags: [
        'Sweet Tooth',
        'Cash Friendly',
        'Big Portions',
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
      voteCount: 2987,
      priceLevel: 4,
      locations: [
        RestaurantLocation(
          name: 'Lincoln Park',
          address:
              '1723 N Halsted St, Chicago, IL 60614',
        ),
      ],
      insiderTip:
          'Tickets, not reservations. They sell out'
          ' instantly. Set a calendar alert.',
      whatToOrder:
          'The Gallery menu. You do not choose.'
          ' You experience.',
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
      voteCount: 2765,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Chicago, IL',
        ),
      ],
      insiderTip:
          'Get the combo: Italian beef dipped with'
          ' hot peppers plus a Chicago dog.',
      whatToOrder:
          'Italian beef, dipped, hot. Chicago-style'
          ' hot dog. Chocolate cake shake.',
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
      voteCount: 2543,
      locations: [
        RestaurantLocation(
          name: 'Multiple locations',
          address: 'Various, Chicago, IL',
        ),
      ],
      insiderTip:
          'Order ahead. A real deep dish takes'
          ' 45 minutes.',
      whatToOrder:
          'Buttercrust deep dish with sausage.',
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
      voteCount: 2321,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'West Loop',
          address:
              '809 W Randolph St, Chicago, IL 60607',
        ),
      ],
      insiderTip:
          'The goat empanadas are a must.'
          ' Do not skip them.',
      whatToOrder:
          'Goat empanadas, hamachi crudo,'
          ' wood oven pig face.',
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
      voteCount: 2098,
      locations: [
        RestaurantLocation(
          name: 'Irving Park',
          address:
              '3800 N Pulaski Rd, Chicago, IL 60641',
        ),
      ],
      insiderTip:
          'Get there before noon on weekends or'
          ' brisket sells out.',
      whatToOrder:
          'Brisket and half rack of ribs.'
          ' Mac and cheese.',
      vibeTags: [
        'No Frills',
        'Worth the Wait',
        'Casual',
      ],
    ),
    Restaurant(
      id: 'chi-6',
      cityId: 'chicago',
      name: 'Au Cheval',
      cuisine: 'Burgers',
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
      description:
          'The burger that launched a thousand wait'
          ' lists. Single or double, both legendary.',
      rank: 6,
      voteCount: 1876,
      locations: [
        RestaurantLocation(
          name: 'West Loop',
          address:
              '800 W Randolph St, Chicago, IL 60607',
        ),
      ],
      insiderTip:
          'Put your name in before you want to eat.'
          ' The wait is real.',
      whatToOrder:
          'Double cheeseburger with egg and bacon.',
      vibeTags: [
        'Worth the Wait',
        'Late Night',
        'Iconic',
      ],
    ),
    Restaurant(
      id: 'chi-7',
      cityId: 'chicago',
      name: "Dove's Luncheonette",
      cuisine: 'Tex-Mex',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description:
          'Retro Tex-Mex diner with vinyl playing'
          ' and mezcal flowing.',
      rank: 7,
      voteCount: 1654,
      locations: [
        RestaurantLocation(
          name: 'Wicker Park',
          address:
              '1545 N Damen Ave, Chicago, IL 60622',
        ),
      ],
      insiderTip:
          'Brunch is chaos in the best way.'
          ' The playlist alone is worth the wait.',
      whatToOrder:
          'Fried chicken torta, elote,'
          ' any mezcal cocktail.',
      vibeTags: [
        'Brunch Spot',
        'Cozy',
        'Good Drinks',
      ],
    ),
    Restaurant(
      id: 'chi-8',
      cityId: 'chicago',
      name: "Jim's Original",
      cuisine: 'Hot Dogs',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description:
          'Maxwell Street Polish sausage stand, open'
          ' since 1939. Cash, no frills.',
      rank: 8,
      voteCount: 1432,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'University Village',
          address:
              '1250 S Union Ave, Chicago, IL 60607',
        ),
      ],
      insiderTip:
          "3 AM after a night out is peak Jim's.",
      whatToOrder:
          'Maxwell Street Polish with grilled onions'
          ' and sport peppers.',
      vibeTags: [
        'Late Night',
        'Cash Only',
        'Street Food',
      ],
    ),
    Restaurant(
      id: 'chi-9',
      cityId: 'chicago',
      name: 'Kasama',
      cuisine: 'Filipino',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description:
          'First Filipino restaurant to earn a Michelin'
          ' star. Bakery by day, tasting menu by night.',
      rank: 9,
      voteCount: 1287,
      priceLevel: 3,
      locations: [
        RestaurantLocation(
          name: 'Ukrainian Village',
          address:
              '1001 N Winchester Ave, Chicago,'
              ' IL 60622',
        ),
      ],
      insiderTip:
          'Daytime bakery requires no reservation.'
          ' Night tasting books out weeks ahead.',
      whatToOrder:
          'Longanisa breakfast sandwich (day).'
          ' Full tasting (night).',
      vibeTags: [
        'Chef-Driven',
        'Breakfast Spot',
        'Hidden Gem',
      ],
    ),
    Restaurant(
      id: 'chi-10',
      cityId: 'chicago',
      name: "Mister D's",
      cuisine: 'Diner',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      description:
          'Old-school Chicago diner. Greek owners,'
          ' massive portions, bottomless coffee.',
      rank: 10,
      voteCount: 1098,
      priceLevel: 1,
      locations: [
        RestaurantLocation(
          name: 'South Loop',
          address:
              '2 E Roosevelt Rd, Chicago, IL 60605',
        ),
      ],
      insiderTip:
          'The gyros plate is enough for two people.',
      whatToOrder:
          'Gyros plate, Greek omelet, slice of pie.',
      vibeTags: [
        'Old School',
        'Big Portions',
        'Breakfast Spot',
      ],
    ),
  ];
}
