---
tool: food_get_restaurant_menu
domain: food
---

# food_get_restaurant_menu

Full menu for one restaurant: categories → items → option groups (same group/option ids as
`food_get_item_options`). Keyed on The local server restaurant ids 30101–30105.

Scheduled orders: pass the `from`/`to` of a slot from `food_get_scheduling_slots` (confirmed with
`food_check_slot_availability`) as `scheduled_slot_start`/`scheduled_slot_end` and the menu is
evaluated for that slot. The local server models this for Morning Syrniki Café `30104`
(`scheduled-slot-syrniki`); Green Bowl Co. `30105` does not accept scheduled orders
(`scheduled-slot-not-supported`). For the other restaurants a slot is ignored and the regular menu
is returned.

Triggers: `restaurant_id` 30101–30105 → that menu, `39999` → `upstream-unavailable`, only one of
the two slot fields (as an ISO time plus `""`) → `half-specified-slot`, anything else →
`restaurant-not-found`.

Try: "show me the Morning Syrniki Café menu", "what can I get from Morning Syrniki tomorrow at 9?".

## Scenario: upstream-unavailable

`restaurant_id: 39999` → upstream 503.

```json match
{
  "restaurant_id": 39999
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "error": "failed to get restaurant menu: unexpected response status 503"
}
```

## Scenario: half-specified-slot

Only one slot bound set (here `scheduled_slot_end: ""`) → validation error, no upstream call.

```json match
{
  "scheduled_slot_start": "~T",
  "scheduled_slot_end": ""
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "error": "scheduled_slot_start and scheduled_slot_end must both be set, or both omitted"
}
```

## Scenario: half-specified-slot-start

Mirror case: `scheduled_slot_start: ""` with an end time → same validation error.

```json match
{
  "scheduled_slot_start": "",
  "scheduled_slot_end": "~T"
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "error": "scheduled_slot_start and scheduled_slot_end must both be set, or both omitted"
}
```

## Scenario: scheduled-slot-syrniki

Restaurant `30104` with both slot bounds (any values, typically from `food_get_scheduling_slots`) → the menu evaluated for that slot; `availability_details.scheduling.requested_slot` echoes the slot.

