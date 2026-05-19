// Package auth provides Firebase ID-token validation middleware for cove-api.
package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	firebaseauth "firebase.google.com/go/v4/auth"
)

// TokenVerifier abstracts Firebase ID-token verification so the middleware
// can be unit-tested without a live Firebase project.
type TokenVerifier interface {
	VerifyIDToken(ctx context.Context, idToken string) (*firebaseauth.Token, error)
}

// contextKey is an unexported type for context keys in this package,
// preventing collisions with keys from other packages.
type contextKey string

const (
	uidKey    contextKey = "uid"
	claimsKey contextKey = "claims"
)

// Middleware returns an http.Handler middleware that validates the Firebase ID
// token supplied in the "Authorization: Bearer <token>" header.
//
// On success the verified UID and decoded claims are stored in the request
// context (retrieve them with UIDFromContext and ClaimsFromContext) and the
// next handler is called.
//
// On any failure (missing header, malformed header, invalid or expired token)
// the middleware responds with 401 and a generic JSON error body.  Validation
// details are intentionally omitted to avoid leaking information to callers.
func Middleware(verifier TokenVerifier) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			idToken, ok := bearerToken(r)
			if !ok {
				writeUnauthorized(w)
				return
			}

			decoded, err := verifier.VerifyIDToken(r.Context(), idToken)
			if err != nil {
				writeUnauthorized(w)
				return
			}

			ctx := context.WithValue(r.Context(), uidKey, decoded.UID)
			ctx = context.WithValue(ctx, claimsKey, decoded.Claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// UIDFromContext returns the Firebase UID stored by Middleware.
// The second return value is false if the request was not authenticated.
func UIDFromContext(ctx context.Context) (string, bool) {
	uid, ok := ctx.Value(uidKey).(string)
	return uid, ok
}

// ClaimsFromContext returns the decoded token claims stored by Middleware.
// The second return value is false if the request was not authenticated.
func ClaimsFromContext(ctx context.Context) (map[string]interface{}, bool) {
	claims, ok := ctx.Value(claimsKey).(map[string]interface{})
	return claims, ok
}

// bearerToken extracts the raw token string from an
// "Authorization: Bearer <token>" header.  Returns ("", false) when the
// header is absent, not in Bearer form, or the token part is empty.
func bearerToken(r *http.Request) (string, bool) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", false
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
		return "", false
	}

	token := strings.TrimSpace(parts[1])
	if token == "" {
		return "", false
	}

	return token, true
}

// writeUnauthorized writes a 401 response with a generic JSON error body.
// The response intentionally omits the underlying reason to avoid leaking
// information about token format or validation logic.
func writeUnauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": "unauthorized"})
}
