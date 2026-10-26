package handler

import (
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

// producerDetail is the GET /producers/:id response body.
type producerDetail struct {
	ID          string          `json:"id"`
	Name        string          `json:"name"`
	Description *string         `json:"description,omitempty"`
	Tier        string          `json:"tier"`
	TrustScore  float64         `json:"trust_score"`
	City        *string         `json:"city,omitempty"`
	State       *string         `json:"state,omitempty"`
	WebsiteURL  *string         `json:"website_url,omitempty"`
	Signals     []Signal        `json:"signals"`
	Places      []producerPlace `json:"places"`
}

type producerPlace struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Type string `json:"type"`
	Slug string `json:"slug,omitempty"`
}

// ProducerHandler handles GET /producers/{id}.
// Returns producer detail with signals and associated place list.
func (d *Deps) ProducerHandler(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "missing producer id")
		return
	}

	// ── Core producer ────────────────────────────────────────────────────────
	const producerSQL = `
SELECT id, name, description, tier, trust_score, city, state, website_url
FROM   directory.producers
WHERE  id = $1 AND is_active`

	var (
		producerID                           pgtype.UUID
		name, tier                           string
		description, city, state, websiteURL *string
		trustScore                           float64
	)
	err := d.DB.QueryRow(r.Context(), producerSQL, id).Scan(
		&producerID, &name, &description, &tier, &trustScore,
		&city, &state, &websiteURL,
	)
	if err != nil {
		if isNotFound(err) {
			writeError(w, http.StatusNotFound, "producer not found")
			return
		}
		log.Printf("ERROR producer query id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "producer query failed")
		return
	}

	// ── Signals ──────────────────────────────────────────────────────────────
	const signalsSQL = `
SELECT s.code, s.name, s.description, s.weight, es.status, es.verified_at, es.cert_number
FROM   catalog.entity_signals es
JOIN   catalog.signals s ON s.id = es.signal_id
WHERE  es.producer_id = $1 AND s.is_active
ORDER  BY s.weight DESC, s.name`

	signals, err := querySignals(d, r, signalsSQL, id)
	if err != nil {
		log.Printf("ERROR producer signals id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "signals query failed")
		return
	}

	// ── Places ───────────────────────────────────────────────────────────────
	const placesSQL = `
SELECT id, name, type, coalesce(slug, '')
FROM   directory.places
WHERE  run_by_producer_id = $1 AND is_active
ORDER  BY name`

	plRows, err := d.DB.Query(r.Context(), placesSQL, id)
	if err != nil {
		log.Printf("ERROR producer places id=%s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "places query failed")
		return
	}
	defer plRows.Close()

	var places []producerPlace
	for plRows.Next() {
		var plID pgtype.UUID
		var plName, plType, plSlug string
		if err := plRows.Scan(&plID, &plName, &plType, &plSlug); err != nil {
			log.Printf("ERROR producer places scan id=%s: %v", id, err)
			writeError(w, http.StatusInternalServerError, "places scan failed")
			return
		}
		places = append(places, producerPlace{
			ID:   formatUUID(plID),
			Name: plName,
			Type: plType,
			Slug: plSlug,
		})
	}
	if err := plRows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "places iteration failed")
		return
	}

	writeJSON(w, http.StatusOK, producerDetail{
		ID:          formatUUID(producerID),
		Name:        name,
		Description: description,
		Tier:        tier,
		TrustScore:  trustScore,
		City:        city,
		State:       state,
		WebsiteURL:  websiteURL,
		Signals:     signals,
		Places:      places,
	})
}