```json match
{
  "restaurant_id": 30104,
  "scheduled_slot_start": "*",
  "scheduled_slot_end": "*"
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30104,
    "name": {
      "value": "Morning Syrniki Café",
      "localized_value": "Morning Syrniki Café"
    },
    "location": {
      "value": "Dubai Marina",
      "localized_value": "Dubai Marina"
    },
    "availability_details": {
      "is_available": true,
      "title": "Scheduled order",
      "subtitle": "Delivery in your chosen slot",
      "scheduling": {
        "requested_slot": {
          "start": "{{args.scheduled_slot_start}}",
          "end": "{{args.scheduled_slot_end}}",
          "is_available": true,
          "title": "Slot available",
          "subtitle": "We'll deliver within your chosen slot"
        }
      }
    },
    "brand": {
      "id": 130104,
      "name": "Morning Syrniki Café",
      "name_localized": "Morning Syrniki Café",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/morning-syrniki-cafe.png",
      "link": "careem://food.careem.com/restaurants/brands/130104",
      "brand_media": []
    },
    "brand_id": 130104,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0851,
      "lng": 55.1462
    },
    "cuisines": [
      {
        "id": 21,
        "name": "Breakfast",
        "name_localized": "Breakfast",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/breakfast.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 47,
        "name": "Eastern European",
        "name_localized": "Eastern European",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/ukrainian.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 25,
      "careem_delivery_fee": 5,
      "delivery_method": "scheduled",
      "delivery_type": "careem",
      "distance_in_km": 0.4,
      "fee": 5,
      "range": "20 - 30",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/morning-syrniki-cafe-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": true,
    "is_new": false,
    "item_count": 2,
    "link": "careemfood://restaurants/30104",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/morning-syrniki-cafe-logo.png",
    "menu": {
      "id": 301040,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301041,
          "name": "Syrniki",
          "name_localized": "Syrniki",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/syrniki.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700401,
              "item": "Classic Syrniki with Sour Cream",
              "item_localized": "Classic Syrniki with Sour Cream",
              "description": "Four golden cottage-cheese pancakes served with your choice of topping.",
              "description_localized": "Four golden cottage-cheese pancakes served with your choice of topping.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700401.jpg",
              "active": true,
              "groups": [
                {
                  "id": 84011,
                  "name": "Choose your topping",
                  "name_localized": "Choose your topping",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 840111,
                      "item": "Sour cream",
                      "item_localized": "Sour cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840112,
                      "item": "Berry jam",
                      "item_localized": "Berry jam",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840113,
                      "item": "Condensed milk",
                      "item_localized": "Condensed milk",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    }
                  ]
                },
                {
                  "id": 84012,
                  "name": "Add-ons",
                  "name_localized": "Add-ons",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 0,
                  "max": 2,
                  "multi_select": true,
                  "order": 2,
                  "options": [
                    {
                      "id": 840121,
                      "item": "Extra sour cream",
                      "item_localized": "Extra sour cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    },
                    {
                      "id": 840122,
                      "item": "Fresh berries",
                      "item_localized": "Fresh berries",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 6,
                        "total": 6
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30104/items/700401",
              "master_product_id": "mp_700401",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 34,
                "total": 34
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30104/items/700401"
            }
          ]
        },
        {
          "id": 301042,
          "name": "Coffee",
          "name_localized": "Coffee",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/coffee.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700402,
              "item": "Cappuccino",
              "item_localized": "Cappuccino",
              "description": "Double-shot espresso with steamed milk foam.",
              "description_localized": "Double-shot espresso with steamed milk foam.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700402.jpg",
              "active": true,
              "groups": [
                {
                  "id": 84021,
                  "name": "Choose your milk",
                  "name_localized": "Choose your milk",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 840211,
                      "item": "Full cream",
                      "item_localized": "Full cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840212,
                      "item": "Oat",
                      "item_localized": "Oat",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    },
                    {
                      "id": 840213,
                      "item": "Almond",
                      "item_localized": "Almond",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    }
                  ]
                },
                {
                  "id": 84022,
                  "name": "Choose your size",
                  "name_localized": "Choose your size",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 2,
                  "options": [
                    {
                      "id": 840221,
                      "item": "Regular",
                      "item_localized": "Regular",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840222,
                      "item": "Large",
                      "item_localized": "Large",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30104/items/700402",
              "master_product_id": "mp_700402",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 19,
                "total": 19
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30104/items/700402"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 12,
    "price": {
      "average": 45,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.8,
      "average_text": "4.8",
      "count": 640,
      "count_text": "640",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30104?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: scheduled-slot-not-supported

Restaurant `30105` (Green Bowl Co. does not accept scheduled orders) with a slot → menu returned, but `scheduling_enabled: false` and `requested_slot.is_available: false`.

```json match
{
  "restaurant_id": 30105,
  "scheduled_slot_start": "*",
  "scheduled_slot_end": "*"
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30105,
    "name": {
      "value": "Green Bowl Co.",
      "localized_value": "Green Bowl Co."
    },
    "location": {
      "value": "JLT Cluster F",
      "localized_value": "JLT Cluster F"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now",
      "scheduling": {
        "requested_slot": {
          "start": "{{args.scheduled_slot_start}}",
          "end": "{{args.scheduled_slot_end}}",
          "is_available": false,
          "title": "Scheduling unavailable",
          "subtitle": "This restaurant doesn't accept scheduled orders"
        }
      }
    },
    "brand": {
      "id": 130105,
      "name": "Green Bowl Co.",
      "name_localized": "Green Bowl Co.",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/green-bowl-co.png",
      "link": "careem://food.careem.com/restaurants/brands/130105",
      "brand_media": []
    },
    "brand_id": 130105,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0688,
      "lng": 55.1447
    },
    "cuisines": [
      {
        "id": 34,
        "name": "Healthy",
        "name_localized": "Healthy",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/healthy.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 35,
        "name": "Salads",
        "name_localized": "Salads",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/salads.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 30,
      "careem_delivery_fee": 6,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 2.1,
      "fee": 6,
      "range": "25 - 35",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/green-bowl-co-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 1,
    "link": "careemfood://restaurants/30105",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/green-bowl-co-logo.png",
    "menu": {
      "id": 301050,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301051,
          "name": "Bowls",
          "name_localized": "Bowls",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/bowls.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700501,
              "item": "Chicken Caesar Bowl",
              "item_localized": "Chicken Caesar Bowl",
              "description": "Grilled chicken, romaine, parmesan, croutons and Caesar dressing.",
              "description_localized": "Grilled chicken, romaine, parmesan, croutons and Caesar dressing.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700501.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30105/items/700501",
              "master_product_id": "mp_700501",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 38,
                "total": 38
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30105/items/700501"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 15,
    "price": {
      "average": 50,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.3,
      "average_text": "4.3",
      "count": 410,
      "count_text": "410",
      "state": "default"
    },
    "scheduling_enabled": false,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30105?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: morning-syrniki-cafe

Restaurant `30104` — Morning Syrniki Café.

```json match
{
  "restaurant_id": 30104
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30104,
    "name": {
      "value": "Morning Syrniki Café",
      "localized_value": "Morning Syrniki Café"
    },
    "location": {
      "value": "Dubai Marina",
      "localized_value": "Dubai Marina"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130104,
      "name": "Morning Syrniki Café",
      "name_localized": "Morning Syrniki Café",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/morning-syrniki-cafe.png",
      "link": "careem://food.careem.com/restaurants/brands/130104",
      "brand_media": []
    },
    "brand_id": 130104,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0851,
      "lng": 55.1462
    },
    "cuisines": [
      {
        "id": 21,
        "name": "Breakfast",
        "name_localized": "Breakfast",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/breakfast.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 47,
        "name": "Eastern European",
        "name_localized": "Eastern European",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/ukrainian.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 25,
      "careem_delivery_fee": 5,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 0.4,
      "fee": 5,
      "range": "20 - 30",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/morning-syrniki-cafe-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": true,
    "is_new": false,
    "item_count": 2,
    "link": "careemfood://restaurants/30104",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/morning-syrniki-cafe-logo.png",
    "menu": {
      "id": 301040,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301041,
          "name": "Syrniki",
          "name_localized": "Syrniki",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/syrniki.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700401,
              "item": "Classic Syrniki with Sour Cream",
              "item_localized": "Classic Syrniki with Sour Cream",
              "description": "Four golden cottage-cheese pancakes served with your choice of topping.",
              "description_localized": "Four golden cottage-cheese pancakes served with your choice of topping.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700401.jpg",
              "active": true,
              "groups": [
                {
                  "id": 84011,
                  "name": "Choose your topping",
                  "name_localized": "Choose your topping",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 840111,
                      "item": "Sour cream",
                      "item_localized": "Sour cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840112,
                      "item": "Berry jam",
                      "item_localized": "Berry jam",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840113,
                      "item": "Condensed milk",
                      "item_localized": "Condensed milk",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    }
                  ]
                },
                {
                  "id": 84012,
                  "name": "Add-ons",
                  "name_localized": "Add-ons",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 0,
                  "max": 2,
                  "multi_select": true,
                  "order": 2,
                  "options": [
                    {
                      "id": 840121,
                      "item": "Extra sour cream",
                      "item_localized": "Extra sour cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    },
                    {
                      "id": 840122,
                      "item": "Fresh berries",
                      "item_localized": "Fresh berries",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 6,
                        "total": 6
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30104/items/700401",
              "master_product_id": "mp_700401",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 34,
                "total": 34
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30104/items/700401"
            }
          ]
        },
        {
          "id": 301042,
          "name": "Coffee",
          "name_localized": "Coffee",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/coffee.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700402,
              "item": "Cappuccino",
              "item_localized": "Cappuccino",
              "description": "Double-shot espresso with steamed milk foam.",
              "description_localized": "Double-shot espresso with steamed milk foam.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700402.jpg",
              "active": true,
              "groups": [
                {
                  "id": 84021,
                  "name": "Choose your milk",
                  "name_localized": "Choose your milk",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 840211,
                      "item": "Full cream",
                      "item_localized": "Full cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840212,
                      "item": "Oat",
                      "item_localized": "Oat",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    },
                    {
                      "id": 840213,
                      "item": "Almond",
                      "item_localized": "Almond",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    }
                  ]
                },
                {
                  "id": 84022,
                  "name": "Choose your size",
                  "name_localized": "Choose your size",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 2,
                  "options": [
                    {
                      "id": 840221,
                      "item": "Regular",
                      "item_localized": "Regular",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 840222,
                      "item": "Large",
                      "item_localized": "Large",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30104/items/700402",
              "master_product_id": "mp_700402",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 19,
                "total": 19
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30104/items/700402"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 12,
    "price": {
      "average": 45,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.8,
      "average_text": "4.8",
      "count": 640,
      "count_text": "640",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30104?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: shawarma-station

Restaurant `30101` — Shawarma Station.

```json match
{
  "restaurant_id": 30101
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30101,
    "name": {
      "value": "Shawarma Station",
      "localized_value": "Shawarma Station"
    },
    "location": {
      "value": "Dubai Marina",
      "localized_value": "Dubai Marina"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130101,
      "name": "Shawarma Station",
      "name_localized": "Shawarma Station",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/shawarma-station.png",
      "link": "careem://food.careem.com/restaurants/brands/130101",
      "brand_media": []
    },
    "brand_id": 130101,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0812,
      "lng": 55.1405
    },
    "cuisines": [
      {
        "id": 5,
        "name": "Arabic",
        "name_localized": "Arabic",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/arabic.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 318,
        "name": "Shawarma",
        "name_localized": "Shawarma",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/shawarma.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 25,
      "careem_delivery_fee": 7,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 1.1,
      "fee": 7,
      "range": "20 - 30",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/shawarma-station-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 3,
    "link": "careemfood://restaurants/30101",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/shawarma-station-logo.png",
    "menu": {
      "id": 301010,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301011,
          "name": "Wraps",
          "name_localized": "Wraps",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/wraps.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700101,
              "item": "Chicken Shawarma Wrap",
              "item_localized": "Chicken Shawarma Wrap",
              "description": "Marinated chicken, garlic toum, pickles and fries wrapped in saj bread.",
              "description_localized": "Marinated chicken, garlic toum, pickles and fries wrapped in saj bread.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700101.jpg",
              "active": true,
              "groups": [
                {
                  "id": 81011,
                  "name": "Choose your size",
                  "name_localized": "Choose your size",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 810111,
                      "item": "Regular",
                      "item_localized": "Regular",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 810112,
                      "item": "Large",
                      "item_localized": "Large",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 6,
                        "total": 6
                      }
                    }
                  ]
                },
                {
                  "id": 81012,
                  "name": "Extras",
                  "name_localized": "Extras",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 0,
                  "max": 2,
                  "multi_select": true,
                  "order": 2,
                  "options": [
                    {
                      "id": 810121,
                      "item": "Extra garlic sauce",
                      "item_localized": "Extra garlic sauce",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 2,
                        "total": 2
                      }
                    },
                    {
                      "id": 810122,
                      "item": "No pickles",
                      "item_localized": "No pickles",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30101/items/700101",
              "master_product_id": "mp_700101",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 18,
                "total": 18
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30101/items/700101"
            }
          ]
        },
        {
          "id": 301012,
          "name": "Plates",
          "name_localized": "Plates",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/plates.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700102,
              "item": "Falafel Plate",
              "item_localized": "Falafel Plate",
              "description": "Six crispy falafel with hummus, tahini, salad and pita.",
              "description_localized": "Six crispy falafel with hummus, tahini, salad and pita.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700102.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30101/items/700102",
              "master_product_id": "mp_700102",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 22,
                "total": 22
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30101/items/700102"
            },
            {
              "id": 700103,
              "item": "Mixed Grill Platter",
              "item_localized": "Mixed Grill Platter",
              "description": "Shish tawook, kofta and lamb tikka with grilled vegetables and rice.",
              "description_localized": "Shish tawook, kofta and lamb tikka with grilled vegetables and rice.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700103.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30101/items/700103",
              "master_product_id": "mp_700103",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 65,
                "total": 65
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30101/items/700103"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 12,
    "price": {
      "average": 35,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.6,
      "average_text": "4.6",
      "count": 2310,
      "count_text": "999+",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30101?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: sakura-sushi-lab

Restaurant `30102` — Sakura Sushi Lab.

```json match
{
  "restaurant_id": 30102
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30102,
    "name": {
      "value": "Sakura Sushi Lab",
      "localized_value": "Sakura Sushi Lab"
    },
    "location": {
      "value": "JLT Cluster D",
      "localized_value": "JLT Cluster D"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130102,
      "name": "Sakura Sushi Lab",
      "name_localized": "Sakura Sushi Lab",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/sakura-sushi-lab.png",
      "link": "careem://food.careem.com/restaurants/brands/130102",
      "brand_media": []
    },
    "brand_id": 130102,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0715,
      "lng": 55.1418
    },
    "cuisines": [
      {
        "id": 9,
        "name": "Japanese",
        "name_localized": "Japanese",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/japanese.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 312,
        "name": "Sushi",
        "name_localized": "Sushi",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/sushi.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 40,
      "careem_delivery_fee": 0,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 2.4,
      "fee": 0,
      "range": "35 - 45",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/sakura-sushi-lab-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 2,
    "link": "careemfood://restaurants/30102",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/sakura-sushi-lab-logo.png",
    "menu": {
      "id": 301020,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301021,
          "name": "Rolls",
          "name_localized": "Rolls",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/rolls.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700201,
              "item": "Salmon Avocado Roll (8 pcs)",
              "item_localized": "Salmon Avocado Roll (8 pcs)",
              "description": "Fresh salmon, avocado and cucumber, topped with sesame.",
              "description_localized": "Fresh salmon, avocado and cucumber, topped with sesame.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700201.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30102/items/700201",
              "master_product_id": "mp_700201",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 42,
                "total": 42
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30102/items/700201"
            }
          ]
        },
        {
          "id": 301022,
          "name": "Bento",
          "name_localized": "Bento",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/bento.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700202,
              "item": "Chicken Katsu Bento",
              "item_localized": "Chicken Katsu Bento",
              "description": "Panko chicken katsu, steamed rice, salad and miso soup.",
              "description_localized": "Panko chicken katsu, steamed rice, salad and miso soup.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700202.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30102/items/700202",
              "master_product_id": "mp_700202",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 48,
                "total": 48
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30102/items/700202"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 25,
    "price": {
      "average": 90,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [
      {
        "id": 950102,
        "name": "15% off",
        "name_localized": "15% off",
        "percentage": 15,
        "total_percentage": 15,
        "min_basket_value": 40,
        "text": "15% off your order",
        "text_localized": "15% off your order",
        "terms": [
          {
            "term": "Valid on orders above AED 40",
            "term_localized": "Valid on orders above AED 40"
          },
          {
            "term": "Maximum discount is AED 30",
            "term_localized": "Maximum discount is AED 30"
          }
        ]
      }
    ],
    "rating": {
      "average": 4.4,
      "average_text": "4.4",
      "count": 870,
      "count_text": "870",
      "state": "default"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30102?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: pizza-piazza

Restaurant `30103` — Pizza Piazza.

```json match
{
  "restaurant_id": 30103
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30103,
    "name": {
      "value": "Pizza Piazza",
      "localized_value": "Pizza Piazza"
    },
    "location": {
      "value": "Dubai Marina",
      "localized_value": "Dubai Marina"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130103,
      "name": "Pizza Piazza",
      "name_localized": "Pizza Piazza",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/pizza-piazza.png",
      "link": "careem://food.careem.com/restaurants/brands/130103",
      "brand_media": []
    },
    "brand_id": 130103,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0789,
      "lng": 55.1389
    },
    "cuisines": [
      {
        "id": 8,
        "name": "Italian",
        "name_localized": "Italian",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/italian.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 313,
        "name": "Pizza",
        "name_localized": "Pizza",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/pizza.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 30,
      "careem_delivery_fee": 5,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 1.6,
      "fee": 5,
      "range": "25 - 35",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/pizza-piazza-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 2,
    "link": "careemfood://restaurants/30103",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/pizza-piazza-logo.png",
    "menu": {
      "id": 301030,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301031,
          "name": "Pizzas",
          "name_localized": "Pizzas",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/pizzas.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700301,
              "item": "Margherita Pizza",
              "item_localized": "Margherita Pizza",
              "description": "San Marzano tomato, fior di latte mozzarella and fresh basil.",
              "description_localized": "San Marzano tomato, fior di latte mozzarella and fresh basil.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700301.jpg",
              "active": true,
              "groups": [
                {
                  "id": 83011,
                  "name": "Choose your size",
                  "name_localized": "Choose your size",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 830111,
                      "item": "Medium",
                      "item_localized": "Medium",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 830112,
                      "item": "Large",
                      "item_localized": "Large",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 12,
                        "total": 12
                      }
                    }
                  ]
                },
                {
                  "id": 83012,
                  "name": "Choose your crust",
                  "name_localized": "Choose your crust",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 2,
                  "options": [
                    {
                      "id": 830121,
                      "item": "Classic",
                      "item_localized": "Classic",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 830122,
                      "item": "Thin",
                      "item_localized": "Thin",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    }
                  ]
                },
                {
                  "id": 83013,
                  "name": "Extra toppings",
                  "name_localized": "Extra toppings",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 0,
                  "max": 3,
                  "multi_select": true,
                  "order": 3,
                  "options": [
                    {
                      "id": 830131,
                      "item": "Mushrooms",
                      "item_localized": "Mushrooms",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    },
                    {
                      "id": 830132,
                      "item": "Black olives",
                      "item_localized": "Black olives",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    },
                    {
                      "id": 830133,
                      "item": "Extra mozzarella",
                      "item_localized": "Extra mozzarella",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 6,
                        "total": 6
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30103/items/700301",
              "master_product_id": "mp_700301",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 39,
                "total": 39
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30103/items/700301"
            },
            {
              "id": 700302,
              "item": "Pepperoni Pizza",
              "item_localized": "Pepperoni Pizza",
              "description": "Tomato sauce, mozzarella and spicy beef pepperoni.",
              "description_localized": "Tomato sauce, mozzarella and spicy beef pepperoni.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700302.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30103/items/700302",
              "master_product_id": "mp_700302",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 46,
                "total": 46
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30103/items/700302"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 18,
    "price": {
      "average": 60,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.5,
      "average_text": "4.5",
      "count": 1540,
      "count_text": "999+",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30103?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: green-bowl-co

Restaurant `30105` — Green Bowl Co. (immediate delivery only: `scheduling_enabled: false`).

```json match
{
  "restaurant_id": 30105
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30105,
    "name": {
      "value": "Green Bowl Co.",
      "localized_value": "Green Bowl Co."
    },
    "location": {
      "value": "JLT Cluster F",
      "localized_value": "JLT Cluster F"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130105,
      "name": "Green Bowl Co.",
      "name_localized": "Green Bowl Co.",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/green-bowl-co.png",
      "link": "careem://food.careem.com/restaurants/brands/130105",
      "brand_media": []
    },
    "brand_id": 130105,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0688,
      "lng": 55.1447
    },
    "cuisines": [
      {
        "id": 34,
        "name": "Healthy",
        "name_localized": "Healthy",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/healthy.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 35,
        "name": "Salads",
        "name_localized": "Salads",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/salads.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 30,
      "careem_delivery_fee": 6,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 2.1,
      "fee": 6,
      "range": "25 - 35",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/green-bowl-co-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 1,
    "link": "careemfood://restaurants/30105",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/green-bowl-co-logo.png",
    "menu": {
      "id": 301050,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301051,
          "name": "Bowls",
          "name_localized": "Bowls",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/bowls.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700501,
              "item": "Chicken Caesar Bowl",
              "item_localized": "Chicken Caesar Bowl",
              "description": "Grilled chicken, romaine, parmesan, croutons and Caesar dressing.",
              "description_localized": "Grilled chicken, romaine, parmesan, croutons and Caesar dressing.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700501.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30105/items/700501",
              "master_product_id": "mp_700501",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 38,
                "total": 38
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30105/items/700501"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 15,
    "price": {
      "average": 50,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.3,
      "average_text": "4.3",
      "count": 410,
      "count_text": "410",
      "state": "default"
    },
    "scheduling_enabled": false,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30105?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: restaurant-not-found

Default: restaurant id not locally world (use 30101–30105) → upstream 404. Production omits `restaurant` on error.

```json response
{
  "page": "food_get_restaurant_menu",
  "error": "failed to get restaurant menu: unexpected response status 404"
}
```

<!-- BEGIN extra-restaurants (generated by sandbox/extra/generate.py) -->

## Scenario: smash-burger-house

Restaurant `30106` — Smash Burger House.

```json match
{
  "restaurant_id": 30106
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30106,
    "name": {
      "value": "Smash Burger House",
      "localized_value": "Smash Burger House"
    },
    "location": {
      "value": "Business Bay",
      "localized_value": "Business Bay"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130106,
      "name": "Smash Burger House",
      "name_localized": "Smash Burger House",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/smash-burger-house.png",
      "link": "careem://food.careem.com/restaurants/brands/130106",
      "brand_media": []
    },
    "brand_id": 130106,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0861,
      "lng": 55.152
    },
    "cuisines": [
      {
        "id": 14,
        "name": "Burgers",
        "name_localized": "Burgers",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/burgers.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 15,
        "name": "American",
        "name_localized": "American",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/american.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 30,
      "careem_delivery_fee": 6,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 2.2,
      "fee": 6,
      "range": "25 - 35",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/smash-burger-house-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 4,
    "link": "careemfood://restaurants/30106",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/smash-burger-house-logo.png",
    "menu": {
      "id": 301060,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301061,
          "name": "Burgers",
          "name_localized": "Burgers",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/burgers.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700601,
              "item": "Classic Smash Burger",
              "item_localized": "Classic Smash Burger",
              "description": "Two smashed beef patties, cheddar, pickles and house sauce in a brioche bun.",
              "description_localized": "Two smashed beef patties, cheddar, pickles and house sauce in a brioche bun.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700601.jpg",
              "active": true,
              "groups": [
                {
                  "id": 90611,
                  "name": "Choose your patty",
                  "name_localized": "Choose your patty",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 906111,
                      "item": "Single",
                      "item_localized": "Single",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 906112,
                      "item": "Double",
                      "item_localized": "Double",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 9,
                        "total": 9
                      }
                    }
                  ]
                },
                {
                  "id": 90612,
                  "name": "Add-ons",
                  "name_localized": "Add-ons",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 0,
                  "max": 2,
                  "multi_select": true,
                  "order": 2,
                  "options": [
                    {
                      "id": 906121,
                      "item": "Extra cheese",
                      "item_localized": "Extra cheese",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    },
                    {
                      "id": 906122,
                      "item": "Crispy bacon",
                      "item_localized": "Crispy bacon",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 5,
                        "total": 5
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30106/items/700601",
              "master_product_id": "mp_700601",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 32,
                "total": 32
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30106/items/700601"
            },
            {
              "id": 700602,
              "item": "Spicy Chicken Burger",
              "item_localized": "Spicy Chicken Burger",
              "description": "Crispy chicken thigh, jalapeno slaw and chipotle mayo.",
              "description_localized": "Crispy chicken thigh, jalapeno slaw and chipotle mayo.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700602.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30106/items/700602",
              "master_product_id": "mp_700602",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 29,
                "total": 29
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30106/items/700602"
            }
          ]
        },
        {
          "id": 301062,
          "name": "Sides",
          "name_localized": "Sides",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/sides.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700603,
              "item": "Loaded Fries",
              "item_localized": "Loaded Fries",
              "description": "Fries with cheese sauce, jalapenos and crispy onions.",
              "description_localized": "Fries with cheese sauce, jalapenos and crispy onions.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700603.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30106/items/700603",
              "master_product_id": "mp_700603",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 15,
                "total": 15
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30106/items/700603"
            },
            {
              "id": 700604,
              "item": "Onion Rings",
              "item_localized": "Onion Rings",
              "description": "Beer-batter onion rings with ranch dip.",
              "description_localized": "Beer-batter onion rings with ranch dip.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700604.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30106/items/700604",
              "master_product_id": "mp_700604",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 12,
                "total": 12
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30106/items/700604"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 15,
    "price": {
      "average": 48,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.5,
      "average_text": "4.5",
      "count": 1820,
      "count_text": "999+",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30106?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: sweet-tooth-bakery

Restaurant `30107` — Sweet Tooth Bakery.

```json match
{
  "restaurant_id": 30107
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30107,
    "name": {
      "value": "Sweet Tooth Bakery",
      "localized_value": "Sweet Tooth Bakery"
    },
    "location": {
      "value": "Al Barsha",
      "localized_value": "Al Barsha"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130107,
      "name": "Sweet Tooth Bakery",
      "name_localized": "Sweet Tooth Bakery",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/sweet-tooth-bakery.png",
      "link": "careem://food.careem.com/restaurants/brands/130107",
      "brand_media": []
    },
    "brand_id": 130107,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0712,
      "lng": 55.1331
    },
    "cuisines": [
      {
        "id": 22,
        "name": "Dessert",
        "name_localized": "Dessert",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/dessert.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 23,
        "name": "Bakery",
        "name_localized": "Bakery",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/bakery.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 35,
      "careem_delivery_fee": 5,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 3.4,
      "fee": 5,
      "range": "30 - 40",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/sweet-tooth-bakery-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 4,
    "link": "careemfood://restaurants/30107",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/sweet-tooth-bakery-logo.png",
    "menu": {
      "id": 301070,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301071,
          "name": "Desserts",
          "name_localized": "Desserts",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/desserts.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700701,
              "item": "Kunafa with Cheese",
              "item_localized": "Kunafa with Cheese",
              "description": "Warm shredded kunafa filled with sweet cheese, finished with syrup.",
              "description_localized": "Warm shredded kunafa filled with sweet cheese, finished with syrup.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700701.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30107/items/700701",
              "master_product_id": "mp_700701",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 24,
                "total": 24
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30107/items/700701"
            },
            {
              "id": 700702,
              "item": "Chocolate Lava Cake",
              "item_localized": "Chocolate Lava Cake",
              "description": "Molten chocolate centre, served warm.",
              "description_localized": "Molten chocolate centre, served warm.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700702.jpg",
              "active": true,
              "groups": [
                {
                  "id": 90721,
                  "name": "Add a scoop",
                  "name_localized": "Add a scoop",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 0,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 907211,
                      "item": "Vanilla ice cream",
                      "item_localized": "Vanilla ice cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 5,
                        "total": 5
                      }
                    },
                    {
                      "id": 907212,
                      "item": "Pistachio ice cream",
                      "item_localized": "Pistachio ice cream",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 6,
                        "total": 6
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30107/items/700702",
              "master_product_id": "mp_700702",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 28,
                "total": 28
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30107/items/700702"
            },
            {
              "id": 700703,
              "item": "Cheesecake Slice",
              "item_localized": "Cheesecake Slice",
              "description": "Creamy baked cheesecake with berry compote.",
              "description_localized": "Creamy baked cheesecake with berry compote.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700703.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30107/items/700703",
              "master_product_id": "mp_700703",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 3,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 22,
                "total": 22
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30107/items/700703"
            }
          ]
        },
        {
          "id": 301072,
          "name": "Boxes",
          "name_localized": "Boxes",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/boxes.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700704,
              "item": "Baklava Box (12 pcs)",
              "item_localized": "Baklava Box (12 pcs)",
              "description": "Assorted pistachio and walnut baklava.",
              "description_localized": "Assorted pistachio and walnut baklava.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700704.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30107/items/700704",
              "master_product_id": "mp_700704",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 35,
                "total": 35
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30107/items/700704"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 10,
    "price": {
      "average": 30,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.7,
      "average_text": "4.7",
      "count": 950,
      "count_text": "950",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30107?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: gelato-corner

Restaurant `30108` — Gelato Corner.

```json match
{
  "restaurant_id": 30108
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30108,
    "name": {
      "value": "Gelato Corner",
      "localized_value": "Gelato Corner"
    },
    "location": {
      "value": "Dubai Marina",
      "localized_value": "Dubai Marina"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130108,
      "name": "Gelato Corner",
      "name_localized": "Gelato Corner",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/gelato-corner.png",
      "link": "careem://food.careem.com/restaurants/brands/130108",
      "brand_media": []
    },
    "brand_id": 130108,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0805,
      "lng": 55.1411
    },
    "cuisines": [
      {
        "id": 24,
        "name": "Gelato",
        "name_localized": "Gelato",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/gelato.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 22,
        "name": "Dessert",
        "name_localized": "Dessert",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/dessert.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 20,
      "careem_delivery_fee": 5,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 0.9,
      "fee": 5,
      "range": "15 - 25",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/gelato-corner-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 3,
    "link": "careemfood://restaurants/30108",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/gelato-corner-logo.png",
    "menu": {
      "id": 301080,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301081,
          "name": "Gelato",
          "name_localized": "Gelato",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/gelato.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700801,
              "item": "Pistachio Gelato Cup",
              "item_localized": "Pistachio Gelato Cup",
              "description": "Slow-churned pistachio gelato.",
              "description_localized": "Slow-churned pistachio gelato.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700801.jpg",
              "active": true,
              "groups": [
                {
                  "id": 90811,
                  "name": "Choose your size",
                  "name_localized": "Choose your size",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 908111,
                      "item": "Small",
                      "item_localized": "Small",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 908112,
                      "item": "Medium",
                      "item_localized": "Medium",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    },
                    {
                      "id": 908113,
                      "item": "Large",
                      "item_localized": "Large",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 7,
                        "total": 7
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30108/items/700801",
              "master_product_id": "mp_700801",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 18,
                "total": 18
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30108/items/700801"
            },
            {
              "id": 700802,
              "item": "Mango Sorbet",
              "item_localized": "Mango Sorbet",
              "description": "Dairy-free mango sorbet.",
              "description_localized": "Dairy-free mango sorbet.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700802.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30108/items/700802",
              "master_product_id": "mp_700802",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 16,
                "total": 16
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30108/items/700802"
            }
          ]
        },
        {
          "id": 301082,
          "name": "Waffles",
          "name_localized": "Waffles",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/waffles.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700803,
              "item": "Waffle with Chocolate",
              "item_localized": "Waffle with Chocolate",
              "description": "Hot waffle with chocolate sauce and hazelnuts.",
              "description_localized": "Hot waffle with chocolate sauce and hazelnuts.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700803.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30108/items/700803",
              "master_product_id": "mp_700803",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 26,
                "total": 26
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30108/items/700803"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 5,
    "price": {
      "average": 22,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.4,
      "average_text": "4.4",
      "count": 610,
      "count_text": "610",
      "state": "default"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30108?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: sunrise-foul-and-falafel

Restaurant `30109` — Sunrise Foul & Falafel.

```json match
{
  "restaurant_id": 30109
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30109,
    "name": {
      "value": "Sunrise Foul & Falafel",
      "localized_value": "Sunrise Foul & Falafel"
    },
    "location": {
      "value": "JLT Cluster B",
      "localized_value": "JLT Cluster B"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130109,
      "name": "Sunrise Foul & Falafel",
      "name_localized": "Sunrise Foul & Falafel",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/sunrise-foul-and-falafel.png",
      "link": "careem://food.careem.com/restaurants/brands/130109",
      "brand_media": []
    },
    "brand_id": 130109,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0695,
      "lng": 55.144
    },
    "cuisines": [
      {
        "id": 21,
        "name": "Breakfast",
        "name_localized": "Breakfast",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/breakfast.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 5,
        "name": "Arabic",
        "name_localized": "Arabic",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/arabic.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 20,
      "careem_delivery_fee": 4,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 1.8,
      "fee": 4,
      "range": "15 - 25",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/sunrise-foul-and-falafel-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 4,
    "link": "careemfood://restaurants/30109",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/sunrise-foul-and-falafel-logo.png",
    "menu": {
      "id": 301090,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301091,
          "name": "Breakfast plates",
          "name_localized": "Breakfast plates",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/breakfast-plates.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700901,
              "item": "Foul Medames",
              "item_localized": "Foul Medames",
              "description": "Slow-cooked fava beans with olive oil, lemon and cumin, served with bread.",
              "description_localized": "Slow-cooked fava beans with olive oil, lemon and cumin, served with bread.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700901.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30109/items/700901",
              "master_product_id": "mp_700901",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 14,
                "total": 14
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30109/items/700901"
            },
            {
              "id": 700902,
              "item": "Hummus Plate",
              "item_localized": "Hummus Plate",
              "description": "Creamy hummus with olive oil and warm pita.",
              "description_localized": "Creamy hummus with olive oil and warm pita.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700902.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30109/items/700902",
              "master_product_id": "mp_700902",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 16,
                "total": 16
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30109/items/700902"
            },
            {
              "id": 700903,
              "item": "Shakshuka Pan",
              "item_localized": "Shakshuka Pan",
              "description": "Eggs poached in spiced tomato sauce.",
              "description_localized": "Eggs poached in spiced tomato sauce.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700903.jpg",
              "active": true,
              "groups": [
                {
                  "id": 90931,
                  "name": "Choose your spice",
                  "name_localized": "Choose your spice",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 909311,
                      "item": "Mild",
                      "item_localized": "Mild",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 909312,
                      "item": "Hot",
                      "item_localized": "Hot",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30109/items/700903",
              "master_product_id": "mp_700903",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 3,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 24,
                "total": 24
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30109/items/700903"
            }
          ]
        },
        {
          "id": 301092,
          "name": "Sandwiches",
          "name_localized": "Sandwiches",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/sandwiches.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 700904,
              "item": "Falafel Sandwich",
              "item_localized": "Falafel Sandwich",
              "description": "Crispy falafel, tahini, pickles and tomato in saj bread.",
              "description_localized": "Crispy falafel, tahini, pickles and tomato in saj bread.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/700904.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30109/items/700904",
              "master_product_id": "mp_700904",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 10,
                "total": 10
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30109/items/700904"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 8,
    "price": {
      "average": 18,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.6,
      "average_text": "4.6",
      "count": 1320,
      "count_text": "999+",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30109?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: wok-express

Restaurant `30110` — Wok Express.

```json match
{
  "restaurant_id": 30110
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30110,
    "name": {
      "value": "Wok Express",
      "localized_value": "Wok Express"
    },
    "location": {
      "value": "Business Bay",
      "localized_value": "Business Bay"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130110,
      "name": "Wok Express",
      "name_localized": "Wok Express",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/wok-express.png",
      "link": "careem://food.careem.com/restaurants/brands/130110",
      "brand_media": []
    },
    "brand_id": 130110,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0888,
      "lng": 55.1498
    },
    "cuisines": [
      {
        "id": 30,
        "name": "Asian",
        "name_localized": "Asian",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/asian.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 31,
        "name": "Chinese",
        "name_localized": "Chinese",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/chinese.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 30,
      "careem_delivery_fee": 6,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 2.6,
      "fee": 6,
      "range": "25 - 35",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/wok-express-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 3,
    "link": "careemfood://restaurants/30110",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/wok-express-logo.png",
    "menu": {
      "id": 301100,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301101,
          "name": "Wok",
          "name_localized": "Wok",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/wok.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701001,
              "item": "Chicken Chow Mein",
              "item_localized": "Chicken Chow Mein",
              "description": "Stir-fried noodles with chicken, cabbage and spring onion.",
              "description_localized": "Stir-fried noodles with chicken, cabbage and spring onion.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701001.jpg",
              "active": true,
              "groups": [
                {
                  "id": 91011,
                  "name": "Choose your noodles",
                  "name_localized": "Choose your noodles",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 910111,
                      "item": "Egg noodles",
                      "item_localized": "Egg noodles",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 910112,
                      "item": "Rice noodles",
                      "item_localized": "Rice noodles",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 2,
                        "total": 2
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30110/items/701001",
              "master_product_id": "mp_701001",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 30,
                "total": 30
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30110/items/701001"
            },
            {
              "id": 701002,
              "item": "Beef & Broccoli",
              "item_localized": "Beef & Broccoli",
              "description": "Tender beef and broccoli in oyster sauce, with steamed rice.",
              "description_localized": "Tender beef and broccoli in oyster sauce, with steamed rice.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701002.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30110/items/701002",
              "master_product_id": "mp_701002",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 38,
                "total": 38
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30110/items/701002"
            }
          ]
        },
        {
          "id": 301102,
          "name": "Starters",
          "name_localized": "Starters",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/starters.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701003,
              "item": "Vegetable Spring Rolls (6)",
              "item_localized": "Vegetable Spring Rolls (6)",
              "description": "Crispy rolls with sweet chilli dip.",
              "description_localized": "Crispy rolls with sweet chilli dip.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701003.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30110/items/701003",
              "master_product_id": "mp_701003",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 18,
                "total": 18
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30110/items/701003"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 14,
    "price": {
      "average": 40,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.3,
      "average_text": "4.3",
      "count": 780,
      "count_text": "780",
      "state": "default"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30110?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: mandi-palace

Restaurant `30111` — Mandi Palace.

```json match
{
  "restaurant_id": 30111
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30111,
    "name": {
      "value": "Mandi Palace",
      "localized_value": "Mandi Palace"
    },
    "location": {
      "value": "Al Quoz",
      "localized_value": "Al Quoz"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130111,
      "name": "Mandi Palace",
      "name_localized": "Mandi Palace",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/mandi-palace.png",
      "link": "careem://food.careem.com/restaurants/brands/130111",
      "brand_media": []
    },
    "brand_id": 130111,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0771,
      "lng": 55.1342
    },
    "cuisines": [
      {
        "id": 5,
        "name": "Arabic",
        "name_localized": "Arabic",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/arabic.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 319,
        "name": "Mandi",
        "name_localized": "Mandi",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/mandi.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 35,
      "careem_delivery_fee": 7,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 3.0,
      "fee": 7,
      "range": "30 - 40",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/mandi-palace-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 3,
    "link": "careemfood://restaurants/30111",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/mandi-palace-logo.png",
    "menu": {
      "id": 301110,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301111,
          "name": "Mains",
          "name_localized": "Mains",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/mains.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701101,
              "item": "Chicken Mandi",
              "item_localized": "Chicken Mandi",
              "description": "Slow-cooked chicken over spiced rice with a tomato chilli sauce.",
              "description_localized": "Slow-cooked chicken over spiced rice with a tomato chilli sauce.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701101.jpg",
              "active": true,
              "groups": [
                {
                  "id": 91111,
                  "name": "Choose your rice",
                  "name_localized": "Choose your rice",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 911111,
                      "item": "Plain rice",
                      "item_localized": "Plain rice",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 911112,
                      "item": "Saffron rice",
                      "item_localized": "Saffron rice",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 4,
                        "total": 4
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30111/items/701101",
              "master_product_id": "mp_701101",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 38,
                "total": 38
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30111/items/701101"
            },
            {
              "id": 701102,
              "item": "Lamb Mansaf",
              "item_localized": "Lamb Mansaf",
              "description": "Lamb in jameed yogurt sauce over rice, topped with almonds and pine nuts.",
              "description_localized": "Lamb in jameed yogurt sauce over rice, topped with almonds and pine nuts.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701102.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30111/items/701102",
              "master_product_id": "mp_701102",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 45,
                "total": 45
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30111/items/701102"
            }
          ]
        },
        {
          "id": 301112,
          "name": "Sides",
          "name_localized": "Sides",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/sides.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701103,
              "item": "Mutabbal & Bread",
              "item_localized": "Mutabbal & Bread",
              "description": "Smoky aubergine dip with warm bread.",
              "description_localized": "Smoky aubergine dip with warm bread.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701103.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30111/items/701103",
              "master_product_id": "mp_701103",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 14,
                "total": 14
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30111/items/701103"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 20,
    "price": {
      "average": 55,
      "range": "",
      "scale": {
        "value": 2,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.8,
      "average_text": "4.8",
      "count": 2050,
      "count_text": "999+",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30111?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: napoli-slice

Restaurant `30112` — Napoli Slice.

```json match
{
  "restaurant_id": 30112
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30112,
    "name": {
      "value": "Napoli Slice",
      "localized_value": "Napoli Slice"
    },
    "location": {
      "value": "Downtown",
      "localized_value": "Downtown"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130112,
      "name": "Napoli Slice",
      "name_localized": "Napoli Slice",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/napoli-slice.png",
      "link": "careem://food.careem.com/restaurants/brands/130112",
      "brand_media": []
    },
    "brand_id": 130112,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0891,
      "lng": 55.1473
    },
    "cuisines": [
      {
        "id": 7,
        "name": "Italian",
        "name_localized": "Italian",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/italian.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 8,
        "name": "Pizza",
        "name_localized": "Pizza",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/pizza.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 25,
      "careem_delivery_fee": 5,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 1.5,
      "fee": 5,
      "range": "20 - 30",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/napoli-slice-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 3,
    "link": "careemfood://restaurants/30112",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/napoli-slice-logo.png",
    "menu": {
      "id": 301120,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301121,
          "name": "Pizza",
          "name_localized": "Pizza",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/pizza.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701201,
              "item": "Pepperoni Slice Combo",
              "item_localized": "Pepperoni Slice Combo",
              "description": "Two pepperoni slices with a drink.",
              "description_localized": "Two pepperoni slices with a drink.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701201.jpg",
              "active": true,
              "groups": [
                {
                  "id": 91211,
                  "name": "Choose your drink",
                  "name_localized": "Choose your drink",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 912111,
                      "item": "Cola",
                      "item_localized": "Cola",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 912112,
                      "item": "Orange soda",
                      "item_localized": "Orange soda",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 912113,
                      "item": "Water",
                      "item_localized": "Water",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30112/items/701201",
              "master_product_id": "mp_701201",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 24,
                "total": 24
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30112/items/701201"
            },
            {
              "id": 701202,
              "item": "Four Cheese Pizza",
              "item_localized": "Four Cheese Pizza",
              "description": "Mozzarella, gorgonzola, parmesan and provolone.",
              "description_localized": "Mozzarella, gorgonzola, parmesan and provolone.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701202.jpg",
              "active": true,
              "groups": [
                {
                  "id": 91221,
                  "name": "Choose your size",
                  "name_localized": "Choose your size",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 912211,
                      "item": "Medium",
                      "item_localized": "Medium",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 912212,
                      "item": "Large",
                      "item_localized": "Large",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 10,
                        "total": 10
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30112/items/701202",
              "master_product_id": "mp_701202",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 44,
                "total": 44
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30112/items/701202"
            }
          ]
        },
        {
          "id": 301122,
          "name": "Sides",
          "name_localized": "Sides",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/sides.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701203,
              "item": "Garlic Bread",
              "item_localized": "Garlic Bread",
              "description": "Toasted ciabatta with garlic butter.",
              "description_localized": "Toasted ciabatta with garlic butter.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701203.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30112/items/701203",
              "master_product_id": "mp_701203",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 14,
                "total": 14
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30112/items/701203"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 12,
    "price": {
      "average": 35,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.2,
      "average_text": "4.2",
      "count": 540,
      "count_text": "540",
      "state": "default"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30112?business_type=restaurants&merchant_type=normal"
  }
}
```

## Scenario: fresh-greens

Restaurant `30113` — Fresh Greens.

```json match
{
  "restaurant_id": 30113
}
```

```json response
{
  "page": "food_get_restaurant_menu",
  "restaurant": {
    "id": 30113,
    "name": {
      "value": "Fresh Greens",
      "localized_value": "Fresh Greens"
    },
    "location": {
      "value": "Dubai Marina",
      "localized_value": "Dubai Marina"
    },
    "availability_details": {
      "is_available": true,
      "title": "Open",
      "subtitle": "Delivering now"
    },
    "brand": {
      "id": 130113,
      "name": "Fresh Greens",
      "name_localized": "Fresh Greens",
      "count": 1,
      "image_url": "https://careem-catalog-media.media.careem.com/food/brands/fresh-greens.png",
      "link": "careem://food.careem.com/restaurants/brands/130113",
      "brand_media": []
    },
    "brand_id": 130113,
    "business_type": "restaurants",
    "city_id": 1,
    "coordinate": {
      "lat": 25.0826,
      "lng": 55.1389
    },
    "cuisines": [
      {
        "id": 11,
        "name": "Healthy",
        "name_localized": "Healthy",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/healthy.jpg",
        "keywords": null,
        "keywords_localized": null
      },
      {
        "id": 12,
        "name": "Salads",
        "name_localized": "Salads",
        "image_url": "https://careem-catalog-media.media.careem.com/food/cuisines/salads.jpg",
        "keywords": null,
        "keywords_localized": null
      }
    ],
    "currency": {
      "id": 1,
      "code": "AED",
      "name": "Dirham",
      "name_localized": "Dirham",
      "label": "AED",
      "label_localized": "AED",
      "position": "left",
      "decimals": 2,
      "purchasing_power_index": 1,
      "name_short": "Dirhams",
      "cents_100": true
    },
    "delivery": {
      "average": 25,
      "careem_delivery_fee": 5,
      "delivery_method": "on_demand",
      "delivery_type": "careem",
      "distance_in_km": 1.2,
      "fee": 5,
      "range": "20 - 30",
      "unit": "min",
      "unit_localized": "mins"
    },
    "has_items": true,
    "image_url": "https://careem-catalog-media.media.careem.com/food/restaurants/fresh-greens-hero.jpg",
    "include_tax": true,
    "included_tax": 5,
    "is_cplus_merchant": false,
    "is_favourite": false,
    "is_new": false,
    "item_count": 3,
    "link": "careemfood://restaurants/30113",
    "logo_url": "https://careem-catalog-media.media.careem.com/food/restaurants/fresh-greens-logo.png",
    "menu": {
      "id": 301130,
      "active": true,
      "currency": {
        "id": 1,
        "code": "AED",
        "name": "Dirham",
        "name_localized": "Dirham",
        "label": "AED",
        "label_localized": "AED",
        "position": "left",
        "decimals": 2,
        "purchasing_power_index": 1,
        "name_short": "Dirhams",
        "cents_100": true
      },
      "groups": [
        {
          "id": 301131,
          "name": "Bowls and salads",
          "name_localized": "Bowls and salads",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/bowls-and-salads.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701301,
              "item": "Quinoa Power Bowl",
              "item_localized": "Quinoa Power Bowl",
              "description": "Quinoa, roasted veg, chickpeas, avocado and lemon tahini.",
              "description_localized": "Quinoa, roasted veg, chickpeas, avocado and lemon tahini.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701301.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30113/items/701301",
              "master_product_id": "mp_701301",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 36,
                "total": 36
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30113/items/701301"
            },
            {
              "id": 701302,
              "item": "Greek Salad",
              "item_localized": "Greek Salad",
              "description": "Cucumber, tomato, olives, feta and oregano dressing.",
              "description_localized": "Cucumber, tomato, olives, feta and oregano dressing.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701302.jpg",
              "active": true,
              "groups": [],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30113/items/701302",
              "master_product_id": "mp_701302",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 2,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 28,
                "total": 28
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30113/items/701302"
            }
          ]
        },
        {
          "id": 301132,
          "name": "Wraps",
          "name_localized": "Wraps",
          "active": true,
          "category_type": "normal",
          "image_url": "https://careem-catalog-media.media.careem.com/food/categories/wraps.jpg",
          "items_layout": "list",
          "items": [
            {
              "id": 701303,
              "item": "Grilled Chicken Light Wrap",
              "item_localized": "Grilled Chicken Light Wrap",
              "description": "Grilled chicken, greens and yogurt dressing.",
              "description_localized": "Grilled chicken, greens and yogurt dressing.",
              "image_url": "https://careem-catalog-media.media.careem.com/food/items/701303.jpg",
              "active": true,
              "groups": [
                {
                  "id": 91331,
                  "name": "Choose your bread",
                  "name_localized": "Choose your bread",
                  "description": "",
                  "description_localized": "",
                  "active": true,
                  "min": 1,
                  "max": 1,
                  "multi_select": false,
                  "order": 1,
                  "options": [
                    {
                      "id": 913311,
                      "item": "Whole wheat",
                      "item_localized": "Whole wheat",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 0,
                        "total": 0
                      }
                    },
                    {
                      "id": 913312,
                      "item": "Low-carb",
                      "item_localized": "Low-carb",
                      "is_active": true,
                      "price": {
                        "discount": 0,
                        "discount_percentage": 0,
                        "original": 3,
                        "total": 3
                      }
                    }
                  ]
                }
              ],
              "is_near_expiry": false,
              "is_time_in_range": true,
              "link": "careemfood://restaurants/30113/items/701303",
              "master_product_id": "mp_701303",
              "maximum_quantity": 20,
              "nutritional_categorization": [],
              "order": 1,
              "price": {
                "discount": 0,
                "discount_percentage": 0,
                "original": 30,
                "total": 30
              },
              "superapp_link": "careem://now.careem.com/shops/restaurants/30113/items/701303"
            }
          ]
        }
      ]
    },
    "menu_layout": "capsule",
    "merchant_type": "normal",
    "preparation_time": 10,
    "price": {
      "average": 34,
      "range": "",
      "scale": {
        "value": 1,
        "upper_bound": 3
      }
    },
    "promotions": [],
    "rating": {
      "average": 4.5,
      "average_text": "4.5",
      "count": 700,
      "count_text": "700",
      "state": "highlight"
    },
    "scheduling_enabled": true,
    "superapp_link": "careem://now.careem.com/shops/restaurants/30113?business_type=restaurants&merchant_type=normal"
  }
}
```

<!-- END extra-restaurants -->

## Definition

```json tool
{
  "annotations": {
    "readOnlyHint": true
  },
  "description": "Fetch the full menu of a specific restaurant by ID, including all categories, items, prices, and customization options (add-ons, choices). Use after finding a restaurant ID from search results to show the user what they can order.",
  "inputSchema": {
    "additionalProperties": false,
    "properties": {
      "city_id": {
        "description": "city ID for scoping results",
        "type": "string"
      },
      "domain": {
        "description": "order domain; defaults to food",
        "type": "string"
      },
      "latitude": {
        "description": "user's current location latitude",
        "type": "number"
      },
      "longitude": {
        "description": "user's current location longitude",
        "type": "number"
      },
      "restaurant_id": {
        "description": "ID of the restaurant to fetch the menu for",
        "type": "integer"
      },
      "scheduled_slot_end": {
        "description": "UTC ISO end of a confirmed-available scheduling slot; omit for immediate delivery",
        "type": "string"
      },
      "scheduled_slot_start": {
        "description": "UTC ISO start of a confirmed-available scheduling slot; omit for immediate delivery",
        "type": "string"
      }
    },
    "required": [
      "restaurant_id",
      "latitude",
      "longitude"
    ],
    "type": "object"
  },
  "name": "food_get_restaurant_menu",
  "outputSchema": {
    "additionalProperties": false,
    "properties": {
      "error": {
        "type": "string"
      },
      "page": {
        "type": "string"
      },
      "restaurant": {
        "additionalProperties": false,
        "properties": {
          "availability_details": {
            "additionalProperties": false,
            "properties": {
              "is_available": {
                "type": "boolean"
              },
              "scheduling": {
                "additionalProperties": false,
                "properties": {
                  "requested_slot": {
                    "additionalProperties": false,
                    "properties": {
                      "end": {
                        "type": "string"
                      },
                      "is_available": {
                        "type": "boolean"
                      },
                      "start": {
                        "type": "string"
                      },
                      "subtitle": {
                        "type": "string"
                      },
                      "title": {
                        "type": "string"
                      }
                    },
                    "required": [
                      "start",
                      "end",
                      "is_available",
                      "title",
                      "subtitle"
                    ],
                    "type": "object"
                  }
                },
                "required": [
                  "requested_slot"
                ],
                "type": [
                  "null",
                  "object"
                ]
              },
              "subtitle": {
                "type": "string"
              },
              "title": {
                "type": "string"
              }
            },
            "required": [
              "is_available",
              "title",
              "subtitle"
            ],
            "type": "object"
          },
          "brand": {
            "additionalProperties": false,
            "properties": {
              "brand_media": {
                "items": {
                  "type": "string"
                },
                "type": [
                  "null",
                  "array"
                ]
              },
              "count": {
                "maximum": 2147483647,
                "minimum": -2147483648,
                "type": "integer"
              },
              "id": {
                "type": "integer"
              },
              "image_url": {
                "type": "string"
              },
              "link": {
                "type": "string"
              },
              "name": {
                "type": "string"
              },
              "name_localized": {
                "type": "string"
              }
            },
            "required": [
              "id",
              "name",
              "name_localized",
              "count",
              "image_url",
              "link"
            ],
            "type": "object"
          },
          "brand_id": {
            "type": "integer"
          },
          "business_type": {
            "type": "string"
          },
          "city_id": {
            "type": "integer"
          },
          "coordinate": {
            "additionalProperties": false,
            "properties": {
              "lat": {
                "type": "number"
              },
              "lng": {
                "type": "number"
              }
            },
            "required": [
              "lat",
              "lng"
            ],
            "type": "object"
          },
          "cuisines": {
            "items": {
              "additionalProperties": false,
              "properties": {
                "id": {
                  "type": "integer"
                },
                "image_url": {
                  "type": "string"
                },
                "keywords": {
                  "type": [
                    "null",
                    "string"
                  ]
                },
                "keywords_localized": {
                  "type": [
                    "null",
                    "string"
                  ]
                },
                "name": {
                  "type": "string"
                },
                "name_localized": {
                  "type": "string"
                }
              },
              "required": [
                "id",
                "name",
                "name_localized",
                "image_url",
                "keywords",
                "keywords_localized"
              ],
              "type": "object"
            },
            "type": [
              "null",
              "array"
            ]
          },
          "currency": {
            "additionalProperties": false,
            "properties": {
              "cents_100": {
                "type": "boolean"
              },
              "code": {
                "type": "string"
              },
              "decimals": {
                "maximum": 2147483647,
                "minimum": -2147483648,
                "type": "integer"
              },
              "id": {
                "type": "integer"
              },
              "label": {
                "type": "string"
              },
              "label_localized": {
                "type": "string"
              },
              "name": {
                "type": "string"
              },
              "name_localized": {
                "type": "string"
              },
              "name_short": {
                "type": "string"
              },
              "position": {
                "type": "string"
              },
              "purchasing_power_index": {
                "maximum": 2147483647,
                "minimum": -2147483648,
                "type": "integer"
              }
            },
            "required": [
              "id",
              "code",
              "name",
              "name_localized",
              "label",
              "label_localized",
              "position",
              "decimals",
              "purchasing_power_index",
              "name_short",
              "cents_100"
            ],
            "type": "object"
          },
          "delivery": {
            "additionalProperties": false,
            "properties": {
              "average": {
                "maximum": 2147483647,
                "minimum": -2147483648,
                "type": "integer"
              },
              "careem_delivery_fee": {
                "type": "number"
              },
              "delivery_method": {
                "type": "string"
              },
              "delivery_type": {
                "type": "string"
              },
              "distance_in_km": {
                "type": "number"
              },
              "fee": {
                "type": "number"
              },
              "range": {
                "type": "string"
              },
              "unit": {
                "type": "string"
              },
              "unit_localized": {
                "type": "string"
              }
            },
            "required": [
              "delivery_method",
              "delivery_type",
              "average",
              "range",
              "unit",
              "unit_localized",
              "careem_delivery_fee",
              "fee",
              "distance_in_km"
            ],
            "type": "object"
          },
          "has_items": {
            "type": "boolean"
          },
          "id": {
            "type": "integer"
          },
          "image_url": {
            "type": "string"
          },
          "include_tax": {
            "type": "boolean"
          },
          "included_tax": {
            "type": "number"
          },
          "is_cplus_merchant": {
            "type": "boolean"
          },
          "is_favourite": {
            "type": "boolean"
          },
          "is_new": {
            "type": "boolean"
          },
          "item_count": {
            "maximum": 2147483647,
            "minimum": -2147483648,
            "type": "integer"
          },
          "link": {
            "type": "string"
          },
          "location": {
            "additionalProperties": false,
            "properties": {
              "localized_value": {
                "type": "string"
              },
              "value": {
                "type": "string"
              }
            },
            "required": [
              "value",
              "localized_value"
            ],
            "type": "object"
          },
          "logo_url": {
            "type": "string"
          },
          "menu": {
            "additionalProperties": false,
            "properties": {
              "active": {
                "type": "boolean"
              },
              "currency": {
                "additionalProperties": false,
                "properties": {
                  "cents_100": {
                    "type": "boolean"
                  },
                  "code": {
                    "type": "string"
                  },
                  "decimals": {
                    "maximum": 2147483647,
                    "minimum": -2147483648,
                    "type": "integer"
                  },
                  "id": {
                    "type": "integer"
                  },
                  "label": {
                    "type": "string"
                  },
                  "label_localized": {
                    "type": "string"
                  },
                  "name": {
                    "type": "string"
                  },
                  "name_localized": {
                    "type": "string"
                  },
                  "name_short": {
                    "type": "string"
                  },
                  "position": {
                    "type": "string"
                  },
                  "purchasing_power_index": {
                    "maximum": 2147483647,
                    "minimum": -2147483648,
                    "type": "integer"
                  }
                },
                "required": [
                  "id",
                  "code",
                  "name",
                  "name_localized",
                  "label",
                  "label_localized",
                  "position",
                  "decimals",
                  "purchasing_power_index",
                  "name_short",
                  "cents_100"
                ],
                "type": "object"
              },
              "groups": {
                "items": {
                  "additionalProperties": false,
                  "properties": {
                    "active": {
                      "type": "boolean"
                    },
                    "category_type": {
                      "type": "string"
                    },
                    "id": {
                      "type": "integer"
                    },
                    "image_url": {
                      "type": "string"
                    },
                    "items": {
                      "items": {
                        "additionalProperties": false,
                        "properties": {
                          "active": {
                            "type": "boolean"
                          },
                          "description": {
                            "type": "string"
                          },
                          "description_localized": {
                            "type": "string"
                          },
                          "groups": {
                            "items": {
                              "additionalProperties": false,
                              "properties": {
                                "active": {
                                  "type": "boolean"
                                },
                                "description": {
                                  "type": "string"
                                },
                                "description_localized": {
                                  "type": "string"
                                },
                                "id": {
                                  "type": "integer"
                                },
                                "max": {
                                  "type": "integer"
                                },
                                "min": {
                                  "type": "integer"
                                },
                                "multi_select": {
                                  "type": "boolean"
                                },
                                "name": {
                                  "type": "string"
                                },
                                "name_localized": {
                                  "type": "string"
                                },
                                "options": {
                                  "items": {
                                    "additionalProperties": false,
                                    "properties": {
                                      "id": {
                                        "type": "integer"
                                      },
                                      "is_active": {
                                        "type": "boolean"
                                      },
                                      "item": {
                                        "type": "string"
                                      },
                                      "item_localized": {
                                        "type": "string"
                                      },
                                      "price": {
                                        "additionalProperties": false,
                                        "properties": {
                                          "discount": {
                                            "type": "number"
                                          },
                                          "discount_percentage": {
                                            "type": "number"
                                          },
                                          "original": {
                                            "type": "number"
                                          },
                                          "total": {
                                            "type": "number"
                                          }
                                        },
                                        "required": [
                                          "original",
                                          "discount",
                                          "total",
                                          "discount_percentage"
                                        ],
                                        "type": "object"
                                      }
                                    },
                                    "required": [
                                      "id",
                                      "item",
                                      "item_localized",
                                      "is_active",
                                      "price"
                                    ],
                                    "type": "object"
                                  },
                                  "type": [
                                    "null",
                                    "array"
                                  ]
                                },
                                "order": {
                                  "type": "integer"
                                }
                              },
                              "required": [
                                "id",
                                "name",
                                "name_localized",
                                "description",
                                "description_localized",
                                "multi_select",
                                "min",
                                "max",
                                "order",
                                "active",
                                "options"
                              ],
                              "type": "object"
                            },
                            "type": [
                              "null",
                              "array"
                            ]
                          },
                          "id": {
                            "type": "integer"
                          },
                          "image_url": {
                            "type": "string"
                          },
                          "is_near_expiry": {
                            "type": "boolean"
                          },
                          "is_time_in_range": {
                            "type": "boolean"
                          },
                          "item": {
                            "type": "string"
                          },
                          "item_localized": {
                            "type": "string"
                          },
                          "link": {
                            "type": "string"
                          },
                          "master_product_id": {
                            "type": "string"
                          },
                          "maximum_quantity": {
                            "type": "integer"
                          },
                          "nutritional_categorization": {
                            "items": {
                              "additionalProperties": false,
                              "properties": {
                                "key": {
                                  "type": "string"
                                },
                                "name_localized": {
                                  "type": "string"
                                }
                              },
                              "required": [
                                "key",
                                "name_localized"
                              ],
                              "type": "object"
                            },
                            "type": [
                              "null",
                              "array"
                            ]
                          },
                          "order": {
                            "type": "integer"
                          },
                          "price": {
                            "additionalProperties": false,
                            "properties": {
                              "discount": {
                                "type": "number"
                              },
                              "discount_percentage": {
                                "type": "number"
                              },
                              "original": {
                                "type": "number"
                              },
                              "total": {
                                "type": "number"
                              }
                            },
                            "required": [
                              "original",
                              "discount",
                              "total",
                              "discount_percentage"
                            ],
                            "type": "object"
                          },
                          "superapp_link": {
                            "type": "string"
                          }
                        },
                        "required": [
                          "id",
                          "item",
                          "item_localized",
                          "link",
                          "superapp_link",
                          "image_url",
                          "description",
                          "description_localized",
                          "price",
                          "active",
                          "order",
                          "maximum_quantity",
                          "groups",
                          "nutritional_categorization",
                          "is_near_expiry",
                          "is_time_in_range",
                          "master_product_id"
                        ],
                        "type": "object"
                      },
                      "type": [
                        "null",
                        "array"
                      ]
                    },
                    "items_layout": {
                      "type": "string"
                    },
                    "name": {
                      "type": "string"
                    },
                    "name_localized": {
                      "type": "string"
                    }
                  },
                  "required": [
                    "id",
                    "name",
                    "name_localized",
                    "active",
                    "image_url",
                    "category_type",
                    "items_layout",
                    "items"
                  ],
                  "type": "object"
                },
                "type": [
                  "null",
                  "array"
                ]
              },
              "id": {
                "type": "integer"
              }
            },
            "required": [
              "id",
              "currency",
              "active",
              "groups"
            ],
            "type": "object"
          },
          "menu_layout": {
            "type": "string"
          },
          "merchant_type": {
            "type": "string"
          },
          "name": {
            "additionalProperties": false,
            "properties": {
              "localized_value": {
                "type": "string"
              },
              "value": {
                "type": "string"
              }
            },
            "required": [
              "value",
              "localized_value"
            ],
            "type": "object"
          },
          "preparation_time": {
            "maximum": 2147483647,
            "minimum": -2147483648,
            "type": "integer"
          },
          "price": {
            "additionalProperties": false,
            "properties": {
              "average": {
                "type": "number"
              },
              "range": {
                "type": "string"
              },
              "scale": {
                "additionalProperties": false,
                "properties": {
                  "upper_bound": {
                    "maximum": 2147483647,
                    "minimum": -2147483648,
                    "type": "integer"
                  },
                  "value": {
                    "maximum": 2147483647,
                    "minimum": -2147483648,
                    "type": "integer"
                  }
                },
                "required": [
                  "value",
                  "upper_bound"
                ],
                "type": "object"
              }
            },
            "required": [
              "average",
              "range",
              "scale"
            ],
            "type": "object"
          },
          "promotions": {
            "items": {
              "additionalProperties": false,
              "properties": {
                "id": {
                  "type": "integer"
                },
                "min_basket_value": {
                  "maximum": 2147483647,
                  "minimum": -2147483648,
                  "type": "integer"
                },
                "name": {
                  "type": "string"
                },
                "name_localized": {
                  "type": "string"
                },
                "percentage": {
                  "maximum": 2147483647,
                  "minimum": -2147483648,
                  "type": "integer"
                },
                "terms": {
                  "items": {
                    "additionalProperties": false,
                    "properties": {
                      "term": {
                        "type": "string"
                      },
                      "term_localized": {
                        "type": "string"
                      }
                    },
                    "required": [
                      "term",
                      "term_localized"
                    ],
                    "type": "object"
                  },
                  "type": [
                    "null",
                    "array"
                  ]
                },
                "text": {
                  "type": "string"
                },
                "text_localized": {
                  "type": "string"
                },
                "total_percentage": {
                  "maximum": 2147483647,
                  "minimum": -2147483648,
                  "type": "integer"
                }
              },
              "required": [
                "id",
                "percentage",
                "total_percentage",
                "name",
                "name_localized",
                "text",
                "text_localized",
                "min_basket_value",
                "terms"
              ],
              "type": "object"
            },
            "type": [
              "null",
              "array"
            ]
          },
          "rating": {
            "additionalProperties": false,
            "properties": {
              "average": {
                "type": "number"
              },
              "average_text": {
                "type": "string"
              },
              "count": {
                "type": "integer"
              },
              "count_text": {
                "type": "string"
              },
              "state": {
                "type": "string"
              }
            },
            "required": [
              "average",
              "average_text",
              "count",
              "count_text",
              "state"
            ],
            "type": "object"
          },
          "scheduling_enabled": {
            "type": "boolean"
          },
          "superapp_link": {
            "type": "string"
          }
        },
        "required": [
          "merchant_type",
          "id",
          "name",
          "city_id",
          "location",
          "coordinate",
          "cuisines",
          "currency",
          "rating",
          "price",
          "preparation_time",
          "promotions",
          "link",
          "superapp_link",
          "image_url",
          "logo_url",
          "delivery",
          "menu",
          "has_items",
          "item_count",
          "brand",
          "brand_id",
          "is_new",
          "availability_details",
          "is_cplus_merchant",
          "scheduling_enabled",
          "is_favourite",
          "include_tax",
          "included_tax",
          "business_type",
          "menu_layout"
        ],
        "type": [
          "null",
          "object"
        ]
      }
    },
    "required": [
      "page"
    ],
    "type": "object"
  },
  "title": "Get Restaurant Menu"
}
```
