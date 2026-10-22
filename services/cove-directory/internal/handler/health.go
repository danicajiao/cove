package handler

import "net/http"

// HealthHandler handles GET /health.
// Unauthenticated — used by Kubernetes liveness and readiness probes.
func (d *Deps) HealthHandler(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"service": "cove-directory",
		"status":  "ok",
		"commit":  d.CommitSHA,
	})
}
