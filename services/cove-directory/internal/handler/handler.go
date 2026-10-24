// Package handler implements the HTTP handlers for cove-directory endpoints.
// All handlers share a Deps struct that holds the database pool, imgproxy
// signer, and build metadata.
package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/danicajiao/cove/packages/imgproxy"
)

// Deps holds the shared dependencies injected into every handler.
type Deps struct {
	DB        *pgxpool.Pool
	Signer    *imgproxy.Signer
	CommitSHA string
}

// Signal is a trust signal attached to a producer, place, or item.
type Signal struct {
	Code        string     `json:"code"`
	Name        string     `json:"name"`
	Description *string    `json:"description,omitempty"`
	Weight      float64    `json:"weight"`
	Status      string     `json:"status"`
	VerifiedAt  *time.Time `json:"verified_at,omitempty"`
	CertNumber  *string    `json:"cert_number,omitempty"`
}

// ImageVariants holds signed imgproxy URLs for list-view sizes (thumb, sm, md).
type ImageVariants struct {
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Thumb  string `json:"thumb"`
	Sm     string `json:"sm"`
	Md     string `json:"md"`
}

// writeJSON writes a JSON-encoded body with the given HTTP status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// writeError writes a JSON error body with the given HTTP status code.
func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// formatUUID converts a pgtype.UUID to its standard hyphenated hex string.
func formatUUID(u pgtype.UUID) string {
	if !u.Valid {
		return ""
	}
	b := u.Bytes
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// signListVariants signs thumb, sm, and md for a media_key.
// Returns nil if mediaKey is empty (no primary image on record).
func (d *Deps) signListVariants(mediaKey string, width, height int) *ImageVariants {
	if mediaKey == "" {
		return nil
	}
	urls := d.Signer.SignVariants(mediaKey, "thumb", "sm", "md")
	return &ImageVariants{
		Width:  width,
		Height: height,
		Thumb:  urls["thumb"],
		Sm:     urls["sm"],
		Md:     urls["md"],
	}
}

// isNotFound returns true when err is a pgx "no rows" sentinel.
func isNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}

// querySignals runs a signals SELECT that takes a single $1 entity-ID argument
// and returns the results as []Signal. The caller provides the full SQL and the
// id value for $1.
func querySignals(d *Deps, r *http.Request, sql, id string) ([]Signal, error) {
	rows, err := d.DB.Query(r.Context(), sql, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var signals []Signal
	for rows.Next() {
		var code, name, status string
		var description, certNumber *string
		var verifiedAt *time.Time
		var weight float64
		if err := rows.Scan(&code, &name, &description, &weight, &status, &verifiedAt, &certNumber); err != nil {
			return nil, err
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
	return signals, rows.Err()
}
