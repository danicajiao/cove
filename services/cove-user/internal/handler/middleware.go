package handler

import (
	"log"
	"net/http"
)

// UIDMiddleware rejects requests that do not carry a non-empty X-Cove-Uid
// header with 401 Unauthorized. cove-user does NOT validate Firebase tokens
// itself — it trusts the UID injected by the upstream cove-api gateway.
func UIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Cove-Uid") == "" {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// isGuest reports whether the caller signed in anonymously. cove-api always
// sets X-Cove-Guest to "true" or "false" from the verified token, overwriting
// anything the client sent; a missing header counts as not a guest.
func isGuest(r *http.Request) bool {
	return r.Header.Get("X-Cove-Guest") == "true"
}

// AccountRequiredMiddleware rejects guests with 403 account_required. Wrap the
// routes that need a signed-up account (favorites and follows); the iOS app
// turns this response into a sign-up prompt.
func AccountRequiredMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if isGuest(r) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			_, _ = w.Write([]byte(`{"error":"account_required"}`))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// TouchLastSeen records that the caller used Cove today. The UPDATE only
// matches when last_seen_at is more than a day old, so it writes at most once a
// day per user; other requests cost an index lookup and no write. Guest cleanup
// deletes guests whose last_seen_at is older than 30 days. Errors are logged
// and the request continues, since a missed update is retried on the next one.
// Must run after UIDMiddleware.
func (d *Deps) TouchLastSeen(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, err := d.DB.Exec(r.Context(), touchLastSeenSQL, r.Header.Get("X-Cove-Uid")); err != nil {
			log.Printf("ERROR TouchLastSeen: %v", err)
		}
		next.ServeHTTP(w, r)
	})
}

const touchLastSeenSQL = `
UPDATE profile.users SET last_seen_at = now()
WHERE auth_uid = $1 AND last_seen_at < now() - interval '1 day'`
