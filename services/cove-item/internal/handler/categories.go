package handler

import (
	"log"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5/pgtype"
)

// CategoryNode is one node in the GET /categories response tree.
type CategoryNode struct {
	ID       string          `json:"id"`
	Name     string          `json:"name"`
	Path     string          `json:"path"`
	ImageKey *string         `json:"image_key,omitempty"`
	Children []*CategoryNode `json:"children,omitempty"`
}

// CategoriesHandler handles GET /categories.
// Returns the full category tree ordered by ltree path, ready for the
// onboarding picker and browse surface.
func (d *Deps) CategoriesHandler(w http.ResponseWriter, r *http.Request) {
	const sql = `
SELECT id, name, path::text, image_key
FROM   catalog.categories
ORDER  BY path`

	rows, err := d.DB.Query(r.Context(), sql)
	if err != nil {
		log.Printf("ERROR categories query: %v", err)
		writeError(w, http.StatusInternalServerError, "categories query failed")
		return
	}
	defer rows.Close()

	var cats []catFlat
	for rows.Next() {
		var id pgtype.UUID
		var name, path string
		var imageKey *string
		if err := rows.Scan(&id, &name, &path, &imageKey); err != nil {
			log.Printf("ERROR categories scan: %v", err)
			writeError(w, http.StatusInternalServerError, "category scan failed")
			return
		}
		cats = append(cats, catFlat{id: formatUUID(id), name: name, path: path, imageKey: imageKey})
	}
	if err := rows.Err(); err != nil {
		log.Printf("ERROR categories rows: %v", err)
		writeError(w, http.StatusInternalServerError, "category iteration failed")
		return
	}

	tree := buildCategoryTree(cats)
	writeJSON(w, http.StatusOK, map[string]any{"categories": tree})
}

type catFlat struct {
	id       string
	name     string
	path     string
	imageKey *string
}

// buildCategoryTree assembles a slice of root CategoryNode trees from a flat
// list of (id, name, path, image_key) rows sorted by ltree path. Parent paths
// are derived by stripping the last dot-delimited segment.
func buildCategoryTree(cats []catFlat) []*CategoryNode {
	nodeMap := make(map[string]*CategoryNode, len(cats))
	for _, c := range cats {
		nodeMap[c.path] = &CategoryNode{ID: c.id, Name: c.name, Path: c.path, ImageKey: c.imageKey}
	}

	var roots []*CategoryNode
	for _, c := range cats {
		node := nodeMap[c.path]
		if dot := strings.LastIndex(c.path, "."); dot >= 0 {
			parentPath := c.path[:dot]
			if parent, ok := nodeMap[parentPath]; ok {
				parent.Children = append(parent.Children, node)
				continue
			}
		}
		roots = append(roots, node)
	}
	return roots
}
