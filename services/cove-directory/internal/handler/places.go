package handler

import (
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

// placeDetailFull is the GET /places/:id response body.
type placeDetailFull struct {
	ID           string      `json:"id"`
	Name         string      `json:"name"`
	Description  *string     `json:"description,omitempty"`
	Type         string      `json:"type"`
	TrustScore   float64     `json:"trust_score"`
	City         *string     `json:"city,omitempty"`
	State        *string     `json:"state,omitempty"`
	Address      *string     `json:"address,omitempty"`
	WebsiteURL   *string     `json:"website_url,omitempty"`
	ProducerID   string      `json:"producer_id,omitempty"`
	ProducerName string      `json:"producer_name,omitempty"`
	Signals      []Signal    `json:"signals"`
	Items        []placeItem `json:"items"`
}

type placeItem struct {
	ID         string         `json:"id"`
	Name       string         `json:"name"`
	PriceCents *int           `json:"price_cents,omitempty"`
	ListingURL *string        `json:"listing_url,omitempty"`
	Image      *ImageVariants `json:"image,omitempty"`
}

// PlaceHandler handles GET /places/{id}.
// Returns place detail with signals and list of available items.
func (d *Deps) PlaceHandler(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "missing place id")
		return
	}

	// ── Core place + producer ────────────────────────────────────────────────
	const plSQL = `
SELECT
    pl.id, pl.name, pl.description, pl.type, pl.trust_score,
    pl.city, pl.state, pl.address, pl.website_url,
    pr.id AS producer_id, pr.name AS producer_name
FROM directory.places pl
LEFT JOIN directory.producers pr ON pr.id = pl.run_by_producer_id
WHERE pl.id = $1 AND pl.is_active`

	var (
		plID                                   pgtype.UUID
		plName, plType                         string
		plDesc, plCity, plState, plAddr, plURL *string
		trustScore                             float64
		producerID                             pgtype.UUID
		producerName                           *string
	)
	err := d.DB.QueryRow(r.Context(), plSQL, id).Scan(
		&plID, &plName, &plDesc, &plType, &trustScore,
		&plCity, &plState, &plAddr, &plURL,
		&producerID, &producerName,
	)
	if err != nil {
		if isNotFound(err) {
			writeError(w, http.StatusNotFound, "place not found")
			return
		}
		log.Printf("ERROR place query id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "place query failed")
		return
	}

	// ── Signals ──────────────────────────────────────────────────────────────
	const signalsSQL = `
SELECT s.code, s.name, s.description, s.weight, es.status, es.verified_at, es.cert_number
FROM   catalog.entity_signals es
JOIN   catalog.signals s ON s.id = es.signal_id
WHERE  es.place_id = $1 AND s.is_active
ORDER  BY s.weight DESC, s.name`

	signals, err := querySignals(d, r, signalsSQL, id)
	if err != nil {
		log.Printf("ERROR place signals id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "signals query failed")
		return
	}

	// ── Items available at this place ────────────────────────────────────────
	const itemsSQL = `
SELECT
    p.id, p.name, p.price_cents,
    a.listing_url,
    img.media_key, img.width, img.height
FROM catalog.availability a
JOIN catalog.items        p   ON p.id = a.item_id
LEFT JOIN LATERAL (
    SELECT media_key, width, height
    FROM   catalog.media
    WHERE  item_id = p.id AND role = 'primary'
    LIMIT  1
) img ON TRUE
WHERE a.place_id = $1 AND a.is_active AND p.is_active
ORDER BY p.name`

	itemRows, err := d.DB.Query(r.Context(), itemsSQL, id)
	if err != nil {
		log.Printf("ERROR place items id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "items query failed")
		return
	}
	defer itemRows.Close()

	var items []placeItem
	for itemRows.Next() {
		var itemID pgtype.UUID
		var itemName string
		var priceCents *int32
		var listingURL, mediaKey *string
		var imgWidth, imgHeight *int32

		if err := itemRows.Scan(&itemID, &itemName, &priceCents, &listingURL,
			&mediaKey, &imgWidth, &imgHeight); err != nil {
			log.Printf("ERROR place items scan id=%s: %v", id, err)
			writeError(w, http.StatusInternalServerError, "items scan failed")
			return
		}

		var pc *int
		if priceCents != nil {
			v := int(*priceCents)
			pc = &v
		}

		var img *ImageVariants
		if mediaKey != nil && *mediaKey != "" {
			w2, h2 := 0, 0
			if imgWidth != nil {
				w2 = int(*imgWidth)
			}
			if imgHeight != nil {
				h2 = int(*imgHeight)
			}
			img = d.signListVariants(*mediaKey, w2, h2)
		}

		items = append(items, placeItem{
			ID:         formatUUID(itemID),
			Name:       itemName,
			PriceCents: pc,
			ListingURL: listingURL,
			Image:      img,
		})
	}
	if err := itemRows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "items iteration failed")
		return
	}

	// ── Assemble response ────────────────────────────────────────────────────
	producerIDStr := ""
	producerNameStr := ""
	if producerID.Valid {
		producerIDStr = formatUUID(producerID)
	}
	if producerName != nil {
		producerNameStr = *producerName
	}

	writeJSON(w, http.StatusOK, placeDetailFull{
		ID:           formatUUID(plID),
		Name:         plName,
		Description:  plDesc,
		Type:         plType,
		TrustScore:   trustScore,
		City:         plCity,
		State:        plState,
		Address:      plAddr,
		WebsiteURL:   plURL,
		ProducerID:   producerIDStr,
		ProducerName: producerNameStr,
		Signals:      signals,
		Items:        items,
	})
}
