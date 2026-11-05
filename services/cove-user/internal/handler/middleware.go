package handler

import "net/http"

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
