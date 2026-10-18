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
// Algorithm:
//  1. Resolve auth_uid → internal user_id. If the user has no profile yet,
//     skip straight to the global fallback (new users still get recommendations).
//  2. If the user has interests, return those categories ordered by engagement
//     count in profile.events (last 30 days) descending.
//  3. If the user has no interests (or no profile), fall back to all leaf
//     categories ordered by total event count across all users (last 30 days).
//  4. If no events exist at all, the COALESCE(engagement, 0) clause naturally
//     falls back to alphabetical by name.
//
// The result count is capped by the optional ?limit= query parameter
// (default 25, max 100).
func (d *Deps) RecommendedCategoriesHandler(w http.ResponseWriter, r *http.Request) {
	authUID := r.Header.Get("X-Cove-Uid")

	limit := defaultCategoryLimit
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= maxCategoryLimit {
			limit = n
		}
	}

	// ── Resolve user_id (best-effort — new users without a profile skip to fallback) ──
	var userIDUUID pgtype.UUID
	userLookupErr := d.DB.QueryRow(r.Context(),
		`SELECT id FROM profile.users WHERE auth_uid = $1`, authUID).Scan(&userIDUUID)

	if userLookupErr != nil && !isNotFound(userLookupErr) {
		log.Printf("ERROR RecommendedCategoriesHandler lookup auth_uid=%s: %v", authUID, userLookupErr)
		writeError(w, http.StatusInternalServerError, "recommendations query failed")
		return
	}

	categories := []recommendedCategory{}

	// ── Query 1: interest-based personalization (only when user has a profile) ──
	if userLookupErr == nil {
		userID := formatUUID(userIDUUID)

		const interestSQL = `
SELECT c.id, c.name, c.path::text, c.image_key
FROM profile.interests i
JOIN catalog.categories c ON c.id = i.category_id
LEFT JOIN (
    SELECT category_id, COUNT(*) AS engagement
    FROM profile.events
    WHERE user_id = $1
      AND category_id IS NOT NULL
      AND created_at > now() - interval '30 days'
    GROUP BY category_id
) e ON e.category_id = i.category_id
WHERE i.user_id = $1
ORDER BY COALESCE(e.engagement, 0) DESC, c.name ASC
LIMIT $2`

		rows, err := d.DB.Query(r.Context(), interestSQL, userID, limit)
		if err != nil {
			log.Printf("ERROR RecommendedCategoriesHandler interest query user_id=%s: %v", userID, err)
			writeError(w, http.StatusInternalServerError, "recommendations query failed")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var id pgtype.UUID
			var name, path string
			var imageKey *string
			if err := rows.Scan(&id, &name, &path, &imageKey); err != nil {
				log.Printf("ERROR RecommendedCategoriesHandler interest scan user_id=%s: %v", userID, err)
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
	}

	// If interests filled the limit exactly, return now — no top-up needed.
	if len(categories) >= limit {
		writeJSON(w, http.StatusOK, recommendedCategoriesResponse{Categories: categories})
		return
	}

	// ── Query 2: top-up / global fallback ────────────────────────────────────
	// When the user has fewer interests than the requested limit, fill the
	// remainder from globally popular leaf categories. Exclude any category
	// already returned from interests so there are no duplicates.
	remaining := limit - len(categories)

	excludeIDs := make([]string, len(categories))
	for i, cat := range categories {
		excludeIDs[i] = cat.ID
	}

	const fallbackSQL = `
SELECT c.id, c.name, c.path::text, c.image_key
FROM catalog.categories c
LEFT JOIN (
    SELECT category_id, COUNT(*) AS engagement
    FROM profile.events
    WHERE category_id IS NOT NULL
      AND created_at > now() - interval '30 days'
    GROUP BY category_id
) e ON e.category_id = c.id
WHERE c.is_leaf = true
  AND NOT (c.id::text = ANY($2))
ORDER BY COALESCE(e.engagement, 0) DESC, c.name ASC
LIMIT $1`

	fallbackRows, err := d.DB.Query(r.Context(), fallbackSQL, remaining, excludeIDs)
	if err != nil {
		log.Printf("ERROR RecommendedCategoriesHandler fallback query auth_uid=%s: %v", authUID, err)
		writeError(w, http.StatusInternalServerError, "recommendations query failed")
		return
	}
	defer fallbackRows.Close()

	for fallbackRows.Next() {
		var id pgtype.UUID
		var name, path string
		var imageKey *string
		if err := fallbackRows.Scan(&id, &name, &path, &imageKey); err != nil {
			log.Printf("ERROR RecommendedCategoriesHandler fallback scan auth_uid=%s: %v", authUID, err)
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
	if err := fallbackRows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "recommendations iteration failed")
		return
	}

	writeJSON(w, http.StatusOK, recommendedCategoriesResponse{Categories: categories})
}
