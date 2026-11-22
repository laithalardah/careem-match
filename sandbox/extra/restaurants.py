"""Extra made-up restaurants for the local sandbox (ids 30106+). Source of truth for generate.py.

Each dish: (name, description, price, [option groups]); option group: (name, min, max, [(option, price)]).
Everything here is invented test data in the same shape as Careem's own sandbox restaurants.
"""

# (id, brand/name, area, (lat, lng), cuisines [(id, name)], rating, rating_count, eta, eta_range, fee, km, prep, price_avg,
#  menu groups [(group name, [dish...])], search queries that should find it)
EXTRA = [
    dict(
        id=30106, slug="smash-burger-house", name="Smash Burger House", area="Business Bay", coord=(25.0861, 55.1520),
        cuisines=[(14, "Burgers"), (15, "American")], rating=4.5, rating_count=1820, eta=30, eta_range="25 - 35",
        fee=6, km=2.2, prep=15, price_avg=48, queries=["burger"],
        menu=[
            ("Burgers", [
                ("Classic Smash Burger", "Two smashed beef patties, cheddar, pickles and house sauce in a brioche bun.", 32, [
                    ("Choose your patty", 1, 1, [("Single", 0), ("Double", 9)]),
                    ("Add-ons", 0, 2, [("Extra cheese", 3), ("Crispy bacon", 5)]),
                ]),
                ("Spicy Chicken Burger", "Crispy chicken thigh, jalapeno slaw and chipotle mayo.", 29, []),
            ]),
            ("Sides", [
                ("Loaded Fries", "Fries with cheese sauce, jalapenos and crispy onions.", 15, []),
                ("Onion Rings", "Beer-batter onion rings with ranch dip.", 12, []),
            ]),
        ],
    ),
    dict(
        id=30107, slug="sweet-tooth-bakery", name="Sweet Tooth Bakery", area="Al Barsha", coord=(25.0712, 55.1331),
        cuisines=[(22, "Dessert"), (23, "Bakery")], rating=4.7, rating_count=950, eta=35, eta_range="30 - 40",
        fee=5, km=3.4, prep=10, price_avg=30, queries=["dessert"],
        menu=[
            ("Desserts", [
                ("Kunafa with Cheese", "Warm shredded kunafa filled with sweet cheese, finished with syrup.", 24, []),
                ("Chocolate Lava Cake", "Molten chocolate centre, served warm.", 28, [
                    ("Add a scoop", 0, 1, [("Vanilla ice cream", 5), ("Pistachio ice cream", 6)]),
                ]),
                ("Cheesecake Slice", "Creamy baked cheesecake with berry compote.", 22, []),
            ]),
            ("Boxes", [
                ("Baklava Box (12 pcs)", "Assorted pistachio and walnut baklava.", 35, []),
            ]),
        ],
    ),
    dict(
        id=30108, slug="gelato-corner", name="Gelato Corner", area="Dubai Marina", coord=(25.0805, 55.1411),
        cuisines=[(24, "Gelato"), (22, "Dessert")], rating=4.4, rating_count=610, eta=20, eta_range="15 - 25",
        fee=5, km=0.9, prep=5, price_avg=22, queries=["dessert", "gelato"],
        menu=[
            ("Gelato", [
                ("Pistachio Gelato Cup", "Slow-churned pistachio gelato.", 18, [
                    ("Choose your size", 1, 1, [("Small", 0), ("Medium", 4), ("Large", 7)]),
                ]),
                ("Mango Sorbet", "Dairy-free mango sorbet.", 16, []),
            ]),
            ("Waffles", [
                ("Waffle with Chocolate", "Hot waffle with chocolate sauce and hazelnuts.", 26, []),
            ]),
        ],
    ),
    dict(
        id=30109, slug="sunrise-foul-and-falafel", name="Sunrise Foul & Falafel", area="JLT Cluster B", coord=(25.0695, 55.1440),
        cuisines=[(21, "Breakfast"), (5, "Arabic")], rating=4.6, rating_count=1320, eta=20, eta_range="15 - 25",
        fee=4, km=1.8, prep=8, price_avg=18, queries=["foul"],
        menu=[
            ("Breakfast plates", [
                ("Foul Medames", "Slow-cooked fava beans with olive oil, lemon and cumin, served with bread.", 14, []),
                ("Hummus Plate", "Creamy hummus with olive oil and warm pita.", 16, []),
                ("Shakshuka Pan", "Eggs poached in spiced tomato sauce.", 24, [
                    ("Choose your spice", 1, 1, [("Mild", 0), ("Hot", 0)]),
                ]),
            ]),
            ("Sandwiches", [
                ("Falafel Sandwich", "Crispy falafel, tahini, pickles and tomato in saj bread.", 10, []),
            ]),
        ],
    ),
    dict(
        id=30110, slug="wok-express", name="Wok Express", area="Business Bay", coord=(25.0888, 55.1498),
        cuisines=[(30, "Asian"), (31, "Chinese")], rating=4.3, rating_count=780, eta=30, eta_range="25 - 35",
        fee=6, km=2.6, prep=14, price_avg=40, queries=["noodles"],
        menu=[
            ("Wok", [
                ("Chicken Chow Mein", "Stir-fried noodles with chicken, cabbage and spring onion.", 30, [
                    ("Choose your noodles", 1, 1, [("Egg noodles", 0), ("Rice noodles", 2)]),
                ]),
                ("Beef & Broccoli", "Tender beef and broccoli in oyster sauce, with steamed rice.", 38, []),
            ]),
            ("Starters", [
                ("Vegetable Spring Rolls (6)", "Crispy rolls with sweet chilli dip.", 18, []),
            ]),
        ],
    ),
    dict(
        id=30111, slug="mandi-palace", name="Mandi Palace", area="Al Quoz", coord=(25.0771, 55.1342),
        cuisines=[(5, "Arabic"), (319, "Mandi")], rating=4.8, rating_count=2050, eta=35, eta_range="30 - 40",
        fee=7, km=3.0, prep=20, price_avg=55, queries=["mandi", "mansaf"],
        menu=[
            ("Mains", [
                ("Chicken Mandi", "Slow-cooked chicken over spiced rice with a tomato chilli sauce.", 38, [
                    ("Choose your rice", 1, 1, [("Plain rice", 0), ("Saffron rice", 4)]),
                ]),
                ("Lamb Mansaf", "Lamb in jameed yogurt sauce over rice, topped with almonds and pine nuts.", 45, []),
            ]),
            ("Sides", [
                ("Mutabbal & Bread", "Smoky aubergine dip with warm bread.", 14, []),
            ]),
        ],
    ),
    dict(
        id=30112, slug="napoli-slice", name="Napoli Slice", area="Downtown", coord=(25.0891, 55.1473),
        cuisines=[(7, "Italian"), (8, "Pizza")], rating=4.2, rating_count=540, eta=25, eta_range="20 - 30",
        fee=5, km=1.5, prep=12, price_avg=35, queries=["slice"],
        menu=[
            ("Pizza", [
                ("Pepperoni Slice Combo", "Two pepperoni slices with a drink.", 24, [
                    ("Choose your drink", 1, 1, [("Cola", 0), ("Orange soda", 0), ("Water", 0)]),
                ]),
                ("Four Cheese Pizza", "Mozzarella, gorgonzola, parmesan and provolone.", 44, [
                    ("Choose your size", 1, 1, [("Medium", 0), ("Large", 10)]),
                ]),
            ]),
            ("Sides", [
                ("Garlic Bread", "Toasted ciabatta with garlic butter.", 14, []),
            ]),
        ],
    ),
    dict(
        id=30113, slug="fresh-greens", name="Fresh Greens", area="Dubai Marina", coord=(25.0826, 55.1389),
        cuisines=[(11, "Healthy"), (12, "Salads")], rating=4.5, rating_count=700, eta=25, eta_range="20 - 30",
        fee=5, km=1.2, prep=10, price_avg=34, queries=["salad"],
        menu=[
            ("Bowls and salads", [
                ("Quinoa Power Bowl", "Quinoa, roasted veg, chickpeas, avocado and lemon tahini.", 36, []),
                ("Greek Salad", "Cucumber, tomato, olives, feta and oregano dressing.", 28, []),
            ]),
            ("Wraps", [
                ("Grilled Chicken Light Wrap", "Grilled chicken, greens and yogurt dressing.", 30, [
                    ("Choose your bread", 1, 1, [("Whole wheat", 0), ("Low-carb", 3)]),
                ]),
            ]),
        ],
    ),
]
