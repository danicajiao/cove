package handler

import (
	"log"
	"net/http"
	"strconv"

	"github.com/jackc/pgx/v5/pgtype"
)

// Default and ceiling for the number of category cards returned. Callers tune
// the count via the optional ?limit= query parameter.
const (
	defaultCategoryLimit = 25
	maxCategoryLimit     = 100
)

type recommendedCategory struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Path     string  `json:"path"`
	ImageKey *string `json:"image_key,omitempty"`
}

type recommendedCategoriesResponse struct {
	Categories []recommendedCategory `json:"categories"`
}

// RecommendedCategoriesHandler handles GET /recommendations/categories.
//
// The home shelf shows level 1 categories only. One query ranks them:
//  1. Level 1 categories the user selected as interests come first, ordered by
//     the user's own engagement, then global engagement, then name.
//  2. The remaining level 1 categories follow, ordered by global engagement,
//     then name.
//
// Engagement is the count of profile.activity in the last 30 days, rolled up to
// the level 1 ancestor: activity on food.coffee.whole_bean, or on an item in
// it, counts toward food. Users without a profile (or without interests) get
// every level 1 category ordered by global engagement. Level 2 interests are
// stored but don't affect the shelf.
//
// The result count is capped by the optional ?limit= query parameter
// (default 25, max 100), which covers every level 1 category by default.
func (d *Deps) RecommendedCategoriesHandler(w http.ResponseWriter, r *http.Request) {
	authUID := r.Header.Get("X-Cove-Uid")

	limit := defaultCategoryLimit
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= maxCategoryLimit {
			limit = n
		}
	}

	// ── Resolve user_id (best-effort — new users without a profile get the global order) ──
	var userIDUUID pgtype.UUID
	userLookupErr := d.DB.QueryRow(r.Context(),
		`SELECT id FROM profile.users WHERE auth_uid = $1`, authUID).Scan(&userIDUUID)

	if userLookupErr != nil && !isNotFound(userLookupErr) {
		log.Printf("ERROR RecommendedCategoriesHandler lookup auth_uid=%s: %v", authUID, userLookupErr)
		writeError(w, http.StatusInternalServerError, "recommendations query failed")
		return
	}

	// NULL user_id matches no interests or activity, leaving only the global order.
	var userID *string
	if userLookupErr == nil {
		id := formatUUID(userIDUUID)
		userID = &id
	}

	const shelfSQL = `
WITH recent AS (
    SELECT e.user_id, subpath(c.path, 0, 1) AS root_path
    FROM profile.activity e
    LEFT JOIN catalog.items it ON it.id = e.item_id
    JOIN catalog.categories c ON c.id = COALESCE(e.category_id, it.category_id)
    WHERE e.created_at > now() - interval '30 days'
),
global_engagement AS (
    SELECT root_path, COUNT(*) AS n FROM recent GROUP BY root_path
),
user_engagement AS (
    SELECT root_path, COUNT(*) AS n FROM recent WHERE user_id = $1::uuid GROUP BY root_path
),
selected AS (
    SELECT category_id FROM profile.interests WHERE user_id = $1::uuid
)
SELECT c.id, c.name, c.path::text, c.image_key
FROM catalog.categories c
LEFT JOIN selected s          ON s.category_id = c.id
LEFT JOIN user_engagement u   ON u.root_path = c.path
LEFT JOIN global_engagement g ON g.root_path = c.path
WHERE nlevel(c.path) = 1
ORDER BY (s.category_id IS NOT NULL) DESC,
         CASE WHEN s.category_id IS NOT NULL THEN COALESCE(u.n, 0) ELSE 0 END DESC,
         COALESCE(g.n, 0) DESC,
         c.name ASC
LIMIT $2`

	rows, err := d.DB.Query(r.Context(), shelfSQL, userID, limit)
	if err != nil {
		log.Printf("ERROR RecommendedCategoriesHandler query auth_uid=%s: %v", authUID, err)
		writeError(w, http.StatusInternalServerError, "recommendations query failed")
		return
	}
	defer rows.Close()

	categories := []recommendedCategory{}
	for rows.Next() {
		var id pgtype.UUID
		var name, path string
		var imageKey *string
		if err := rows.Scan(&id, &name, &path, &imageKey); err != nil {
			log.Printf("ERROR RecommendedCategoriesHandler scan auth_uid=%s: %v", authUID, err)
			writeError(w, http.StatusInternalServerError, "recommendations scan failed")
			return
		}
		categories = append(categories, recommendedCategory{
			ID:       formatUUID(id),
			Name:     name,
			Path:     path,
			ImageKey: imageKey,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "recommendations iteration failed")
		return
	}

	writeJSON(w, http.StatusOK, recommendedCategoriesResponse{Categories: categories})
}
