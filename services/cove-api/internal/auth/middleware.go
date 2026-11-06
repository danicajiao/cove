// Package auth provides Firebase ID-token validation middleware for cove-api.
package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
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
	guestKey  contextKey = "guest"
)

// anonymousProvider is the Firebase sign-in provider of an anonymous (guest)
// user, as reported in the token's firebase.sign_in_provider claim.
const anonymousProvider = "anonymous"

// Identity headers the gateway sets on every forwarded request. Upstream
// services trust them without re-validating the Firebase token, so they are
// always overwritten (never passed through from the client).
const (
	HeaderUID   = "X-Cove-Uid"
	HeaderGuest = "X-Cove-Guest"
)

// Middleware returns an http.Handler middleware that validates the Firebase ID
// token supplied in the "Authorization: Bearer <token>" header.
//
// On success the verified UID, decoded claims and guest status are stored in
// the request context (retrieve them with UIDFromContext, ClaimsFromContext
// and IsGuestFromContext) and the next handler is called. A caller is a guest
// when the token's sign-in provider is "anonymous".
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
			ctx = context.WithValue(ctx, guestKey, decoded.Firebase.SignInProvider == anonymousProvider)
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

// IsGuestFromContext reports whether Middleware verified an anonymous (guest)
// token for this request. It is false for unauthenticated requests.
func IsGuestFromContext(ctx context.Context) bool {
	guest, _ := ctx.Value(guestKey).(bool)
	return guest
}

// SetIdentityHeaders writes the gateway's identity headers onto r before it is
// forwarded upstream. X-Cove-Uid carries the verified UID and X-Cove-Guest is
// always "true" or "false". Any client-sent values are replaced, and both
// headers are removed when the request was not authenticated, so a client can
// never choose its own identity.
func SetIdentityHeaders(r *http.Request) {
	uid, ok := UIDFromContext(r.Context())
	if !ok {
		r.Header.Del(HeaderUID)
		r.Header.Del(HeaderGuest)
		return
	}
	r.Header.Set(HeaderUID, uid)
	r.Header.Set(HeaderGuest, strconv.FormatBool(IsGuestFromContext(r.Context())))
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
