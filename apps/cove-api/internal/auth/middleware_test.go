package auth_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	fbauth "firebase.google.com/go/v4/auth"

	"github.com/danicajiao/cove/apps/cove-api/internal/auth"
)

// mockVerifier implements TokenVerifier for use in unit tests.
type mockVerifier struct {
	token *fbauth.Token
	err   error
}

func (m *mockVerifier) VerifyIDToken(_ context.Context, _ string) (*fbauth.Token, error) {
	return m.token, m.err
}

// okHandler is a test handler that writes 200 OK.
var okHandler = http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
})

func TestMiddleware_MissingAuthorizationHeader(t *testing.T) {
	handler := auth.Middleware(&mockVerifier{err: errors.New("should not be called")})(okHandler)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rr.Code)
	}
}

func TestMiddleware_MalformedHeader_NoBearer(t *testing.T) {
	handler := auth.Middleware(&mockVerifier{})(okHandler)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rr.Code)
	}
}

func TestMiddleware_MalformedHeader_BearerWithNoToken(t *testing.T) {
	handler := auth.Middleware(&mockVerifier{})(okHandler)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer ")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rr.Code)
	}
}

func TestMiddleware_ExpiredToken(t *testing.T) {
	verifier := &mockVerifier{err: errors.New("firebase: ID token has expired")}
	handler := auth.Middleware(verifier)(okHandler)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer expired.token.here")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rr.Code)
	}
}

func TestMiddleware_ValidToken_Passes(t *testing.T) {
	const wantUID = "user-abc-123"

	verifier := &mockVerifier{
		token: &fbauth.Token{
			UID:    wantUID,
			Claims: map[string]interface{}{"role": "member"},
		},
	}

	var gotUID string
	downstream := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := auth.UIDFromContext(r.Context())
		if !ok {
			t.Error("UIDFromContext: expected UID in context, got none")
		}
		gotUID = uid
		w.WriteHeader(http.StatusOK)
	})

	handler := auth.Middleware(verifier)(downstream)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer valid.token.here")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
	if gotUID != wantUID {
		t.Errorf("expected UID %q in context, got %q", wantUID, gotUID)
	}
}

func TestMiddleware_ValidToken_ClaimsInContext(t *testing.T) {
	verifier := &mockVerifier{
		token: &fbauth.Token{
			UID:    "user-xyz",
			Claims: map[string]interface{}{"email": "user@example.com"},
		},
	}

	var gotClaims map[string]interface{}
	downstream := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := auth.ClaimsFromContext(r.Context())
		if !ok {
			t.Error("ClaimsFromContext: expected claims in context, got none")
		}
		gotClaims = claims
		w.WriteHeader(http.StatusOK)
	})

	handler := auth.Middleware(verifier)(downstream)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer valid.token.here")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
	if gotClaims["email"] != "user@example.com" {
		t.Errorf("expected email claim in context, got %v", gotClaims)
	}
}

func TestMiddleware_ErrorResponseDoesNotLeakDetails(t *testing.T) {
	// Ensure the 401 body does not echo back Firebase's internal error message.
	verifier := &mockVerifier{err: errors.New("firebase: ID token has expired at 2024-01-01")}
	handler := auth.Middleware(verifier)(okHandler)

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer expired.token")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	body := rr.Body.String()
	if strings.Contains(body, "firebase") || strings.Contains(body, "expired") {
		t.Errorf("401 response body leaks error details: %q", body)
	}
}
