package handler

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5/pgtype"
)

// discoveryResult is one item in the GET /discovery response.
type discoveryResult struct {
	ID           string           `json:"id"`
	Name         string           `json:"name"`
	Description  *string          `json:"description,omitempty"`
	PriceCents   *int             `json:"price_cents,omitempty"`
	Brand        *string          `json:"brand,omitempty"`
	Producer     *producerSummary `json:"producer,omitempty"` // nil for brand-only and secondhand items
	NearestPlace placeSummary     `json:"nearest_place"`
	Places       []placeSummary   `json:"places"`
	PrimaryImage *ImageVariants   `json:"primary_image,omitempty"`
	BaseTrust    float64          `json:"base_trust"`
	Score        float64          `json:"score"`
}

type producerSummary struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	TrustScore float64 `json:"trust_score"`
}

type placeSummary struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Type       string   `json:"type"`
	DistanceM  *float64 `json:"distance_m,omitempty"`
	ListingURL *string  `json:"listing_url,omitempty"`
}

// DiscoveryHandler handles GET /discovery.
//
// Query params (all optional):
//   - q        — free-text search term
//   - lat, lon — decimal-degree coordinates; must appear together
//   - radius   — search radius in metres (default 50 000 when lat/lon provided)
//   - category — ltree path; scopes results to that subtree (e.g. "food.coffee")
func (d *Deps) DiscoveryHandler(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	latStr := r.URL.Query().Get("lat")
	lonStr := r.URL.Query().Get("lon")
	radiusStr := r.URL.Query().Get("radius")
	category := r.URL.Query().Get("category")

	var lat, lon, radiusM *float64
	if latStr != "" || lonStr != "" {
		if latStr == "" || lonStr == "" {
			writeError(w, http.StatusBadRequest, "lat and lon must be provided together")
			return
		}
		la, err1 := strconv.ParseFloat(latStr, 64)
		lo, err2 := strconv.ParseFloat(lonStr, 64)
		if err1 != nil || err2 != nil {
			writeError(w, http.StatusBadRequest, "lat and lon must be valid decimal numbers")
			return
		}
		lat = &la
		lon = &lo

		defaultRadius := 50_000.0 // 50 km
		if radiusStr != "" {
			rm, err := strconv.ParseFloat(radiusStr, 64)
			if err != nil || rm <= 0 {
				writeError(w, http.StatusBadRequest, "radius must be a positive number (metres)")
				return
			}
			defaultRadius = rm
		}
		radiusM = &defaultRadius
	}

	sql, args := buildDiscoverySQL(q, lat, lon, radiusM, category)

	rows, err := d.DB.Query(r.Context(), sql, args...)
	if err != nil {
		log.Printf("ERROR discovery query: %v", err)
		writeError(w, http.StatusInternalServerError, "discovery query failed")
		return
	}
	defer rows.Close()

	type rawRow struct {
		itemID             pgtype.UUID
		itemName           string
		description        *string
		priceCents         *int32
		brand              *string
		producerID         pgtype.UUID
		producerName       *string
		producerTrustScore *float64
		plID               pgtype.UUID
		plName             string
		plType             string
		plListingURL       *string
		distanceM          *float64
		baseTrust          float64
		score              float64
		mediaKey           *string
		imgWidth           *int32
		imgHeight          *int32
	}

	var raws []rawRow
	itemIDs := make([]pgtype.UUID, 0, 25)

	for rows.Next() {
		var rw rawRow
		if err := rows.Scan(
			&rw.itemID, &rw.itemName, &rw.description, &rw.priceCents, &rw.brand,
			&rw.producerID, &rw.producerName, &rw.producerTrustScore,
			&rw.plID, &rw.plName, &rw.plType, &rw.plListingURL,
			&rw.distanceM, &rw.baseTrust, &rw.score,
			&rw.mediaKey, &rw.imgWidth, &rw.imgHeight,
		); err != nil {
			log.Printf("ERROR discovery scan: %v", err)
			writeError(w, http.StatusInternalServerError, "result scan failed")
			return
		}
		raws = append(raws, rw)
		itemIDs = append(itemIDs, rw.itemID)
	}
	if err := rows.Err(); err != nil {
		log.Printf("ERROR discovery rows: %v", err)
		writeError(w, http.StatusInternalServerError, "result iteration failed")
		return
	}

	if len(raws) == 0 {
		writeJSON(w, http.StatusOK, map[string]any{"results": []any{}})
		return
	}

	plMap, err := fetchPlacesForItems(r.Context(), d, itemIDs, lat, lon)
	if err != nil {
		log.Printf("ERROR fetching places: %v", err)
		writeError(w, http.StatusInternalServerError, "place query failed")
		return
	}

	results := make([]discoveryResult, 0, len(raws))
	for _, rw := range raws {
		itemIDStr := formatUUID(rw.itemID)

		var priceCents *int
		if rw.priceCents != nil {
			pc := int(*rw.priceCents)
			priceCents = &pc
		}

		var primaryImage *ImageVariants
		if rw.mediaKey != nil && *rw.mediaKey != "" {
			w2, h2 := 0, 0
			if rw.imgWidth != nil {
				w2 = int(*rw.imgWidth)
			}
			if rw.imgHeight != nil {
				h2 = int(*rw.imgHeight)
			}
			primaryImage = d.signListVariants(*rw.mediaKey, w2, h2)
		}

		var producer *producerSummary
		if rw.producerID.Valid {
			producer = &producerSummary{
				ID:         formatUUID(rw.producerID),
				Name:       *rw.producerName,
				TrustScore: *rw.producerTrustScore,
			}
		}

		results = append(results, discoveryResult{
			ID:          itemIDStr,
			Name:        rw.itemName,
			Description: rw.description,
			PriceCents:  priceCents,
			Brand:       rw.brand,
			Producer:    producer,
			NearestPlace: placeSummary{
				ID:         formatUUID(rw.plID),
				Name:       rw.plName,
				Type:       rw.plType,
				DistanceM:  rw.distanceM,
				ListingURL: rw.plListingURL,
			},
			Places:       plMap[itemIDStr],
			PrimaryImage: primaryImage,
			BaseTrust:    rw.baseTrust,
			Score:        rw.score,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{"results": results})
}

// buildDiscoverySQL constructs the discovery SELECT and its bound arguments.
// All parameters except the active flags are optional; the query degrades
// gracefully when none of q / geo / category are supplied (returns all active
// items ranked by trust score).
func buildDiscoverySQL(q string, lat, lon, radiusM *float64, category string) (string, []any) {
	var args []any
	n := 0
	bind := func(v any) string {
		args = append(args, v)
		n++
		return fmt.Sprintf("$%d", n)
	}

	hasGeo := lat != nil && lon != nil && radiusM != nil
	hasQ := q != ""
	hasCat := category != ""

	// Bind all parameters upfront so we can reference the same placeholder
	// in both SELECT and WHERE without repeating the value.
	var qRef, lonRef, latRef, radiusRef, catRef string
	if hasQ {
		qRef = bind(q)
	}
	if hasGeo {
		lonRef = bind(*lon)
		latRef = bind(*lat)
		radiusRef = bind(*radiusM)
	}
	if hasCat {
		catRef = bind(category)
	}

	// Geography point expression used in both score and WHERE.
	var geoPoint string
	if hasGeo {
		geoPoint = fmt.Sprintf("ST_Point(%s, %s)::geography", lonRef, latRef)
	}

	// Blended score: trust 40 %, relevance 30 %, proximity 30 %.
	var scoreParts []string
	scoreParts = append(scoreParts, "0.40 * (coalesce(pr.trust_score, 0) + pl.trust_score)")
	if hasQ {
		scoreParts = append(scoreParts,
			fmt.Sprintf("0.30 * ts_rank(p.search_vec, websearch_to_tsquery('english', %s))", qRef))
	}
	if hasGeo {
		scoreParts = append(scoreParts,
			fmt.Sprintf("0.30 * (1.0 / (1 + ST_Distance(pl.location, %s)))", geoPoint))
	}
	scoreExpr := strings.Join(scoreParts, "\n            + ")

	// Distance column expression — NULL for non-geo queries.
	distanceExpr := "NULL::double precision"
	if hasGeo {
		distanceExpr = fmt.Sprintf("ST_Distance(pl.location, %s)", geoPoint)
	}

	// WHERE predicates.
	var where []string
	// An item may have no producer; when it has one, the producer must be active.
	where = append(where, "p.is_active", "(pr.id IS NULL OR pr.is_active)", "a.is_active", "pl.is_active")
	if hasQ {
		where = append(where, fmt.Sprintf(
			"p.search_vec @@ websearch_to_tsquery('english', %s)", qRef))
	}
	if hasGeo {
		where = append(where, fmt.Sprintf(
			"ST_DWithin(pl.location, %s, %s)", geoPoint, radiusRef))
	}
	if hasCat {
		where = append(where, fmt.Sprintf(
			"p.category_id IN (SELECT id FROM catalog.categories WHERE path <@ %s::ltree)", catRef))
	}
	whereClause := strings.Join(where, "\n      AND ")

	sql := fmt.Sprintf(`
WITH ranked AS (
    SELECT DISTINCT ON (p.id)
        p.id,
        p.name,
        p.description,
        p.price_cents,
        p.brand,
        pr.id                               AS producer_id,
        pr.name                             AS producer_name,
        pr.trust_score                      AS producer_trust_score,
        pl.id                               AS pl_id,
        pl.name                             AS pl_name,
        pl.type                             AS pl_type,
        a.listing_url                       AS pl_listing_url,
        %s                                  AS distance_m,
        (coalesce(pr.trust_score, 0) + pl.trust_score) AS base_trust,
        (%s)                                AS score,
        img.media_key,
        img.width                           AS img_width,
        img.height                          AS img_height
    FROM catalog.items             p
    LEFT JOIN directory.producers  pr ON pr.id = p.producer_id
    JOIN catalog.availability      a  ON a.item_id = p.id
    JOIN directory.places          pl ON pl.id = a.place_id
    LEFT JOIN LATERAL (
        SELECT media_key, width, height
        FROM   catalog.media
        WHERE  item_id = p.id AND role = 'primary'
        LIMIT  1
    ) img ON TRUE
    WHERE %s
    ORDER BY p.id, (%s) DESC
)
SELECT
    id, name, description, price_cents, brand,
    producer_id, producer_name, producer_trust_score,
    pl_id, pl_name, pl_type, pl_listing_url,
    distance_m, base_trust, score,
    media_key, img_width, img_height
FROM ranked
ORDER BY score DESC
LIMIT 25`,
		distanceExpr,
		scoreExpr,
		whereClause,
		scoreExpr,
	)

	return sql, args
}

// fetchPlacesForItems returns a map of itemID string → []placeSummary
// for all active places stocking any of the given items.
func fetchPlacesForItems(ctx context.Context, d *Deps, itemIDs []pgtype.UUID, lat, lon *float64) (map[string][]placeSummary, error) {
	if len(itemIDs) == 0 {
		return nil, nil
	}

	var args []any
	args = append(args, itemIDs)

	var distanceExpr string
	if lat != nil && lon != nil {
		distanceExpr = "ST_Distance(pl.location, ST_Point($2, $3)::geography)"
		args = append(args, *lon, *lat)
	} else {
		distanceExpr = "NULL::double precision"
	}

	sql := fmt.Sprintf(`
SELECT
    a.item_id,
    pl.id,
    pl.name,
    pl.type,
    a.listing_url,
    %s AS distance_m
FROM catalog.availability a
JOIN directory.places     pl ON pl.id = a.place_id
WHERE a.item_id = ANY($1)
  AND a.is_active
  AND pl.is_active
ORDER BY a.item_id, distance_m NULLS LAST`, distanceExpr)

	rows, err := d.DB.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[string][]placeSummary)
	for rows.Next() {
		var itemID, plID pgtype.UUID
		var plName, plType string
		var listingURL *string
		var distM *float64

		if err := rows.Scan(&itemID, &plID, &plName, &plType, &listingURL, &distM); err != nil {
			return nil, err
		}
		key := formatUUID(itemID)
		result[key] = append(result[key], placeSummary{
			ID:         formatUUID(plID),
			Name:       plName,
			Type:       plType,
			DistanceM:  distM,
			ListingURL: listingURL,
		})
	}
	return result, rows.Err()
}
