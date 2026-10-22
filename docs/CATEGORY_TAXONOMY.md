# Category Taxonomy

> **Keep this doc in sync:** The authoritative runtime state is the live database. The audit trail is the migration files. This document is the human-readable snapshot — update it in the same PR as any migration that adds, removes, or renames a category node.

## Contents

- [Overview](#overview)
- [Design principles](#design-principles)
- [v1 taxonomy](#v1-taxonomy)
- [Adding a category](#adding-a-category)
- [Removing a category](#removing-a-category)
- [Database integrity rules](#database-integrity-rules)

---

## Overview

Cove's category taxonomy is a **3-level tree** stored in Postgres using the `ltree` extension. Each node has a dot-separated path (`food.coffee.whole_bean`) and a display name (`Whole Bean`). The path is the stable identity; the name is what the iOS app shows.

Items may only be assigned to **leaf nodes** — the deepest node in a given branch. Non-leaf categories are browse/navigation nodes only; they cannot be set as an item's `category_id`.

The v1 taxonomy has **10 top-level categories** and 252 nodes total (10 top-level, 59 level-2, 183 level-3), seeded via migration `000004`. `eat_drink` is the newest top-level category; see [Why Eat & Drink is separate from Food](#why-eat--drink-is-separate-from-food). Leaf enforcement is defined in `000003`. Display names were later corrected in `000014` (Plantcare, Bodycare, Haircare) and `000015` (Protein).

### Category images

Category images live in Garage (`cove-media`) in two aspect-ratio variants. Keys mirror the path, with dots as hyphens and underscores kept, and are seeded by `000013`:

| Variant | Key | Crop | Set on | API field |
|---|---|---|---|---|
| Card | `images/categories/card/<path>.jpg` | ~13:6 (1560×720 source) | Every node | `image_key`, from `GET /categories` and `GET /recommendations/categories` |
| Wide | `images/categories/wide/<path>.jpg` | 4:1 (1560×388 source) | Level 1 only | `wide_image_key`, from `GET /categories` |

Clients read keys from the API and never build them. A new category needs its image uploaded to Garage and its keys set in the same migration that adds it.

---

## Design principles

### Tree nodes vs attributes

> **Categories define *what* an item is. Attributes define *how it differs from others in the same category*.**

A new category branch is warranted when:
- The distinction is **fixed and mutually exclusive** (an item is either beer or wine, not both)
- The set is **small and stable** (adding 10 new nodes does not spiral the tree)
- The difference changes **what the item fundamentally is**, not a property of it

A new `attributes` key is warranted when:
- The values **overlap** (an item can be both organic and locally sourced)
- The set is **open-ended or continuous** (dietary tags, ABV, season)
- The distinction is a **filter facet**, not a categorical identity

Examples of deliberate attribute choices:
- **Gender** (men's/women's/unisex) — an item can be unisex; the tree would duplicate every clothing node three times. Lives on `attributes`.
- **Dietary tags** (vegan, gluten-free, organic) — a product can carry many of these simultaneously. Lives on `attributes`.
- **Beer style details** (ABV, IBU) — continuous numeric values; range filtering requires typed attributes, not tree nodes.
- **Wine characteristics** (tannins, skin contact) — tasting notes and production method are facets, not identity.

### 3-level cap

The v1 taxonomy is capped at **3 levels** (`root.mid.leaf` — e.g. `food.coffee.whole_bean`). This is deep enough to power homepage category cards and category-scoped discovery without creating a maintenance burden. Some branches are deliberately shallower (2 levels, e.g. `art.paintings`) — the cap is a maximum, not a requirement.

### Why alcohol is separate from food

Alcohol has distinct regulatory, cultural, and discovery contexts. Grouping `food.beer` alongside `food.baked_goods` would make browse-mode category cards confusing and would complicate any future age-gating. Keeping it as a top-level `alcohol` preserves that separation cleanly.

### Why Eat & Drink is separate from Food

> **An item's category is what it is, not where you eat it.**

Eat & Drink covers **dishes and drinks made to order**: a cortado, boba, pad thai, a house cocktail. Food and Alcohol cover **goods**, including the sweets you eat on the spot: a bag of beans, a croissant, a chocolate bar, a pint of gelato, a bottle of gin. A croissant is `food.baked_goods.pastries` whether it comes in a box or on a plate, so no item ever has to choose between two branches.

Eat & Drink is organized by **cuisine**, because cuisine is how people choose where to eat and what they tell us at onboarding. A dish nearly always has one cuisine; a restaurant that spans several appears under each of them through the category roll-up from its items. Cafés and bars are not cuisines, so `cafes`, `juices` and `bars` sit alongside the cuisines at level 2.

There is no `eat_drink.desserts`: every dessert already has a home in Food (`baked_goods`, `confections`, `dairy.ice_cream`), and a plated dessert at a restaurant takes the restaurant's cuisine (tiramisu → `eat_drink.european`).

Served drinks at a bar, cocktails included, live under `eat_drink.bars` rather than `alcohol`. Age-gating, when it ships, must cover both `alcohol` and `eat_drink.bars`.

### Places reach Eat & Drink three ways

A place appears in a level 1 category's Places section through the roll-up of the items it sells. Eat & Drink adds two place-level routes, because a bakery or patisserie sells Food items but is somewhere you go to eat:

- **Item roll-up**: a boba shop appears under `cafes` because it sells boba, which is `eat_drink.cafes`.
- **Place type**: café, restaurant, bar, bakery and dessert shop always appear in Eat & Drink → Places.
- **Cuisine tags on the place**: a place can be tagged with cuisines directly, so a patisserie (type bakery) tagged European appears under Eat & Drink → European even though its items are all `food.baked_goods`.

A candy shop is type `shop` and appears under Food only.

### Flavors, meals and diets are filters

Matcha, brunch, and dietary tags (vegan, gluten-free) overlap and cut across branches, so they are filter facets, not tree nodes. A matcha latte is `eat_drink.cafes`, matcha cake is `food.baked_goods.cakes`, and matcha soft serve is `food.dairy.ice_cream`; search and the matcha filter find all three.

---

## v1 taxonomy

`eat_drink` is listed first to match its position in the app's fixed level 1 order.

```
eat_drink
├── cafes                — espresso drinks, pour-over, tea and matcha, boba  ← leaf at level 2
├── juices               — fresh juice, smoothies, agua fresca  ← leaf at level 2
├── bars                 — house cocktails, mocktails, zero-proof drinks  ← leaf at level 2
├── american             — burgers, diners, BBQ, Southern, soul food  ← leaf at level 2
├── latin                — Mexican, Salvadoran, Peruvian, Caribbean  ← leaf at level 2
├── european             — Italian, French, Greek, Spanish  ← leaf at level 2
├── mideast              — falafel, shawarma, mezze  ← leaf at level 2
├── african              — Ethiopian, West African, North African  ← leaf at level 2
└── asian                — Chinese, Japanese, Korean, Vietnamese, Thai, Indian  ← leaf at level 2

food
├── coffee
│   ├── whole_bean       — single-origin bags, local roaster blends
│   ├── ground           — house blend, espresso roast, drip grind
│   └── cold_brew        — concentrate, ready-to-drink bottles
├── tea
│   ├── loose_leaf       — oolong, darjeeling, green tea
│   ├── blends           — chai, wellness blends, house blends
│   └── herbal           — chamomile, mint, rooibos, hibiscus
├── beverages
│   ├── kombucha         — seasonal flavors, raw kombucha
│   ├── juice            — cold-pressed, fresh-squeezed
│   └── soda             — craft sodas, ginger beer, shrubs
├── baked_goods
│   ├── breads           — sourdough, focaccia, rye loaves
│   ├── pastries         — croissants, danishes, scones
│   ├── cakes            — layer cakes, bundt cakes, celebration cakes
│   ├── pies             — fruit pies, savory hand pies
│   └── cookies          — chocolate chip, sandwich cookies, shortbread
├── confections
│   ├── chocolate        — bars, truffles, bark, bonbons
│   ├── caramels         — soft caramels, sea salt caramels
│   ├── fudge            — classic, flavored fudge
│   ├── taffy            — pulled taffy, saltwater taffy
│   └── candy            — hard candy, gummies, lollipops
├── preserves
│   ├── jams             — strawberry, mixed berry, stone fruit
│   ├── jellies          — grape, pepper jelly, herb jelly
│   ├── fruit_butters    — apple butter, pumpkin butter
│   ├── chutneys         — mango chutney, onion chutney
│   └── pickled          — dill pickles, bread and butter, fermented veg
├── snacks
│   ├── granola          — clusters, granola bars, loose granola
│   ├── jerky            — beef jerky, turkey jerky, bison jerky
│   ├── popcorn          — kettle corn, flavored popcorn
│   ├── nuts             — roasted almonds, spiced mixed nuts
│   ├── chips            — potato chips, veggie chips, plantain chips
│   └── trail_mix        — custom blends, fruit and nut mixes
├── condiments
│   ├── hot_sauce        — fermented hot sauce, pepper mash
│   ├── salsa            — fresh pico, roasted salsa, verde
│   ├── mustard          — whole grain, honey mustard, spicy brown
│   ├── vinegar          — apple cider vinegar, infused balsamic
│   ├── spices           — spice blends, single-origin spices, rubs
│   └── oils             — infused olive oil, chili oil, herb oil
├── fresh
│   ├── pasta            — handmade pasta, filled pasta, gnocchi
│   ├── sauces           — marinara, pesto, cream sauce, bolognese
│   └── dips             — hummus, baba ganoush, tzatziki, queso
├── produce
│   ├── vegetables       — seasonal farm vegetables
│   ├── fruits           — local seasonal fruit
│   ├── mushrooms        — oyster, shiitake, lion's mane, foraged
│   ├── herbs            — fresh cut herbs, herb bundles
│   └── eggs             — farm eggs, duck eggs, quail eggs
├── protein
│   ├── beef             — local ranch beef, ground beef, steaks
│   ├── poultry          — whole chickens, heritage breed, duck
│   ├── pork             — heritage pork, charcuterie, bacon
│   ├── fish             — local trout, smoked salmon, cured fish
│   └── game             — elk, bison, venison, rabbit
├── dairy
│   ├── cheese           — artisan cheese, aged varieties, fresh chèvre
│   ├── milk             — whole milk, A2 milk, oat milk
│   ├── butter           — cultured butter, compound butters
│   ├── ice_cream        — small-batch ice cream, gelato, sorbet
│   └── yogurt           — whole milk yogurt, Greek-style, labneh
└── pantry
    ├── syrups           — simple syrups, flavored coffee syrups
    ├── sweeteners       — coconut sugar, monk fruit, date syrup
    ├── honey            — raw honey, varietal honey, honeycomb
    ├── baking           — specialty flour, baking mixes, extracts
    └── grains           — heirloom grains, ancient grains, rice

alcohol
├── beer
│   ├── ipa              — West Coast IPA, hazy IPA, session IPA
│   ├── stout            — oatmeal stout, milk stout, imperial stout
│   ├── lager            — Czech-style pilsner, helles, märzen
│   ├── wheat            — hefeweizen, American wheat, witbier
│   ├── sour             — Berliner Weisse, gose, lambic-style
│   ├── amber            — amber ale, red ale, Scottish ale
│   └── specialty        — barrel-aged, fruit beers, experimental
├── cider
│   ├── apple            — traditional dry cider, semi-sweet, ice cider
│   └── specialty        — pear, cherry, hopped, botanical cider
├── wine
│   ├── red              — Pinot Noir, Cabernet, Malbec, Tempranillo
│   ├── white            — Chardonnay, Sauvignon Blanc, Riesling
│   ├── rose             — dry rosé, Provence-style
│   ├── sparkling        — Pét Nat, traditional method, Prosecco-style
│   └── specialty        — orange wine, ice wine, dessert wine
└── spirits
    ├── whiskey          — bourbon, rye, single malt, blended
    ├── gin              — London dry, botanical, navy strength
    ├── vodka            — craft vodka, flavored, potato
    ├── rum              — aged rum, white rum, spiced
    ├── tequila          — blanco, reposado, mezcal, añejo
    └── specialty        — aquavit, amaro, absinthe, grappa

apparel
├── mens
│   ├── tops             — t-shirts, flannels, henleys, button-downs
│   ├── bottoms          — jeans, chinos, shorts, trousers
│   └── outerwear        — jackets, coats, vests, parkas
├── womens
│   ├── tops             — blouses, tees, tanks, sweaters
│   ├── bottoms          — jeans, skirts, trousers, shorts
│   ├── dresses          — sundresses, wrap dresses, midi dresses
│   └── outerwear        — jackets, coats, cardigans, blazers
├── unisex
│   ├── tops             — sweatshirts, tees, hoodies
│   ├── bottoms          — joggers, sweatpants, linen trousers
│   └── outerwear        — puffer jackets, fleece, raincoats
├── accessories
│   ├── hats             — beanies, baseball caps, wide-brim hats
│   ├── belts            — leather belts, woven belts, braided
│   ├── bags             — tote bags, crossbody bags, backpacks
│   ├── scarves          — wool scarves, silk scarves, wraps
│   ├── gloves           — knit gloves, leather gloves, mittens
│   └── shoes            — handmade leather shoes, boots, sandals
└── jewelry
    ├── necklaces        — pendants, chains, chokers, lariats
    ├── earrings         — studs, hoops, dangles, ear cuffs
    ├── rings            — bands, statement rings, stacking rings
    └── bracelets        — cuffs, beaded bracelets, chain

home
├── decor
│   ├── candles          — soy candles, beeswax pillars, tapers
│   └── ceramics         — vases, decorative bowls, figurines
├── kitchen
│   ├── ceramics         — mugs, plates, bowls, serving dishes
│   ├── cutting_boards   — wood cutting boards, charcuterie boards
│   ├── utensils         — wooden spoons, handmade knives, spatulas
│   └── linens           — dish towels, napkins, aprons
├── textiles
│   ├── blankets         — wool blankets, quilts, weighted blankets
│   ├── pillows          — throw pillows, lumbar pillows, floor cushions
│   └── throws           — knit throws, woven throws, sherpa throws
└── furniture
    ├── tables           — coffee tables, side tables, dining tables
    ├── seating          — chairs, stools, benches, ottomans
    └── shelving         — floating shelves, bookshelves, ladder shelves

plants
├── indoor
│   ├── succulents       — echeveria, aloe, haworthia, cactus
│   ├── tropicals        — pothos, monstera, ferns, philodendron
│   └── herbs            — potted basil, mint, rosemary, thyme
├── outdoor
│   ├── perennials       — lavender, coneflower, black-eyed Susan
│   ├── annuals          — petunias, marigolds, zinnias, impatiens
│   └── shrubs           — rosemary, boxwood, hydrangea, lilac
├── seeds
│   ├── vegetable        — tomato, pepper, kale, squash seeds
│   ├── flower           — wildflower mixes, sunflower, cosmos
│   ├── fruit            — strawberry, melon, pumpkin seeds
│   └── herb             — basil, dill, cilantro, chive seeds
├── dried
│   ├── bouquets         — dried wildflowers, lavender bundles
│   ├── wreaths          — dried floral wreaths, herb wreaths
│   └── arrangements     — preserved floral arrangements, terrariums
└── plantcare
    ├── soil             — potting mix, cactus mix, worm castings
    ├── fertilizer       — liquid fertilizer, compost, slow-release
    ├── pots             — handmade ceramic pots, terracotta, hanging
    └── tools            — pruning shears, trowels, watering cans

beauty
├── cosmetics
│   ├── face             — foundation, blush, bronzer, highlighter
│   ├── eyes             — eyeshadow, mascara, eyeliner, brow gel
│   ├── lips             — lipstick, lip gloss, lip liner, balm
│   └── nails            — nail polish, nail art, strengtheners
├── skincare
│   ├── cleansers        — face wash, cleansing balms, micellar water
│   ├── moisturizers     — face cream, gel moisturizer, night cream
│   ├── serums           — vitamin C, hyaluronic acid, retinol
│   ├── oils             — rosehip oil, face oils, dry oils
│   └── spf              — SPF moisturizer, mineral sunscreen
├── bodycare
│   ├── soap             — bar soap, liquid soap, castile soap
│   ├── bath_bombs       — fizzy bath bombs, CBD bath bombs
│   ├── scrubs           — sugar scrubs, salt scrubs, coffee scrubs
│   ├── bath_salts       — epsom salts, mineral bath salts, soaking salts
│   └── lotion           — body lotion, body butter, body oil
├── haircare
│   ├── shampoo          — clarifying, moisturizing, dry shampoo
│   ├── conditioner      — deep conditioner, leave-in, co-wash
│   ├── masks            — hair masks, scalp treatments, protein packs
│   ├── oils             — argan oil, jojoba oil, hair serums
│   └── styling          — pomade, curl cream, hair wax, mousse
├── fragrance
│   ├── perfume          — eau de parfum, floral, woody, gourmand
│   ├── cologne          — eau de cologne, fresh, citrus, fougère
│   ├── body_spray       — light fragrance mists, deodorant spray
│   └── solid            — solid perfume, fragrance balm, wax melts
└── supplements
    ├── vitamins         — multivitamins, vitamin C, D3, B12
    └── herbal           — echinacea, ashwagandha, elderberry, adaptogen blends

art
├── paintings            — oil, acrylic, watercolor originals  ← leaf at level 2
├── prints               — limited edition prints, giclée, screen prints  ← leaf at level 2
├── sculptures           — ceramic, wood, metal, mixed media  ← leaf at level 2
├── photography          — fine art prints, framed photos, editions  ← leaf at level 2
├── drawings             — charcoal, pencil, ink, pastel originals  ← leaf at level 2
└── materials
    ├── paint            — acrylic, oil, watercolor, gouache
    ├── brushes          — natural hair, synthetic, fan, detail
    ├── canvas           — stretched canvas, canvas pads, boards
    ├── paper            — watercolor paper, sketch pads, printmaking
    └── ink              — India ink, calligraphy inks, screen printing ink

pets
├── dogs
│   ├── food             — homemade treats, raw food, baked biscuits
│   ├── accessories      — collars, leashes, bandanas, harnesses
│   ├── grooming         — shampoo, conditioner, grooming kits
│   └── toys             — rope toys, chew toys, puzzle feeders
├── cats
│   ├── food             — homemade treats, freeze-dried, raw toppers
│   ├── accessories      — collars, harnesses, beds, scratchers
│   ├── grooming         — brushes, deshedding tools, nail trimmers
│   └── toys             — feather wands, catnip toys, crinkle balls
├── birds
│   ├── food             — seed mixes, pellets, dried fruit treat sticks
│   ├── accessories      — perches, cage covers, foraging cups
│   └── toys             — foraging toys, swings, foot toys, bells
└── exotic
    ├── food             — specialized diets, freeze-dried, live feeders
    └── accessories      — tanks, hides, enclosure decor, heat mats

music
├── instruments
│   ├── guitars          — acoustic, electric, classical, resonator
│   ├── violins          — full-size, fractional, handmade, folk fiddles
│   ├── drums            — snare drums, hand drums, cajóns, frame drums
│   ├── keyboards        — digital pianos, MIDI controllers, melodicas
│   ├── bass             — electric bass, upright bass, bass ukulele
│   └── trumpet          — Bb trumpet, flugelhorn, cornet, pocket trumpet
├── recorded
│   ├── vinyl            — LPs, EPs, 45s, picture discs, local artists
│   ├── cd               — albums, EPs, local band CDs, live recordings
│   └── cassette         — lo-fi releases, mixtapes, zine-style releases
└── accessories
    ├── cases            — guitar cases, gig bags, instrument pouches
    ├── string_sets      — acoustic strings, electric strings, bass strings
    └── picks            — celluloid picks, nylon picks, thumb picks
```

---

## Adding a category

**Choose the right level first.** Review [Design principles](#design-principles) before adding a node. If the distinction is a filter facet, it belongs in `attributes`, not the tree.

### 1. Write a new migration

Create the next numbered migration file:

```bash
# example: adding food.fresh.kimchi
touch services/cove-item/migrations/000016_add_kimchi_category.up.sql
touch services/cove-item/migrations/000016_add_kimchi_category.down.sql
```

**up:**
```sql
INSERT INTO catalog.categories (id, name, path, image_key)
VALUES (gen_random_uuid(), 'Kimchi', 'food.fresh.kimchi',
        'images/categories/card/food-fresh-kimchi.jpg')
ON CONFLICT (path) DO UPDATE SET name = EXCLUDED.name, image_key = EXCLUDED.image_key;
```

**down:**
```sql
-- Only safe if no items reference this category.
-- The FK constraint will block this if items exist.
DELETE FROM catalog.categories WHERE path = 'food.fresh.kimchi';
```

> The `AFTER INSERT` trigger automatically marks `food.fresh` as `is_leaf = false` — no manual update needed.

### 2. Update this document

Add the new node to the tree above. Keep it in the same PR as the migration.

### 3. Run the migration

```bash
# From the repo root
migrate -path services/cove-item/migrations \
        -database "postgres://..." \
        -x-migrations-table schema_migrations_cove_item \
        up
```

See [DATABASE_MIGRATIONS.md](DATABASE_MIGRATIONS.md) for the full connection string and staging runbook.

---

## Removing a category

Removing a category from the live database requires care — items may already be assigned to it.

### Steps

1. **Check for dependent items** before writing the migration:
   ```sql
   SELECT COUNT(*) FROM catalog.items
   WHERE category_id = (SELECT id FROM catalog.categories WHERE path = 'food.fresh.kimchi');
   ```
   If any items exist, reassign or remove them first in a separate migration.

2. **Remove children first** if the node has any. The `BEFORE DELETE` trigger blocks deletion of a non-leaf category — you must delete all descendants bottom-up, or delete them in the same migration in the correct order.

3. **Write the migration:**

   **up:**
   ```sql
   -- Remove leaf first, then parent (if parent becomes a leaf again, the
   -- AFTER DELETE trigger updates is_leaf automatically).
   DELETE FROM catalog.categories WHERE path = 'food.fresh.kimchi';
   ```

   **down:**
   ```sql
   INSERT INTO catalog.categories (id, name, path)
   VALUES (gen_random_uuid(), 'Kimchi', 'food.fresh.kimchi')
   ON CONFLICT (path) DO UPDATE SET name = EXCLUDED.name;
   ```

4. **Update this document** to remove the node from the tree above.

---

## Database integrity rules

Four triggers on `catalog.categories` and `catalog.items` enforce taxonomy integrity automatically. You do not need to maintain `is_leaf` manually.

| Trigger | Table | Fires | What it does |
|---|---|---|---|
| `categories_mark_parent_non_leaf` | `catalog.categories` | `AFTER INSERT` | Marks the inserted node's direct parent as `is_leaf = false` |
| `categories_recheck_parent_leaf` | `catalog.categories` | `AFTER DELETE` | Re-evaluates the deleted node's parent; flips it back to `is_leaf = true` if no siblings remain |
| `categories_prevent_non_leaf_delete` | `catalog.categories` | `BEFORE DELETE` | Raises an exception if the category still has children |
| `items_enforce_leaf_category` | `catalog.items` | `BEFORE INSERT OR UPDATE` | Raises an exception if `category_id` points to a non-leaf category |

The `RESTRICT` foreign key on `catalog.items.category_id` provides a fifth layer: Postgres itself will block deletion of any category that has items referencing it, before any trigger fires.

Defined in:
- `services/cove-item/migrations/000003_catalog.up.sql` — `is_leaf` column, insert trigger, delete guard and parent recheck triggers, item enforcement trigger

---

## References

- [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) — schema overview, ltree mechanics, attributes vs categories
- [Postgres Primer](POSTGRES_PRIMER.md) — ltree operator reference
- [Database Migrations](DATABASE_MIGRATIONS.md) — how to run migrations against staging
