package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

// itemDetail is the GET /items/:id response body.
type itemDetail struct {
	ID          string           `json:"id"`
	Name        string           `json:"name"`
	Description *string          `json:"description,omitempty"`
	PriceCents  *int             `json:"price_cents,omitempty"`
	Attributes  json.RawMessage  `json:"attributes,omitempty"`
	Details     json.RawMessage  `json:"details,omitempty"`
	CategoryID  string           `json:"category_id"`
	Brand       *string          `json:"brand,omitempty"`
	Producer    *producerSummary `json:"producer,omitempty"` // nil for brand-only and secondhand items
	Signals     []Signal         `json:"signals"`
	Places      []placeDetail    `json:"places"`
	Media       []ItemMedia      `json:"media"`
}

type placeDetail struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	Type       string  `json:"type"`
	ListingURL *string `json:"listing_url,omitempty"`
}

// ItemHandler handles GET /items/{id}.
// Returns full item detail: signals (item + producer + place), all
// places, and signed imgproxy URLs for all five media variants.
func (d *Deps) ItemHandler(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "missing item id")
		return
	}

	// ── Core item + producer ───────────────────────────────────────────────
	const itemSQL = `
SELECT
    p.id, p.name, p.description, p.price_cents,
    p.attributes, p.details, p.category_id::text, p.brand,
    pr.id AS producer_id, pr.name AS producer_name, pr.trust_score
FROM catalog.items p
LEFT JOIN directory.producers pr ON pr.id = p.producer_id
WHERE p.id = $1 AND p.is_active`

	var (
		itemID, producerID  pgtype.UUID
		itemName            string
		producerName, brand *string
		description         *string
		priceCents          *int32
		attributes, details []byte
		categoryID          string
		producerTrust       *float64
	)
	err := d.DB.QueryRow(r.Context(), itemSQL, id).Scan(
		&itemID, &itemName, &description, &priceCents,
		&attributes, &details, &categoryID, &brand,
		&producerID, &producerName, &producerTrust,
	)
	if err != nil {
		if isNotFound(err) {
			writeError(w, http.StatusNotFound, "item not found")
			return
		}
		log.Printf("ERROR item query id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "item query failed")
		return
	}

	// ── Signals: item + producer + places that carry this item ─────────────
	const signalsSQL = `
SELECT scope, code, name, description, weight, status, verified_at, cert_number
FROM (
    SELECT 'item'     AS scope, s.code, s.name, s.description, s.weight,
           es.status, es.verified_at, es.cert_number
    FROM catalog.entity_signals es
    JOIN catalog.signals s ON s.id = es.signal_id
    WHERE es.item_id = $1 AND s.is_active

    UNION ALL

    SELECT 'producer' AS scope, s.code, s.name, s.description, s.weight,
           es.status, es.verified_at, es.cert_number
    FROM catalog.entity_signals es
    JOIN catalog.signals s ON s.id = es.signal_id
    JOIN catalog.items   i ON i.producer_id = es.producer_id
    WHERE i.id = $1 AND s.is_active

    UNION ALL

    SELECT 'place'    AS scope, s.code, s.name, s.description, s.weight,
           es.status, es.verified_at, es.cert_number
    FROM catalog.entity_signals es
    JOIN catalog.signals        s ON s.id = es.signal_id
    JOIN catalog.availability   a ON a.place_id = es.place_id
    WHERE a.item_id = $1 AND a.is_active AND s.is_active
) combined
ORDER BY weight DESC, name`

	sigRows, err := d.DB.Query(r.Context(), signalsSQL, id)
	if err != nil {
		log.Printf("ERROR signals query item=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "signals query failed")
		return
	}
	defer sigRows.Close()

	var signals []Signal
	for sigRows.Next() {
		var scope, code, name string
		var description, certNumber *string
		var verifiedAt *time.Time
		var weight float64
		var status string
		if err := sigRows.Scan(&scope, &code, &name, &description, &weight,
			&status, &verifiedAt, &certNumber); err != nil {
			log.Printf("ERROR signals scan item=%s: %v", id, err)
			writeError(w, http.StatusInternalServerError, "signals scan failed")
			return
		}
		signals = append(signals, Signal{
			Code:        code,
			Name:        name,
			Description: description,
			Weight:      weight,
			Status:      status,
			VerifiedAt:  verifiedAt,
			CertNumber:  certNumber,
		})
	}
	if err := sigRows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "signals iteration failed")
		return
	}

	// ── Places ─────────────────────────────────────────────────────────────
	const placesSQL = `
SELECT pl.id, pl.name, pl.type, a.listing_url
FROM catalog.availability a
JOIN directory.places     pl ON pl.id = a.place_id
WHERE a.item_id = $1 AND a.is_active AND pl.is_active
ORDER BY pl.name`

	plRows, err := d.DB.Query(r.Context(), placesSQL, id)
	if err != nil {
		log.Printf("ERROR places query item=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "places query failed")
		return
	}
	defer plRows.Close()

	var places []placeDetail
	for plRows.Next() {
		var plID pgtype.UUID
		var plName, plType string
		var listingURL *string
		if err := plRows.Scan(&plID, &plName, &plType, &listingURL); err != nil {
			log.Printf("ERROR places scan item=%s: %v", id, err)
			writeError(w, http.StatusInternalServerError, "places scan failed")
			return
		}
		places = append(places, placeDetail{
			ID:         formatUUID(plID),
			Name:       plName,
			Type:       plType,
			ListingURL: listingURL,
		})
	}
	if err := plRows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "places iteration failed")
		return
	}

	// ── Media ──────────────────────────────────────────────────────────────
	const mediaSQL = `
SELECT media_key, role, coalesce(alt_text, ''), width, height
FROM   catalog.media
WHERE  item_id = $1
ORDER  BY sort_order`

	medRows, err := d.DB.Query(r.Context(), mediaSQL, id)
	if err != nil {
		log.Printf("ERROR media query item=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "media query failed")
		return
	}
	defer medRows.Close()

	var media []ItemMedia
	for medRows.Next() {
		var mediaKey, role, altText string
		var width, height int32
		if err := medRows.Scan(&mediaKey, &role, &altText, &width, &height); err != nil {
			log.Printf("ERROR media scan item=%s: %v", id, err)
			writeError(w, http.StatusInternalServerError, "media scan failed")
			return
		}
		media = append(media, d.signAllVariants(mediaKey, role, altText, int(width), int(height)))
	}
	if err := medRows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "media iteration failed")
		return
	}

	// ── Assemble response ──────────────────────────────────────────────────
	var pc *int
	if priceCents != nil {
		v := int(*priceCents)
		pc = &v
	}

	var producer *producerSummary
	if producerID.Valid {
		producer = &producerSummary{
			ID:         formatUUID(producerID),
			Name:       *producerName,
			TrustScore: *producerTrust,
		}
	}

	detail := itemDetail{
		ID:          formatUUID(itemID),
		Name:        itemName,
		Description: description,
		PriceCents:  pc,
		Attributes:  attributes,
		Details:     details,
		CategoryID:  categoryID,
		Brand:       brand,
		Producer:    producer,
		Signals:     signals,
		Places:      places,
		Media:       media,
	}

	writeJSON(w, http.StatusOK, detail)
}
