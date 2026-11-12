# Item Availability

> **Status:** Planned, not built (November 2026). [Data Model](DATA_MODEL.md) summarizes the item kinds, brands and visit lists described here. This document has the detail: how an item is sold, which places have it, and what Item Details shows as a result. [ITEM_AVAILABILITY.html](ITEM_AVAILABILITY.html) is an interactive version with example data: an explorer for Item Details and a chain menu grid. Open it in a browser, since GitHub shows HTML files as source.

## Contents

- [Summary](#summary)
- [The model](#the-model)
- [Item kinds](#item-kinds)
- [Worked examples](#worked-examples)
- [House-made items and locations](#house-made-items-and-locations)
- [Secondhand items and makers](#secondhand-items-and-makers)
- [The place list on Item Details](#the-place-list-on-item-details)
- [Verification on Item Details](#verification-on-item-details)
- [Visit lists](#visit-lists)
- [Schema changes](#schema-changes)
- [Decisions and open questions](#decisions-and-open-questions)

---

## Summary

Every item has a producer and a set of places that have it, through `catalog.availability`. The missing piece is **how the item is sold**, which this document calls its **kind**:

| Kind | Meaning | Example |
|---|---|---|
| **Goods** (default) | Any place can carry it | Onyx beans, a hemp soda, an art print, a vintage lamp |
| **House-made** | Only places its producer runs have it | Thump's cold brew, a Call Your Mother bagel |
| **One of a kind** | Only one was ever made, so it's at one place until it sells | An original painting |

The kind decides what Item Details shows: the list of places, the price line, the main button and the community prompt.

Most of the schema already exists. The plan adds:
- `items.kind`, `items.at_every_location` and `items.sold_at`;
- a required `items.producer_id`, with community-started pages for brands and one shared Unknown maker;
- per-place price, sightings and condition on `availability`;
- visit lists in `profile`.

See [Schema changes](#schema-changes).

---

## The model

| Record | Table | Role |
|---|---|---|
| **Producer** | `directory.producers` | Makes things: Thump, Onyx, a soda maker, an artist, a brand like DWR. Trust signals like B Corp attach here and show on everything it makes. The community can start a producer's page, and the producer claims it later. |
| **Place** | `directory.places` | Somewhere you can go. A producer can run it (`run_by_producer_id`), or no producer does (a gallery, a consignment shop). |
| **Item** | `catalog.items` | One thing a producer makes. Every item has one, even if it's the shared Unknown maker (see [Brands and unknown makers](#brands-and-unknown-makers)). It has one kind. |
| **Availability** | `catalog.availability` | Links an item to a place that has it, with that place's price, whether it's new or secondhand, and when people last saw it there. |

A business that both makes and sells is two records: Thump the producer and Thump the café. That's what lets Thump open a second café, lets Onyx run eight, and fits places that make nothing (a gallery) and producers with no place (an artist). [Data Model](DATA_MODEL.md#producer-run-places) explains the same split with New Belgium.

---

## Item kinds

| | Goods | House-made | One of a kind |
|---|---|---|---|
| **Examples** | Onyx espresso blend, hemp soda, almond croissant, an art print, a vintage Toto lamp or 90s Levi's | Thump's cold brew, an Onyx latte, a Call Your Mother bagel | A painting, a one-off handmade chair |
| **Where it can be** | The producer's own places and any place that carries it, new or secondhand | Only places its producer runs: every location by default, or only some | One place at a time, until it sells |
| **Place list** | "Find it nearby", or "Also nearby" when opened from a place. Empty state asks people to add a place. | "Where to get it", or "All 5 Call Your Mother locations" with the nearest first. Hidden when there's only one place and you're on it. No "add a place" prompt. | None. "Where it is" shows the one place and when it was last seen. |
| **Price line** | "List price", or "$24 at Thump" when opened from a place. With no list price, "From $450". | "$5 at Thump" | "$1,200 at Gallery 12", or "Sold" |
| **Main button** | Find it nearby | Add the place to a visit list when there's one place, otherwise Find it nearby | Add the place to a visit list. Once sold: follow the artist. |
| **Community prompt** | "Bought or seen this lately? Help others by confirming the details." For secondhand: "Seen one lately? Let others know where it is." | "Had this lately? Let others know it's still on the menu." | "Seen it lately? Let others know it's still there." |

Goods have "Similar to this" below the place list. House-made and one-of-a-kind items show "More from" the producer instead, because the producer's other things are the better next step.

### Choosing a kind

Whoever adds the item answers two questions. The kind defaults to Goods, and a producer who claims the listing can change it.

1. **Was only one ever made?** Yes → One of a kind. Ask about the design, not the copy: a shop might have the only vintage Toto lamp around, but the lamp was made many times.
2. **Can you buy it anywhere other than the maker's own places?** Yes, or not sure → Goods. No → House-made, which then gets one setting: every location (the default) or only some.

Edge cases:

- A bakery that sells croissants in its own shop and to Onyx: **Goods**, since it travels.
- An original painting and prints of it are two items: **One of a kind** and **Goods**.
- A vintage lamp or 90s jeans: **Goods**. Being secondhand is about the copy, so it goes on each shop's availability row (see [Secondhand items and makers](#secondhand-items-and-makers)).

---

## Worked examples

| Example | Made by | Kind | Where it shows |
|---|---|---|---|
| Thump's cold brew | Thump | House-made, every location | Thump's café. A second café gets it automatically. |
| Beans Thump roasts and sells to other shops | Thump | Goods | Thump's cafés plus any shop that carries them |
| Onyx espresso blend sold at Thump | Onyx | Goods | Onyx's cafés and Thump, one row each, each with its own price |
| An Onyx latte | Onyx | House-made, every location | All 8 Onyx cafés |
| Bakery croissants sold at Onyx cafés | The bakery | Goods | The bakery's shop and each Onyx café that carries them |
| A local CBD soda at Thump | The soda maker | Goods | Thump and any other stockist |
| Call Your Mother's everything bagel | Call Your Mother | House-made, every location | All 5 delis |
| A special only one deli makes | Call Your Mother | House-made, only some | That deli |
| An original painting at a gallery | The artist | One of a kind | The gallery, until it sells |
| Prints of that painting | The artist | Goods | The gallery and anywhere else that carries them |
| A 1996 Toto Cube Lamp | DWR, a community-started page | Goods | Each shop with copies, its row marked secondhand |
| A pair of 90s Levi's 501s | Levi's, a community-started page | Goods | Each shop with a pair, its row marked secondhand |
| A hand-carved chair, maker unknown | Unknown maker | One of a kind | The shop that has it, until it sells |

Onyx is in Arizona. Its places illustrate how this works once Cove covers more than one city. In v1, every place is in the Denver metro area ([Geospatial gate](DATA_MODEL.md#geospatial-the-local-availability-gate)).

---

## House-made items and locations

Call Your Mother runs 5 delis in Denver with one menu. Other restaurants change the menu by location. Both keep **one item per dish**, and a setting on each house-made item decides which locations have it:

- **Every location** (`at_every_location = true`, the default). The item counts as available at every place its producer runs. That list is worked out when it's read, not stored, so a sixth deli has the menu on the day it opens and nothing has to be copied.
- **Only some** (`at_every_location = false`). The item is only where an availability row lists it, the same as goods. A new location doesn't get it.

For every-location items, a stored availability row only records an exception:

| Case | Example | What's stored |
|---|---|---|
| Same menu everywhere | Call Your Mother's bagels | Nothing beyond the item |
| Missing at one location | The smallest deli drops the hot sandwich | One row at that deli with `is_active = false` |
| Price differs at one location | One deli charges more for lox | One row at that deli with its own `price_cents` |
| Only at some locations | A deli's own special | `at_every_location = false`, plus a row at each deli that has it |

Copying the menu into each deli instead would mean one row per item per deli (20 for Call Your Mother), plus a copy job whenever a deli opens. Every place `cove-directory` added would then need a matching write from `cove-catalog`. Working it out on read avoids both, since `cove_catalog` can already read `directory.places`.

Every query that asks "where is this item?" has to use the same rule, and that includes the discovery query, which joins through `availability`. A view keeps the rule in one place:

```sql
-- Places that have each item: stored rows, plus implied rows for every-location
-- house-made items at the places their producer runs. A stored row at one of
-- those places overrides the implied one (is_active = false turns it off there).
CREATE VIEW catalog.item_places AS
SELECT a.item_id, a.place_id, coalesce(a.price_cents, i.price_cents) AS price_cents
FROM catalog.availability a
JOIN catalog.items i ON i.id = a.item_id
WHERE a.is_active
UNION ALL
SELECT i.id, p.id, i.price_cents
FROM catalog.items i
JOIN directory.places p ON p.run_by_producer_id = i.producer_id AND p.is_active
WHERE i.kind = 'house_made'
  AND i.at_every_location
  AND NOT EXISTS (
      SELECT 1 FROM catalog.availability a
      WHERE a.item_id = i.id AND a.place_id = p.id
  );
```

On Item Details, an every-location item with several places sums them up ("All 5 Call Your Mother locations"), shows the nearest 2, and puts the rest behind "See all". When some locations are turned off, it says "4 of 5 Call Your Mother locations" and "Not at RiNo". A location's own page lists the every-location items, minus any turned off there, plus its own specials marked "Only here".

**When people add a chain's item:** someone adds the everything bagel after one visit. Because Call Your Mother runs more than one deli, the bagel starts as every location, since most chains keep one menu. Someone who finds it missing taps "Not at this location", which turns it off at that deli. Once Call Your Mother claims its listing, it can set each item exactly.

---

## Secondhand items and makers

### Vintage isn't one of a kind

"One of a kind" means only one was ever made. Secondhand copies of a design made many times are **Goods**: one item for the design, and each shop's copies are an availability row marked secondhand. Discogs works the same way, with one page per record and many sellers' copies under it.

| | Item | Kind | What each shop has |
|---|---|---|---|
| 90s Levi's 501 | "Levi's 501, 1990s" (producer Levi's) | Goods | A row per shop: secondhand, its price, and a note like "W32, light wash" |
| 1996 Toto Cube Lamp | "Toto Cube Lamp, 1996" (producer DWR) | Goods | A local seller's row says 2 available at their price. A seller in another state has its own row. |
| An original painting, or a one-off handmade chair | One item | One of a kind | One place until it sells |

Availability gets three fields for this:
- **`condition`:** `new` or `secondhand`.
- **`quantity`:** optional.
- **`note`:** a short note for size or condition.

A shop with three pairs in different sizes is still one row ("W30–W34, from $68"), which keeps the one-row-per-item-per-place key. These fields record what a listing or a person reported, not live stock: Cove doesn't track inventory or model SKUs ([what's not modeled](DATA_MODEL.md#what-is-deliberately-not-modeled)).

**Secondhand sightings go stale faster.** Vintage stock turns over in days. A secondhand sighting older than about **2 weeks** shows "May have sold · last seen 3 weeks ago". A new-stock sighting waits about **4 weeks** before it shows as "Last seen here".

**Matching:** when someone adds the lamp at a second shop, "Add a place" should find the existing item, so the shop is added as a new row instead of creating a duplicate item.

**When an era deserves its own item** is a judgment call. "Levi's 501, 1990s" is worth separating from today's 501s, because people search for the era and it's priced differently. When the design hasn't really changed, a new copy and a secondhand copy can sit on the same item as separate rows.

### Brands and unknown makers

Every item has a producer:

- **Brands are producers.** DWR and Levi's get producer pages like any other maker. The community can start a page, and the business claims it later, using the provenance and claim fields planned in [Listings and ownership](DATA_MODEL.md#listings-and-ownership). Until a claim, Cove verifies any trust signals on the page, as it does for every listing.
- **Unknown makers share one fallback producer, Unknown maker.** It has no page and stays out of producer listings and trust scoring. On Item Details the producer line shows "Maker unknown" as plain text.
- **With no producer page**, "More at" the place replaces "More from" ("More at Loft 54"). Trust signals come from the place, and the top verification level is confirmed by a place that has the item ("Confirmed by Loft 54 · 2 weeks ago").

Whether community-started pages cover individual makers is still open. Today an individual appears only as a name attached to a place until they opt in, because a producer can be one person working from home.

---

## The place list on Item Details

- **Every place shows, nearest first, in a row that scrolls sideways.** Places within 25 mi come first. After the last of them, a small vertical divider in the row reads "More than 25 mi away", and the farther places follow it, also nearest first. Far places use the same card as nearby ones. The row shows up to 2 far places, and the section header shows "See all" when there are more. When nothing is within 25 mi, the row starts with the divider.
- **Compact cards:** the row uses compact place cards: a small photo, the type and distance, the name, and the availability line.
- **Opened from a place:** the price line uses that place's price ("$24 at Thump"), the list becomes "Also nearby" or "Other Onyx locations" and leaves out the place you came from, and the main button saves that place.
- **No list price** (common for secondhand): the price line starts from the cheapest place, "From $450".
- **Sightings:** each card says how fresh its information is, using the stale windows above. A recent sighting shows how many people saw it ("Seen here by 6 people"); a stale one shows when it was last seen ("Last seen here 5 weeks ago"). Sightings depend on community contributions, which are planned for v3 ([Out of scope for v1](DATA_MODEL.md#out-of-scope-for-v1)). Until then, cards show what the listing says.
- **Distances come from the area being browsed.** Onboarding asks for location services, and by default distances and ranking use where the person is. Someone can browse another area instead, like New York while planning a trip, and distances follow that area. Items, places and producers don't show a "Local" tag: being local is expressed through distance and ranking, not a badge.

In v1 all places are in the Denver metro area, so the far divider mostly matters for places at its edges, like Boulder or Castle Rock. It matters more once Cove covers several cities, which is also when browsing another city becomes useful.

---

## Verification on Item Details

The first block in More details says who confirmed the item's details and when. Its badge also sits after the item name.

| Level | Detail line |
|---|---|
| **Community added** | "Added by someone 5 days ago · not confirmed yet" |
| **Community verified** | "Confirmed by 14 people · 3 days ago" |
| **Producer verified** | "Confirmed by Wonderstate Coffee · 2 weeks ago". Adds "· 3 people since" only when people confirmed after the producer did. |

- **Every level shows the community prompt and a "Confirm details" button**, because details can change after anyone confirms them, like a new price. Confirm details lets people confirm the details as they are or edit what changed. The prompt follows the item kind (see [Item kinds](#item-kinds)).
- **The copy says "people", not "locals" or "users".** Cove doesn't check where anyone lives, and visitors confirm things too.

---

## Visit lists

The main button on Item Details saves a place to a visit list. People can make as many lists as they want, like one for a trip to San Francisco.

- Everyone starts with one list, **Want to visit**.
- With one list, the button saves straight to it. With more, it opens a picker. A list can have a city, and the list for the place's city is suggested first, so a San Francisco bakery suggests the San Francisco trip.
- Saving from Item Details remembers the item, so the list says why: "Sunset Bakery · for the Country Sourdough".
- Visit lists hold places you want to go. Favorites (`profile.favorites`) stay for items, and following a producer or place (`profile.follows`) keeps you up to date with it.

Lists work for any city, not only where someone is: browsing New York to plan a trip shows distances from New York, and the places save to the New York list.

Visit lists are user data, so they live in `cove-user`'s `profile` schema (see [Schema changes](#schema-changes)).

---

## Schema changes

### Already in the database

| Column or table | Used for |
|---|---|
| `directory.places.run_by_producer_id` | Which producer runs a place. Thump runs 1, Call Your Mother 5, Onyx 8, a gallery none. |
| `catalog.items.producer_id` (nullable today), `catalog.items.brand` | Who makes the item, or a plain brand name. The producer becomes required and `brand` is retired. |
| `catalog.items.price_cents` | The list price |
| `catalog.availability` (`item_id`, `place_id`, `listing_source`, `is_active`) | Which places have an item. `listing_source` already tells the producer's own place (`producer_listed`) apart from a stockist (`place_listed`). |
| `catalog.entity_signals` | Trust signals like B Corp, on a producer, place or item |

### To add

The names are a starting point, to be settled in the migrations.

```sql
ALTER TABLE catalog.items
    ADD COLUMN kind              text    NOT NULL DEFAULT 'goods'
        CHECK (kind IN ('goods', 'house_made', 'original')),
    ADD COLUMN at_every_location boolean NOT NULL DEFAULT true,  -- read only for house_made
    ADD COLUMN sold_at           timestamptz;                    -- original only; the item stays viewable

ALTER TABLE catalog.availability
    ADD COLUMN price_cents  integer,                             -- this place's price; null falls back to items.price_cents
    ADD COLUMN condition    text    NOT NULL DEFAULT 'new'
        CHECK (condition IN ('new', 'secondhand')),
    ADD COLUMN quantity     integer,                             -- as reported, not tracked stock
    ADD COLUMN note         text,                                -- "W30–W34", "sold as a pair"
    ADD COLUMN last_seen_at timestamptz,
    ADD COLUMN seen_count   integer NOT NULL DEFAULT 0;

-- cove-directory: one shared producer for items whose maker isn't known.
-- Identified by its slug; it has no page and stays out of producer listings
-- and trust scoring.
INSERT INTO directory.producers (name, slug) VALUES ('Unknown maker', 'unknown-maker');

-- cove-catalog, after brands are backfilled as producers and items with an
-- unknown maker point at the row above:
ALTER TABLE catalog.items ALTER COLUMN producer_id SET NOT NULL;
ALTER TABLE catalog.items DROP COLUMN brand;

CREATE TABLE profile.visit_lists (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES profile.users(id) ON DELETE CASCADE,
    name       text        NOT NULL,
    city       text,                                             -- optional; drives the suggested list
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON profile.visit_lists (user_id);

CREATE TABLE profile.visit_list_places (
    list_id  uuid        NOT NULL REFERENCES profile.visit_lists(id) ON DELETE CASCADE,
    place_id uuid        NOT NULL REFERENCES directory.places(id)    ON DELETE CASCADE,
    item_id  uuid        REFERENCES catalog.items(id)                ON DELETE SET NULL,  -- the item it was saved from
    added_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (list_id, place_id)
);
```

Rules that a column can't express:

- **House-made follows the producer.** The [`catalog.item_places` view](#house-made-items-and-locations) applies it on read.
- **One place for one of a kind.** An original has at most one active availability row. A partial unique index on `availability` can't see `items.kind`, so a trigger enforces this.
- **Stale windows** (about 14 days secondhand, 28 days new) are applied when the list is built, from `last_seen_at`.

---

## Decisions and open questions

| Status | Topic | Notes |
|---|---|---|
| **Decided** | Every location by default | Every house item is at every place its producer runs unless it's turned off at one. "Only some" covers a location's own specials. |
| **Decided** | Far places still show | Item Details lists every place that has it; places more than 25 mi away follow a "More than 25 mi away" divider inside the scrolling row. Still open: the exact cutoff, and whether people can set it themselves. |
| **Decided** | Visit lists live in `cove-user`, as many as you want | See [Visit lists](#visit-lists). |
| **Decided** | Vintage isn't one of a kind | Secondhand copies of a design are Goods, with the condition on each shop's row. Still open: the exact stale window, and when an era deserves its own item. |
| **Decided** | Location-based, with no Local tag | Onboarding asks for location services. Distances and ranking use the area being browsed, which is where the person is by default, so trip planning works. No Local tag on items, places or producers. See [The place list on Item Details](#the-place-list-on-item-details). |
| **Decided** | Every item has a producer | Brands get community-started producer pages that the business can claim; unknown makers share one Unknown maker with no page, and "More at" the place replaces "More from". See [Brands and unknown makers](#brands-and-unknown-makers). |
| **Open** | Community pages for individual makers | Today an individual appears only as a name until they opt in. Decide whether the community can start a page for one. |
| **Open** | Browsing another area | How someone picks the area they're browsing, and whether a visit list's city sets it automatically. |
| **Open** | Seasonal and limited-time items | A special that runs for a month could be "Only some" with an end date, or switched off when it ends. Not modeled yet. |
| **Open** | Sharing visit lists | Whether friends on the same trip can share a list. |
