# Extra sandbox restaurants

Careem's sandbox ships 5 restaurants and 10 dishes. This folder adds 8 more made-up ones (ids 30106-30113) so the
group matching has real choice: burgers, desserts (2), a Jordanian mansaf place, noodles, a second pizza,
breakfast, and healthy spot.

| id | Restaurant | Category |
| --- | --- | --- |
| 30106 | Smash Burger House | Burger |
| 30107 | Sweet Tooth Bakery | Dessert |
| 30108 | Gelato Corner | Dessert |
| 30109 | Sunrise Foul & Falafel | Breakfast |
| 30110 | Wok Express | Asian |
| 30111 | Mandi Palace | Shawarma (Arabic) |
| 30112 | Napoli Slice | Pizza |
| 30113 | Fresh Greens | Healthy |

- Edit `restaurants.py` (names, dishes, prices, options), then run `py -3.12 sandbox/extra/generate.py`.
- The generator only writes between `BEGIN/END extra-restaurants` markers in `food_get_restaurant_menu.md`,
  `food_get_items_options.md` and `food_merchant_search.md`. Careem's original scenarios are never touched.
  `--remove` takes everything out again.
- The server re-reads tool files on every call. Check with `npm test` in `sandbox/server` (all scenarios are validated
  against the tool schemas).
- After changing restaurants, refresh the backend cache: `python catalog.py --refresh` in `backend/`.
- Search queries that find the new places: burger, dessert, gelato, mandi, mansaf, foul, noodles, slice, salad.
