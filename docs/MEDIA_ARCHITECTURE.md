# Media Architecture

> **Status:** Planned — built in Phase 2 alongside `cove-image`. v1 covers product images only; videos and documents are deferred. The bucket `cove-media` is already provisioned in Garage.

## Contents

- [Overview](#overview)
- [The mental model](#the-mental-model)
- [Data model](#data-model)
- [Variant catalog](#variant-catalog)
- [Serving variants](#serving-variants)
- [Picking variants on iOS](#picking-variants-on-ios)
- [Vendor upload flow](#vendor-upload-flow)
- [The imgproxy URL — anatomy](#the-imgproxy-url--anatomy)
- [Auth model](#auth-model)
- [Caching](#caching)
- [Pre-warming](#pre-warming)
- [Garbage collection](#garbage-collection)
- [What's deferred](#whats-deferred)
- [References](#references)

---

## Overview

Every product in Cove has at least one image, and most have a small gallery. Those images need to:

- Render fast and crisp on every device size (small iPhone to 4K desktop in a future web client)
- Survive an upload from any vendor's camera (HEIC, JPEG, PNG, oddly-rotated, with embedded GPS metadata)
- Cache aggressively at the edge so the cluster doesn't re-do work
- Stay safe from URL abuse without breaking how `<img>` and `AsyncImage` work

This doc describes the system that delivers all of that. For the broader catalog model see [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md); for product schema specifics see [Category & Product Architecture](CATEGORY_AND_PRODUCT_ARCHITECTURE.md); for Postgres mechanics see [Postgres Primer](POSTGRES_PRIMER.md).

---

## The mental model

Three pieces, each doing one thing well:

| Piece | Role |
|---|---|
| **Garage** (`cove-media` bucket) | Stores one canonical, high-resolution copy of every uploaded image. S3-compatible, in-cluster. |
| **imgproxy** | Generates resized / re-encoded variants on the fly from the canonical source. Open-source, libvips-backed, runs as a single Deployment in the cluster. |
| **Cloudflare** | Caches every uniquely-URL'd variant at the edge. Once warmed, the cluster never sees that exact URL again. |

The principle that ties them together: **one source of truth, infinite derived views.** Vendors upload once. imgproxy turns that one source into whatever shape a screen needs. Cloudflare remembers every shape and serves it from the edge. The cluster pays the transformation cost exactly once per (image, variant) combination.

---

## Data model

A product owns zero or more media items. The primary image is used in every list view; gallery images show up on the detail screen carousel.

```sql
CREATE TABLE product.product_media (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id  uuid        NOT NULL REFERENCES product.products(id) ON DELETE CASCADE,
    media_key   text        NOT NULL,                 -- Garage object key (content-addressed)
    role        text        NOT NULL CHECK (role IN ('primary', 'gallery')),
    sort_order  integer     NOT NULL DEFAULT 0,
    alt_text    text,                                 -- accessibility, future SEO
    width       integer     NOT NULL,                 -- source dimensions (for layout hints)
    height      integer     NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),

    -- Exactly one primary per product. Deferrable so vendors can swap
    -- primary in a single transaction (DELETE + INSERT or two UPDATEs).
    UNIQUE (product_id, role) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX ON product.product_media (product_id, sort_order);
```

Notes:

- **`media_key` is content-addressed.** `cove-image` writes objects under `<sha256-of-bytes>.webp`, so the same upload twice never wastes storage and never overwrites a different image.
- **`width` / `height` are source dimensions.** Clients use these to reserve layout space *before* the image loads, eliminating layout shift in list views.
- **No `image_key` column on `products`.** The primary image is `WHERE role = 'primary'` on this table; list queries pull it via a `LATERAL JOIN`.
- **`ON DELETE CASCADE`.** Deleting a product removes its media rows automatically. (The Garage objects themselves are pruned by a separate cleanup job — see "Garbage collection" below.)

### Why a child table, not multiple columns on `products`

A `primary_image_key` + `gallery_image_keys jsonb` shape on `products` would work for v1 but:

- Variable-cardinality gallery items model badly in flat columns
- Sort order would either live in the JSONB (awkward to UPDATE) or require renaming columns
- Cascade behavior is cleaner with a real child table
- Alt text and source dimensions need somewhere structured to live

The child-table cost is one JOIN per product on list queries — indexed, negligible.

---

## Variant catalog

A small, fixed catalog of sizes. Server-defined; clients pick by name.

| Variant | Dimensions | Used for |
|---|---|---|
| `thumb` | 200 × 200 | Search result thumbnails, small grid views (1×) |
| `sm` | 400 × 400 | List views (2×), avatar-like contexts |
| `md` | 800 × 800 | Detail hero (1×) / list views (3× on Pro iPhones) |
| `lg` | 1600 × 1600 | Detail hero / carousel (2×) |
| `xl` | 3200 × 3200 | Retina desktop / future web client |

All variants resize with `fill` mode (crop overflow to exact square dimensions). Output format is WebP for v1; AVIF support can be added with a new variant suffix without disturbing existing URLs.

### Why a fixed catalog, not arbitrary client-requested dimensions

| Aspect | Fixed catalog (chosen) | Arbitrary dimensions |
|---|---|---|
| CDN cache hit rate | Bounded set of URLs per image — predictable | Each unique dimension fragments cache; near-duplicates never share a hit |
| Signing surface | Server signs only catalog URLs; client cannot ask for any other | Server has to sign anything the client asks for, or expose the signing key |
| Forward compatibility | Add a new variant by deploying server config | No central place to manage available sizes |
| iOS implementation | Switch over a known enum | Compute pixel dimensions everywhere |

### Adding a new variant

When the future web client needs `2k` (2048 × 2048) for retina laptops:

1. Add the row to the catalog (single config value in `cove-product` / `cove-image`)
2. Server starts including `2k` in response shapes that already return the full set (or add it to specific endpoints)
3. Clients that know about it use it; clients that don't ignore it

No migration. No URL rotation. No cache invalidation.

---

## Serving variants

Response shapes differ by endpoint — list views need one image with a few sizes; detail views need the full gallery with the full size set.

### List endpoint (e.g. search, browse)

OpenAPI schema:

```yaml
ProductSummary:
  properties:
    id:         { type: string, format: uuid }
    name:       { type: string }
    priceCents: { type: integer }
    vendorName: { type: string }
    primaryImage:
      $ref: '#/components/schemas/ImageVariants'

ImageVariants:
  required: [width, height]
  properties:
    width:   { type: integer }
    height:  { type: integer }
    altText: { type: string }
    thumb:   { type: string, format: uri }
    sm:      { type: string, format: uri }
    md:      { type: string, format: uri }
```

SQL backing it (search query, primary image only):

```sql
SELECT
    p.id, p.name, p.price_cents,
    v.name AS vendor_name,
    m.media_key, m.width, m.height, m.alt_text
FROM product.products p
JOIN vendor.vendors v ON v.id = p.vendor_id
LEFT JOIN LATERAL (
    SELECT media_key, width, height, alt_text
    FROM product.product_media
    WHERE product_id = p.id AND role = 'primary'
    LIMIT 1
) m ON TRUE
WHERE p.is_active
  AND p.search_vec @@ websearch_to_tsquery('english', $1)
ORDER BY ts_rank(p.search_vec, websearch_to_tsquery('english', $1)) DESC
LIMIT $2;
```

The Go handler then signs three imgproxy URLs per result (`thumb`, `sm`, `md`) and assembles the response.

### Detail endpoint

OpenAPI schema:

```yaml
ProductDetail:
  properties:
    # ...all the product fields...
    media:
      type: array
      items: { $ref: '#/components/schemas/ProductMedia' }

ProductMedia:
  required: [role, width, height]
  properties:
    role:    { type: string, enum: [primary, gallery] }
    altText: { type: string }
    width:   { type: integer }
    height:  { type: integer }
    variants:
      properties:
        thumb: { type: string, format: uri }
        sm:    { type: string, format: uri }
        md:    { type: string, format: uri }
        lg:    { type: string, format: uri }
        xl:    { type: string, format: uri }
```

SQL fetches the full gallery for the product:

```sql
SELECT id, media_key, role, sort_order, alt_text, width, height
FROM product.product_media
WHERE product_id = $1
ORDER BY sort_order;
```

The handler signs all five variants per media item.

### Payload size

A list response with 25 results × 3 variant URLs (~200 chars each) is ~15 KB just in image URLs — fine over modern mobile networks, cheaper than fetching extra metadata. Detail responses with 6 media items × 5 variants are ~6 KB — also fine.

---

## Picking variants on iOS

The client knows two things: the rendering context (target point size) and the device pixel scale (`UIScreen.main.scale` or the SwiftUI environment equivalent).

```swift
extension ImageVariants {
    /// Pick the smallest variant whose width meets or exceeds the target pixel size.
    /// Falls back to the largest available if the target exceeds the catalog.
    func url(forTargetPointSize size: CGFloat,
             scale: CGFloat = UIScreen.main.scale) -> URL? {
        let target = size * scale
        let candidate: String?
        switch target {
        case ..<300:   candidate = thumb
        case ..<600:   candidate = sm
        case ..<1200:  candidate = md
        case ..<2400:  candidate = lg
        default:       candidate = xl
        }
        return candidate.flatMap(URL.init(string:))
    }
}

// Usage
AsyncImage(url: product.primaryImage.url(forTargetPointSize: 150)) { phase in
    switch phase {
    case .success(let image): image.resizable().scaledToFill()
    case .failure:            Color.gray
    case .empty:              ProgressView()
    @unknown default:         EmptyView()
    }
}
.aspectRatio(
    product.primaryImage.width / product.primaryImage.height,
    contentMode: .fill
)
.frame(width: 150, height: 150)
.clipped()
```

The `width`/`height` from the response means the `AsyncImage` reserves its space before the bytes arrive — no layout shift when the image loads in.

For a future web client, the same response shape maps directly to `<picture>` with `srcset` (no client-side variant-selection logic needed; the browser does it).

---

## Vendor upload flow

Vendors upload once; the server handles everything that needs to be identical across products.

### Minimum requirements (enforced server-side in `cove-image`)

| Requirement | Value | Why |
|---|---|---|
| Minimum dimensions | 2000 × 2000 | Need clean downscale to `xl` (3200) without upscaling artifacts on retina displays |
| Maximum dimensions | 8000 × 8000 | Cap imgproxy memory/CPU per transformation |
| Maximum file size | 20 MB | Generous for high-quality phone or DSLR shots |
| Accepted formats | JPEG, PNG, WebP, HEIC | HEIC is iPhone's default; accepting it removes friction for vendors |
| Aspect ratio | Any (documented preference: square or 4:3 for catalog browsing) | Server `fill`-crops to square variants regardless |

These are returned in a structured error response when violated so the client can show a useful message ("Image must be at least 2000×2000 pixels").

### Normalization pipeline

After accepting the upload, `cove-image` runs the bytes through libvips before writing to Garage:

```
1. Decode source format            (handles HEIC, JPEG, PNG, WebP)
2. Auto-rotate from EXIF flag      (phone photos often have rotation set)
3. Strip EXIF metadata             (privacy: removes GPS coordinates; size win)
4. Convert color space to sRGB     (consistency across devices and imgproxy reads)
5. Re-encode as WebP, quality 90   (high-fidelity, compact)
6. Compute SHA-256 of resulting bytes
7. Write to Garage as cove-media/<sha256>.webp
8. Return { key, width, height } to the caller
```

Why each step matters:

- **Strip EXIF** — phone photos embed GPS coordinates by default. Without this, every product image leaks the vendor's location.
- **Auto-rotate** — phones store the image with the sensor's native orientation and a separate rotation flag. Without rotating during decode, half the uploads display sideways.
- **sRGB color space** — Adobe RGB and P3 sources render with shifted colors when imgproxy converts them at delivery time. Normalizing once on upload avoids surprises.
- **WebP quality 90** — visually lossless; ~40-60% smaller than the equivalent JPEG. Cheap storage win.
- **Content-addressed key** — if a vendor uploads the same image twice (different products, same source photo), Garage stores one object. If a vendor mid-upload retries, we don't pollute storage with half-written objects.

### Associating with a product

Upload is decoupled from product association:

1. Vendor app calls `POST /images` with the image bytes → response: `{ media_key, width, height }`
2. Vendor app calls `POST /products` (or `PATCH`) with the desired role: `{ media_key, role: 'primary' }`
3. `cove-product` inserts into `product_media`

This split means a vendor can upload several images and then arrange them — no need for the upload endpoint to know about products.

---

## The imgproxy URL — anatomy

Every variant URL the server returns looks like this:

```
https://api.coveapp.dev/i/<sig>/rs:fill:600:600/plain/s3://cove-media/<key>.webp@webp
└─────┬──────────┘  └┬┘ └─┬┘ └──────┬───────┘  └──┬──┘ └──────┬──────────┘  └─┬─┘
   public host       │  signature  processing      source     S3 source URL    output
                    path           options          format    (Garage)        format
                    prefix
```

| Component | What it does |
|---|---|
| `https://api.coveapp.dev` | Public hostname (Cloudflare Tunnel) |
| `/i/` | Path prefix routed to imgproxy via cove-gateway. **Not Bearer-authenticated** — see [Auth model](#auth-model) below. |
| `<sig>` | HMAC-SHA256 signature over the path. Server-side secret. Prevents URL forgery. |
| `rs:fill:600:600` | imgproxy processing options. `rs` = resize, `fill` = crop to fill exact dimensions. Other options chainable: `rs:fill:600:600/q:80/bg:fff`. |
| `plain/` | Source URL format mode. `plain` keeps the source URL human-readable; alternative is base64. |
| `s3://cove-media/<key>.webp` | The source for imgproxy to fetch. imgproxy is configured (via env) to resolve `s3://` against the in-cluster Garage endpoint. |
| `@webp` | Output format. imgproxy transcodes to this regardless of source format. |

### Signing in Go

```go
type ImgproxyClient struct {
    PublicBaseURL string  // "https://api.coveapp.dev"
    Key           []byte  // IMGPROXY_KEY (from ESO secret)
    Salt          []byte  // IMGPROXY_SALT (from ESO secret)
}

func (c *ImgproxyClient) SignedURL(bucket, key, variant string) string {
    width, height := variantDimensions(variant)  // looks up the catalog
    path := fmt.Sprintf(
        "/rs:fill:%d:%d/plain/s3://%s/%s@webp",
        width, height, bucket, key,
    )
    mac := hmac.New(sha256.New, c.Key)
    mac.Write(c.Salt)
    mac.Write([]byte(path))
    sig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
    return fmt.Sprintf("%s/i/%s%s", c.PublicBaseURL, sig, path)
}
```

The signing key + salt are 32+ byte random values stored in GCP Secret Manager and synced into the cluster via ExternalSecret. The same values are mounted into the imgproxy Deployment as `IMGPROXY_KEY` and `IMGPROXY_SALT`.

If the keys ever drift, every URL signed with one fails verification on the other — a clear, loud failure mode (every image returns 403).

---

## Auth model

This is the most nuanced part of the architecture. Image URLs need to coexist with three constraints:

1. **Cloudflare wants to cache by URL.** Per-user URLs destroy hit rate.
2. **`<img src>` and `AsyncImage` don't add auth headers.** Custom URLSession wiring at every image-loading site is unworkable.
3. **The catalog is a marketplace.** Product images are inherently meant to be seen by potential buyers.

### The four options

| Option | How it works | CDN-friendly | Right for |
|---|---|---|---|
| **A. Public signed URLs** | Signature makes URL unguessable; anyone with the URL can fetch | ✅ Yes — same URL for all users | Public catalog images |
| **B. Per-user signed URLs** | Server signs with user UID embedded; each user gets a unique URL | ❌ No — cache fragments per user | Private documents per user |
| **C. Short-lived signed URLs** | Signature includes expiration; URL works for a window (e.g. 1 hour) | ⚠️ Within the validity window, yes; URLs rotate when keys do | Vendor drafts, time-limited access |
| **D. Token-protected URLs** | Every fetch requires a Bearer header | ❌ No — every user pays full transformation cost | Genuinely private data with no cacheability requirement |

### Recommendation for Cove

**Per-image-class strategy:**

| Image class | Strategy | Expiry |
|---|---|---|
| Active catalog (`is_active = true` on the product) | Option A — public signed | Effectively unlimited |
| Vendor drafts (`is_active = false`, not yet published) | Option C — short-lived signed | 1 hour, refreshed via authenticated endpoint |
| Truly private (future: vendor verification documents, receipts) | Option D — token-protected | Per-request auth, no CDN |

The implementation is straightforward: `cove-product` checks the product state when constructing the URL and decides which signing mode to use. imgproxy's `IMGPROXY_TOKEN_EXP` config supports verifying the expiry portion of the signature.

### "But the catalog is auth-only — why is the image URL public?"

Image **URLs** are public; the **API that produces them** is not. To discover a product image's URL, a client must first call `/products/search` or `/products/{id}` with a valid Firebase ID Token. The Bearer-token check at `cove-gateway` happens *before* the URL is returned.

Once a URL is in hand, anyone can fetch the bytes — but the URL is unguessable (HMAC-SHA256 signature), and you can't enumerate them without going through the authenticated API. This is the same pattern Etsy, Shopify storefronts, Amazon product images, and every major marketplace uses. Authenticated image serving is reserved for things like medical records, financial documents, and other categories where bytes leaking would be a real harm — not for product catalog images.

---

## Caching

The architecture is layered specifically so the cluster does each transformation **once, ever**:

```
Layer        Caches                          Lifetime
─────        ──────                          ────────
Cloudflare   Variant URL → variant bytes     1 year (immutable URLs)
imgproxy     (none; relies on Cloudflare)    —
Cluster      Garage → original bytes         indefinite
```

### Cache hit rate

For a typical catalog browse session:
- First user to view product X at variant `md`: imgproxy transforms (~30-80ms libvips), Cloudflare caches
- Every subsequent user requesting the same variant URL: served from Cloudflare edge (~10-30ms total round-trip), cluster never sees the request

Because URLs are deterministic (same source key + same variant = same URL across all callers), every product's variants converge to the cache quickly. The cluster's imgproxy pod handles a small, bounded number of transformations: **(images uploaded) × (variants in catalog)**. At 1,000 products with 5 images each and a 5-variant catalog, that's 25,000 transformations across the lifetime of the product. Negligible.

### Cache headers from imgproxy

```http
Cache-Control: public, max-age=31536000, immutable
ETag: "<sha256-of-bytes>"
```

`immutable` tells Cloudflare (and browser caches) that the URL's response will never change — they can serve from cache without revalidation. This is safe because the URL itself encodes the content (via `media_key` = SHA-256 of source bytes). If the source changes, it gets a new key, which produces new URLs.

### When does the cache miss?

- First request for a (source, variant) combination since deployment
- A new variant is added to the catalog
- The signing key rotates (every URL becomes invalid → forces re-signing on the server and re-fetching by clients)

The first two are normal cache-warm scenarios. The third is operationally significant: rotate keys rarely (or not at all), and have a plan if you need to.

---

## Pre-warming

Optionally, `cove-image` can pre-warm Cloudflare's cache right after a successful upload:

```go
go func(key string) {
    for _, variant := range []string{"thumb", "sm", "md", "lg", "xl"} {
        url := imgproxy.SignedURL(bucket: "cove-media", key, variant)
        // HEAD request: warms Cloudflare's cache without downloading bytes
        _, _ = http.Head(url)
    }
}(key)
```

Errors are ignored — if pre-warming fails, the first real user request just triggers a normal cache miss and continues. This is purely opportunistic optimization to make the first user of a new product see snappy load times.

For products with very high traffic, the variants stay warm at the Cloudflare edge naturally; pre-warming is mostly useful for the long tail (new products, infrequently-viewed items where the cache might have evicted).

---

## Garbage collection

When a product is deleted, `ON DELETE CASCADE` removes its `product_media` rows. The Garage objects themselves are **not** automatically removed — we want to keep them briefly in case a vendor changes their mind, and content-addressing means the same image might still be referenced by another product.

A small periodic job sweeps unreferenced objects:

```sql
-- Find Garage keys referenced by no product_media row.
-- Run weekly; delete objects older than 30 days that don't appear in this query.
SELECT DISTINCT media_key FROM product.product_media;
```

The job lists Garage objects, diffs against the SELECT, and deletes any object that is:
- Not referenced in `product_media`
- Older than 30 days (gives vendors a window to recover)

This stays out of the hot path entirely.

---

## What's deferred

These are real future requirements but explicitly out of scope for v1:

- **Videos** — would need a separate pipeline (HLS/DASH transcoding, manifest generation, per-bandwidth renditions). No imgproxy equivalent for video that fits this stack cleanly.
- **Documents** (vendor certifications, ingredient lists as PDFs) — would use Option D (token-protected, no transformation, just signed-URL serving).
- **Watermarking** — imgproxy supports it; not a v1 product requirement.
- **AI-driven cropping** (face detection, salient-object detection) — imgproxy supports `gravity:smart`; defer until v1 catalog shows it's needed.
- **AVIF output** — modern format, ~20% smaller than WebP. Add as a new variant suffix when iOS / web client adoption justifies the imgproxy CPU cost increase.
- **Per-vendor signing keys** — would let us revoke one vendor's image access without rotating the global key. Defer until vendor portal exists.

Each of these can slot in without disturbing the v1 architecture — add a new endpoint, new variant, new field on `product_media`, or new background job. The data model and serving model don't need to change to accommodate them.

---

## References

- [Marketplace Architecture](MARKETPLACE_ARCHITECTURE.md) — the broader service layout and data model
- [Category & Product Architecture](CATEGORY_AND_PRODUCT_ARCHITECTURE.md) — product schema and category hierarchy
- [Postgres Primer](POSTGRES_PRIMER.md) — Postgres mechanics
- [Backend Infrastructure](BACKEND_INFRASTRUCTURE.md) — cluster topology, deployment, Garage
- [imgproxy documentation](https://docs.imgproxy.net/) — full options reference, signing details, deployment guides
